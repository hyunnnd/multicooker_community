import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../domain/pet_animation_state.dart';
import 'cooking_pet_game.dart';

class PetTestScreen extends StatefulWidget {
  const PetTestScreen({super.key});

  @override
  State<PetTestScreen> createState() => _PetTestScreenState();
}

class _PetTestScreenState extends State<PetTestScreen> {
  late final CookingPetGame _game = CookingPetGame(
    onPetTapped: () => setState(() {}),
  );
  AppPetStatus _status = AppPetStatus.idle;

  void _setStatus(AppPetStatus status) {
    setState(() => _status = status);
    _game.setAppStatus(status);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFAF8),
    appBar: AppBar(title: const Text('펫 상태 테스트')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: GameWidget(
                game: _game,
                backgroundBuilder: (_) =>
                    const ColoredBox(color: Colors.transparent),
              ),
            ),
            ValueListenableBuilder<PetAnimationState>(
              valueListenable: _game.displayedState,
              builder: (_, displayed, _) => Column(
                children: [
                  Text(
                    displayed.name,
                    style: const TextStyle(
                      color: Color(0xFF292929),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '앱 상태: ${_status.name} · 표시 중: ${displayed.name}',
                    style: const TextStyle(color: Color(0xFF77736C)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final status in AppPetStatus.values)
                  OutlinedButton(
                    onPressed: () => _setStatus(status),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: status == _status
                            ? const Color(0xFFFE7902)
                            : const Color(0xFFE8E2D7),
                      ),
                    ),
                    child: Text(status.name),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
