enum PetAnimationState {
  idle,
  searching,
  connecting,
  connected,
  thinking,
  cooking,
  waiting,
  success,
  error,
  sleeping,
  tapped,
}

enum AppPetStatus {
  idle,
  searching,
  connecting,
  connected,
  thinking,
  cooking,
  waiting,
  success,
  error,
  sleeping,
}

extension AppPetStatusAnimation on AppPetStatus {
  PetAnimationState get animation => PetAnimationState.values[index];
}
