import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../router/app_router.dart';
import '../../features/auth/provider/auth_provider.dart';
import '../../features/cooking/data/models/cooking_session_state.dart';
import '../../features/cooking/provider/cooking_session_provider.dart';
import '../../features/device/provider/device_provider.dart';
import '../../features/pet/domain/pet_animation_state.dart';
import '../../features/pet/presentation/cooking_pet_game.dart';
import '../../features/profile/provider/profile_provider.dart';
import 'tutorial_visibility.dart';

class GlobalCookerOverlay extends StatefulWidget {
  const GlobalCookerOverlay({
    required this.child,
    required this.currentPath,
    required this.onOpenCooking,
    this.hidePet = false,
    super.key,
  });

  final Widget child;
  final String currentPath;
  final ValueChanged<String> onOpenCooking;
  final bool hidePet;

  @override
  State<GlobalCookerOverlay> createState() => _GlobalCookerOverlayState();
}

class _GlobalCookerOverlayState extends State<GlobalCookerOverlay> {
  final _petKey = GlobalKey<_CookerPetButtonState>();
  Offset? _petPosition;
  Offset? _dragStartPointer;
  Offset? _dragStartPetPosition;
  Size? _draggedPetSize;
  bool _tutorialActive = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final hidden =
        _tutorialActive ||
        widget.hidePet ||
        !profile.settings.slimeEnabled ||
        _isAuthRoute(
          widget.currentPath,
          isAuthenticated: auth.isAuthenticated,
        );
    final content = hidden ? widget.child : _buildPetOverlay(context);
    return NotificationListener<TutorialVisibilityNotification>(
      onNotification: (notification) {
        if (_tutorialActive != notification.visible) {
          setState(() => _tutorialActive = notification.visible);
        }
        return false;
      },
      child: content,
    );
  }

  Widget _buildPetOverlay(BuildContext context) {
    final session = context.watch<CookingSessionProvider>();
    final device = context.watch<DeviceProvider>();
    final recipe = session.currentRecipe;
    final phase = session.state.phase;
    final hasSession = recipe != null && phase != CookingPhase.idle;
    final active = hasSession && phase != CookingPhase.completed;
    final connectionLost = device.reconnectingAfterLoss;
    final connectionIssue =
        connectionLost || (!device.isConnected && device.errorMessage != null);
    final status = connectionIssue
        ? AppPetStatus.error
        : hasSession
        ? _statusForCooking(phase)
        : _statusForDevice(device);
    final allowSleep = !hasSession;
    final needsConnection =
        !device.isConnected && _isCookingRoute(widget.currentPath);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _petKey.currentState?.recordUserInteraction(),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            widget.child,
            Positioned(
              left: _petPosition?.dx,
              top: _petPosition?.dy,
              right: _petPosition == null ? 12 : null,
              bottom: _petPosition == null ? 80 : null,
              child: _CookerPetButton(
                key: _petKey,
                status: status,
                allowSleep: allowSleep,
                isConnectionIssue: connectionIssue,
                bubbleText: connectionLost
                    ? '재연결 ${device.reconnectAttempt}/3'
                    : connectionIssue
                    ? '연결 오류 · 기기 관리'
                    : needsConnection
                    ? '저를 눌러 연결하러 가요'
                    : active && status == AppPetStatus.cooking
                    ? _bubbleText(session)
                    : null,
                title: connectionLost
                    ? '한돌이가 쿠커를 다시 찾고 있어요'
                    : connectionIssue
                    ? '한돌이가 쿠커 연결을 확인하고 있어요'
                    : needsConnection
                    ? '한돌이가 쿠커 연결을 기다리고 있어요'
                    : active
                    ? _title(session)
                    : _deviceTitle(status),
                subtitle: connectionLost
                    ? '가까이 두면 자동으로 다시 연결할게요'
                    : connectionIssue
                    ? '탭해서 기기 관리 화면을 열어주세요'
                    : active
                    ? _subtitle(session)
                    : _deviceSubtitle(status),
                onTap: connectionIssue || needsConnection
                    ? () => appRouter.go('/device')
                    : active
                    ? () => widget.onOpenCooking(recipe.id)
                    : null,
                onDragStart: _beginPetDrag,
                onDrag: (position) => _movePet(position, constraints.biggest),
                onDragEnd: _endPetDrag,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCookingRoute(String path) =>
      path == '/cooking' ||
      (path.startsWith('/recipes/') && path.endsWith('/cook'));

  bool _isAuthRoute(
    String path, {
    required bool isAuthenticated,
  }) =>
      path == '/' ||
      path == '/login' ||
      path.startsWith('/register') ||
      (!isAuthenticated && path.startsWith('/reset'));

  void _beginPetDrag(Offset globalPosition) {
    final overlayBox = context.findRenderObject() as RenderBox?;
    final petBox = _petKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || petBox == null || !petBox.hasSize) return;

    _dragStartPointer = overlayBox.globalToLocal(globalPosition);
    _dragStartPetPosition = overlayBox.globalToLocal(
      petBox.localToGlobal(Offset.zero),
    );
    _draggedPetSize = petBox.size;
  }

  void _movePet(Offset globalPosition, Size overlaySize) {
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
    if (_dragStartPointer == null || _dragStartPetPosition == null) {
      _beginPetDrag(globalPosition);
    }

    final startPointer = _dragStartPointer;
    final startPetPosition = _dragStartPetPosition;
    if (startPointer == null || startPetPosition == null) return;

    final currentPointer = overlayBox.globalToLocal(globalPosition);
    final delta = currentPointer - startPointer;
    final petSize = _draggedPetSize ?? const Size(136, 66);
    final maxX = (overlaySize.width - petSize.width).clamp(0.0, double.infinity);
    final maxY = (overlaySize.height - petSize.height).clamp(0.0, double.infinity);
    final target = startPetPosition + delta;

    setState(() {
      _petPosition = Offset(
        target.dx.clamp(0.0, maxX).toDouble(),
        target.dy.clamp(0.0, maxY).toDouble(),
      );
    });
  }

  void _endPetDrag() {
    _dragStartPointer = null;
    _dragStartPetPosition = null;
    _draggedPetSize = null;
  }

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
    _ => '한돌이가 대기 중이에요',
  };

  String _deviceSubtitle(AppPetStatus status) => switch (status) {
    AppPetStatus.searching => '주변 Graphene Cooker 검색 중',
    AppPetStatus.connecting => '연결을 준비하고 있어요',
    AppPetStatus.connected || AppPetStatus.cooking => '기기 관리에서 조리 설정 가능',
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
    super.key,
    required this.status,
    required this.allowSleep,
    required this.isConnectionIssue,
    required this.bubbleText,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
  });

  final AppPetStatus status;
  final bool allowSleep;
  final bool isConnectionIssue;
  final String? bubbleText;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final ValueChanged<Offset> onDragStart;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  @override
  State<_CookerPetButton> createState() => _CookerPetButtonState();
}

class _CookerPetButtonState extends State<_CookerPetButton> {
  late final CookingPetGame _game = CookingPetGame(
    displaySize: 61,
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

  void recordUserInteraction() => _game.recordUserInteraction();

  void _handleTap() {
    _game.playTapped(notify: false);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '한돌이, ${widget.title}',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onPanStart: (details) {
        _game.startStruggling();
        widget.onDragStart(details.globalPosition);
      },
      onPanUpdate: (details) => widget.onDrag(details.globalPosition),
      onPanEnd: (_) {
        _game.stopStruggling();
        widget.onDragEnd();
      },
      onPanCancel: () {
        _game.stopStruggling();
        widget.onDragEnd();
      },
      child: SizedBox(
        width: 136,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.bubbleText != null) ...[
              _PetStatusBubble(
                text: widget.bubbleText!,
                showNavigationHint: widget.isConnectionIssue,
              ),
              const SizedBox(height: 4),
            ],
            SizedBox(
              width: 66,
              height: 66,
              child: ColorFiltered(
                colorFilter: widget.isConnectionIssue
                    ? const ColorFilter.mode(
                        Color(0xFFFF3B30),
                        BlendMode.modulate,
                      )
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: AbsorbPointer(
                  child: GameWidget(
                    game: _game,
                    backgroundBuilder: (_) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PetStatusBubble extends StatelessWidget {
  const _PetStatusBubble({
    required this.text,
    required this.showNavigationHint,
  });

  final String text;
  final bool showNavigationHint;

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
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
          if (showNavigationHint) ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Color(0xFF292929),
            ),
          ],
        ],
      ),
    ),
  );
}

String _time(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}
