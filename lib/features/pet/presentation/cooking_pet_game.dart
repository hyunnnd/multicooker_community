import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../domain/pet_animation_state.dart';
import 'cooking_pet.dart';

class CookingPetGame extends FlameGame {
  CookingPetGame({this.displaySize = 192, this.onPetTapped});

  final double displaySize;
  VoidCallback? onPetTapped;
  final ValueNotifier<PetAnimationState> displayedState = ValueNotifier(
    PetAnimationState.idle,
  );

  AppPetStatus _appStatus = AppPetStatus.idle;
  bool _allowSleep = true;
  late final CookingPet _pet;
  bool _ready = false;

  AppPetStatus get appStatus => _appStatus;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    _pet = CookingPet(
      displaySize: displaySize,
      onTapped: () => onPetTapped?.call(),
      onAnimationChanged: (state) => displayedState.value = state,
    );
    await add(_pet);
    _ready = true;
    _pet.setAppStatus(_appStatus, allowSleep: _allowSleep);
    _centerPet();
  }

  void setAppStatus(AppPetStatus status, {bool allowSleep = true}) {
    _appStatus = status;
    _allowSleep = allowSleep;
    if (_ready) _pet.setAppStatus(status, allowSleep: allowSleep);
  }

  void playTapped() {
    if (_ready) _pet.playTapped();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_ready) _centerPet();
  }

  @override
  void onRemove() {
    displayedState.dispose();
    super.onRemove();
  }

  void _centerPet() => _pet.position = size / 2;
}
