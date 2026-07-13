enum GoogleAuthFlowStatus { login, register, unknown }

class GoogleAuthCallback {
  const GoogleAuthCallback({
    required this.uri,
    this.code,
    this.error,
    this.status = GoogleAuthFlowStatus.unknown,
  });

  final Uri uri;
  final String? code;
  final String? error;
  final GoogleAuthFlowStatus status;

  bool get hasCode => code != null && code!.isNotEmpty;
  bool get hasError => error != null && error!.isNotEmpty;
  bool get isRegistration => status == GoogleAuthFlowStatus.register;

  static bool matches(Uri uri) {
    return uri.scheme.toLowerCase() == 'multicooker' &&
        uri.host.toLowerCase() == 'auth' &&
        uri.path == '/google/callback';
  }

  factory GoogleAuthCallback.fromUri(Uri uri) {
    final statusValue = uri.queryParameters['status']?.toLowerCase();
    final status = switch (statusValue) {
      'login' => GoogleAuthFlowStatus.login,
      'register' => GoogleAuthFlowStatus.register,
      _ => GoogleAuthFlowStatus.unknown,
    };

    return GoogleAuthCallback(
      uri: uri,
      code: _nonEmpty(uri.queryParameters['code']),
      error: _nonEmpty(uri.queryParameters['error']),
      status: status,
    );
  }

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
