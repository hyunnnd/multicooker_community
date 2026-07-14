import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_token_storage.dart';
import 'auth_interceptor.dart';

class DioClient {
  DioClient(this._storage) {
    apiDio = _createDio(ApiConstants.apiBaseUrl);
    authDio = _createDio(ApiConstants.authBaseUrl);

    final apiRefreshDio = _createDio(ApiConstants.apiBaseUrl);
    final authRefreshDio = _createDio(ApiConstants.authBaseUrl);

    authDio.interceptors.add(
      AuthInterceptor(
        _storage,
        authRefreshDio,
        audience: TokenAudience.auth,
      ),
    );

    apiDio.interceptors.add(
      AuthInterceptor(
        _storage,
        apiRefreshDio,
        audience: TokenAudience.api,
        recoverSession: () => _recoverLocalApiSession(
          authDio: authDio,
          localDio: apiRefreshDio,
        ),
      ),
    );
  }

  final SecureTokenStorage _storage;

  /// Local app/API server client. Use this for community, recipes, AI, device.
  late final Dio apiDio;

  /// Company server client. Used for authentication APIs.
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

  Future<RecoveredTokenPair?> _recoverLocalApiSession({
    required Dio authDio,
    required Dio localDio,
  }) async {
    final profileResponse = await authDio.get<Object>(ApiConstants.me);
    if (profileResponse.data is! Map) return null;
    final profile = Map<String, dynamic>.from(profileResponse.data as Map);
    final rawEmail = _readString(profile, const ['email']);
    final email = rawEmail?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;

    final nickname = _readString(
          profile,
          const ['nickname', 'name', 'username'],
        ) ??
        email.split('@').first;
    final externalUserId =
        profile['id'] ?? profile['user_id'] ?? profile['sub'];

    final response = await localDio.post<Object>(
      ApiConstants.localAuthSync,
      data: {
        'email': email,
        'nickname': nickname,
        'external_user_id': externalUserId?.toString(),
      },
    );
    if (response.data is! Map) return null;
    final data = Map<String, dynamic>.from(response.data as Map);
    final accessToken = (data['access_token'] ?? '').toString().trim();
    final refreshToken = (data['refresh_token'] ?? '').toString().trim();
    if (accessToken.isEmpty || refreshToken.isEmpty) return null;

    await _storage.saveApiAccountEmail(email);
    return RecoveredTokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  String? _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) return value.toString();
    }
    return null;
  }
}
