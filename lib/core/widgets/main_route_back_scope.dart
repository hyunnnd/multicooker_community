import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class MainRouteBackScope extends StatefulWidget {
  const MainRouteBackScope({
    required this.child,
    this.onBackPressed,
    this.backToHomeWhenUnhandled = false,
    this.exitMessage = '한 번 더 뒤로가기 누르면 앱이 종료됩니다.',
    super.key,
  });

  final Widget child;
  final bool Function()? onBackPressed;
  final bool backToHomeWhenUnhandled;
  final String exitMessage;

  @override
  State<MainRouteBackScope> createState() => _MainRouteBackScopeState();
}

class _MainRouteBackScopeState extends State<MainRouteBackScope> {
  DateTime? _lastBackPressedAt;

  void _handleBackPressed() {
    final handled = widget.onBackPressed?.call() ?? false;
    if (handled) return;

    if (widget.backToHomeWhenUnhandled) {
      context.go('/home');
      return;
    }

    final now = DateTime.now();
    final shouldExit = _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= const Duration(seconds: 2);

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.exitMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 78),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: widget.child,
    );
  }
}
