part of '../community_screen.dart';

class _SimpleHeader extends StatelessWidget {
  const _SimpleHeader({required this.title, required this.onBack, this.trailing, this.border = true});
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(border: border ? const Border(bottom: BorderSide(color: _gray100)) : null),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: GestureDetector(onTap: onBack, child: const SizedBox(width: 42, child: Icon(Icons.arrow_back, size: 21, color: _text2)))),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _text)),
          if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing!),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color, required this.size, required this.fontSize});
  final String name;
  final Color color;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(name.isEmpty ? '?' : name.substring(0, 1), style: TextStyle(fontSize: fontSize, color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});
  final PostCategory category;

  @override
  Widget build(BuildContext context) {
    final isQa = category == PostCategory.qa;
    return _Pill(
      label: category.label,
      bg: isQa ? _orange100 : const Color(0xFFDBEAFE),
      fg: isQa ? _orangeText : const Color(0xFF2563EB),
      fontSize: 11,
      weight: FontWeight.w600,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg, required this.fontSize, required this.weight});
  final String label;
  final Color bg;
  final Color fg;
  final double fontSize;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: fontSize, color: fg, fontWeight: weight, height: 1)),
    );
  }
}

class _SmallActionIcon extends StatelessWidget {
  const _SmallActionIcon({required this.icon, required this.label, required this.color, this.onTap, this.iconSize = 16, this.fontSize = 12});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: fontSize, color: color)),
        ],
      ),
    );
  }
}

class _NetworkImageBox extends StatelessWidget {
  const _NetworkImageBox({required this.url, required this.width, required this.height});
  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppImage(
      source: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: Container(
        width: width,
        height: height,
        color: _gray100,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: _gray400, size: 20),
      ),
    );
  }
}

class _PopularInfo extends StatelessWidget {
  const _PopularInfo({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, size: 16, color: _red),
          const SizedBox(width: 5),
          Text('최근 $days일 활동량 기준 인기글', style: const TextStyle(fontSize: 12, color: _gray500, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.searching, this.text});
  final bool searching;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 84),
      child: Center(child: Text(text ?? (searching ? '검색 결과가 없습니다.' : '게시글이 없습니다.'), style: const TextStyle(fontSize: 13, color: _gray500))),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 84, 20, 0),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 34, color: _gray400),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _gray500, height: 1.5)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white), child: const Text('DB 다시 불러오기')),
        ],
      ),
    );
  }
}

class _CategorySelect extends StatelessWidget {
  const _CategorySelect({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isQa = label == 'Q&A';
    final selectedColor = isQa ? _orange : const Color(0xFF2563EB);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? selectedColor : _gray200),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: selected ? Colors.white : _gray400),
        ),
      ),
    );
  }
}

class _PostMenu extends StatelessWidget {
  const _PostMenu({required this.isMine, required this.onEdit, required this.onDelete, required this.onReport, required this.onBlock});
  final bool isMine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 21, color: _text2),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
        if (value == 'report') onReport();
        if (value == 'block') onBlock();
      },
      itemBuilder: (_) => [
        if (isMine) const PopupMenuItem(value: 'edit', child: Text('수정')),
        if (isMine) const PopupMenuItem(value: 'delete', child: Text('삭제')),
        if (!isMine) const PopupMenuItem(value: 'report', child: Text('신고')),
        if (!isMine) const PopupMenuItem(value: 'block', child: Text('차단')),
      ],
    );
  }
}

class _CommentMenu extends StatelessWidget {
  const _CommentMenu({required this.isMine, required this.onEdit, required this.onDelete, required this.onReport, required this.onBlock, this.small = false});
  final bool isMine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 92),
      icon: Icon(Icons.more_vert, size: small ? 16 : 18, color: _gray400),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
        if (value == 'report') onReport();
        if (value == 'block') onBlock();
      },
      itemBuilder: (_) => [
        if (isMine) const PopupMenuItem(value: 'edit', child: Text('수정')),
        if (isMine) const PopupMenuItem(value: 'delete', child: Text('삭제')),
        if (!isMine) const PopupMenuItem(value: 'report', child: Text('신고')),
        if (!isMine) const PopupMenuItem(value: 'block', child: Text('차단')),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.title, required this.message, required this.confirmLabel, required this.onCancel, required this.onConfirm});
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.center,
        child: Container(
          width: 280,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _text)),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.5, color: _gray500)),
                  ],
                ),
              ),
              const Divider(height: 1, color: _gray100),
              Row(
                children: [
                  Expanded(child: InkWell(onTap: onCancel, child: const SizedBox(height: 46, child: Center(child: Text('취소', style: TextStyle(fontSize: 14, color: _gray500)))))),
                  Container(width: 1, height: 46, color: _gray100),
                  Expanded(child: InkWell(onTap: onConfirm, child: SizedBox(height: 46, child: Center(child: Text(confirmLabel, style: const TextStyle(fontSize: 14, color: _red, fontWeight: FontWeight.w700)))))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
