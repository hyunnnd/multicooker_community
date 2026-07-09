import '../../../recipe/data/models/recipe.dart';

enum CookingControlMode { automatic, semiAutomatic }

enum CookingPhase {
  idle,
  preheating,
  preheatReady,
  cooking,
  stepReady,
  completed,
  error,
}

class CookingSessionState {
  const CookingSessionState({
    this.recipe,
    this.currentInstructionIndex = 0,
    this.currentCookerStepIndex = 0,
    this.isRunning = false,
    this.isPaused = false,
    this.isCompleted = false,
    this.remainingSeconds = 0,
    this.currentTemperature = 0,
    this.targetTemperature = 0,
    this.currentStatusText = '조리 준비',
    this.phase = CookingPhase.idle,
    this.controlMode = CookingControlMode.automatic,
    this.needsUserAction = false,
    this.currentUserActionMessage,
  });

  final Recipe? recipe;
  final int currentInstructionIndex;
  final int currentCookerStepIndex;
  final bool isRunning;
  final bool isPaused;
  final bool isCompleted;
  final int remainingSeconds;
  final int currentTemperature;
  final int targetTemperature;
  final String currentStatusText;
  final CookingPhase phase;
  final CookingControlMode controlMode;
  final bool needsUserAction;
  final String? currentUserActionMessage;

  CookingSessionState copyWith({
    Recipe? recipe,
    int? currentInstructionIndex,
    int? currentCookerStepIndex,
    bool? isRunning,
    bool? isPaused,
    bool? isCompleted,
    int? remainingSeconds,
    int? currentTemperature,
    int? targetTemperature,
    String? currentStatusText,
    CookingPhase? phase,
    CookingControlMode? controlMode,
    bool? needsUserAction,
    String? currentUserActionMessage,
    bool clearUserActionMessage = false,
  }) => CookingSessionState(
    recipe: recipe ?? this.recipe,
    currentInstructionIndex:
        currentInstructionIndex ?? this.currentInstructionIndex,
    currentCookerStepIndex:
        currentCookerStepIndex ?? this.currentCookerStepIndex,
    isRunning: isRunning ?? this.isRunning,
    isPaused: isPaused ?? this.isPaused,
    isCompleted: isCompleted ?? this.isCompleted,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    currentTemperature: currentTemperature ?? this.currentTemperature,
    targetTemperature: targetTemperature ?? this.targetTemperature,
    currentStatusText: currentStatusText ?? this.currentStatusText,
    phase: phase ?? this.phase,
    controlMode: controlMode ?? this.controlMode,
    needsUserAction: needsUserAction ?? this.needsUserAction,
    currentUserActionMessage: clearUserActionMessage
        ? null
        : currentUserActionMessage ?? this.currentUserActionMessage,
  );
}
