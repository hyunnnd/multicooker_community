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
  String? _toastMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty) {
      _showToast('이메일을 입력해 주세요.');
      return;
    }
    if (_password.text.isEmpty) {
      _showToast('비밀번호를 입력해 주세요.');
      return;
    }
    final ok = await context.read<AuthProvider>().login(
      _email.text,
      _password.text,
    );
    if (!mounted) return;
    if (!ok) {
      _showToast('이메일 또는 비밀번호를 확인해 주세요.');
      return;
    }
    context.go('/home');
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
      _showToast('구글 로그인에 실패했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showToast(String message) => setState(() => _toastMessage = message);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => LoadingOverlay(
        isLoading: auth.isLoading || _googleLoading,
        child: AuthScaffold(
          title: 'Graphene Multi-Cooker',
          toast: ErrorView(
            _toastMessage,
            toast: true,
            friendlyMessage: _toastMessage,
          ),
          children: [
            AppTextField(
              controller: _email,
              label: 'Email',
              hintText: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _password,
              label: 'Password',
              hintText: '••••••••',
              obscureText: true,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/reset'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('비밀번호를 잊으셨나요?'),
              ),
            ),
            AppButton(
              label: '로그인',
              icon: Icons.login_outlined,
              onPressed: _login,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '또는',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
                label: const Text('Google로 계속하기'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.go('/register'),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text.rich(
                  TextSpan(
                    text: '계정이 없으신가요?  ',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    children: [
                      TextSpan(
                        text: '회원가입',
                        style: TextStyle(
                          color: Color(0xFFF97316),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
