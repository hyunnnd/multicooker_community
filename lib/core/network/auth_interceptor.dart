import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_token_storage.dart';

enum TokenAudience { auth, api }

class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._storage,
    this._refreshDio, {
    required this.audience,
  });

  final SecureTokenStorage _storage;
  final Dio _refreshDio;
  final TokenAudience audience;

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
        err.requestOptions.extra['retry'] == true) {
      handler.next(err);
      return;
    }

    final refreshToken = await _readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      handler.next(err);
      return;
    }

    try {
      final refreshResponse = await _refreshDio.post(
        ApiConstants.refresh,
        data: {'refresh_token': refreshToken},
      );
      final data = Map<String, dynamic>.from(refreshResponse.data as Map);
      final accessToken = data['access_token'] as String;
      final nextRefreshToken = data['refresh_token'] as String;
      await _saveTokens(
        accessToken: accessToken,
        refreshToken: nextRefreshToken,
      );

      final retryOptions = err.requestOptions;
      retryOptions.extra['retry'] = true;
      retryOptions.headers['Authorization'] = 'Bearer $accessToken';
      final retryResponse = await _refreshDio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      if (audience == TokenAudience.auth) {
        await _storage.clearAuthTokens();
      } else {
        await _storage.clearApiTokens();
      }
      handler.next(err);
    }
  }
}
