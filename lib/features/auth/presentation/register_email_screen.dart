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

class RegisterEmailScreen extends StatefulWidget {
  const RegisterEmailScreen({super.key});

  @override
  State<RegisterEmailScreen> createState() => _RegisterEmailScreenState();
}

class _RegisterEmailScreenState extends State<RegisterEmailScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_email.text.isEmpty) {
      return;
    }
    final ok = await context.read<AuthProvider>().sendRegisterEmailCode(
      _email.text,
    );
    if (!mounted) return;
    if (ok) {
      context.go('/register/verify?email=${Uri.encodeComponent(_email.text)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => LoadingOverlay(
        isLoading: auth.isLoading,
        child: AuthScaffold(
          title: '회원가입 이메일 인증',
          showBack: true,
          children: [
            ErrorView(auth.errorMessage),
            AppTextField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            AppButton(label: '인증코드 발송', icon: Icons.mail, onPressed: _send),
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('또는'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            const GoogleAuthButton(label: 'Google로 회원가입'),
          ],
        ),
      ),
    );
  }
}
