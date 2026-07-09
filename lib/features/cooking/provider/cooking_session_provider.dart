import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';

import '../../device/data/ble/cooker_service.dart';
import '../../recipe/data/models/cooker_step.dart';
import '../../recipe/data/models/recipe.dart';
import '../../recipe/data/models/recipe_compatibility_type.dart';
import '../../recipe/data/models/recipe_instruction_step.dart';
import '../data/models/cooking_session_state.dart';

class CookingSessionProvider extends ChangeNotifier {
  static const _preheatSafetyMinutes = 30;

  CookingSessionProvider(this._service) {
    _statusSubscription = _service.states.listen(_onCookerStatus);
  }

  final CookerService _service;
  Timer? _timer;
  StreamSubscription<CookerState>? _statusSubscription;
  List<CookingSection> _sections = const [];
  bool _singleStepMode = false;
  CookingSessionState state = const CookingSessionState();

  Recipe? get currentRecipe => state.recipe;
  bool get isPaused => state.isPaused;
  bool get isCompleted => state.isCompleted;
  bool get needsUserAction => state.needsUserAction;
  bool get isPreheating => state.phase == CookingPhase.preheating;
  bool get isPreheatReady => state.phase == CookingPhase.preheatReady;
  bool get isCooking => state.phase == CookingPhase.cooking;

  RecipeInstructionStep? get currentInstruction {
    final recipe = state.recipe;
    if (recipe == null || recipe.instructionSteps.isEmpty) return null;
    return recipe.instructionSteps[state.currentInstructionIndex];
  }

  CookerStep? get currentCookerStep {
    final recipe = state.recipe;
    if (recipe == null ||
        recipe.cookerSteps.isEmpty ||
        currentInstruction?.linkedCookerStepId == null) {
      return null;
    }
    return recipe.cookerSteps[state.currentCookerStepIndex];
  }

  void prepareRecipe(Recipe recipe) {
    _timer?.cancel();
    _sections = recipe.cookerSteps
        .map(
          (step) => CookingSection(
            temperature: step.temperature,
            duration: step.timeMin,
          ),
        )
        .toList(growable: false);
    state = CookingSessionState(recipe: recipe);
    notifyListeners();
  }

  Future<void> startCooking() async {
    await startRecipeProgram();
  }

  Future<void> startPreheating({
    required Recipe recipe,
    required int targetTemperature,
    CookingControlMode controlMode = CookingControlMode.automatic,
  }) async {
    prepareRecipe(recipe);
    _singleStepMode = false;
    _sections = [
      CookingSection(
        temperature: targetTemperature,
        duration: _preheatSafetyMinutes,
      ),
    ];
    await _service.send(_command(CookingStatus.cooking));
    state = state.copyWith(
      phase: CookingPhase.preheating,
      isRunning: true,
      isPaused: false,
      targetTemperature: targetTemperature,
      controlMode: controlMode,
      remainingSeconds: 0,
      currentStatusText: '쿠커 예열 중',
    );
    notifyListeners();
  }

  Future<void> startRecipeProgram() async {
    final recipe = state.recipe;
    if (recipe == null || !recipe.supportsCooker) return;
    _singleStepMode = false;
    final sections = recipe.cookerSteps
        .map(
          (step) => CookingSection(
            temperature: step.temperature,
            duration: step.timeMin,
          ),
        )
        .toList(growable: false);
    if (sections.length > 10) {
      throw ArgumentError('조리 구간은 최대 10개까지 전송할 수 있습니다.');
    }
    _sections = sections;
    await _service.send(_command(CookingStatus.cooking));
    state = state.copyWith(
      phase: CookingPhase.cooking,
      isRunning: true,
      isPaused: false,
      currentStatusText: '조리 중',
      controlMode: CookingControlMode.automatic,
    );
    _loadInstruction(state.currentInstructionIndex);
  }

  Future<void> startRecipeStep({
    required int instructionIndex,
    required int temperature,
    required int duration,
  }) async {
    final recipe = state.recipe;
    if (recipe == null || !recipe.supportsCooker) return;
    _singleStepMode = true;
    _sections = [CookingSection(temperature: temperature, duration: duration)];
    final linkedId =
        recipe.instructionSteps[instructionIndex].linkedCookerStepId;
    final cookerIndex = recipe.cookerSteps.indexWhere(
      (step) => step.id == linkedId,
    );
    await _service.send(_command(CookingStatus.cooking));
    state = state.copyWith(
      phase: CookingPhase.cooking,
      isRunning: true,
      isPaused: false,
      currentInstructionIndex: instructionIndex,
      currentCookerStepIndex: cookerIndex < 0 ? 0 : cookerIndex,
      targetTemperature: temperature,
      remainingSeconds: duration * 60,
      currentStatusText: '조리 중',
      controlMode: CookingControlMode.semiAutomatic,
    );
    notifyListeners();
    _startTimer();
  }

  void startAppStep({required int instructionIndex}) {
    final recipe = state.recipe;
    if (recipe == null) return;
    final instruction = recipe.instructionSteps[instructionIndex];
    _singleStepMode = true;
    state = state.copyWith(
      phase: CookingPhase.cooking,
      controlMode: CookingControlMode.semiAutomatic,
      isRunning: true,
      isPaused: false,
      currentInstructionIndex: instructionIndex,
      targetTemperature: 0,
      remainingSeconds: (instruction.estimatedTimeMin ?? 0) * 60,
      currentStatusText: instruction.title,
    );
    notifyListeners();
    if (state.remainingSeconds > 0) {
      _startTimer();
    } else {
      _finishSingleStep();
    }
  }

  Future<void> pauseCooking() async {
    await _service.send(_command(CookingStatus.stopped));
    _timer?.cancel();
    state = state.copyWith(isPaused: true, currentStatusText: '일시정지');
    notifyListeners();
  }

  Future<void> resumeCooking() async {
    await _service.send(_command(CookingStatus.cooking));
    state = state.copyWith(
      isPaused: false,
      currentStatusText: isPreheating ? '쿠커 예열 중' : '조리 중',
    );
    notifyListeners();
    _startTimer();
  }

  Future<void> stopCooking() async {
    await _service.send(_command(CookingStatus.stopped));
    _timer?.cancel();
    state = const CookingSessionState();
    notifyListeners();
  }

  Future<void> finishSession() async {
    _timer?.cancel();
    _sections = const [];
    try {
      await _service.send(_command(CookingStatus.standby));
    } finally {
      state = const CookingSessionState();
      notifyListeners();
    }
  }

  void moveToNextStep() {
    final recipe = state.recipe;
    final instruction = currentInstruction;
    if (recipe == null || instruction == null) return;
    if (recipe.compatibilityType != RecipeCompatibilityType.fullAuto &&
        instruction.requiresUserAction) {
      state = state.copyWith(
        needsUserAction: true,
        currentUserActionMessage: instruction.description,
      );
      notifyListeners();
      return;
    }
    _advance();
  }

  void completeCurrentUserAction() {
    state = state.copyWith(
      needsUserAction: false,
      clearUserActionMessage: true,
    );
    _advance();
  }

  void addOneMinute() {
    state = state.copyWith(
      remainingSeconds: state.remainingSeconds + 60,
      needsUserAction: false,
      clearUserActionMessage: true,
    );
    notifyListeners();
    _startTimer();
  }

  void completeCooking() {
    _timer?.cancel();
    state = state.copyWith(
      isRunning: false,
      isCompleted: true,
      phase: CookingPhase.completed,
      currentStatusText: '조리 완료',
    );
    notifyListeners();
  }

  void _advance() {
    final recipe = state.recipe;
    if (recipe == null) return;
    final nextIndex = state.currentInstructionIndex + 1;
    if (nextIndex >= recipe.instructionSteps.length) {
      completeCooking();
    } else {
      _loadInstruction(nextIndex);
    }
  }

  void _loadInstruction(int index) {
    final recipe = state.recipe;
    if (recipe == null) return;
    _timer?.cancel();
    final instruction = recipe.instructionSteps[index];
    var cookerIndex = state.currentCookerStepIndex;
    if (instruction.linkedCookerStepId != null) {
      final found = recipe.cookerSteps.indexWhere(
        (step) => step.id == instruction.linkedCookerStepId,
      );
      if (found >= 0) cookerIndex = found;
    }
    final cookerStep = recipe.cookerSteps.isEmpty
        ? null
        : recipe.cookerSteps[cookerIndex];
    final hasLinkedStep = instruction.linkedCookerStepId != null;
    state = state.copyWith(
      currentInstructionIndex: index,
      currentCookerStepIndex: cookerIndex,
      remainingSeconds: hasLinkedStep
          ? cookerStep!.timeMin * 60
          : (instruction.estimatedTimeMin ?? 0) * 60,
      currentTemperature: state.currentTemperature,
      targetTemperature: hasLinkedStep ? cookerStep!.temperature : 0,
      currentStatusText: hasLinkedStep ? cookerStep!.label : '사용자 단계',
      needsUserAction: false,
      clearUserActionMessage: true,
    );
    notifyListeners();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (state.isPaused || state.remainingSeconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = state.remainingSeconds - 1;
      state = state.copyWith(remainingSeconds: next < 0 ? 0 : next);
      notifyListeners();
      if (next > 0) return;
      _timer?.cancel();
      if (state.phase == CookingPhase.preheating) {
        unawaited(_finishPreheating());
        return;
      }
      if (_singleStepMode) {
        _finishSingleStep();
        return;
      }
      if (state.controlMode == CookingControlMode.automatic) {
        _advance();
      } else if (currentInstruction?.requiresUserAction ?? false) {
        state = state.copyWith(
          needsUserAction: true,
          currentUserActionMessage: currentInstruction!.description,
        );
        notifyListeners();
      }
    });
  }

  CookerCommand _command(CookingStatus status) => CookerCommand(
    mode: CookerMode.cooking,
    sections: _sections,
    status: status,
  );

  void _onCookerStatus(CookerState cooker) {
    if (state.recipe == null) return;
    if (cooker.status == CookingStatus.completed) {
      if (state.phase == CookingPhase.preheating) {
        state = state.copyWith(currentTemperature: cooker.currentTemperature);
        if (cooker.currentTemperature >= state.targetTemperature) {
          unawaited(_finishPreheating());
        } else {
          state = state.copyWith(
            phase: CookingPhase.error,
            isRunning: false,
            currentStatusText: '예열 시간 초과',
          );
          notifyListeners();
        }
        return;
      }
      if (_singleStepMode) {
        _finishSingleStep();
        return;
      }
      if (currentInstruction?.linkedCookerStepId == null &&
          state.remainingSeconds > 0) {
        return;
      }
      final nextIndex = state.currentInstructionIndex + 1;
      final instructions = state.recipe!.instructionSteps;
      if (nextIndex < instructions.length &&
          instructions[nextIndex].linkedCookerStepId == null &&
          instructions[nextIndex].estimatedTimeMin != null) {
        _loadInstruction(nextIndex);
        return;
      }
      completeCooking();
      return;
    }
    var instructionIndex = state.currentInstructionIndex;
    var cookerIndex = state.currentCookerStepIndex;
    var targetTemperature = state.targetTemperature;
    if (state.phase == CookingPhase.cooking && cooker.section > 0) {
      final recipe = state.recipe!;
      final reportedIndex = cooker.section - 1;
      if (reportedIndex < recipe.cookerSteps.length) {
        cookerIndex = reportedIndex;
        final cookerStep = recipe.cookerSteps[cookerIndex];
        targetTemperature = cookerStep.temperature;
        final found = recipe.instructionSteps.indexWhere(
          (step) => step.linkedCookerStepId == cookerStep.id,
        );
        if (found >= 0) instructionIndex = found;
      }
    }
    state = state.copyWith(
      currentInstructionIndex: instructionIndex,
      currentCookerStepIndex: cookerIndex,
      currentTemperature: cooker.currentTemperature,
      targetTemperature: targetTemperature,
      remainingSeconds: (cooker.currentMinute * 60) + cooker.currentSecond,
      currentStatusText: switch (cooker.status) {
        CookingStatus.cooking => '조리 중',
        CookingStatus.stopped => '조리 중지',
        CookingStatus.completed => '조리 완료',
        CookingStatus.standby => '대기 중',
        CookingStatus.error => '오류',
      },
      phase: cooker.status == CookingStatus.error
          ? CookingPhase.error
          : state.phase,
    );
    notifyListeners();
    if (state.phase == CookingPhase.preheating &&
        state.targetTemperature > 0 &&
        cooker.currentTemperature >= state.targetTemperature) {
      unawaited(_finishPreheating());
    }
  }

  Future<void> _finishPreheating() async {
    if (state.phase != CookingPhase.preheating) return;
    _timer?.cancel();
    state = state.copyWith(
      phase: CookingPhase.preheatReady,
      isRunning: false,
      isPaused: false,
      remainingSeconds: 0,
      currentStatusText: '예열 완료',
    );
    notifyListeners();
    try {
      await _service.send(_command(CookingStatus.stopped));
      if (state.controlMode == CookingControlMode.automatic) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await startRecipeProgram();
      }
    } catch (_) {
      state = state.copyWith(
        phase: CookingPhase.error,
        isRunning: false,
        currentStatusText: '예열 종료 실패',
      );
      notifyListeners();
    }
  }

  void _finishSingleStep() {
    _timer?.cancel();
    final recipe = state.recipe;
    if (recipe == null) return;
    final nextIndex = state.currentInstructionIndex + 1;
    if (nextIndex >= recipe.instructionSteps.length) {
      completeCooking();
      return;
    }
    state = state.copyWith(
      phase: CookingPhase.stepReady,
      isRunning: false,
      isPaused: false,
      currentInstructionIndex: nextIndex,
      remainingSeconds: 0,
      currentStatusText: '다음 단계 준비',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}
