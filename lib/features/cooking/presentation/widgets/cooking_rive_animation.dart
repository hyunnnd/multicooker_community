import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

class CookingRiveAnimation extends StatefulWidget {
  const CookingRiveAnimation({
    this.size,
    this.backgroundColor,
    this.scale = 1,
    super.key,
  });

  final double? size;
  final Color? backgroundColor;
  final double scale;

  @override
  State<CookingRiveAnimation> createState() => _CookingRiveAnimationState();
}

class _CookingRiveAnimationState extends State<CookingRiveAnimation> {
  late final _fileLoader = rive.FileLoader.fromAsset(
    'assets/animations/cooking_wait.riv',
    riveFactory: rive.Factory.rive,
  );

  @override
  void dispose() {
    _fileLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.backgroundColor ?? const Color(0xFFFFFFF5);
    final animation = ColoredBox(
      color: background,
      child: ClipRect(
        child: Transform.scale(
          scale: widget.scale,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(background, BlendMode.modulate),
            child: rive.RiveWidgetBuilder(
              fileLoader: _fileLoader,
              artboardSelector: rive.ArtboardSelector.byName('New Artboard'),
              stateMachineSelector: rive.StateMachineSelector.byName(
                'State Machine 1',
              ),
              builder: (context, state) => switch (state) {
                rive.RiveLoading() => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF97316)),
                ),
                rive.RiveFailed() => const Icon(
                  Icons.soup_kitchen_outlined,
                  color: Color(0xFFF97316),
                ),
                rive.RiveLoaded() => rive.RiveWidget(
                  controller: state.controller,
                  fit: rive.Fit.contain,
                  alignment: Alignment.center,
                ),
              },
            ),
          ),
        ),
      ),
    );
    if (widget.size == null) return animation;
    return SizedBox.square(dimension: widget.size, child: animation);
  }
}
