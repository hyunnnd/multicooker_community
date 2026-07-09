import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _apiAccessTokenKey = 'api_access_token';
  static const _apiRefreshTokenKey = 'api_refresh_token';
  static const _authAccessTokenKey = 'auth_access_token';
  static const _authRefreshTokenKey = 'auth_refresh_token';

  Future<String?> readApiAccessToken() => _storage.read(key: _apiAccessTokenKey);
  Future<String?> readApiRefreshToken() => _storage.read(key: _apiRefreshTokenKey);
  Future<String?> readAuthAccessToken() => _storage.read(key: _authAccessTokenKey);
  Future<String?> readAuthRefreshToken() => _storage.read(key: _authRefreshTokenKey);

  Future<void> saveApiTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _apiAccessTokenKey, value: accessToken);
    await _storage.write(key: _apiRefreshTokenKey, value: refreshToken);
  }

  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _authAccessTokenKey, value: accessToken);
    await _storage.write(key: _authRefreshTokenKey, value: refreshToken);
  }

  Future<void> clearApiTokens() async {
    await _storage.delete(key: _apiAccessTokenKey);
    await _storage.delete(key: _apiRefreshTokenKey);
  }

  Future<void> clearAuthTokens() async {
    await _storage.delete(key: _authAccessTokenKey);
    await _storage.delete(key: _authRefreshTokenKey);
  }

  Future<void> clear() async {
    await clearApiTokens();
    await clearAuthTokens();
    // Remove old token keys used by previous builds so account state cannot mix.
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  // Backward-compatible names. Local app APIs use the API token pair.
  Future<String?> readAccessToken() => readApiAccessToken();
  Future<String?> readRefreshToken() => readApiRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) => saveApiTokens(accessToken: accessToken, refreshToken: refreshToken);
}
