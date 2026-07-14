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

  void _goToPage(int page, int maxPage) {
    final next = page.clamp(0, maxPage);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

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
        backgroundColor: _background,
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          _visiblePage == 0
              ? 'STEP 0 · 예열'
              : 'STEP $_visiblePage / ${recipe.instructionSteps.length}',
          style: const TextStyle(
            color: _orange,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _ModePill(
                mode: _mode,
                enabled: !active,
                onChanged: (mode) => setState(() => _mode = mode),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
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
            _StepPager(
              count: recipe.instructionSteps.length + 1,
              current: _visiblePage,
              onPrevious: () =>
                  _goToPage(_visiblePage - 1, recipe.instructionSteps.length),
              onNext: () =>
                  _goToPage(_visiblePage + 1, recipe.instructionSteps.length),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final CookingControlMode mode;
  final bool enabled;
  final ValueChanged<CookingControlMode> onChanged;

  bool get _automatic => mode == CookingControlMode.automatic;

  @override
  Widget build(BuildContext context) => Container(
    width: 114,
    height: 34,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _orangeSoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Stack(
      children: [
        AnimatedAlign(
          alignment: _automatic ? Alignment.centerLeft : Alignment.centerRight,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 54,
            height: 28,
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
        Row(
          children: [
            _ModeButton(
              label: '자동',
              selected: _automatic,
              enabled: enabled,
              onTap: () => onChanged(CookingControlMode.automatic),
            ),
            _ModeButton(
              label: '반자동',
              selected: !_automatic,
              enabled: enabled,
              onTap: () => onChanged(CookingControlMode.semiAutomatic),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(7),
    child: SizedBox(
      width: 54,
      height: 28,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: TextStyle(
            color: selected ? Colors.white : _sub,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
          child: Text(label),
        ),
      ),
    ),
  );
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
    final sameRecipe = session.currentRecipe?.id == recipe.id;
    final phase = sameRecipe ? session.state.phase : CookingPhase.idle;
    final defaultTarget = recipe.cookerSteps.isEmpty
        ? 200
        : recipePreheatTarget(recipe);
    final target = sameRecipe && session.state.targetTemperature > 0
        ? session.state.targetTemperature
        : defaultTarget;
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
          const Expanded(
            flex: 3,
            child: CookingRiveAnimation(
              backgroundColor: _background,
              scale: 2.1,
            ),
          ),
          const SizedBox(height: 14),
          _ValueRow(label: '목표 온도', value: '$target°C'),
          if (phase == CookingPhase.preheating)
            _CookerSettingsButton(session: session, temperature: target),
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
          if (complete)
            Expanded(
              child: _CompleteView(recipe: recipe, session: session),
            )
          else
            const Expanded(
              flex: 3,
              child: CookingRiveAnimation(
                backgroundColor: _background,
                scale: 2.1,
              ),
            ),
          const SizedBox(height: 12),
          if (complete)
            const SizedBox.shrink()
          else if (step != null) ...[
            _ValueRow(
              label: '목표 온도',
              value:
                  '${current ? session.state.targetTemperature : step.temperature}°C',
            ),
            if (current)
              _CookerSettingsButton(
                session: session,
                temperature: session.state.targetTemperature,
                minutes: (session.state.remainingSeconds / 60).ceil().clamp(
                  1,
                  90,
                ),
              ),
            _ValueRow(
              label: '조리 시간',
              value: current
                  ? '${(session.state.remainingSeconds / 60).ceil().clamp(1, 90)}분'
                  : '${step.timeMin}분',
            ),
          ] else
            _ValueRow(
              label: '진행 시간',
              value: '${instruction.estimatedTimeMin ?? 0}분',
            ),
          if (complete)
            const SizedBox.shrink()
          else if (current) ...[
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

class _CompleteView extends StatelessWidget {
  const _CompleteView({required this.recipe, required this.session});

  final Recipe recipe;
  final CookingSessionProvider session;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.check_circle, color: _orange, size: 74),
      const SizedBox(height: 18),
      Text(
        recipe.title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ink,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '조리가 완료되었습니다.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _sub),
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: _CompleteStat(
              label: '조리 시간',
              value: '${recipe.totalTimeMin}분',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompleteStat(
              label: '쿠커 단계',
              value: '${recipe.cookerSteps.length}개',
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () async {
          final params = <String, String>{
            'write': '1',
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'rating': '5',
            if ((recipe.thumbnailUrl ?? '').trim().isNotEmpty)
              'recipeImage': recipe.thumbnailUrl!.trim(),
          };
          final created = await context.push<bool>(
            Uri(path: '/community', queryParameters: params).toString(),
          );
          if (!context.mounted || created != true) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('후기가 등록되었습니다.')),
          );
        },
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('후기 작성'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => context.push('/community'),
        icon: const Icon(Icons.ios_share),
        label: const Text('커뮤니티에 공유'),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () async {
          await session.finishSession();
          if (context.mounted) context.go('/home');
        },
        style: _primaryStyle,
        icon: const Icon(Icons.home_outlined),
        label: const Text('홈으로 돌아가기'),
      ),
    ],
  );
}

class _CompleteStat extends StatelessWidget {
  const _CompleteStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _orangeSoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Text(label, style: const TextStyle(color: _sub, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
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
        color: _background,
        border: Border.all(color: _background),
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

class _CookerSettingsButton extends StatelessWidget {
  const _CookerSettingsButton({
    required this.session,
    required this.temperature,
    this.minutes,
  });

  final CookingSessionProvider session;
  final int temperature;
  final int? minutes;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: session.isPaused
          ? null
          : () => _showCookerSettingsDialog(
              context,
              session,
              temperature,
              minutes,
            ),
      icon: const Icon(Icons.tune, size: 18),
      label: Text(minutes == null ? '온도 변경' : '온도/시간 변경'),
    ),
  );
}

Future<void> _showCookerSettingsDialog(
  BuildContext context,
  CookingSessionProvider session,
  int currentTemperature,
  int? currentMinutes,
) async {
  var temperature = currentTemperature.toDouble().clamp(40, 250).toDouble();
  var minutes = (currentMinutes ?? 1).toDouble().clamp(1, 90).toDouble();
  var sending = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: _background,
        title: Text(currentMinutes == null ? '목표 온도 변경' : '온도/시간 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${temperature.round()}°C',
              style: const TextStyle(
                color: _orange,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            Slider(
              value: temperature,
              min: 40,
              max: 250,
              divisions: 210,
              activeColor: _orange,
              inactiveColor: _orangeSoft,
              label: '${temperature.round()}°C',
              onChanged: sending
                  ? null
                  : (value) => setState(() => temperature = value),
            ),
            if (currentMinutes != null) ...[
              const SizedBox(height: 12),
              Text(
                '${minutes.round()}분',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Slider(
                value: minutes,
                min: 1,
                max: 90,
                divisions: 89,
                activeColor: _orange,
                inactiveColor: _orangeSoft,
                label: '${minutes.round()}분',
                onChanged: sending
                    ? null
                    : (value) => setState(() => minutes = value),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: sending ? null : () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            style: _primaryStyle,
            onPressed: sending
                ? null
                : () async {
                    setState(() => sending = true);
                    try {
                      await session.updateCookerSettings(
                        temperature: temperature.round(),
                        durationMinutes: currentMinutes == null
                            ? null
                            : minutes.round(),
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (error) {
                      if (!context.mounted) return;
                      setState(() => sending = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('설정을 변경하지 못했습니다: $error')),
                      );
                    }
                  },
            child: Text(sending ? '전송 중...' : '적용'),
          ),
        ],
      ),
    ),
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

class _StepPager extends StatelessWidget {
  const _StepPager({
    required this.count,
    required this.current,
    required this.onPrevious,
    required this.onNext,
  });

  final int count;
  final int current;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(
      children: [
        IconButton(
          tooltip: '이전 단계',
          onPressed: current == 0 ? null : onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: _PageDots(count: count, current: current),
        ),
        IconButton(
          tooltip: '다음 단계',
          onPressed: current >= count - 1 ? null : onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
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
