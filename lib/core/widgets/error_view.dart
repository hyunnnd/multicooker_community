import 'package:flutter/material.dart';

class ErrorView extends StatefulWidget {
  const ErrorView(
    this.message, {
    super.key,
    this.toast = false,
    this.friendlyMessage,
  });

  final String? message;
  final bool toast;
  final String? friendlyMessage;

  @override
  State<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<ErrorView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
    _opacity = TweenSequence<double>([
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
  }

  @override
  void didUpdateWidget(covariant ErrorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.toast && widget.message != oldWidget.message) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message == null || widget.message!.isEmpty) {
      return const SizedBox.shrink();
    }
    final child = _card();
    if (!widget.toast) return child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }

  Widget _card() {
    final normalized = widget.message!.toLowerCase();
    final expired =
        normalized.contains('expired') || normalized.contains('token');
    final title = expired
        ? '세션이 만료됐어요'
        : widget.friendlyMessage ?? '요청을 처리하지 못했어요';
    final description = expired
        ? '보안을 위해 자동 로그아웃되었어요. 다시 로그인해 주세요.'
        : widget.friendlyMessage == null
        ? '입력한 정보를 확인한 뒤 다시 시도해 주세요.'
        : '입력한 내용을 확인한 뒤 다시 시도해 주세요.';
    return Container(
      margin: widget.toast
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        boxShadow: widget.toast
            ? const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
