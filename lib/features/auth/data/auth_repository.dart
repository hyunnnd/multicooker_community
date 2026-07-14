import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_token_storage.dart';
import 'auth_api.dart';
import 'models/complete_register_request.dart';
import 'models/complete_reset_password_request.dart';
import 'models/google_token_exchange_request.dart';
import 'models/login_request.dart';
import 'models/refresh_request.dart';
import 'models/token_response.dart';

class AuthRepository {
  AuthRepository(this._authApi, this._localAuthApi, this._storage);

  final AuthApi _authApi;
  final LocalAuthApi _localAuthApi;
  final SecureTokenStorage _storage;

  Future<bool> hasAccessToken() async {
    final token = await _storage.readAuthAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Restores the current company account.
  ///
  /// The deployed company server currently issues JWTs from `/auth/login` and
  /// `/auth/google/token`, but it does not expose `/auth/me`. Older app builds
  /// treated that expected 404 response as a failed login and displayed
  /// `Not Found` even though token issuance and local API synchronization had
  /// already succeeded. When `/auth/me` is unavailable, recover the account
  /// email from the verified company JWT (`sub`) instead.
  ///
  /// A real 401 response is still propagated so an invalid/expired session is
  /// not mistaken for a valid login.
  Future<Map<String, dynamic>> restoreCompanyProfile() async {
    try {
      return await _guard(() => _authApi.me());
    } on ApiException catch (error) {
      if (error.statusCode != 404 && error.statusCode != 405) rethrow;
      return _profileFromStoredCompanyToken();
    }
  }

  /// Ensures that the local SQLite API token belongs to the same company
  /// account and is usable. Existing tokens are not deleted before a successful
  /// replacement, so a transient startup/network failure no longer leaves the
  /// app permanently authenticated without community/profile data.
  Future<void> ensureLocalApiSession({
    Map<String, dynamic>? companyProfile,
  }) async {
    final profile = companyProfile ?? await restoreCompanyProfile();
    final email = _readString(profile, ['email'])?.toLowerCase();
    if (email == null || email.isEmpty) {
      throw ApiException('로그인 계정의 이메일 정보를 확인할 수 없습니다.');
    }

    final storedEmail =
        (await _storage.readApiAccountEmail())?.trim().toLowerCase();
    var apiToken = await _storage.readApiAccessToken();
    if (apiToken != null && apiToken.isNotEmpty && storedEmail != email) {
      // Tokens created by older builds did not record their account email.
      // Clear those too rather than risking data from a previous account.
      await _storage.clearApiTokens();
      apiToken = null;
    }

    final accountMatches = storedEmail == email;
    if (accountMatches && apiToken != null && apiToken.isNotEmpty) {
      try {
        final localProfile = await _guard(() => _localAuthApi.me());
        final localEmail =
            _readString(localProfile, ['email'])?.trim().toLowerCase();
        if (localEmail == email) return;
      } catch (_) {
        // The refresh/recovery interceptor may already have tried. A direct
        // sync below is the final startup recovery path.
      }
    }

    await _syncLocalApiTokenWithRetry(profile, fallbackEmail: email);
  }

  Future<void> sendRegisterEmailCode(String email) =>
      _guard(() => _authApi.sendRegisterEmailCode(email));

  Future<void> verifyRegisterEmailCode(String email, String code) =>
      _guard(() => _authApi.verifyRegisterEmailCode(email, code));

  Future<void> completeRegister(CompleteRegisterRequest request) =>
      _guard(() => _authApi.completeRegister(request));

  Future<void> sendResetPasswordEmailCode(String email) =>
      _guard(() => _authApi.sendResetPasswordEmailCode(email));

  Future<void> verifyResetPasswordEmailCode(String email, String code) =>
      _guard(() => _authApi.verifyResetPasswordEmailCode(email, code));

  Future<void> completeResetPassword(CompleteResetPasswordRequest request) =>
      _guard(() => _authApi.completeResetPassword(request));

  Future<TokenResponse> login(String email, String password) async {
    return _guard(() async {
      final authToken = await _authApi.login(
        LoginRequest(email: email, password: password),
      );
      _ensureValidTokenResponse(authToken);
      await _storage.saveAuthTokens(
        accessToken: authToken.accessToken,
        refreshToken: authToken.refreshToken,
      );
      await _storage.clearApiTokens();
      await _syncLocalApiTokenFallback(email: email);
      return authToken;
    });
  }

  Future<TokenResponse> loginWithGoogleCode(String code) async {
    return _guard(() async {
      final normalizedCode = code.trim();
      if (normalizedCode.isEmpty) {
        throw ApiException('구글 로그인 코드가 없습니다.');
      }

      final authToken = await _authApi.exchangeGoogleCode(
        GoogleTokenExchangeRequest(normalizedCode),
      );
      _ensureValidTokenResponse(authToken);

      await _storage.saveAuthTokens(
        accessToken: authToken.accessToken,
        refreshToken: authToken.refreshToken,
      );
      await _storage.clearApiTokens();

      final email = _emailFromJwt(authToken.accessToken);
      await _syncLocalApiTokenFallback(email: email);
      return authToken;
    });
  }

  Future<TokenResponse?> refreshToken() async {
    final refreshToken = await _storage.readAuthRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    return _guard(() async {
      final authToken = await _authApi.refresh(RefreshRequest(refreshToken));
      _ensureValidTokenResponse(authToken);
      await _storage.saveAuthTokens(
        accessToken: authToken.accessToken,
        refreshToken: authToken.refreshToken,
      );
      await _syncLocalApiTokenFallback(
        email: _emailFromJwt(authToken.accessToken),
      );
      return authToken;
    });
  }

  Future<void> logout() async {
    final authRefreshToken = await _storage.readAuthRefreshToken();
    final apiRefreshToken = await _storage.readApiRefreshToken();
    try {
      if (authRefreshToken != null && authRefreshToken.isNotEmpty) {
        await _authApi.logout(RefreshRequest(authRefreshToken));
      }
    } catch (_) {
      // Even if the company auth server is unreachable, local tokens must clear.
    }
    try {
      if (apiRefreshToken != null && apiRefreshToken.isNotEmpty) {
        await _localAuthApi.logout(RefreshRequest(apiRefreshToken));
      }
    } catch (_) {
      // Ignore local logout failure; token storage is cleared below.
    } finally {
      await _storage.clear();
    }
  }

  Future<void> clearStoredSession() => _storage.clear();

  Future<Map<String, dynamic>> me() async {
    try {
      return await restoreCompanyProfile();
    } on ApiException catch (error) {
      // Keep a previously authenticated session usable during a temporary
      // company-server/network failure, but never mask an explicit 401.
      if (error.statusCode == 401) rethrow;
      return _profileFromStoredCompanyToken();
    } catch (_) {
      return _profileFromStoredCompanyToken();
    }
  }

  Future<Map<String, dynamic>> _profileFromStoredCompanyToken() async {
    final authToken = await _storage.readAuthAccessToken();
    final email = _emailFromJwt(authToken ?? '');
    if (email == null || email.isEmpty) {
      throw ApiException('로그인 토큰에서 계정 정보를 확인할 수 없습니다.');
    }
    return <String, dynamic>{
      'email': email,
      'nickname': _nicknameFromEmail(email),
      'avatar_color': 0xFFFF8C42,
    };
  }

  Future<void> _syncLocalApiTokenFallback({String? email}) async {
    try {
      final profile = await _authApi.me();
      await _syncLocalApiTokenWithRetry(profile, fallbackEmail: email);
    } catch (_) {
      if (email == null || email.trim().isEmpty) return;
      try {
        await _syncLocalApiTokenWithRetry({
          'email': email,
          'nickname': _nicknameFromEmail(email),
        });
      } catch (_) {
        // Company login remains usable when the personal API is temporarily
        // offline. Startup and the API interceptor retry this synchronization.
      }
    }
  }

  Future<void> _syncLocalApiTokenWithRetry(
    Map<String, dynamic> profile, {
    String? fallbackEmail,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _guard(
          () => _syncLocalApiToken(profile, fallbackEmail: fallbackEmail),
        );
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: attempt == 0 ? 300 : 800),
          );
        }
      }
    }
    throw lastError ?? ApiException('개인 API 로그인 정보를 만들지 못했습니다.');
  }

  Future<void> _syncLocalApiToken(
    Map<String, dynamic> profile, {
    String? fallbackEmail,
  }) async {
    final email = _readString(profile, ['email']) ?? fallbackEmail;
    if (email == null || email.trim().isEmpty) {
      throw ApiException('개인 API 동기화에 필요한 이메일이 없습니다.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    final nickname = _readString(profile, ['nickname', 'name', 'username']) ??
        _nicknameFromEmail(normalizedEmail);
    final externalUserId = profile['id'] ?? profile['user_id'] ?? profile['sub'];
    final apiToken = await _localAuthApi.syncAuthenticatedUser(
      email: normalizedEmail,
      nickname: nickname,
      externalUserId: externalUserId,
    );
    _ensureValidTokenResponse(apiToken);
    await _storage.saveApiTokens(
      accessToken: apiToken.accessToken,
      refreshToken: apiToken.refreshToken,
    );
    await _storage.saveApiAccountEmail(normalizedEmail);
  }

  String? _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return null;
  }

  String _nicknameFromEmail(String email) {
    final raw = email.trim();
    if (raw.isEmpty) return '사용자';
    return raw.split('@').first;
  }

  void _ensureValidTokenResponse(TokenResponse response) {
    if (response.accessToken.trim().isEmpty ||
        response.refreshToken.trim().isEmpty) {
      throw ApiException('서버에서 유효한 로그인 토큰을 받지 못했습니다.');
    }
  }

  String? _emailFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map) return null;
      final subject = payload['sub'];
      if (subject is! String || subject.trim().isEmpty) return null;
      return subject.trim();
    } catch (_) {
      return null;
    }
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
