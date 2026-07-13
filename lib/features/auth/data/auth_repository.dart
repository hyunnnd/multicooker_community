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

  Future<Map<String, dynamic>> me() async {
    return _guard(() async {
      try {
        return await _authApi.me();
      } catch (_) {
        final authToken = await _storage.readAuthAccessToken();
        final apiToken = await _storage.readApiAccessToken();
        if ((authToken == null || authToken.isEmpty) &&
            (apiToken == null || apiToken.isEmpty)) {
          rethrow;
        }
        final email = _emailFromJwt(authToken ?? '');
        return <String, dynamic>{
          'email': email,
          'nickname': email == null ? null : _nicknameFromEmail(email),
          'avatar_color': 0xFFFF8C42,
        };
      }
    });
  }

  Future<void> _syncLocalApiTokenFallback({String? email}) async {
    try {
      final profile = await _authApi.me();
      await _syncLocalApiToken(profile, fallbackEmail: email);
    } catch (_) {
      if (email == null || email.trim().isEmpty) return;
      try {
        await _syncLocalApiToken({
          'email': email,
          'nickname': _nicknameFromEmail(email),
        });
      } catch (_) {
        // Login should still succeed when the local DB server is unavailable.
        // Community/recipe DB features will show their own server error later.
      }
    }
  }

  Future<void> _syncLocalApiToken(
    Map<String, dynamic> profile, {
    String? fallbackEmail,
  }) async {
    final email = _readString(profile, ['email']) ?? fallbackEmail;
    if (email == null || email.trim().isEmpty) return;
    final nickname = _readString(profile, ['nickname', 'name', 'username']) ??
        _nicknameFromEmail(email);
    final externalUserId = profile['id'] ?? profile['user_id'] ?? profile['sub'];
    final apiToken = await _localAuthApi.syncAuthenticatedUser(
      email: email.trim(),
      nickname: nickname,
      externalUserId: externalUserId,
    );
    await _storage.saveApiTokens(
      accessToken: apiToken.accessToken,
      refreshToken: apiToken.refreshToken,
    );
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
