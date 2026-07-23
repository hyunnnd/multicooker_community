import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';

import '../../device/data/ble/cooker_service.dart';
import '../../recipe/data/models/cooker_step.dart';
import '../../recipe/data/models/recipe.dart';
import '../../recipe/data/models/recipe_compatibility_type.dart';
import '../../recipe/data/models/recipe_instruction_step.dart';
import '../../profile/data/profile_repository.dart';
import '../data/models/cooking_session_state.dart';

class CookingSessionProvider extends ChangeNotifier {
  static const _preheatSafetyMinutes = 100;

  CookingSessionProvider(this._service, {ProfileRepository? profileRepository})
    : _profileRepository = profileRepository {
    _statusSubscription = _service.states.listen(_onCookerStatus);
  }

  final CookerService _service;
  final ProfileRepository? _profileRepository;
  Timer? _timer;
  StreamSubscription<CookerState>? _statusSubscription;
  List<CookingSection> _sections = const [];
  bool _singleStepMode = false;
  DateTime? _sessionStartedAt;
  bool _historyRecorded = false;
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
    _sessionStartedAt = null;
    _historyRecorded = false;
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
    _markSessionStarted();
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
    _markSessionStarted();
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
      isCompleted: false,
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
    _markSessionStarted();
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
      isCompleted: false,
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
    _markSessionStarted();
    final instruction = recipe.instructionSteps[instructionIndex];
    _singleStepMode = true;
    state = state.copyWith(
      phase: CookingPhase.cooking,
      controlMode: CookingControlMode.semiAutomatic,
      isRunning: true,
      isPaused: false,
      isCompleted: false,
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

  Future<int?> resumeCooking() async {
    final remainingSeconds = state.remainingSeconds;
    final roundedMinutes = _setCurrentSectionToRemainingDuration(
      remainingSeconds,
    );
    await _service.send(_command(CookingStatus.cooking));
    state = state.copyWith(
      isPaused: false,
      remainingSeconds: roundedMinutes == null
          ? remainingSeconds
          : roundedMinutes * 60,
      currentStatusText: isPreheating ? '쿠커 예열 중' : '조리 중',
    );
    notifyListeners();
    _startTimer();
    return roundedMinutes;
  }

  int? _setCurrentSectionToRemainingDuration(int remainingSeconds) {
    if (state.phase != CookingPhase.cooking ||
        _sections.isEmpty ||
        remainingSeconds <= 0) {
      return null;
    }
    final index = (_singleStepMode ? 0 : state.currentCookerStepIndex)
        .clamp(0, _sections.length - 1)
        .toInt();
    final section = _sections[index];
    final roundedMinutes = (remainingSeconds / 60).round().clamp(1, 90);
    final updated = [..._sections];
    updated[index] = CookingSection(
      temperature: section.temperature,
      duration: roundedMinutes,
    );
    _sections = updated;
    return roundedMinutes;
  }

  Future<void> updateCookerSettings({
    required int temperature,
    int? durationMinutes,
  }) async {
    if (state.phase != CookingPhase.preheating &&
        state.phase != CookingPhase.cooking) {
      return;
    }
    if (_sections.isEmpty) return;
    final wasPaused = state.isPaused;

    final index = state.phase == CookingPhase.preheating || _singleStepMode
        ? 0
        : state.currentCookerStepIndex.clamp(0, _sections.length - 1).toInt();
    final section = _sections[index];
    final duration = durationMinutes ?? section.duration;
    final nextSections = [..._sections];
    nextSections[index] = CookingSection(
      temperature: temperature,
      duration: duration,
    );
    _sections = nextSections;

    if (state.phase == CookingPhase.cooking && !wasPaused) {
      await _service.send(_command(CookingStatus.stopped));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await _service.send(
      _command(wasPaused ? CookingStatus.stopped : CookingStatus.cooking),
    );
    state = state.copyWith(
      targetTemperature: temperature,
      remainingSeconds: durationMinutes == null
          ? state.remainingSeconds
          : duration * 60,
      currentStatusText: wasPaused ? '일시정지' : state.currentStatusText,
    );
    notifyListeners();
    if (durationMinutes != null && !wasPaused) _startTimer();
  }

  Future<void> stopCooking() async {
    final recipe = state.recipe;
    final startedAt = _sessionStartedAt;
    await _service.send(_command(CookingStatus.stopped));
    _timer?.cancel();
    if (recipe != null && startedAt != null && !_historyRecorded) {
      await _recordHistory(
        recipe: recipe,
        status: 'cancelled',
        startedAt: startedAt,
      );
    }
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
    final recipe = state.recipe;
    _timer?.cancel();
    state = state.copyWith(
      isRunning: false,
      isCompleted: true,
      phase: CookingPhase.completed,
      currentStatusText: '조리 완료',
    );
    notifyListeners();
    if (recipe != null && !_historyRecorded) {
      unawaited(
        _recordHistory(
          recipe: recipe,
          status: 'completed',
          startedAt: _sessionStartedAt ?? DateTime.now(),
        ),
      );
    }
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
    final section = hasLinkedStep && cookerIndex < _sections.length
        ? _sections[cookerIndex]
        : null;
    state = state.copyWith(
      currentInstructionIndex: index,
      currentCookerStepIndex: cookerIndex,
      isCompleted: false,
      remainingSeconds: hasLinkedStep
          ? (section?.duration ?? cookerStep!.timeMin) * 60
          : (instruction.estimatedTimeMin ?? 0) * 60,
      currentTemperature: state.currentTemperature,
      targetTemperature: hasLinkedStep
          ? section?.temperature ?? cookerStep!.temperature
          : 0,
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
        targetTemperature = cookerIndex < _sections.length
            ? _sections[cookerIndex].temperature
            : cookerStep.temperature;
        final found = recipe.instructionSteps.indexWhere(
          (step) => step.linkedCookerStepId == cookerStep.id,
        );
        if (found >= 0) instructionIndex = found;
      }
    }
    // 조리 시간은 앱 세션의 카운트다운을 기준으로 표시한다. 쿠커는
    // stopped/cooking 전환 때 목표 시간을 다시 보고할 수 있어 남은 시간이
    // 초기화되는 것을 막는다.
    final keepLocalClock =
        state.isPaused ||
        (state.phase == CookingPhase.cooking && state.remainingSeconds > 0);

    state = state.copyWith(
      currentInstructionIndex: instructionIndex,
      currentCookerStepIndex: cookerIndex,
      currentTemperature: cooker.currentTemperature,
      targetTemperature: targetTemperature,
      remainingSeconds: keepLocalClock
          ? state.remainingSeconds
          : (cooker.currentMinute * 60) + cooker.currentSecond,
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

  void _markSessionStarted() {
    _sessionStartedAt ??= DateTime.now();
  }

  Future<void> _recordHistory({
    required Recipe recipe,
    required String status,
    required DateTime startedAt,
  }) async {
    if (_historyRecorded) return;
    _historyRecorded = true;
    final repository = _profileRepository;
    if (repository == null) return;

    var elapsedSeconds = 0;
    final steps = <Map<String, dynamic>>[];
    for (final step in recipe.cookerSteps) {
      elapsedSeconds += step.timeMin * 60;
      steps.add({
        'temperature': step.temperature,
        'time_offset': elapsedSeconds,
        'label': step.label,
      });
    }
    final maxTemperature = recipe.cookerSteps.isEmpty
        ? state.targetTemperature
        : recipe.cookerSteps
              .map((step) => step.temperature)
              .reduce((a, b) => a > b ? a : b);
    try {
      await repository.createCookingHistory(
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        deviceName: 'Graphene Multi-Cooker',
        status: status,
        totalTimeMin: recipe.totalTimeMin,
        maxTemperature: maxTemperature,
        steps: steps,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
      );
    } catch (_) {
      // 조리 완료 화면은 유지하고, 이력 서버 오류 때문에 조리 흐름을 막지 않습니다.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}
