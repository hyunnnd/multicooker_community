import 'dart:async' as async;
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../domain/pet_animation_state.dart';
import 'cooking_pet_game.dart';

class CookingPet extends SpriteAnimationGroupComponent<PetAnimationState>
    with HasGameReference<CookingPetGame> {
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

  static const _frameWidth = 192.0;
  static const _frameHeight = 208.0;

  final VoidCallback? onTapped;
  final void Function(PetAnimationState)? onAnimationChanged;

  AppPetStatus _appStatus = AppPetStatus.idle;
  async.Timer? _tapTimer;
  async.Timer? _sleepTimer;
  bool _allowSleep = true;
  bool _loaded = false;
  bool _showingTap = false;
  bool _wearingChefHat = true;
  double _idleMotionTime = 0;
  final _random = Random();
  late final Map<PetAnimationState, SpriteAnimation> _chefAnimations;
  late final Map<PetAnimationState, SpriteAnimation> _idleAnimations;

  PetAnimationState get displayedState => current ?? _appStatus.animation;

  @override
  Future<void> onLoad() async {
    final chefImage = await game.images.load('pet/tangerine_chef.webp');
    final idleImage = await game.images.load('pet/tangerine_idle.png');
    _chefAnimations = _animationsFor(chefImage);
    _idleAnimations = _steadyAnimationsFor(idleImage);
    _wearingChefHat = _usesChefHat(_appStatus);
    animations = _wearingChefHat ? _chefAnimations : _idleAnimations;
    _loaded = true;
    _applyAppStatus();
  }

  Map<PetAnimationState, SpriteAnimation> _animationsFor(Image image) {
    final animations = <PetAnimationState, SpriteAnimation>{};
    for (final spec in _specs.entries) {
      animations[spec.key] = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: spec.value.frames,
          stepTime: spec.value.stepTime,
          textureSize: Vector2(_frameWidth, _frameHeight),
          texturePosition: Vector2(0, spec.value.row * _frameHeight),
          loop: true,
        ),
      );
    }
    return animations;
  }

  Map<PetAnimationState, SpriteAnimation> _steadyAnimationsFor(Image image) {
    return {
      for (final state in PetAnimationState.values)
        state: SpriteAnimation([
          SpriteAnimationFrame(
            Sprite(
              image,
              srcPosition: Vector2.zero(),
              srcSize: Vector2(_frameWidth, _frameHeight),
            ),
            1,
          ),
        ], loop: true),
    };
  }

  void setAppStatus(AppPetStatus status, {bool allowSleep = true}) {
    if (status == _appStatus && allowSleep == _allowSleep) return;
    _appStatus = status;
    _allowSleep = allowSleep;
    if (_loaded) {
      _setSheetFor(status);
      if (!_showingTap) _applyAppStatus();
    }
  }

  void playTapped({bool notify = true}) {
    if (!_loaded) return;
    _tapTimer?.cancel();
    _idleMotionTime = 0;
    _showingTap = true;
    _setAnimation(PetAnimationState.tapped);
    if (notify) onTapped?.call();
    _tapTimer = async.Timer(const Duration(milliseconds: 620), () {
      stopStruggling();
    });
  }

  void startStruggling() {
    if (!_loaded) return;
    _tapTimer?.cancel();
    _idleMotionTime = 0;
    _showingTap = true;
    _setAnimation(PetAnimationState.struggling);
  }

  void stopStruggling() {
    _idleMotionTime = 0;
    _showingTap = false;
    if (_loaded) _applyAppStatus();
  }

  void recordUserInteraction() {
    if (!_loaded) return;
    _tapTimer?.cancel();
    _idleMotionTime = 0;
    _showingTap = false;
    _applyAppStatus();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_wearingChefHat) {
      scale.setValues(1, 1);
      angle = 0;
      return;
    }

    _idleMotionTime += dt;
    switch (displayedState) {
      case PetAnimationState.tapped:
        _applyTapMotion();
        break;
      case PetAnimationState.struggling:
        _applyStruggleMotion();
        break;
      default:
        _applyIdleMotion();
    }
  }

  void _applyIdleMotion() {
    final wobble = sin(_idleMotionTime * 3.2);
    scale.setValues(1 + wobble * 0.035, 1 - wobble * 0.025);
    angle = sin(_idleMotionTime * 2.1) * 0.025;
  }

  void _applyTapMotion() {
    final progress = min(_idleMotionTime / 0.62, 1.0);
    final bump = sin(progress * pi);
    final shake = sin(_idleMotionTime * 26) * bump;
    scale.setValues(1 + bump * 0.05, 1 + bump * 0.04);
    angle = shake * 0.06;
  }

  void _applyStruggleMotion() {
    final shake = sin(_idleMotionTime * 18);
    scale.setValues(1 + shake * 0.05, 1 - shake * 0.035);
    angle = shake * 0.07;
  }

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
      _setAnimation(_idleActivities[_random.nextInt(_idleActivities.length)]);
    });
  }

  void _setSheetFor(AppPetStatus status) {
    final wearingChefHat = _usesChefHat(status);
    if (_wearingChefHat == wearingChefHat) return;
    _wearingChefHat = wearingChefHat;
    animations = wearingChefHat ? _chefAnimations : _idleAnimations;
    if (wearingChefHat) {
      scale.setValues(1, 1);
      angle = 0;
    }
  }

  bool _usesChefHat(AppPetStatus status) => switch (status) {
    AppPetStatus.connected ||
    AppPetStatus.cooking ||
    AppPetStatus.waiting ||
    AppPetStatus.success => true,
    _ => false,
  };

  void _setAnimation(PetAnimationState state) {
    current = state;
    onAnimationChanged?.call(state);
  }
}

const _idleActivities = [
  PetAnimationState.idle,
  PetAnimationState.thinking,
  PetAnimationState.waiting,
];

class _PetAnimationSpec {
  const _PetAnimationSpec(this.frames, this.stepTime, this.row);

  final int frames;
  final double stepTime;
  final int row;
}

const _specs = <PetAnimationState, _PetAnimationSpec>{
  PetAnimationState.idle: _PetAnimationSpec(6, 0.22, 0),
  PetAnimationState.searching: _PetAnimationSpec(6, 0.14, 8),
  PetAnimationState.connecting: _PetAnimationSpec(6, 0.16, 7),
  PetAnimationState.connected: _PetAnimationSpec(6, 0.15, 0),
  PetAnimationState.thinking: _PetAnimationSpec(6, 0.18, 8),
  PetAnimationState.cooking: _PetAnimationSpec(6, 0.11, 7),
  PetAnimationState.waiting: _PetAnimationSpec(6, 0.25, 6),
  PetAnimationState.success: _PetAnimationSpec(5, 0.13, 4),
  PetAnimationState.error: _PetAnimationSpec(6, 0.13, 5),
  PetAnimationState.sleeping: _PetAnimationSpec(6, 0.24, 0),
  PetAnimationState.tapped: _PetAnimationSpec(4, 0.12, 3),
  PetAnimationState.struggling: _PetAnimationSpec(6, 0.13, 1),
};
