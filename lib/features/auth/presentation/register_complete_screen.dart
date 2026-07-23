import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../data/models/complete_register_request.dart';
import '../provider/auth_provider.dart';
import 'auth_scaffold.dart';

class RegisterCompleteScreen extends StatefulWidget {
  const RegisterCompleteScreen({super.key, this.email});

  final String? email;

  @override
  State<RegisterCompleteScreen> createState() => _RegisterCompleteScreenState();
}

class _RegisterCompleteScreenState extends State<RegisterCompleteScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _email;
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _mobile = TextEditingController();
  final _age = TextEditingController(text: '0');
  final _code = TextEditingController();
  Timer? _verificationTimer;
  String _sex = 'MALE';
  bool _marketing = false;
  bool _emailCodeSent = false;
  bool _emailCodeVerified = false;
  int _remainingSeconds = 0;
  String? _toastMessage;
  int _toastVersion = 0;

  bool get _hasVerifiedEmail => widget.email?.isNotEmpty ?? false;
  bool get _isEmailVerified => _hasVerifiedEmail || _emailCodeVerified;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email ?? '');
    _email.addListener(_resetEmailVerification);
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _verificationTimer?.cancel();
    _password.dispose();
    _passwordConfirm.dispose();
    _mobile.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _showToast('이메일을 입력해 주세요.');
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      _showToast('올바른 이메일 주소를 입력해 주세요.');
      return;
    }
    if (!_isEmailVerified) {
      _showToast('이메일 인증을 먼저 완료해 주세요.');
      return;
    }
    if (_password.text.isEmpty) {
      _showToast('비밀번호를 입력해 주세요.');
      return;
    }
    if (_passwordConfirm.text.isEmpty) {
      _showToast('비밀번호 확인을 입력해 주세요.');
      return;
    }
    if (_password.text != _passwordConfirm.text) {
      _showToast('비밀번호와 비밀번호 확인이 일치하지 않아요.');
      return;
    }
    if (_mobile.text.trim().isEmpty) {
      _showToast('휴대전화를 입력해 주세요.');
      return;
    }
    if (_age.text.trim().isEmpty) {
      _showToast('나이를 입력해 주세요.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.completeRegister(
      CompleteRegisterRequest(
        email: email,
        password: _password.text,
        mobile: _mobile.text,
        sex: _sex,
        age: int.tryParse(_age.text) ?? 0,
        marketingOptIn: _marketing,
      ),
    );
    if (!mounted) return;
    if (!ok) {
      _showToast(_registerError(auth.errorMessage, '회원가입을 완료하지 못했어요.'));
      return;
    }
    final loggedIn = await auth.login(email, _password.text);
    if (!mounted) return;
    if (!loggedIn) {
      _showToast('회원가입은 완료됐지만 자동 로그인에 실패했어요. 다시 로그인해 주세요.');
      return;
    }
    showAppToast(context, '회원가입이 완료되었습니다.', success: true);
    context.go('/my/tutorial');
  }

  Future<void> _sendEmailCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _showToast('이메일을 입력해 주세요.');
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      _showToast('올바른 이메일 주소를 입력해 주세요.');
      return;
    }
    final ok = await context.read<AuthProvider>().sendRegisterEmailCode(email);
    if (!mounted) return;
    if (!ok) {
      final error = context.read<AuthProvider>().errorMessage;
      _showToast(_registerError(error, '인증코드를 보내지 못했어요. 다시 시도해 주세요.'));
      return;
    }
    setState(() {
      _emailCodeSent = true;
      _emailCodeVerified = false;
      _remainingSeconds = 180;
    });
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _remainingSeconds = 0);
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  Future<void> _verifyEmailCode() async {
    if (_code.text.trim().isEmpty) {
      _showToast('인증코드를 입력해 주세요.');
      return;
    }
    if (_remainingSeconds == 0) {
      _showToast('인증 시간이 만료됐어요. 코드를 다시 보내 주세요.');
      return;
    }
    final ok = await context.read<AuthProvider>().verifyRegisterEmailCode(
      _email.text.trim(),
      _code.text.trim(),
    );
    if (!mounted) return;
    if (!ok) {
      _showToast('인증코드가 올바르지 않아요. 다시 확인해 주세요.');
      return;
    }
    _verificationTimer?.cancel();
    setState(() {
      _emailCodeVerified = true;
    });
  }

  void _resetEmailVerification() {
    if (!_emailCodeSent && !_emailCodeVerified) return;
    _verificationTimer?.cancel();
    setState(() {
      _emailCodeSent = false;
      _emailCodeVerified = false;
      _remainingSeconds = 0;
      _code.clear();
    });
  }

  String _registerError(String? error, String fallback) {
    final message = error?.toLowerCase() ?? '';
    if (message.contains('already') ||
        message.contains('exists') ||
        message.contains('duplicate') ||
        message.contains('이미')) {
      return '이미 가입된 이메일이에요. 로그인해 주세요.';
    }
    return fallback;
  }

  void _showToast(String message) {
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    setState(() {
      _toastMessage = message;
      _toastVersion++;
    });
  }

  String get _remainingTime =>
      '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => LoadingOverlay(
        isLoading: auth.isLoading,
        child: AuthScaffold(
          title: _hasVerifiedEmail ? '회원가입 완료' : '회원가입',
          showBack: true,
          showBrandHeader: false,
          backPath: _hasVerifiedEmail
              ? '/register/verify?email=${Uri.encodeComponent(widget.email!)}'
              : '/login',
          toast: ErrorView(
            _toastMessage,
            key: ValueKey(_toastVersion),
            toast: true,
            friendlyMessage: _toastMessage,
          ),
          children: [
            if (_hasVerifiedEmail)
              Text(
                widget.email!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _email,
                      label: '이메일',
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: auth.isLoading || _emailCodeVerified
                          ? null
                          : _sendEmailCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: _emailCodeVerified
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFF97316),
                        disabledBackgroundColor: const Color(0xFF16A34A),
                        disabledForegroundColor: Colors.white,
                      ),
                      child: Text(
                        _emailCodeVerified
                            ? '인증완료!'
                            : _emailCodeSent
                            ? '재발송'
                            : '보내기',
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (!_hasVerifiedEmail) ...[
              Opacity(
                opacity: _emailCodeSent && !_emailCodeVerified ? 1 : .55,
                child: IgnorePointer(
                  ignoring: !_emailCodeSent || _emailCodeVerified,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _code,
                          label: '인증코드',
                          hintText: '6자리 인증코드',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: auth.isLoading ? null : _verifyEmailCode,
                          child: const Text('인증'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_emailCodeSent && !_emailCodeVerified) ...[
                const SizedBox(height: 8),
                Text(
                  '인증 시간 $_remainingTime',
                  style: TextStyle(
                    color: _remainingSeconds == 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            AppTextField(
              controller: _password,
              label: '비밀번호',
              hintText: '8자 이상 · 영문 대/소문자·숫자·특수문자 조합',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _passwordConfirm,
              label: '비밀번호 확인',
              hintText: '••••••••',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _mobile,
              label: '휴대전화',
              hintText: '010-0000-0000',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _age,
              label: '나이',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: const InputDecoration(labelText: '성별'),
              items: const [
                DropdownMenuItem(value: 'MALE', child: Text('남성')),
                DropdownMenuItem(value: 'FEMALE', child: Text('여성')),
              ],
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 4,
              iconEnabledColor: const Color(0xFF6B7280),
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (value) => setState(() => _sex = value ?? 'MALE'),
            ),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: _marketing,
                onChanged: (value) =>
                    setState(() => _marketing = value ?? false),
                title: const Text('마케팅 수신 동의'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: '가입 완료',
              icon: Icons.person_add_outlined,
              onPressed: _complete,
            ),
          ],
        ),
      ),
    );
  }
}
