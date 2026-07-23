import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../language/language_provider.dart';
import 'app_back_paths.dart';

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({required this.currentIndex, super.key});

  final int currentIndex;

  static const _paths = [
    '/ai-scan',
    '/recipes',
    '/home',
    '/community',
    '/settings',
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final items = [
      const _NavItem(Icons.camera_alt_outlined, Icons.camera_alt, 'AI'),
      _NavItem(
        Icons.menu_book_outlined,
        Icons.menu_book,
        lang.t('레시피', 'Recipe'),
      ),
      _NavItem(Icons.home_outlined, Icons.home, lang.t('홈', 'Home')),
      _NavItem(Icons.forum_outlined, Icons.forum, lang.t('커뮤니티', 'Community')),
      _NavItem(Icons.person_outline, Icons.person, lang.t('설정', 'My')),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final active = currentIndex == index;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (index != currentIndex) context.go(_paths[index]);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? item.activeIcon : item.icon,
                      size: 22,
                      color: active
                          ? const Color(0xFFF97316)
                          : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active
                            ? const Color(0xFFF97316)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    this.fallbackPath,
    this.heroOverlay = false,
    this.onPressed,
    super.key,
  });

  final String? fallbackPath;
  final bool heroOverlay;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    void goBack() {
      if (onPressed != null) {
        onPressed!();
        return;
      }
      if (context.canPop()) {
        context.pop();
        return;
      }
      final currentPath = GoRouterState.of(context).uri.path;
      context.go(fallbackPath ?? appBackFallbackForPath(currentPath));
    }

    if (!heroOverlay) {
      return Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            tooltip: '뒤로가기',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            color: const Color(0xFF6B7280),
            onPressed: goBack,
          ),
        ),
      );
    }

    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0x99505050),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IconButton(
          tooltip: '뒤로가기',
          onPressed: goBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
