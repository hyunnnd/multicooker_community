import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../provider/auth_provider.dart';
import 'auth_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _googleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('정보를 입력해 주세요')));
      return;
    }
    final ok = await context.read<AuthProvider>().login(
      _email.text,
      _password.text,
    );
    if (!mounted) return;
    if (ok) context.go('/home');
  }

  Future<void> _startGoogleLogin() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      final uri = Uri.parse(
        '${ApiConstants.authBaseUrl}${ApiConstants.googleLogin}',
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Google 로그인 페이지를 열 수 없습니다.');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('구글 로그인 실패: $error')));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => LoadingOverlay(
        isLoading: auth.isLoading || _googleLoading,
        child: AuthScaffold(
          title: 'Graphene Multi-Cooker',
          children: [
            ErrorView(auth.errorMessage),
            AppTextField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _password,
              label: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: 20),
            AppButton(label: 'Sign in', icon: Icons.login, onPressed: _login),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _googleLoading ? null : _startGoogleLogin,
                icon: const Text(
                  'G',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                label: const Text('Continue with Google'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/register'),
              child: const Text('Sign up'),
            ),
            TextButton(
              onPressed: () => context.go('/reset'),
              child: const Text('Forgot password'),
            ),
          ],
        ),
      ),
    );
  }
}
