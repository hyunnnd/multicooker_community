class ApiConstants {
  /// Personal app/API server used by community, personal recipes, saved recipes,
  /// cooking history, AI recommendation, device verification, and settings.
  ///
  /// Galaxy phone and Chrome must be on the same Wi-Fi as this host when using
  /// the default value below. Change it with --dart-define=API_BASE_URL=...
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.1.0.28:8001',
  );

  /// Company server used only for authentication-related APIs.
  ///
  /// Change it with --dart-define=AUTH_API_BASE_URL=...
  static const authBaseUrl = String.fromEnvironment(
    'AUTH_API_BASE_URL',
    defaultValue: 'http://3.36.14.110:8000',
  );

  /// Backward-compatible alias for local prototype APIs.
  static const baseUrl = apiBaseUrl;

  static const registerSendCode = '/auth/register/send_email_code';
  static const registerVerifyCode = '/auth/register/verify_email_code';
  static const registerComplete = '/auth/register/complete';
  static const resetSendCode = '/auth/reset_password/send_email_code';
  static const resetVerifyCode = '/auth/reset_password/verify_email_code';
  static const resetComplete = '/auth/reset_password/complete';
  static const login = '/auth/login';
  static const googleLogin = '/auth/google/login';
  static const googleToken = '/auth/google/token';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const me = '/auth/me';

  /// Local FastAPI endpoint. This maps the company-authenticated user to the
  /// local SQLite DB user and issues a local API token for community/recipe APIs.
  static const localAuthSync = '/auth/local_sync';

  static Uri authUri(String path) => Uri.parse(authBaseUrl).resolve(path);

  static const aiUploadPhoto = '/ai_recommend/upload_ingredients_photo';
  static const aiUploadComplete =
      '/ai_recommend/upload_ingredients_photo_complete';
}
