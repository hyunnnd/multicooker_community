import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../provider/auth_provider.dart';
import 'auth_scaffold.dart';
import 'widgets/google_auth_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

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


  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => LoadingOverlay(
        isLoading: auth.isLoading,
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
            const GoogleAuthButton(),
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
