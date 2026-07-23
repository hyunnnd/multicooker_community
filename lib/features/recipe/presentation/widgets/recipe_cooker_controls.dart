import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../cooking/data/models/cooking_session_state.dart';
import '../../../cooking/presentation/widgets/cooking_rive_animation.dart';
import '../../../cooking/provider/cooking_session_provider.dart';
import '../../../device/provider/device_provider.dart';
import '../../data/models/cooker_step.dart';
import '../../data/models/recipe.dart';
import '../../provider/recipe_provider.dart';

const _orange = Color(0xFFF97316);
const _orangeSoft = Color(0xFFFFEDD5);
const _background = Color(0xFFFFFFF5);
const _ink = Color(0xFF292929);
const _sub = Color(0xFF77736C);
const _border = Color(0xFFE8E2D7);
const _success = Color(0xFF2BAE66);
const _danger = Color(0xFFD92D20);

int recipePreheatTarget(Recipe recipe) =>
    recipe.id == 'egg' ? 50 : recipe.cookerSteps.first.temperature;

Future<void> showRecipeCookerSettings({
  required BuildContext context,
  required Recipe recipe,
  required CookerStep step,
  required int instructionIndex,
  required bool preheating,
  CookingControlMode controlMode = CookingControlMode.automatic,
}) async {
  var temperature =
      (preheating ? recipePreheatTarget(recipe) : step.temperature).toDouble();
  var minutes = step.timeMin.toDouble();
  var sending = false;
  var sent = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _background,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        final device = context.watch<DeviceProvider>();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preheating ? '예열 설정 확인' : '쿠커 설정 확인',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${recipe.title} · ${preheating ? 'Step 0 쿠커 예열' : step.label}',
                    style: const TextStyle(color: _sub),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: '쿠커 상태',
                    value: device.isConnected ? '연결됨' : '연결 필요',
                    valueColor: device.isConnected ? _success : _danger,
                  ),
                  _InfoRow(
                    label: '쿠커 모드',
                    value: preheating ? '예열' : recipe.compatibilityLabel,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '목표 온도 ${temperature.round()}°C',
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
                  if (preheating)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _orangeSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '목표 온도에 도달하면 본 조리가 자동으로 시작됩니다.',
                        style: TextStyle(color: _ink, height: 1.4),
                      ),
                    )
                  else ...[
                    Text(
                      '조리 시간 ${minutes.round()}분',
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
                  if (recipe.cookerSteps.length > 1) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '이후 조리 단계',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    for (final item in recipe.cookerSteps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${item.stepNo}. ${item.label} · ${item.temperature}°C · ${item.timeMin}분',
                          style: const TextStyle(color: _sub, fontSize: 13),
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: sent ? _success : _orange,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: !device.isConnected || sending || sent
                        ? null
                        : () async {
                            setState(() => sending = true);
                            try {
                              final session = context
                                  .read<CookingSessionProvider>();
                              if (preheating) {
                                await session.startPreheating(
                                  recipe: recipe,
                                  targetTemperature: temperature.round(),
                                  controlMode: controlMode,
                                );
                              } else {
                                if (session.currentRecipe?.id != recipe.id) {
                                  session.prepareRecipe(recipe);
                                }
                                await session.startRecipeStep(
                                  instructionIndex: instructionIndex,
                                  temperature: temperature.round(),
                                  duration: minutes.round(),
                                );
                              }
                              if (!context.mounted) return;
                              setState(() {
                                sending = false;
                                sent = true;
                              });
                              await Future<void>.delayed(
                                const Duration(milliseconds: 650),
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            } catch (error) {
                              if (!context.mounted) return;
                              setState(() => sending = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('전송하지 못했습니다: $error')),
                              );
                            }
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (sending) ...[
                          const ClipOval(
                            child: CookingRiveAnimation(
                              size: 28,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else if (sent) ...[
                          const Icon(Icons.check_circle),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          sent
                              ? '전송 완료'
                              : sending
                              ? '쿠커에 보내는 중...'
                              : '쿠커로 전송하기',
                        ),
                      ],
                    ),
                  ),
                  if (!device.isConnected)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push('/device');
                      },
                      icon: const Icon(Icons.bluetooth),
                      label: const Text('쿠커 연결하기'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class RecipeCookerPersistentSheet extends StatefulWidget {
  const RecipeCookerPersistentSheet({
    required this.recipe,
    required this.onCookingStarted,
    super.key,
  });

  final Recipe recipe;
  final VoidCallback onCookingStarted;

  @override
  State<RecipeCookerPersistentSheet> createState() =>
      _RecipeCookerPersistentSheetState();
}

class _RecipeCookerPersistentSheetState
    extends State<RecipeCookerPersistentSheet> {
  bool _expanded = false;
  CookingPhase? _lastPhase;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CookingSessionProvider>();
    final device = context.watch<DeviceProvider>();
    final state = session.state;
    if (_lastPhase != state.phase) {
      final enteredCooking = state.phase == CookingPhase.cooking;
      _lastPhase = state.phase;
      if (enteredCooking) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onCookingStarted(),
        );
      }
    }
    if (state.recipe?.id != widget.recipe.id ||
        state.phase == CookingPhase.idle) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 80) return;
        setState(() => _expanded = velocity < 0);
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: Material(
          color: _background,
          elevation: 12,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            side: BorderSide(color: _border),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!device.isConnected &&
                      state.phase != CookingPhase.completed)
                    const _DisconnectedNotice()
                  else if (_expanded)
                    _ExpandedCookerStatus(
                      session: session,
                      recipe: widget.recipe,
                    )
                  else
                    _CollapsedCookerStatus(
                      session: session,
                      recipe: widget.recipe,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedCookerStatus extends StatelessWidget {
  const _CollapsedCookerStatus({required this.session, required this.recipe});

  final CookingSessionProvider session;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final state = session.state;
    final isPreheat = state.phase == CookingPhase.preheating;
    final ready = state.phase == CookingPhase.preheatReady;
    final stepReady = state.phase == CookingPhase.stepReady;
    final completed = state.phase == CookingPhase.completed;
    final step = state.currentInstructionIndex + 1;
    final title = completed
        ? '조리 완료 · ${recipe.title}'
        : ready
        ? '예열 완료 · ${recipe.title}'
        : stepReady
        ? '다음 단계 준비 · ${recipe.title}'
        : isPreheat
        ? '쿠커 예열 중 · ${recipe.title}'
        : '조리 중 · Step $step / ${recipe.instructionSteps.length}';

    return Row(
      children: [
        CookingRiveAnimation(
          size: 48,
          backgroundColor: completed ? _orangeSoft : _background,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                ready
                    ? '본 조리를 자동으로 시작하고 있어요'
                    : stepReady
                    ? '다음 단계 설정을 확인하고 쿠커에 보내주세요'
                    : completed
                    ? '맛있게 완성된 요리를 확인해보세요'
                    : isPreheat
                    ? '${state.currentTemperature}°C → ${state.targetTemperature}°C · 도달 시 자동 조리'
                    : '남은 시간 ${_time(state.remainingSeconds)} · ${state.targetTemperature}°C',
                style: const TextStyle(color: _sub, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.keyboard_arrow_up, color: _sub),
      ],
    );
  }
}

class _ExpandedCookerStatus extends StatelessWidget {
  const _ExpandedCookerStatus({required this.session, required this.recipe});

  final CookingSessionProvider session;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final state = session.state;
    return switch (state.phase) {
      CookingPhase.preheating => _PreheatingDetails(session: session),
      CookingPhase.preheatReady => _PreheatReadyDetails(session: session),
      CookingPhase.cooking => _CookingDetails(session: session, recipe: recipe),
      CookingPhase.stepReady => const _StepReadyDetails(),
      CookingPhase.completed => _CompletedDetails(
        session: session,
        recipe: recipe,
      ),
      CookingPhase.error => const _ErrorDetails(),
      CookingPhase.idle => const SizedBox.shrink(),
    };
  }
}

class _StepReadyDetails extends StatelessWidget {
  const _StepReadyDetails();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.check_circle, color: _success),
          SizedBox(width: 8),
          Text(
            '현재 단계 완료',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      SizedBox(height: 8),
      Text('다음 조리 단계의 설정을 확인한 뒤 쿠커에 보내주세요.', style: TextStyle(color: _sub)),
    ],
  );
}

class _PreheatingDetails extends StatelessWidget {
  const _PreheatingDetails({required this.session});

  final CookingSessionProvider session;

  @override
  Widget build(BuildContext context) {
    final state = session.state;
    final progress = state.targetTemperature <= 0
        ? 0.0
        : (state.currentTemperature / state.targetTemperature).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '쿠커 예열 중',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const CookingRiveAnimation(size: 72),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  _InfoRow(
                    label: '현재 온도',
                    value: '${state.currentTemperature}°C',
                  ),
                  _InfoRow(
                    label: '목표 온도',
                    value: '${state.targetTemperature}°C',
                  ),
                  _InfoRow(label: '전환 방식', value: '목표 온도 도달 시 자동'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: _orange,
          backgroundColor: _orangeSoft,
        ),
        const SizedBox(height: 8),
        const Text('목표 온도까지 가열 중이에요.', style: TextStyle(color: _sub)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: session.isPaused ? '예열 재개' : '일시정지',
                icon: session.isPaused ? Icons.play_arrow : Icons.pause,
                onPressed: session.isPaused
                    ? () => _resumeCooking(context, session)
                    : session.pauseCooking,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: session.stopCooking,
                icon: const Icon(Icons.stop),
                label: const Text('예열 취소'),
                style: OutlinedButton.styleFrom(foregroundColor: _danger),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreheatReadyDetails extends StatelessWidget {
  const _PreheatReadyDetails({required this.session});

  final CookingSessionProvider session;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Row(
        children: [
          Icon(Icons.check_circle, color: _success),
          SizedBox(width: 8),
          Text(
            '예열 완료',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        '목표 온도 ${session.state.targetTemperature}°C에 도달했어요.\n본 조리를 자동으로 시작하고 있습니다.',
        style: const TextStyle(color: _sub, height: 1.5),
      ),
    ],
  );
}

class _CookingDetails extends StatelessWidget {
  const _CookingDetails({required this.session, required this.recipe});

  final CookingSessionProvider session;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final state = session.state;
    final step = state.currentInstructionIndex + 1;
    final next = step < recipe.instructionSteps.length
        ? recipe.instructionSteps[step].description
        : '현재 단계를 마치면 조리가 완료됩니다.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '조리 중 · Step $step / ${recipe.instructionSteps.length}',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const CookingRiveAnimation(size: 72),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('남은 시간', style: TextStyle(color: _sub)),
                Text(
                  _time(state.remainingSeconds),
                  style: const TextStyle(
                    color: _orange,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        _InfoRow(label: '현재 온도', value: '${state.currentTemperature}°C'),
        _InfoRow(label: '목표 온도', value: '${state.targetTemperature}°C'),
        _InfoRow(label: '조리 모드', value: recipe.compatibilityLabel),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _orangeSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('다음 단계\n$next', style: const TextStyle(height: 1.45)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => context.push('/cooking'),
          icon: const Icon(Icons.open_in_full),
          label: const Text('상세보기'),
        ),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: session.isPaused ? '조리 재개' : '일시정지',
                icon: session.isPaused ? Icons.play_arrow : Icons.pause,
                onPressed: session.isPaused
                    ? () => _resumeCooking(context, session)
                    : session.pauseCooking,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: session.stopCooking,
                icon: const Icon(Icons.stop),
                label: const Text('조리 종료'),
                style: OutlinedButton.styleFrom(foregroundColor: _danger),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _resumeCooking(
  BuildContext context,
  CookingSessionProvider session,
) async {
  final roundedMinutes = await session.resumeCooking();
  if (!context.mounted || roundedMinutes == null) return;
  showAppToast(
    context,
    '30초 기준으로 반올림해 $roundedMinutes분으로 재개했어요.',
    success: true,
  );
}

class _CompletedDetails extends StatelessWidget {
  const _CompletedDetails({required this.session, required this.recipe});

  final CookingSessionProvider session;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '조리가 완료됐어요',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      const Text('맛있게 완성된 요리를 확인해보세요.', style: TextStyle(color: _sub)),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: session.finishSession,
        style: _primaryStyle,
        child: const Text('완료'),
      ),
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => context.push('/community'),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('후기 작성하기'),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: () {
                context.read<RecipeProvider>().toggleSaved(recipe.id);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('레시피를 저장했습니다.')));
              },
              icon: const Icon(Icons.bookmark_border),
              label: const Text('레시피 저장'),
            ),
          ),
        ],
      ),
    ],
  );
}

class _DisconnectedNotice extends StatelessWidget {
  const _DisconnectedNotice();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.bluetooth_disabled, color: _danger),
      const SizedBox(width: 10),
      const Expanded(
        child: Text(
          '쿠커 연결이 끊겼습니다.',
          style: TextStyle(color: _danger, fontWeight: FontWeight.w800),
        ),
      ),
      TextButton(
        onPressed: () => context.push('/device'),
        child: const Text('다시 연결'),
      ),
    ],
  );
}

class _ErrorDetails extends StatelessWidget {
  const _ErrorDetails();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.error_outline, color: _danger),
      SizedBox(width: 10),
      Text('쿠커에서 오류가 발생했습니다.', style: TextStyle(color: _danger)),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = _ink,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: _sub)),
        ),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: _orangeSoft,
      foregroundColor: _orange,
    ),
  );
}

const _primaryStyle = ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(_orange),
  foregroundColor: WidgetStatePropertyAll(Colors.white),
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(50)),
);

String _time(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}
