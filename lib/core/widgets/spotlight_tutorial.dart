import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'tutorial_visibility.dart';

const _orange = Color(0xFFF97316);
const _gray200 = Color(0xFFE5E7EB);
const _gray500 = Color(0xFF6B7280);
const _gray900 = Color(0xFF111827);

class SpotlightTutorialStep {
  const SpotlightTutorialStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.padding = 8,
    this.radius = 16,
    this.cardAbove = false,
    this.cardAboveTarget = false,
    this.cardBottomInset = 24,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final double padding;
  final double radius;
  final bool cardAbove;
  final bool cardAboveTarget;
  final double cardBottomInset;
}

/// 실제 위젯의 RenderBox를 측정해 강조 영역을 그리는 가벼운 온보딩 오버레이입니다.
class SpotlightTutorial extends StatefulWidget {
  const SpotlightTutorial({
    required this.steps,
    required this.onComplete,
    super.key,
  });

  final List<SpotlightTutorialStep> steps;
  final FutureOr<void> Function() onComplete;

  @override
  State<SpotlightTutorial> createState() => _SpotlightTutorialState();
}

class _SpotlightTutorialState extends State<SpotlightTutorial>
    with SingleTickerProviderStateMixin {
  final _containerKey = GlobalKey();
  Timer? _firstMeasure;
  Timer? _secondMeasure;
  Timer? _finishTimer;
  late final AnimationController _spotController;
  Rect? _fromSpot;
  Rect? _toSpot;
  bool _overlayVisible = false;
  bool _finishing = false;
  bool _cardVisible = true;
  bool _changingStep = false;
  var _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _spotController = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      const TutorialVisibilityNotification(true).dispatch(context);
      setState(() => _overlayVisible = true);
    });
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant SpotlightTutorial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps && _stepIndex >= widget.steps.length) {
      _stepIndex = 0;
    }
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _firstMeasure?.cancel();
    _secondMeasure?.cancel();
    _finishTimer?.cancel();
    _spotController.dispose();
    const TutorialVisibilityNotification(false).dispatch(context);
    super.dispose();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    _firstMeasure?.cancel();
    _secondMeasure?.cancel();
    _firstMeasure = Timer(const Duration(milliseconds: 80), _measure);
    _secondMeasure = Timer(const Duration(milliseconds: 200), _measure);
  }

  void _measure() {
    if (!mounted || widget.steps.isEmpty) return;
    final container = _containerKey.currentContext?.findRenderObject();
    final target = widget.steps[_stepIndex].targetKey.currentContext
        ?.findRenderObject();
    if (container is! RenderBox || target is! RenderBox) return;

    final step = widget.steps[_stepIndex];
    final containerOffset = container.localToGlobal(Offset.zero);
    final targetOffset = target.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      targetOffset.dx - containerOffset.dx - step.padding,
      targetOffset.dy - containerOffset.dy - step.padding,
      target.size.width + step.padding * 2,
      target.size.height + step.padding * 2,
    );
    if (_toSpot == rect) return;
    final current = _shownSpot ?? rect;
    _fromSpot = current;
    _toSpot = rect;
    if (current == rect) {
      _spotController.value = 1;
      setState(() {});
      return;
    }
    _spotController
      ..stop()
      ..value = 0
      ..animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 340, damping: 38),
          0,
          1,
          0,
        ),
      );
  }

  Rect? get _shownSpot => _fromSpot == null || _toSpot == null
      ? null
      : Rect.lerp(_fromSpot, _toSpot, _spotController.value);

  Future<void> _previous() => _changeStep(-1);

  void _next() {
    if (_stepIndex == widget.steps.length - 1) {
      _finish();
      return;
    }
    _changeStep(1);
  }

  Future<void> _changeStep(int delta) async {
    if (_changingStep || _finishing) return;
    final nextIndex = _stepIndex + delta;
    if (nextIndex < 0 || nextIndex >= widget.steps.length) return;
    _changingStep = true;
    setState(() => _cardVisible = false);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _stepIndex = nextIndex;
      _cardVisible = true;
    });
    _scheduleMeasure();
    _changingStep = false;
  }

  void _finish() {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _overlayVisible = false;
    });
    _finishTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        const TutorialVisibilityNotification(false).dispatch(context);
      }
      unawaited(Future.sync(widget.onComplete));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    final step = widget.steps[_stepIndex];
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _overlayVisible ? 1 : 0,
      child: LayoutBuilder(
        key: _containerKey,
        builder: (context, constraints) {
          final spot = _shownSpot;
          if (spot == null) return const SizedBox.expand();
          final placeAbove = step.cardAbove;
          final cardBottom = step.cardAboveTarget
              ? (constraints.maxHeight - spot.top + 12).clamp(
                  step.cardBottomInset,
                  constraints.maxHeight - 100,
                )
              : step.cardBottomInset;
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _next,
                child: CustomPaint(
                  painter: _SpotlightPainter(spot: spot, radius: step.radius),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                left: 20,
                right: 20,
                top: placeAbove ? 24 : null,
                bottom: placeAbove ? null : cardBottom,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  curve: const Cubic(0.22, 1, 0.36, 1),
                  opacity: _cardVisible ? 1 : 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 250),
                    curve: const Cubic(0.22, 1, 0.36, 1),
                    offset: _cardVisible ? Offset.zero : const Offset(0, .06),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 250),
                      curve: const Cubic(0.22, 1, 0.36, 1),
                      scale: _cardVisible ? 1 : .96,
                      child: _TutorialCard(
                        key: ValueKey(_stepIndex),
                        step: step,
                        index: _stepIndex,
                        total: widget.steps.length,
                        onSkip: _finish,
                        onPrevious: _previous,
                        onNext: _next,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    super.key,
    required this.step,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.onPrevious,
    required this.onNext,
  });

  final SpotlightTutorialStep step;
  final int index;
  final int total;
  final VoidCallback onSkip;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    elevation: 16,
    shadowColor: const Color(0x70000000),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'STEP ${index + 1} / $total',
                style: const TextStyle(
                  color: _orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9CA3AF),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: const Text('건너뛰기'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            step.title,
            style: const TextStyle(
              color: _gray900,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            step.description,
            style: const TextStyle(color: _gray500, fontSize: 13, height: 1.55),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: i == index
                      ? 22
                      : i < index
                      ? 8
                      : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i <= index ? _orange : _gray200,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (index > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrevious,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: _gray200, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text('이전'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: index == 0 ? 1 : 2,
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(index == total - 1 ? '시작하기 🎉' : '다음'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.spot, required this.radius});

  final Rect spot;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(spot, Radius.circular(radius));
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(cutout, Paint()..color = const Color(0xD1000000));

    void ring(double width, double blur, double opacity) {
      canvas.drawRRect(
        hole,
        Paint()
          ..color = _orange.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    ring(5, 5, .30);
    ring(8, 28, .24);
    ring(2.5, 0, .98);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.spot != spot || oldDelegate.radius != radius;
}
