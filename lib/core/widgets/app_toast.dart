import 'package:flutter/material.dart';

SnackBar appToast(String message, {bool success = false}) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    padding: EdgeInsets.zero,
    content: _AppToastContent(message: message, success: success),
  );
}

class _AppToastContent extends StatefulWidget {
  const _AppToastContent({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  State<_AppToastContent> createState() => _AppToastContentState();
}

class _AppToastContentState extends State<_AppToastContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..forward();
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 8,
    ),
    TweenSequenceItem(tween: ConstantTween(1), weight: 77),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 15,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.success
        ? const Color(0xFF15803D)
        : const Color(0xFFDC2626);
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.success
              ? const Color(0xFFF0FDF4)
              : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              widget.success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showAppToast(
  BuildContext context,
  String message, {
  bool success = false,
}) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(appToast(message, success: success));
}
