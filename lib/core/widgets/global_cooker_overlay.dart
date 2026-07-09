import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/cooking/data/models/cooking_session_state.dart';
import '../../features/cooking/presentation/widgets/cooking_rive_animation.dart';
import '../../features/cooking/provider/cooking_session_provider.dart';

class GlobalCookerOverlay extends StatelessWidget {
  const GlobalCookerOverlay({
    required this.child,
    required this.currentPath,
    required this.onOpenCooking,
    super.key,
  });

  final Widget child;
  final String currentPath;
  final ValueChanged<String> onOpenCooking;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CookingSessionProvider>();
    final recipe = session.currentRecipe;
    final phase = session.state.phase;
    final active =
        recipe != null &&
        phase != CookingPhase.idle &&
        phase != CookingPhase.completed;
    final onCookingScreen =
        currentPath == '/cooking' ||
        (currentPath.startsWith('/recipes/') && currentPath.endsWith('/cook'));

    return Stack(
      children: [
        child,
        if (active && !onCookingScreen)
          Positioned(
            left: 12,
            right: 12,
            bottom: 84,
            child: GestureDetector(
              onTap: () => onOpenCooking(recipe.id),
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -80) {
                  onOpenCooking(recipe.id);
                }
              },
              child: Material(
                elevation: 10,
                color: const Color(0xFFFFFFF5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFE8E2D7)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        child: CookingRiveAnimation(size: 46),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(session),
                              style: const TextStyle(
                                color: Color(0xFF292929),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _subtitle(session),
                              style: const TextStyle(
                                color: Color(0xFF77736C),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_up,
                        color: Color(0xFFF97316),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _title(CookingSessionProvider session) =>
      switch (session.state.phase) {
        CookingPhase.preheating => '쿠커 예열 중 · ${session.currentRecipe!.title}',
        CookingPhase.preheatReady => '예열 완료 · 다음 단계 준비',
        CookingPhase.cooking =>
          '조리 중 · Step ${session.state.currentInstructionIndex + 1}',
        CookingPhase.stepReady => '다음 단계 입력을 기다리고 있어요',
        CookingPhase.error => '쿠커 상태를 확인해주세요',
        _ => session.currentRecipe!.title,
      };

  String _subtitle(CookingSessionProvider session) {
    final state = session.state;
    if (state.phase == CookingPhase.preheating) {
      return '${state.currentTemperature}°C → ${state.targetTemperature}°C';
    }
    if (state.phase == CookingPhase.cooking) {
      return '남은 시간 ${_time(state.remainingSeconds)} · ${state.targetTemperature}°C';
    }
    return '위로 밀거나 탭해서 조리 화면으로 이동';
  }
}

String _time(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}
