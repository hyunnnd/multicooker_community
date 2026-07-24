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
    paint.isAntiAlias = false;
  }

  static const _frameWidth = 192.0;
  static const _frameHeight = 208.0;

  // chef 시트는 셀 경계 안쪽을 아주 조금만 사용하여 텍스처 보간에 의한
  // 인접 프레임 노출을 방지합니다.
  static const _chefHorizontalInset = 0.5;

  // idle 시트의 첫 셀 왼쪽 가장자리에는 다음/이전 그림 조각처럼 보이는
  // 픽셀이 들어 있으므로 안전 영역만 사용합니다. 원본 파일은 수정하지 않습니다.
  static const _idleHorizontalInset = 12.0;

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
    // 현재 펫 디자인은 아래 두 합본 에셋만 사용합니다.
    final chefImage = await game.images.load('pet/tangerine_chef.webp');
    final idleImage = await game.images.load('pet/tangerine_idle.png');

    _chefAnimations = _animatedChefSprites(chefImage);
    _idleAnimations = _steadyIdleSprites(idleImage);

    _wearingChefHat = _usesChefHat(_appStatus);
    animations = _wearingChefHat ? _chefAnimations : _idleAnimations;
    _loaded = true;
    _applyAppStatus();
  }

  Map<PetAnimationState, SpriteAnimation> _animatedChefSprites(Image image) {
    final animations = <PetAnimationState, SpriteAnimation>{};

    for (final entry in _specs.entries) {
      final spec = entry.value;
      final frames = <SpriteAnimationFrame>[];

      for (var column = 0; column < spec.frames; column++) {
        frames.add(
          SpriteAnimationFrame(
            Sprite(
              image,
              srcPosition: Vector2(
                column * _frameWidth + _chefHorizontalInset,
                spec.row * _frameHeight,
              ),
              srcSize: Vector2(
                _frameWidth - (_chefHorizontalInset * 2),
                _frameHeight,
              ),
            ),
            spec.stepTime,
          ),
        );
      }

      animations[entry.key] = SpriteAnimation(frames, loop: true);
    }

    return animations;
  }

  Map<PetAnimationState, SpriteAnimation> _steadyIdleSprites(Image image) {
    final safeIdleSprite = Sprite(
      image,
      srcPosition: Vector2(_idleHorizontalInset, 0),
      srcSize: Vector2(
        _frameWidth - (_idleHorizontalInset * 2),
        _frameHeight,
      ),
    );

    // 미연결 펫은 가로 프레임을 넘겨가며 재생하지 않습니다.
    // 한 프레임을 고정하고 세로 방향의 미세한 숨쉬기 효과만 코드로 적용합니다.
    return {
      for (final state in PetAnimationState.values)
        state: SpriteAnimation(
          [SpriteAnimationFrame(safeIdleSprite, 1)],
          loop: true,
        ),
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
    _tapTimer = async.Timer(const Duration(milliseconds: 620), stopStruggling);
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
    _resetTransform();
    if (_loaded) _applyAppStatus();
  }

  void recordUserInteraction() {
    if (!_loaded) return;
    _tapTimer?.cancel();
    _idleMotionTime = 0;
    _showingTap = false;
    _resetTransform();
    _applyAppStatus();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 모자 펫은 시트 자체의 프레임 애니메이션만 사용합니다.
    if (_wearingChefHat) {
      _resetTransform();
      return;
    }

    _idleMotionTime += dt;
    angle = 0;

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

  // 자동 좌우 이동, 좌우 확대 및 회전을 모두 제거했습니다.
  // x축 크기와 position.x는 항상 유지하고 y축만 아주 작게 변화시킵니다.
  void _applyIdleMotion() {
    final breathing = sin(_idleMotionTime * 3.0);
    scale.setValues(1, 1 + breathing * 0.018);
  }

  void _applyTapMotion() {
    final progress = min(_idleMotionTime / 0.62, 1.0);
    final bump = sin(progress * pi);
    scale.setValues(1, 1 + bump * 0.05);
  }

  void _applyStruggleMotion() {
    final pulse = sin(_idleMotionTime * 14).abs();
    scale.setValues(1, 1 + pulse * 0.035);
  }

  void _resetTransform() {
    scale.setValues(1, 1);
    angle = 0;
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
    _idleMotionTime = 0;
    _resetTransform();
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

// tangerine_chef.webp의 상태별 행과 프레임 수입니다.
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
