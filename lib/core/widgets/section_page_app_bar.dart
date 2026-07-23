import 'package:flutter/material.dart';

import 'main_navigation.dart';

/// 설정 하위 화면에서 사용하는 공통 상단 바입니다.
/// 앱마스터의 기기 관리 화면과 동일하게 회색 배경, 왼쪽 뒤로가기,
/// 오른쪽의 작은 회색 제목으로 구성합니다.
class SectionPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SectionPageAppBar({
    required this.title,
    this.fallbackPath,
    super.key,
  });

  final String title;
  final String? fallbackPath;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: AppBackButton(fallbackPath: fallbackPath),
      ),
      leadingWidth: 60,
      backgroundColor: const Color(0xFFF8FAFC),
      surfaceTintColor: const Color(0xFFF8FAFC),
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 26),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
