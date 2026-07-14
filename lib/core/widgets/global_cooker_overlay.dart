import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/cooking/data/models/cooking_session_state.dart';
import '../../features/cooking/provider/cooking_session_provider.dart';
import '../../features/device/provider/device_provider.dart';
import '../../features/pet/domain/pet_animation_state.dart';
import '../../features/pet/presentation/cooking_pet_game.dart';

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
    final device = context.watch<DeviceProvider>();
    final recipe = session.currentRecipe;
    final phase = session.state.phase;
    final hasSession = recipe != null && phase != CookingPhase.idle;
    final active = hasSession && phase != CookingPhase.completed;
    final onCookingScreen =
        currentPath == '/cooking' ||
        (currentPath.startsWith('/recipes/') && currentPath.endsWith('/cook'));
    final showPet = _isPetEnabledPath(currentPath) && !onCookingScreen;
    final status = hasSession
        ? _statusForCooking(phase)
        : _statusForDevice(device);
    final allowSleep = !hasSession;

    return Stack(
      children: [
        child,
        if (showPet)
          Positioned(
            right: 12,
            bottom: 80,
            child: _CookerPetButton(
              status: status,
              allowSleep: allowSleep,
              bubbleText: active && status == AppPetStatus.cooking
                  ? _bubbleText(session)
                  : null,
              title: active ? _title(session) : _deviceTitle(status),
              subtitle: active ? _subtitle(session) : _deviceSubtitle(status),
              onTap: active ? () => onOpenCooking(recipe!.id) : null,
            ),
          ),
      ],
    );
  }

  bool _isPetEnabledPath(String path) =>
      path == '/home' ||
      path == '/device' ||
      path == '/community' ||
      path == '/settings' ||
      path.startsWith('/recipes') ||
      path.startsWith('/ai');

  AppPetStatus _statusForCooking(CookingPhase phase) => switch (phase) {
    CookingPhase.preheating || CookingPhase.cooking => AppPetStatus.cooking,
    CookingPhase.preheatReady || CookingPhase.stepReady => AppPetStatus.waiting,
    CookingPhase.completed => AppPetStatus.success,
    CookingPhase.error => AppPetStatus.error,
    _ => AppPetStatus.idle,
  };

  AppPetStatus _statusForDevice(DeviceProvider device) {
    if (device.isScanning) return AppPetStatus.searching;
    if (device.isBusy) return AppPetStatus.connecting;
    if (device.isConnected) return AppPetStatus.connected;
    if (device.errorMessage != null) return AppPetStatus.error;
    return AppPetStatus.idle;
  }

  String _deviceTitle(AppPetStatus status) => switch (status) {
    AppPetStatus.searching => '쿠커를 찾고 있어요',
    AppPetStatus.connecting => '쿠커와 연결 중이에요',
    AppPetStatus.connected || AppPetStatus.cooking => '쿠커 연결됨',
    AppPetStatus.error => '쿠커 상태를 확인해주세요',
    _ => '쿠키가 대기 중이에요',
  };

  String _deviceSubtitle(AppPetStatus status) => switch (status) {
    AppPetStatus.searching => '주변 Graphene Cooker 검색 중',
    AppPetStatus.connecting => '연결을 준비하고 있어요',
    AppPetStatus.connected || AppPetStatus.cooking => '기기 관리에서 조리 설정 가능',
    AppPetStatus.error => '기기를 가까이 두고 다시 시도해 주세요',
    _ => '기기를 연결하면 바로 도와드릴게요',
  };

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
    return '펫을 탭해서 조리 화면으로 이동';
  }

  String _bubbleText(CookingSessionProvider session) {
    final state = session.state;
    final temp = state.phase == CookingPhase.preheating
        ? '${state.currentTemperature}°/${state.targetTemperature}°'
        : '${state.targetTemperature}°C';
    return '${_time(state.remainingSeconds)} · $temp';
  }
}

class _CookerPetButton extends StatefulWidget {
  const _CookerPetButton({
    required this.status,
    required this.allowSleep,
    required this.bubbleText,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AppPetStatus status;
  final bool allowSleep;
  final String? bubbleText;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  State<_CookerPetButton> createState() => _CookerPetButtonState();
}

class _CookerPetButtonState extends State<_CookerPetButton> {
  late final CookingPetGame _game = CookingPetGame(
    displaySize: 76,
    onPetTapped: widget.onTap,
  );

  @override
  void initState() {
    super.initState();
    _game.setAppStatus(widget.status, allowSleep: widget.allowSleep);
  }

  @override
  void didUpdateWidget(covariant _CookerPetButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _game.onPetTapped = widget.onTap;
    _game.setAppStatus(widget.status, allowSleep: widget.allowSleep);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.title,
    child: GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -80) widget.onTap?.call();
      },
      child: SizedBox(
        width: 136,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.bubbleText != null) ...[
              _PetStatusBubble(text: widget.bubbleText!),
              const SizedBox(height: 4),
            ],
            SizedBox(
              width: 84,
              height: 84,
              child: GameWidget(
                game: _game,
                backgroundBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PetStatusBubble extends StatelessWidget {
  const _PetStatusBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFFFF5),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFE8E2D7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF292929),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}

String _time(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}
