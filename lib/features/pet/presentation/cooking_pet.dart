import 'dart:async' as async;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../domain/pet_animation_state.dart';
import 'cooking_pet_game.dart';

class CookingPet extends SpriteAnimationGroupComponent<PetAnimationState>
    with TapCallbacks, HasGameReference<CookingPetGame> {
  CookingPet({
    super.position,
    double displaySize = 192,
    this.onTapped,
    this.onAnimationChanged,
  }) : super(
         size: Vector2.all(displaySize),
         anchor: Anchor.center,
         autoResize: false,
       ) {
    paint.filterQuality = FilterQuality.none;
  }

  static const double sourceFrameSize = 96;

  final VoidCallback? onTapped;
  final void Function(PetAnimationState)? onAnimationChanged;

  AppPetStatus _appStatus = AppPetStatus.idle;
  async.Timer? _tapTimer;
  async.Timer? _sleepTimer;
  bool _allowSleep = true;
  bool _loaded = false;
  bool _showingTap = false;

  PetAnimationState get displayedState => current ?? _appStatus.animation;

  @override
  Future<void> onLoad() async {
    final animations = <PetAnimationState, SpriteAnimation>{};
    for (final spec in _specs.entries) {
      try {
        final image = await game.images.load('pet/${spec.key.name}.png');
        animations[spec.key] = SpriteAnimation.fromFrameData(
          image,
          SpriteAnimationData.sequenced(
            amount: spec.value.frames,
            stepTime: spec.value.stepTime,
            textureSize: Vector2.all(sourceFrameSize),
            loop: true,
          ),
        );
      } catch (error) {
        throw StateError(
          '펫 스프라이트 누락: assets/images/pet/${spec.key.name}.png ($error)',
        );
      }
    }
    this.animations = animations;
    _loaded = true;
    _applyAppStatus();
  }

  void setAppStatus(AppPetStatus status, {bool allowSleep = true}) {
    if (status == _appStatus && allowSleep == _allowSleep) return;
    _appStatus = status;
    _allowSleep = allowSleep;
    if (_loaded && !_showingTap) _applyAppStatus();
  }

  void playTapped() {
    if (!_loaded) return;
    _tapTimer?.cancel();
    _showingTap = true;
    _setAnimation(PetAnimationState.tapped);
    onTapped?.call();
    _tapTimer = async.Timer(const Duration(milliseconds: 620), () {
      _showingTap = false;
      if (_loaded) _applyAppStatus();
    });
  }

  @override
  void onTapUp(TapUpEvent event) => playTapped();

  @override
  void onRemove() {
    _tapTimer?.cancel();
    _sleepTimer?.cancel();
    super.onRemove();
  }

  void _applyAppStatus() {
    _sleepTimer?.cancel();
    _setAnimation(_appStatus.animation);
    if (!_allowSleep) return;
    _sleepTimer = async.Timer(const Duration(minutes: 1), () {
      if (!_loaded || _showingTap) return;
      _setAnimation(PetAnimationState.sleeping);
    });
  }

  void _setAnimation(PetAnimationState state) {
    current = state;
    onAnimationChanged?.call(state);
  }
}

class _PetAnimationSpec {
  const _PetAnimationSpec(this.frames, this.stepTime);

  final int frames;
  final double stepTime;
}

const _specs = <PetAnimationState, _PetAnimationSpec>{
  PetAnimationState.idle: _PetAnimationSpec(4, 0.22),
  PetAnimationState.searching: _PetAnimationSpec(6, 0.14),
  PetAnimationState.connecting: _PetAnimationSpec(6, 0.16),
  PetAnimationState.connected: _PetAnimationSpec(4, 0.15),
  PetAnimationState.thinking: _PetAnimationSpec(6, 0.18),
  PetAnimationState.cooking: _PetAnimationSpec(8, 0.11),
  PetAnimationState.waiting: _PetAnimationSpec(4, 0.25),
  PetAnimationState.success: _PetAnimationSpec(6, 0.13),
  PetAnimationState.error: _PetAnimationSpec(4, 0.13),
  PetAnimationState.sleeping: _PetAnimationSpec(6, 0.24),
  PetAnimationState.tapped: _PetAnimationSpec(4, 0.12),
};
