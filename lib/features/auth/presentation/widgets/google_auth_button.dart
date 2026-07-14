import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/api_constants.dart';

class GoogleAuthButton extends StatefulWidget {
  const GoogleAuthButton({
    super.key,
    this.label = 'Google로 로그인 / 회원가입',
  });

  final String label;

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  bool _opening = false;

  Future<void> _openGoogleLogin() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final uri = ApiConstants.authUri(ApiConstants.googleLogin);
      if (kDebugMode) {
        debugPrint('[Google Auth] 로그인 페이지 열기: $uri');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (kDebugMode) {
        debugPrint('[Google Auth] 외부 브라우저 실행 여부: $opened');
      }
      if (!opened && mounted) {
        _showError('구글 로그인 페이지를 열 수 없습니다.');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Google Auth] 로그인 페이지 실행 실패: $error');
      }
      if (mounted) _showError('구글 로그인을 시작하지 못했습니다.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _opening ? null : _openGoogleLogin,
        icon: _opening
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'G',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
        label: Text(widget.label),
      ),
    );
  }
}
