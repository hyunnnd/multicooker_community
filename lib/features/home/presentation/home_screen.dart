import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';
import '../../../core/widgets/spotlight_tutorial.dart';
import '../../device/provider/device_provider.dart';
import '../../profile/provider/profile_provider.dart';
import '../../recipe/data/models/recipe.dart';
import '../../recipe/presentation/widgets/figma_recipe_widgets.dart';
import '../../recipe/provider/recipe_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.startTutorial = false});

  final bool startTutorial;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _connectionKey = GlobalKey();
  final _featuredKey = GlobalKey();
  final _aiKey = GlobalKey();
  final _navigationKey = GlobalKey();
  var _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _scheduleTutorial(widget.startTutorial);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.startTutorial && widget.startTutorial) {
      _scheduleTutorial(true);
    }
  }

  void _scheduleTutorial(bool start) {
    if (start) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showTutorial = true);
      });
    }
  }

  Future<void> _openMyProfile() async {
    final profile = context.read<ProfileProvider>();
    if (profile.summary == null) {
      await profile.refreshSummary();
    }
    if (!mounted) return;
    final userId = profile.summary?.id;
    if (userId == null || userId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 정보를 불러오지 못했습니다.')),
      );
      return;
    }
    context.push('/community/profile/$userId?editable=1&from=home');
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final profile = context.watch<ProfileProvider>();
    final recipeProvider = context.watch<RecipeProvider>();
    final featured = figmaFeaturedRecipe(recipeProvider.recipes);
    final tutorialBottomInset = MediaQuery.paddingOf(context).bottom + 76;

    final steps = [
      SpotlightTutorialStep(
        targetKey: _connectionKey,
        title: '쿠커 연결',
        description: device.isConnected
            ? '${device.deviceName}가 연결되어 있어요. 이곳에서 연결 상태와 기기 관리를 확인할 수 있어요.'
            : '여기서 Graphene Cooker를 블루투스로 연결하세요. 연결 후 앱에서 온도와 시간을 제어할 수 있어요.',
        padding: 8,
        radius: 20,
      ),
      if (featured != null)
        SpotlightTutorialStep(
          targetKey: _featuredKey,
          title: '오늘의 추천 레시피',
          description:
              '${featured.title}을 포함한 추천 레시피를 탭하면 재료와 조리 단계, 쿠커 설정을 확인할 수 있어요.',
          padding: 6,
          radius: 24,
        ),
      SpotlightTutorialStep(
        targetKey: _aiKey,
        title: 'AI 레시피 추천',
        description: '냉장고 속 식재료를 사진으로 찍으면 AI가 만들 수 있는 레시피를 추천해드려요.',
        padding: 8,
        radius: 18,
        cardAboveTarget: true,
        cardBottomInset: tutorialBottomInset,
      ),
      SpotlightTutorialStep(
        targetKey: _navigationKey,
        title: '탭으로 자유롭게 이동하세요',
        description: '하단 탭에서 AI 추천, 레시피, 커뮤니티와 설정을 언제든지 이용할 수 있어요.',
        padding: 0,
        radius: 0,
        cardBottomInset: tutorialBottomInset,
      ),
    ];

    return MainRouteBackScope(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: figmaBg,
            bottomNavigationBar: MainNavigationBar(
              key: _navigationKey,
              currentIndex: 2,
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _todayLabel(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: figmaOrange,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '오늘 뭐 드실래요?',
                                    style: TextStyle(
                                      fontSize: 26,
                                      height: 1.2,
                                      fontWeight: FontWeight.w900,
                                      color: figmaGray900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _openMyProfile,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      profile.summary?.avatarColor ??
                                          0xFF111827,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1A000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: profile.summary?.avatarImageUrl != null &&
                                          profile.summary!.avatarImageUrl!.isNotEmpty
                                      ? Image.network(
                                          profile.summary!.avatarImageUrl!,
                                          fit: BoxFit.cover,
                                          width: 40,
                                          height: 40,
                                          errorBuilder: (_, __, ___) => Text(
                                            _profileInitial(
                                              profile.summary?.nickname,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          _profileInitial(
                                            profile.summary?.nickname,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        KeyedSubtree(
                          key: _connectionKey,
                          child: _DeviceConnectionCard(device: device),
                        ),
                      ],
                    ),
                  ),
                  if (featured != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Expanded(
                                child: Text(
                                  '오늘의 추천',
                                  style: TextStyle(
                                    color: figmaOrange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => context.go('/recipes'),
                                child: const Text(
                                  '더 보기 →',
                                  style: TextStyle(
                                    color: figmaGray400,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          KeyedSubtree(
                            key: _featuredKey,
                            child: FigmaFeaturedRecipeCard(
                              recipe: featured,
                              home: true,
                              onTap: () => _openRecipe(
                                context,
                                recipeProvider,
                                featured,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: KeyedSubtree(
                            key: _aiKey,
                            child: _QuickAction(
                              icon: Icons.auto_awesome_rounded,
                              iconColor: figmaOrange,
                              backgroundColor: const Color(0xFFFFF3E7),
                              label: 'AI 추천',
                              subtitle: '재료로 찾기',
                              onTap: () => context.go('/ai-scan'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.bookmark_border_rounded,
                            iconColor: figmaNavy,
                            backgroundColor: const Color(0xFFEFF6FF),
                            label: '저장한 레시피',
                            subtitle: '${profile.savedRecipes.length}개',
                            onTap: () => context.push('/my/saved-recipes'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.history_rounded,
                            iconColor: figmaGreen,
                            backgroundColor: const Color(0xFFECFDF5),
                            label: '최근 조리',
                            subtitle: '${profile.histories.length}회',
                            onTap: () => context.push('/my/cooking-history'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showTutorial)
            SpotlightTutorial(
              steps: steps,
              onComplete: () async {
                setState(() => _showTutorial = false);
                final profile = context.read<ProfileProvider>();
                await profile.updateSettings(
                  profile.settings.copyWith(tutorialCompleted: true),
                );
                if (mounted) context.go('/home');
              },
            ),
        ],
      ),
    );
  }

  static void _openRecipe(
    BuildContext context,
    RecipeProvider provider,
    Recipe recipe,
  ) {
    provider.selectRecipe(recipe.id);
    context.push('/recipes/${recipe.id}');
  }
}

String _profileInitial(String? nickname) {
  final value = nickname?.trim() ?? '';
  if (value.isEmpty) return 'U';
  return value.characters.first.toUpperCase();
}

String _todayLabel() {
  const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  final now = DateTime.now();
  return '${now.month}월 ${now.day}일 ${weekdays[now.weekday % 7]}요일';
}

class _DeviceConnectionCard extends StatelessWidget {
  const _DeviceConnectionCard({required this.device});

  final DeviceProvider device;

  @override
  Widget build(BuildContext context) {
    final adapterOff =
        device.connectionEvent?.name == 'disconnectedByAdapterOff';
    final Color color;
    final Color background;
    final Color border;
    final IconData icon;
    final String label;

    if (device.isConnected) {
      color = const Color(0xFF15803D);
      background = const Color(0xFFF0FDF4);
      border = const Color(0xFFA7E0BF);
      icon = Icons.check_circle_outline_rounded;
      label = '${device.deviceName} 연결됨';
    } else if (device.reconnectingAfterLoss) {
      color = figmaOrangeDark;
      background = const Color(0xFFFFF7ED);
      border = const Color(0xFFFED7AA);
      icon = Icons.sync_rounded;
      label = '블루투스 연결 끊김 — 재연결 ${device.reconnectAttempt}/3';
    } else if (adapterOff) {
      color = const Color(0xFFDC2626);
      background = const Color(0xFFFEF2F2);
      border = const Color(0xFFFCA5A5);
      icon = Icons.bluetooth_disabled_rounded;
      label = '블루투스 어댑터가 꺼져있어요';
    } else if (device.errorMessage != null) {
      color = const Color(0xFFDC2626);
      background = const Color(0xFFFEF2F2);
      border = const Color(0xFFFCA5A5);
      icon = Icons.error_outline_rounded;
      label = '자동 재연결 실패 — 다시 연결해 주세요';
    } else {
      color = const Color(0xFF2563EB);
      background = const Color(0xFFEFF6FF);
      border = const Color(0xFFBFDBFE);
      icon = Icons.link_rounded;
      label = '연결되지 않음 — 연결해 주세요';
    }

    return InkWell(
      onTap: () => context.go('/device'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Icon(icon, size: 26, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: figmaGray100),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: iconColor),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: figmaGray900,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: figmaGray400,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
