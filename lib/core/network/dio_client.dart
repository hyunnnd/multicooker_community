import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_token_storage.dart';
import 'auth_interceptor.dart';

class DioClient {
  DioClient(SecureTokenStorage storage) {
    apiDio = _createDio(ApiConstants.apiBaseUrl);
    authDio = _createDio(ApiConstants.authBaseUrl);

    final apiRefreshDio = _createDio(ApiConstants.apiBaseUrl);
    final authRefreshDio = _createDio(ApiConstants.authBaseUrl);

    apiDio.interceptors.add(
      AuthInterceptor(
        storage,
        apiRefreshDio,
        audience: TokenAudience.api,
      ),
    );
    authDio.interceptors.add(
      AuthInterceptor(
        storage,
        authRefreshDio,
        audience: TokenAudience.auth,
      ),
    );
  }

  /// Local app/API server client. Use this for community, recipes, AI, device.
  late final Dio apiDio;

  /// Company authentication server client. Use this only for auth flows.
  late final Dio authDio;

  /// Backward-compatible alias. New code should use apiDio or authDio.
  Dio get dio => apiDio;

  Dio _createDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ),
    );
  }
}
