import 'dart:math' as math;

import 'package:flutter/material.dart';

class GrapheneMark3D extends StatefulWidget {
  const GrapheneMark3D({required this.size, this.loop = false, super.key});

  final double size;
  final bool loop;

  @override
  State<GrapheneMark3D> createState() => _GrapheneMark3DState();
}

class _GrapheneMark3DState extends State<GrapheneMark3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.loop ? 1800 : 1100),
    );
    widget.loop ? _controller.repeat(reverse: true) : _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && _controller.isAnimating) _controller.stop();

    return Semantics(
      image: true,
      label: 'Graphene Cooker 로고',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            final value = reduceMotion ? 1.0 : _controller.value;
            var offsetY = 0.0;
            var scaleX = 1.0;
            var scaleY = 1.0;
            var turn = 0.0;

            if (widget.loop) {
              final eased = Curves.easeInOutCubic.transform(value);
              turn = (eased - 0.5) * 0.16;
            } else if (value < 0.52) {
              final drop = Curves.easeInCubic.transform(value / 0.52);
              offsetY = -MediaQuery.sizeOf(context).height * 0.48 * (1 - drop);
              turn = (1 - drop) * -0.08;
            } else if (value < 0.76) {
              final bounce = (value - 0.52) / 0.24;
              offsetY = -widget.size * 0.18 * math.sin(bounce * math.pi);
            } else if (value < 0.92) {
              final settle = (value - 0.76) / 0.16;
              offsetY = -widget.size * 0.05 * math.sin(settle * math.pi);
            }

            if (!widget.loop) {
              final impact = math.exp(-math.pow((value - 0.52) / 0.045, 2));
              scaleX += impact * 0.07;
              scaleY -= impact * 0.09;
            }

            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0025)
                  ..rotateX(0.06)
                  ..rotateY(turn)
                  ..scaleByDouble(scaleX, scaleY, 1, 1),
                child: child,
              ),
            );
          },
          child: const RepaintBoundary(
            child: CustomPaint(painter: _MarkPainter()),
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static const _orange = Color(0xFFFE7902);
  static const _ivory = Color(0xFFFFFFF5);
  static const _ink = Color(0xFF292929);

  @override
  void paint(Canvas canvas, Size size) {
    final depth = size.shortestSide * 0.09;
    final center = Offset(
      size.width / 2 - depth / 3,
      size.height / 2 - depth / 3,
    );
    final radius = size.shortestSide * 0.34;
    final front = _points(center, radius);
    final back = front.map((point) => point + Offset(depth, depth)).toList();

    canvas.drawPath(_path(back), Paint()..color = const Color(0xFF8F3D00));
    for (var index = 0; index < 6; index++) {
      final next = (index + 1) % 6;
      final side = Path()
        ..moveTo(front[index].dx, front[index].dy)
        ..lineTo(front[next].dx, front[next].dy)
        ..lineTo(back[next].dx, back[next].dy)
        ..lineTo(back[index].dx, back[index].dy)
        ..close();
      canvas.drawPath(
        side,
        Paint()
          ..color = index < 3
              ? const Color(0xFFC95B00)
              : const Color(0xFF9F4500),
      );
    }

    canvas.drawPath(_path(front), Paint()..color = _orange);
    canvas.drawPath(
      _path(_points(center, radius * 0.67)),
      Paint()..color = _ivory,
    );
    canvas.drawPath(
      _path(_points(center, radius * 0.24)),
      Paint()..color = _ink,
    );
  }

  List<Offset> _points(Offset center, double radius) =>
      List.generate(6, (index) {
        final angle = (-math.pi / 2) + (index * math.pi / 3);
        return center + Offset(math.cos(angle), math.sin(angle)) * radius;
      });

  Path _path(List<Offset> points) => Path()
    ..addPolygon(points, true)
    ..close();

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
