import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../data/models/complete_register_request.dart';
import '../provider/auth_provider.dart';
import 'auth_scaffold.dart';

class RegisterCompleteScreen extends StatefulWidget {
  const RegisterCompleteScreen({super.key, required this.email});

  final String email;

  @override
  State<RegisterCompleteScreen> createState() => _RegisterCompleteScreenState();
}

class _RegisterCompleteScreenState extends State<RegisterCompleteScreen> {
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _mobile = TextEditingController();
  final _age = TextEditingController(text: '0');
  String _sex = 'MALE';
  bool _marketing = false;

  @override
  void dispose() {
    _password.dispose();
    _passwordConfirm.dispose();
    _mobile.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_password.text != _passwordConfirm.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('입력된 정보가 다릅니다')));
      return;
    }
    final ok = await context.read<AuthProvider>().completeRegister(
      CompleteRegisterRequest(
        email: widget.email,
        password: _password.text,
        mobile: _mobile.text,
        sex: _sex,
        age: int.tryParse(_age.text) ?? 0,
        marketingOptIn: _marketing,
      ),
    );
    if (!mounted) return;
    if (ok) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => LoadingOverlay(
        isLoading: auth.isLoading,
        child: AuthScaffold(
          title: '회원가입 완료',
          showBack: true,
          children: [
            Text(widget.email),
            const SizedBox(height: 12),
            ErrorView(auth.errorMessage),
            AppTextField(
              controller: _password,
              label: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _passwordConfirm,
              label: 'Re-enter Password',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            AppTextField(controller: _mobile, label: 'Mobile'),
            const SizedBox(height: 12),
            AppTextField(
              controller: _age,
              label: 'Age',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: const InputDecoration(labelText: 'Sex'),
              items: const [
                DropdownMenuItem(value: 'MALE', child: Text('Male')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
              ],
              onChanged: (value) => setState(() => _sex = value ?? 'MALE'),
            ),
            CheckboxListTile(
              value: _marketing,
              onChanged: (value) => setState(() => _marketing = value ?? false),
              title: const Text('마케팅 수신 동의'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: '가입 완료',
              icon: Icons.person_add,
              onPressed: _complete,
            ),
          ],
        ),
      ),
    );
  }
}
