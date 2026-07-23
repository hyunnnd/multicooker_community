import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../provider/auth_provider.dart';
import 'auth_scaffold.dart';

class RegisterVerifyCodeScreen extends StatefulWidget {
  const RegisterVerifyCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<RegisterVerifyCodeScreen> createState() =>
      _RegisterVerifyCodeScreenState();
}

class _RegisterVerifyCodeScreenState extends State<RegisterVerifyCodeScreen> {
  final _code = TextEditingController();
  String? _toastMessage;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().isEmpty) {
      _showToast('인증코드를 입력해 주세요.');
      return;
    }
    final ok = await context.read<AuthProvider>().verifyRegisterEmailCode(
      widget.email,
      _code.text,
    );
    if (!mounted) return;
    if (ok) {
      context.go(
        '/register/complete?email=${Uri.encodeComponent(widget.email)}',
      );
    }
  }

  void _showToast(String message) => setState(() => _toastMessage = message);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => LoadingOverlay(
        isLoading: auth.isLoading,
        child: AuthScaffold(
          title: '인증코드 확인',
          showBack: true,
          backPath: '/register',
          toast: ErrorView(
            _toastMessage ?? auth.errorMessage,
            toast: true,
            friendlyMessage: _toastMessage,
          ),
          children: [
            Text(
              widget.email,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _code,
              label: '인증코드',
              hintText: '6자리 인증코드',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: '인증 확인',
              icon: Icons.verified_outlined,
              onPressed: _verify,
            ),
          ],
        ),
      ),
    );
  }
}
