import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const attachOrange = Color(0xFFF97316);
const attachGray400 = Color(0xFF9CA3AF);

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({required this.currentIndex, super.key});

  final int currentIndex;

  static const _paths = [
    '/home',
    '/recipes',
    '/device',
    '/community',
    '/settings',
  ];

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavItem(Icons.home_outlined, Icons.home, '홈'),
      _NavItem(Icons.menu_book_outlined, Icons.menu_book, '레시피'),
      _NavItem(Icons.memory_outlined, Icons.memory, '쿠커'),
      _NavItem(Icons.people_outline, Icons.people, '커뮤니티'),
      _NavItem(Icons.person_outline, Icons.person, '마이'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final active = currentIndex == index;
            final item = items[index];
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
                      color: active ? attachOrange : attachGray400,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? attachOrange : attachGray400,
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
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '뒤로가기',
      icon: const Icon(Icons.arrow_back),
      color: const Color(0xFF6B7280),
      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
    );
  }
}
