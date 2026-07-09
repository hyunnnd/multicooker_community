import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../provider/auth_provider.dart';
import 'auth_scaffold.dart';

class ResetPasswordVerifyCodeScreen extends StatefulWidget {
  const ResetPasswordVerifyCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordVerifyCodeScreen> createState() =>
      _ResetPasswordVerifyCodeScreenState();
}

class _ResetPasswordVerifyCodeScreenState
    extends State<ResetPasswordVerifyCodeScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await context.read<AuthProvider>().verifyResetPasswordEmailCode(
      widget.email,
      _code.text,
    );
    if (!mounted) return;
    if (ok) {
      context.go('/reset/complete?email=${Uri.encodeComponent(widget.email)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => LoadingOverlay(
        isLoading: auth.isLoading,
        child: AuthScaffold(
          title: '재설정 코드 확인',
          showBack: true,
          children: [
            Text(widget.email),
            const SizedBox(height: 12),
            ErrorView(auth.errorMessage),
            AppTextField(controller: _code, label: 'Code'),
            const SizedBox(height: 20),
            AppButton(label: '인증 확인', icon: Icons.verified, onPressed: _verify),
          ],
        ),
      ),
    );
  }
}
