import 'package:flutter/material.dart';

/// 공통 더보기 메뉴 버튼입니다.
///
/// 최근 조리 이력 카드의 회색 둥근 버튼과 팝업 표면 디자인을
/// 커뮤니티 및 마이페이지 전반에서 동일하게 사용합니다.
class AppMoreMenuButton<T> extends StatelessWidget {
  const AppMoreMenuButton({
    required this.itemBuilder,
    required this.onSelected,
    super.key,
    this.tooltip = '옵션',
    this.enabled = true,
    this.offset = const Offset(0, 44),
    this.constraints = const BoxConstraints(minWidth: 160, maxWidth: 240),
    this.onCanceled,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;
  final String tooltip;
  final bool enabled;
  final Offset offset;
  final BoxConstraints constraints;
  final PopupMenuCanceled? onCanceled;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
        tooltip: tooltip,
        enabled: enabled,
        padding: EdgeInsets.zero,
        // app-master와 동일하게 버튼 기준(over) 위치에 44px만 보정합니다.
        // `under`와 44px 오프셋을 함께 쓰면 버튼 아래에서 한 번 더 밀려
        // 팝업이 과하게 떨어져 보입니다.
        position: PopupMenuPosition.over,
        offset: offset,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 6,
        constraints: constraints,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        onSelected: onSelected,
        onCanceled: onCanceled,
        itemBuilder: itemBuilder,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.more_horiz_rounded,
            color: Color(0xFF6B7280),
            size: 20,
          ),
        ),
      );
}
