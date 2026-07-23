import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _apiAccessTokenKey = 'api_access_token';
  static const _apiRefreshTokenKey = 'api_refresh_token';
  static const _apiAccountEmailKey = 'api_account_email';
  static const _authAccessTokenKey = 'auth_access_token';
  static const _authRefreshTokenKey = 'auth_refresh_token';

  Future<String?> readApiAccessToken() =>
      _storage.read(key: _apiAccessTokenKey);
  Future<String?> readApiRefreshToken() =>
      _storage.read(key: _apiRefreshTokenKey);
  Future<String?> readApiAccountEmail() =>
      _storage.read(key: _apiAccountEmailKey);
  Future<String?> readAuthAccessToken() =>
      _storage.read(key: _authAccessTokenKey);
  Future<String?> readAuthRefreshToken() =>
      _storage.read(key: _authRefreshTokenKey);

  Future<void> saveApiTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _apiAccessTokenKey, value: accessToken);
    await _storage.write(key: _apiRefreshTokenKey, value: refreshToken);
  }

  Future<void> saveApiAccountEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      await _storage.delete(key: _apiAccountEmailKey);
      return;
    }
    await _storage.write(key: _apiAccountEmailKey, value: normalized);
  }

  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _authAccessTokenKey, value: accessToken);
    await _storage.write(key: _authRefreshTokenKey, value: refreshToken);
  }


  String _communityNotificationKey(String email, String suffix) {
    final normalized = email.trim().toLowerCase();
    final encoded = base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
    return 'community_notification_${suffix}_$encoded';
  }

  Future<int?> readLastCommunityNotificationId(String email) async {
    final raw = await _storage.read(
      key: _communityNotificationKey(email, 'last_id'),
    );
    return int.tryParse(raw ?? '');
  }

  Future<int?> readLastCommunityNotificationCount(String email) async {
    final raw = await _storage.read(
      key: _communityNotificationKey(email, 'last_count'),
    );
    return int.tryParse(raw ?? '');
  }

  Future<void> saveCommunityNotificationState({
    required String email,
    required int id,
    required int unreadCount,
  }) async {
    await _storage.write(
      key: _communityNotificationKey(email, 'last_id'),
      value: id.toString(),
    );
    await _storage.write(
      key: _communityNotificationKey(email, 'last_count'),
      value: unreadCount.toString(),
    );
  }

  Future<void> clearCommunityNotificationState(String email) async {
    await _storage.delete(
      key: _communityNotificationKey(email, 'last_id'),
    );
    await _storage.delete(
      key: _communityNotificationKey(email, 'last_count'),
    );
  }

  Future<void> clearApiTokens() async {
    await _storage.delete(key: _apiAccessTokenKey);
    await _storage.delete(key: _apiRefreshTokenKey);
    await _storage.delete(key: _apiAccountEmailKey);
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
