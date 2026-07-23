import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_toast.dart';
import '../provider/cooking_session_provider.dart';
import 'widgets/cooker_status_panel.dart';
import 'widgets/cooking_progress_card.dart';
import 'widgets/cooking_rive_animation.dart';
import 'widgets/user_action_required_modal.dart';

class GuidedCookingScreen extends StatelessWidget {
  const GuidedCookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CookingSessionProvider>();
    final recipe = session.currentRecipe;
    final instruction = session.currentInstruction;
    if (recipe == null || instruction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('조리 진행')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/recipes'),
            child: const Text('레시피 선택하기'),
          ),
        ),
      );
    }
    if (session.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/cooking/complete');
      });
    }
    final index = session.state.currentInstructionIndex;
    final next = index + 1 < recipe.instructionSteps.length
        ? recipe.instructionSteps[index + 1]
        : null;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                CookingProgressCard(
                  current: index + 1,
                  total: recipe.instructionSteps.length,
                  recipeTitle: recipe.title,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    children: [
                      if (session.state.isRunning &&
                          !session.isPaused &&
                          session.currentCookerStep != null)
                        const _CookingWaitAnimation()
                      else
                        Container(
                          height: 190,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: instruction.imageUrl == null
                              ? const Icon(
                                  Icons.restaurant,
                                  size: 56,
                                  color: Color(0xFF3378C0),
                                )
                              : Image.network(
                                  instruction.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.restaurant, size: 56),
                                ),
                        ),
                      const SizedBox(height: 18),
                      Text(
                        instruction.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        instruction.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      CookerStatusPanel(
                        step: session.currentCookerStep,
                        remainingSeconds: session.state.remainingSeconds,
                      ),
                      if (next != null) ...[
                        const SizedBox(height: 14),
                        ListTile(
                          tileColor: const Color(0xFFF3F4F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          leading: const Icon(Icons.chevron_right),
                          title: const Text(
                            '다음 단계',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          subtitle: Text(
                            next.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: session.isPaused ? '재개' : '일시정지',
                        onPressed: session.isPaused
                            ? () => _resumeCooking(context, session)
                            : session.pauseCooking,
                        icon: Icon(
                          session.isPaused ? Icons.play_arrow : Icons.pause,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: session.moveToNextStep,
                          icon: const Icon(Icons.check),
                          label: Text(instruction.actionLabel ?? '완료했어요'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: '조리 중지',
                        onPressed: () => _confirmStop(context, session),
                        icon: const Icon(Icons.stop, color: Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (session.needsUserAction)
              UserActionRequiredModal(
                title: instruction.title,
                message:
                    session.state.currentUserActionMessage ??
                    instruction.description,
                actionLabel: instruction.actionLabel ?? '완료했어요',
                onComplete: session.completeCurrentUserAction,
                onAddMinute: session.addOneMinute,
                onStop: () => _confirmStop(context, session),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmStop(
    BuildContext context,
    CookingSessionProvider session,
  ) async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('조리를 중지할까요?'),
        content: const Text('진행 중인 조리와 연결된 쿠커가 정지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 조리'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('중지'),
          ),
        ],
      ),
    );
    if (stop != true) return;
    await session.stopCooking();
    if (context.mounted) context.go('/home');
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

class _CookingWaitAnimation extends StatefulWidget {
  const _CookingWaitAnimation();

  @override
  State<_CookingWaitAnimation> createState() => _CookingWaitAnimationState();
}

class _CookingWaitAnimationState extends State<_CookingWaitAnimation> {
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9ED),
      border: Border.all(color: const Color(0xFFE8E2D7)),
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const CookingRiveAnimation(),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '조리가 진행 중이에요',
          style: TextStyle(
            color: Color(0xFF292929),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '잠시만 기다려주세요',
          style: TextStyle(color: Color(0xFF77736C), fontSize: 14),
        ),
      ],
    ),
  );
}
