import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../device/provider/device_provider.dart';
import '../../recipe/data/models/cooker_step.dart';
import '../../recipe/data/models/recipe.dart';
import '../../recipe/data/models/recipe_instruction_step.dart';
import '../../recipe/provider/recipe_provider.dart';
import '../../recipe/presentation/widgets/recipe_cooker_controls.dart';
import '../data/models/cooking_session_state.dart';
import '../provider/cooking_session_provider.dart';
import 'widgets/cooking_rive_animation.dart';

const _orange = Color(0xFFF97316);
const _orangeSoft = Color(0xFFFFEDD5);
const _background = Color(0xFFFFFFF5);
const _ink = Color(0xFF292929);
const _sub = Color(0xFF77736C);
const _border = Color(0xFFE8E2D7);
const _danger = Color(0xFFD92D20);

class RecipeCookingFlowScreen extends StatefulWidget {
  const RecipeCookingFlowScreen({this.recipeId, super.key});

  final String? recipeId;

  @override
  State<RecipeCookingFlowScreen> createState() =>
      _RecipeCookingFlowScreenState();
}

class _RecipeCookingFlowScreenState extends State<RecipeCookingFlowScreen> {
  final _pageController = PageController();
  CookingControlMode _mode = CookingControlMode.automatic;
  int _visiblePage = 0;
  int _lastSessionPage = -1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final session = context.watch<CookingSessionProvider>();
    final recipe = widget.recipeId == null
        ? session.currentRecipe
        : recipeProvider.recipeById(widget.recipeId!);
    if (recipe == null) {
      return const Scaffold(body: Center(child: Text('레시피를 찾을 수 없습니다.')));
    }

    final active =
        session.currentRecipe?.id == recipe.id &&
        session.state.phase != CookingPhase.idle;
    if (active) _mode = session.state.controlMode;
    final sessionPage =
        !active ||
            session.state.phase == CookingPhase.preheating ||
            session.state.phase == CookingPhase.preheatReady
        ? 0
        : session.state.currentInstructionIndex + 1;
    if (sessionPage != _lastSessionPage) {
      _lastSessionPage = sessionPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients) return;
        _pageController.animateToPage(
          sessionPage.clamp(0, recipe.instructionSteps.length),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(recipe.title),
        actions: [
          if (active)
            IconButton(
              tooltip: '조리 종료',
              onPressed: () => _stop(context, session),
              icon: const Icon(Icons.stop_circle_outlined, color: _danger),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<CookingControlMode>(
                segments: const [
                  ButtonSegment(
                    value: CookingControlMode.automatic,
                    icon: Icon(Icons.autorenew),
                    label: Text('자동'),
                  ),
                  ButtonSegment(
                    value: CookingControlMode.semiAutomatic,
                    icon: Icon(Icons.touch_app_outlined),
                    label: Text('반자동'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: active
                    ? null
                    : (value) => setState(() => _mode = value.first),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : _ink,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? _orange
                        : _orangeSoft,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                children: [
                  Text(
                    _visiblePage == 0
                        ? 'STEP 0 · 예열'
                        : 'STEP $_visiblePage / ${recipe.instructionSteps.length}',
                    style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _mode == CookingControlMode.automatic
                        ? '시간 완료 시 자동 전환'
                        : '사용자 확인 후 전환',
                    style: const TextStyle(color: _sub, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: recipe.instructionSteps.length + 1,
                onPageChanged: (page) => setState(() => _visiblePage = page),
                itemBuilder: (context, page) {
                  if (page == 0) {
                    return _PreheatPage(
                      recipe: recipe,
                      mode: _mode,
                      session: session,
                    );
                  }
                  final index = page - 1;
                  return _CookingStepPage(
                    recipe: recipe,
                    instruction: recipe.instructionSteps[index],
                    index: index,
                    mode: _mode,
                    session: session,
                  );
                },
              ),
            ),
            _PageDots(
              count: recipe.instructionSteps.length + 1,
              current: _visiblePage,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _stop(
    BuildContext context,
    CookingSessionProvider session,
  ) async {
    await session.stopCooking();
    if (context.mounted) context.pop();
  }
}

class _PreheatPage extends StatelessWidget {
  const _PreheatPage({
    required this.recipe,
    required this.mode,
    required this.session,
  });

  final Recipe recipe;
  final CookingControlMode mode;
  final CookingSessionProvider session;

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final target = recipe.id == 'egg'
        ? 50
        : recipe.cookerSteps.isEmpty
        ? 200
        : recipe.cookerSteps.first.temperature;
    final phase = session.currentRecipe?.id == recipe.id
        ? session.state.phase
        : CookingPhase.idle;
    final progress = target <= 0
        ? 0.0
        : (session.state.currentTemperature / target).clamp(0.0, 1.0);
    final waitingForSemi =
        phase == CookingPhase.preheatReady &&
        mode == CookingControlMode.semiAutomatic;

    return _StepSurface(
      title: waitingForSemi ? '예열이 완료됐어요' : '쿠커를 예열합니다',
      description: waitingForSemi
          ? '목표 온도에 도달했습니다. 재료를 넣고 첫 단계를 시작해주세요.'
          : '설정된 조리 온도까지 자동으로 올린 뒤 다음 단계로 이동합니다.',
      child: Column(
        children: [
          const Expanded(child: CookingRiveAnimation()),
          const SizedBox(height: 14),
          _ValueRow(label: '목표 온도', value: '$target°C'),
          _ValueRow(
            label: '현재 온도',
            value: '${session.state.currentTemperature}°C',
          ),
          _ValueRow(
            label: '쿠커 상태',
            value: device.isConnected ? '연결됨' : '연결 필요',
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: _orange,
            backgroundColor: _orangeSoft,
          ),
          const SizedBox(height: 14),
          if (phase == CookingPhase.preheating)
            _RunningControls(session: session, stopLabel: '예열 취소')
          else if (waitingForSemi)
            FilledButton.icon(
              onPressed: () => _startFirstSemiStep(session, recipe),
              style: _primaryStyle,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('첫 조리 단계 시작'),
            )
          else
            FilledButton.icon(
              onPressed: !device.isConnected || recipe.cookerSteps.isEmpty
                  ? null
                  : () => showRecipeCookerSettings(
                      context: context,
                      recipe: recipe,
                      step: recipe.cookerSteps.first,
                      instructionIndex: 0,
                      preheating: true,
                      controlMode: mode,
                    ),
              style: _primaryStyle,
              icon: const Icon(Icons.local_fire_department_outlined),
              label: Text(device.isConnected ? '예열 시작' : '쿠커 연결 필요'),
            ),
        ],
      ),
    );
  }

  void _startFirstSemiStep(CookingSessionProvider session, Recipe recipe) {
    final instruction = recipe.instructionSteps.first;
    final step = _linkedStep(recipe, instruction);
    if (step == null) {
      session.startAppStep(instructionIndex: 0);
    } else {
      session.startRecipeStep(
        instructionIndex: 0,
        temperature: step.temperature,
        duration: step.timeMin,
      );
    }
  }
}

class _CookingStepPage extends StatelessWidget {
  const _CookingStepPage({
    required this.recipe,
    required this.instruction,
    required this.index,
    required this.mode,
    required this.session,
  });

  final Recipe recipe;
  final RecipeInstructionStep instruction;
  final int index;
  final CookingControlMode mode;
  final CookingSessionProvider session;

  @override
  Widget build(BuildContext context) {
    final step = _linkedStep(recipe, instruction);
    final sameRecipe = session.currentRecipe?.id == recipe.id;
    final current =
        sameRecipe &&
        session.state.phase == CookingPhase.cooking &&
        session.state.currentInstructionIndex == index;
    final ready =
        sameRecipe &&
        (session.state.phase == CookingPhase.preheatReady && index == 0 ||
            session.state.phase == CookingPhase.stepReady &&
                session.state.currentInstructionIndex == index);
    final complete =
        sameRecipe && session.state.phase == CookingPhase.completed;

    return _StepSurface(
      title: complete ? '조리가 완료됐어요' : instruction.title,
      description: complete ? '맛있게 완성된 요리를 확인해보세요.' : instruction.description,
      child: Column(
        children: [
          const Expanded(child: CookingRiveAnimation()),
          const SizedBox(height: 12),
          if (step != null) ...[
            _ValueRow(label: '목표 온도', value: '${step.temperature}°C'),
            _ValueRow(label: '조리 시간', value: '${step.timeMin}분'),
          ] else
            _ValueRow(
              label: '진행 시간',
              value: '${instruction.estimatedTimeMin ?? 0}분',
            ),
          if (current) ...[
            const SizedBox(height: 8),
            Text(
              _time(session.state.remainingSeconds),
              style: const TextStyle(
                color: _orange,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            _RunningControls(session: session, stopLabel: '조리 종료'),
          ] else if (complete) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: session.finishSession,
              style: _primaryStyle,
              child: const Text('완료'),
            ),
          ] else if (mode == CookingControlMode.semiAutomatic && ready) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                if (step == null) {
                  session.startAppStep(instructionIndex: index);
                } else {
                  session.startRecipeStep(
                    instructionIndex: index,
                    temperature: step.temperature,
                    duration: step.timeMin,
                  );
                }
              },
              style: _primaryStyle,
              icon: const Icon(Icons.send_outlined),
              label: const Text('이 단계 쿠커에 보내기'),
            ),
          ] else ...[
            const Spacer(),
            const Text(
              '좌우로 넘겨 다른 단계를 미리 확인할 수 있습니다.',
              style: TextStyle(color: _sub, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepSurface extends StatelessWidget {
  const _StepSurface({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(description, style: const TextStyle(color: _sub, height: 1.45)),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class _RunningControls extends StatelessWidget {
  const _RunningControls({required this.session, required this.stopLabel});

  final CookingSessionProvider session;
  final String stopLabel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: session.isPaused
              ? session.resumeCooking
              : session.pauseCooking,
          style: FilledButton.styleFrom(
            backgroundColor: _orangeSoft,
            foregroundColor: _orange,
          ),
          icon: Icon(session.isPaused ? Icons.play_arrow : Icons.pause),
          label: Text(session.isPaused ? '재개' : '일시정지'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: session.stopCooking,
          style: OutlinedButton.styleFrom(foregroundColor: _danger),
          icon: const Icon(Icons.stop),
          label: Text(stopLabel),
        ),
      ),
    ],
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: _sub)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var index = 0; index < count; index++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: index == current ? 22 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == current ? _orange : _orangeSoft,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
    ],
  );
}

CookerStep? _linkedStep(Recipe recipe, RecipeInstructionStep instruction) {
  for (final step in recipe.cookerSteps) {
    if (step.id == instruction.linkedCookerStepId) return step;
  }
  return null;
}

String _time(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

final _primaryStyle = FilledButton.styleFrom(
  backgroundColor: _orange,
  minimumSize: const Size.fromHeight(50),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
);
