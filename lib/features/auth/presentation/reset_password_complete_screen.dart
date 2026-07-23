import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../data/models/complete_reset_password_request.dart';
import '../provider/auth_provider.dart';
import 'auth_scaffold.dart';

class ResetPasswordCompleteScreen extends StatefulWidget {
  const ResetPasswordCompleteScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordCompleteScreen> createState() =>
      _ResetPasswordCompleteScreenState();
}

class _ResetPasswordCompleteScreenState
    extends State<ResetPasswordCompleteScreen> {
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  String? _toastMessage;

  @override
  void dispose() {
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_password.text.isEmpty) {
      _showToast('새 비밀번호를 입력해 주세요.');
      return;
    }
    if (_passwordConfirm.text.isEmpty) {
      _showToast('새 비밀번호 확인을 입력해 주세요.');
      return;
    }
    if (_password.text != _passwordConfirm.text) {
      _showToast('새 비밀번호와 확인 값이 일치하지 않아요.');
      return;
    }
    final ok = await context.read<AuthProvider>().completeResetPassword(
      CompleteResetPasswordRequest(
        email: widget.email,
        newPassword: _password.text,
      ),
    );
    if (!mounted) return;
    if (ok) {
      showAppToast(context, '비밀번호가 재설정되었습니다.', success: true);
      context.go('/login');
    }
  }

  void _showToast(String message) => setState(() => _toastMessage = message);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => LoadingOverlay(
        isLoading: auth.isLoading,
        child: AuthScaffold(
          title: '새 비밀번호 입력',
          showBack: true,
          backPath: '/reset/verify?email=${Uri.encodeComponent(widget.email)}',
          scrollable: false,
          toast: ErrorView(
            _toastMessage ?? auth.errorMessage,
            toast: true,
            friendlyMessage: _toastMessage,
          ),
          children: [
            Text(widget.email),
            const SizedBox(height: 12),
            AppTextField(
              controller: _password,
              label: 'New Password',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _passwordConfirm,
              label: 'Re-enter New Password',
              obscureText: true,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Reset Password',
              icon: Icons.lock_reset,
              onPressed: _complete,
            ),
          ],
        ),
      ),
    );
  }
}
