import 'package:flutter_test/flutter_test.dart';
import 'package:graphene_multicooker_app/features/auth/data/google_auth_callback.dart';

void main() {
  test('parses Google registration callback', () {
    final uri = Uri.parse(
      'multicooker://auth/google/callback?code=one-time-code&status=register',
    );

    expect(GoogleAuthCallback.matches(uri), isTrue);
    final callback = GoogleAuthCallback.fromUri(uri);
    expect(callback.code, 'one-time-code');
    expect(callback.isRegistration, isTrue);
    expect(callback.hasError, isFalse);
  });

  test('parses Google callback error', () {
    final uri = Uri.parse(
      'multicooker://auth/google/callback?error=google_login_failed',
    );

    final callback = GoogleAuthCallback.fromUri(uri);
    expect(callback.hasCode, isFalse);
    expect(callback.error, 'google_login_failed');
  });
}
