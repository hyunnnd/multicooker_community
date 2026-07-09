import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/main_navigation.dart';
import '../../data/models/community_models.dart';
import '../../provider/community_provider.dart';
import '../community_styles.dart';

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({required this.notice, required this.onTap, super.key});

  final CommunityNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCommunityOrangeLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: kCommunityOrange, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notice.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kCommunityText)),
                    const SizedBox(height: 2),
                    Text(notice.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: kCommunitySubtext)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kCommunityOrange),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityNoticeDetailSection extends StatefulWidget {
  const CommunityNoticeDetailSection({required this.noticeId, required this.onBack, required this.onViewAll, required this.onNavigate, super.key});

  final int noticeId;
  final VoidCallback onBack;
  final VoidCallback onViewAll;
  final ValueChanged<int> onNavigate;

  @override
  State<CommunityNoticeDetailSection> createState() => _CommunityNoticeDetailSectionState();
}

class _CommunityNoticeDetailSectionState extends State<CommunityNoticeDetailSection> {
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final notice = provider.noticeById(widget.noticeId);
    if (notice == null) {
      return _NoticeScaffold(onBack: widget.onBack, title: '공지사항', child: const Center(child: Text('공지사항을 찾을 수 없습니다.')));
    }
    final ordered = provider.notices;
    final currentIndex = ordered.indexWhere((item) => item.id == notice.id);
    final pageItems = ordered.skip(_page * 3).take(3).toList();
    final canPrev = _page > 0;
    final canNext = (_page + 1) * 3 < ordered.length;

    return _NoticeScaffold(
      onBack: widget.onBack,
      title: '공지사항',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          Row(
            children: [
              if (notice.important)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(20)),
                  child: const Text('중요', style: TextStyle(fontSize: 11, color: kCommunityOrangeDark, fontWeight: FontWeight.w900)),
                ),
              const Spacer(),
              Text(notice.date, style: const TextStyle(fontSize: 12, color: kCommunitySubtext)),
            ],
          ),
          const SizedBox(height: 14),
          Text(notice.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.25, color: kCommunityText)),
          const SizedBox(height: 12),
          Text(notice.summary, style: const TextStyle(fontSize: 14, color: kCommunitySubtext, height: 1.5)),
          const SizedBox(height: 20),
          Container(height: 1, color: kCommunityBorder),
          const SizedBox(height: 20),
          Text(notice.content, style: const TextStyle(fontSize: 14, height: 1.7, color: kCommunityText)),
          const SizedBox(height: 26),
          const Text('다른 공지', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            decoration: communityCardDecoration(radius: 14),
            child: Column(
              children: [
                for (final item in pageItems)
                  ListTile(
                    onTap: item.id == notice.id ? null : () => widget.onNavigate(item.id),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: item.id == notice.id ? FontWeight.w900 : FontWeight.w700, color: item.id == notice.id ? kCommunityOrangeDark : kCommunityText)),
                    subtitle: Text(item.date, style: const TextStyle(fontSize: 11)),
                    trailing: item.id == notice.id ? const Icon(Icons.check_circle, color: kCommunityOrange, size: 18) : const Icon(Icons.chevron_right, size: 18),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(onPressed: canPrev ? () => setState(() => _page--) : null, icon: const Icon(Icons.chevron_left), label: const Text('이전')),
              const Spacer(),
              Text('${currentIndex + 1}/${ordered.length}', style: const TextStyle(color: kCommunitySubtext)),
              const Spacer(),
              OutlinedButton.icon(onPressed: canNext ? () => setState(() => _page++) : null, icon: const Icon(Icons.chevron_right), label: const Text('다음')),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: widget.onViewAll,
            style: FilledButton.styleFrom(backgroundColor: kCommunityOrange, foregroundColor: Colors.white),
            child: const Text('공지 전체 보기'),
          ),
        ],
      ),
    );
  }
}

class CommunityNoticeListSection extends StatefulWidget {
  const CommunityNoticeListSection({required this.onBack, required this.onSelectNotice, super.key});

  final VoidCallback onBack;
  final ValueChanged<int> onSelectNotice;

  @override
  State<CommunityNoticeListSection> createState() => _CommunityNoticeListSectionState();
}

class _CommunityNoticeListSectionState extends State<CommunityNoticeListSection> {
  final _controller = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final notices = provider.filteredNotices(_controller.text);
    final important = notices.where((notice) => notice.important).toList();
    final normal = notices.where((notice) => !notice.important).toList();
    return _NoticeScaffold(
      onBack: widget.onBack,
      title: '공지사항',
      action: IconButton(
        icon: Icon(_showSearch ? Icons.close : Icons.search),
        onPressed: () => setState(() {
          _showSearch = !_showSearch;
          _controller.clear();
        }),
      ),
      child: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '공지 검색',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_controller.clear)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCommunityBorder)),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (important.isNotEmpty) const _NoticeGroupTitle('중요 공지'),
                for (final notice in important) _NoticeRow(notice: notice, onTap: () => widget.onSelectNotice(notice.id)),
                if (normal.isNotEmpty) const _NoticeGroupTitle('전체 공지'),
                for (final notice in normal) _NoticeRow(notice: notice, onTap: () => widget.onSelectNotice(notice.id)),
                if (notices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('검색 결과가 없습니다.', style: TextStyle(color: kCommunitySubtext))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeScaffold extends StatelessWidget {
  const _NoticeScaffold({required this.onBack, required this.title, required this.child, this.action});

  final VoidCallback onBack;
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kCommunityBackground,
        appBar: AppBar(
          leading: IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [if (action != null) action!],
        ),
        bottomNavigationBar: const MainNavigationBar(currentIndex: 3),
        body: child,
      );
}

class _NoticeGroupTitle extends StatelessWidget {
  const _NoticeGroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kCommunitySubtext)),
      );
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice, required this.onTap});

  final CommunityNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: communityCardDecoration(radius: 14),
        child: ListTile(
          onTap: onTap,
          leading: notice.important ? const Icon(Icons.push_pin, color: kCommunityOrange, size: 18) : null,
          title: Text(notice.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('${notice.date} · ${notice.summary}', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
        ),
      );
}
