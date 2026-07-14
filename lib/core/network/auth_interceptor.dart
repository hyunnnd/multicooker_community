import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_token_storage.dart';

enum TokenAudience { auth, api }

class RecoveredTokenPair {
  const RecoveredTokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

typedef SessionRecovery = Future<RecoveredTokenPair?> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._storage,
    this._refreshDio, {
    required this.audience,
    this.recoverSession,
  });

  final SecureTokenStorage _storage;
  final Dio _refreshDio;
  final TokenAudience audience;
  final SessionRecovery? recoverSession;

  Future<RecoveredTokenPair?>? _recoveryInProgress;

  Future<String?> _readAccessToken() {
    return audience == TokenAudience.auth
        ? _storage.readAuthAccessToken()
        : _storage.readApiAccessToken();
  }

  Future<String?> _readRefreshToken() {
    return audience == TokenAudience.auth
        ? _storage.readAuthRefreshToken()
        : _storage.readApiRefreshToken();
  }

  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    return audience == TokenAudience.auth
        ? _storage.saveAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          )
        : _storage.saveApiTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['authRetry'] == true) {
      handler.next(err);
      return;
    }

    RecoveredTokenPair? tokenPair;
    final refreshToken = await _readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final refreshResponse = await _refreshDio.post(
          ApiConstants.refresh,
          data: {'refresh_token': refreshToken},
        );
        final data = Map<String, dynamic>.from(refreshResponse.data as Map);
        final accessToken = (data['access_token'] ?? '').toString();
        final nextRefreshToken = (data['refresh_token'] ?? '').toString();
        if (accessToken.isNotEmpty && nextRefreshToken.isNotEmpty) {
          tokenPair = RecoveredTokenPair(
            accessToken: accessToken,
            refreshToken: nextRefreshToken,
          );
        }
      } catch (_) {
        // The local refresh token may be missing from a previous build or may
        // have been invalidated when the server restarted. The API audience
        // gets one more chance by rebuilding its session from company auth.
      }
    }

    if (tokenPair == null &&
        audience == TokenAudience.api &&
        recoverSession != null) {
      try {
        final recoveryFuture = _recoveryInProgress ??=
            recoverSession!().whenComplete(() {
              _recoveryInProgress = null;
            });
        tokenPair = await recoveryFuture;
      } catch (_) {
        tokenPair = null;
      }
    }

    if (tokenPair == null) {
      if (audience == TokenAudience.auth) {
        await _storage.clearAuthTokens();
      } else {
        await _storage.clearApiTokens();
      }
      handler.next(err);
      return;
    }

    try {
      await _saveTokens(
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
      );
      final retryOptions = err.requestOptions;
      retryOptions.extra['authRetry'] = true;
      retryOptions.headers['Authorization'] =
          'Bearer ${tokenPair.accessToken}';
      final retryResponse = await _refreshDio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      handler.next(err);
    }
  }
}
