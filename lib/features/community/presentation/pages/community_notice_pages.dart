part of '../community_screen.dart';

class _NoticeDetailPage extends StatefulWidget {
  const _NoticeDetailPage({required this.noticeId, required this.onBack, required this.onNoticeTap, required this.onViewAll});
  final int noticeId;
  final VoidCallback onBack;
  final ValueChanged<int> onNoticeTap;
  final VoidCallback onViewAll;

  @override
  State<_NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<_NoticeDetailPage> {
  int _listPage = 0;
  int? _initializedForNoticeId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final notice = provider.noticeById(widget.noticeId) ?? (provider.notices.isNotEmpty ? provider.notices.first : null);
    if (notice == null) {
      return Column(children: [_SimpleHeader(title: '공지사항', onBack: widget.onBack), const Expanded(child: Center(child: Text('공지사항이 없습니다.')))]);
    }

    final allNotices = provider.notices;
    final currentIndex = allNotices.indexWhere((n) => n.id == notice.id);
    if (_initializedForNoticeId != notice.id) {
      _listPage = currentIndex < 0 ? 0 : currentIndex ~/ _noticePerPage;
      _initializedForNoticeId = notice.id;
    }
    final totalPages = (allNotices.length / _noticePerPage).ceil().clamp(1, 9999).toInt();
    final start = (_listPage * _noticePerPage).clamp(0, allNotices.length).toInt();
    final end = (start + _noticePerPage).clamp(0, allNotices.length).toInt();
    final pageNotices = allNotices.sublist(start, end);

    return Column(
      children: [
        _SimpleHeader(title: '공지사항', onBack: widget.onBack),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notice.important) ...[
                      const Row(
                        children: [
                          Icon(Icons.push_pin_outlined, size: 13, color: _orange),
                          SizedBox(width: 6),
                          Text('중요 공지', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _orange)),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(notice.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.4, color: _text)),
                    const SizedBox(height: 8),
                    Text(notice.date, style: const TextStyle(fontSize: 12, color: _gray400)),
                    const SizedBox(height: 24),
                    Text(notice.content, style: const TextStyle(fontSize: 14, height: 1.85, color: _text2)),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 24),
                color: _bg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Text('공지사항 목록', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _gray500, letterSpacing: 0.2)),
                    const Spacer(),
                    Text('${_listPage + 1} / $totalPages', style: const TextStyle(fontSize: 11, color: _gray400)),
                  ],
                ),
              ),
              for (var i = 0; i < pageNotices.length; i++)
                _NoticeListRow(
                  notice: pageNotices[i],
                  selected: pageNotices[i].id == notice.id,
                  showBottomBorder: i < pageNotices.length - 1,
                  onTap: () {
                    if (pageNotices[i].id != notice.id) widget.onNoticeTap(pageNotices[i].id);
                  },
                ),
              Container(
                color: _bg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Spacer(),
                    Row(
                      children: [
                        _NoticePageButton(
                          icon: Icons.chevron_left,
                          label: '이전',
                          enabled: _listPage > 0,
                          onTap: () => setState(() => _listPage -= 1),
                        ),
                        const SizedBox(width: 20),
                        _NoticePageButton(
                          icon: Icons.chevron_right,
                          label: '다음',
                          reverse: true,
                          enabled: _listPage < totalPages - 1,
                          onTap: () => setState(() => _listPage += 1),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(onTap: widget.onViewAll, child: const Text('전체보기', style: TextStyle(fontSize: 13, color: _gray500))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticePageButton extends StatelessWidget {
  const _NoticePageButton({required this.icon, required this.label, required this.enabled, required this.onTap, this.reverse = false});
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? _gray500 : _gray300;
    final children = <Widget>[
      Icon(icon, size: 15, color: color),
      Text(label, style: TextStyle(fontSize: 13, color: color)),
    ];
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Row(children: reverse ? children.reversed.toList() : children),
    );
  }
}

class _NoticeListPage extends StatefulWidget {
  const _NoticeListPage({required this.onBack, required this.onNoticeTap});
  final VoidCallback onBack;
  final ValueChanged<int> onNoticeTap;

  @override
  State<_NoticeListPage> createState() => _NoticeListPageState();
}

class _NoticeListPageState extends State<_NoticeListPage> {
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
    final query = _controller.text.trim().toLowerCase();
    final important = provider.notices.where((notice) => notice.important).where((notice) => _matchesNotice(notice, query)).toList();
    final regular = provider.notices.where((notice) => !notice.important).where((notice) => _matchesNotice(notice, query)).toList();
    final totalFound = important.length + regular.length;

    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _gray100))),
          child: Row(
            children: [
              GestureDetector(onTap: widget.onBack, child: const SizedBox(width: 36, child: Icon(Icons.arrow_back, size: 20, color: _text2))),
              if (_showSearch)
                Expanded(
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: _gray100, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 14, color: _gray400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: '공지 검색...', hintStyle: TextStyle(fontSize: 13, color: _gray400)),
                            style: const TextStyle(fontSize: 13, color: _text2),
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          GestureDetector(onTap: () => setState(_controller.clear), child: const Icon(Icons.close, size: 13, color: _gray400)),
                      ],
                    ),
                  ),
                )
              else
                const Expanded(child: Text('공지사항', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _text))),
              GestureDetector(
                onTap: () => setState(() {
                  _showSearch = !_showSearch;
                  _controller.clear();
                }),
                child: SizedBox(width: 36, child: Align(alignment: Alignment.centerRight, child: Icon(_showSearch ? Icons.close : Icons.search, size: 20, color: _gray500))),
              ),
            ],
          ),
        ),
        if (_controller.text.isNotEmpty)
          Container(
            width: double.infinity,
            color: _bg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text.rich(
              TextSpan(text: '"', children: [TextSpan(text: _controller.text, style: const TextStyle(color: _orange, fontWeight: FontWeight.w600)), TextSpan(text: '" 검색 결과 $totalFound건')]),
              style: const TextStyle(fontSize: 12, color: _gray500),
            ),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (important.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(color: _orange50, border: Border(bottom: BorderSide(color: _orange100))),
                  child: const Row(children: [Icon(Icons.push_pin_outlined, size: 12, color: _orange), SizedBox(width: 6), Text('중요 공지', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _orangeText))]),
                ),
                for (var i = 0; i < important.length; i++) _NoticeFullRow(notice: important[i], onTap: () => widget.onNoticeTap(important[i].id)),
              ],
              if (regular.isNotEmpty) ...[
                if (important.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: _bg,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Text('일반 공지', style: TextStyle(fontSize: 11, color: _gray400)),
                  ),
                for (final notice in regular) _NoticeFullRow(notice: notice, onTap: () => widget.onNoticeTap(notice.id)),
              ],
              if (totalFound == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Column(children: [Icon(Icons.search, size: 32, color: _gray300), SizedBox(height: 10), Text('검색 결과가 없습니다', style: TextStyle(fontSize: 13, color: _gray400))]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _matchesNotice(CommunityNotice notice, String query) {
    if (query.isEmpty) return true;
    return notice.title.toLowerCase().contains(query) || notice.summary.toLowerCase().contains(query);
  }
}

class _NoticeFullRow extends StatelessWidget {
  const _NoticeFullRow({required this.notice, required this.onTap});
  final CommunityNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _gray100))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (notice.important) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _orange100, borderRadius: BorderRadius.circular(4)),
                          child: const Text('중요', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _orange)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(child: Text(notice.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _text))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notice.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _gray500)),
                  const SizedBox(height: 5),
                  Text(notice.date, style: const TextStyle(fontSize: 11, color: _gray400)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right, size: 16, color: _gray400),
          ],
        ),
      ),
    );
  }
}

class _NoticeListRow extends StatelessWidget {
  const _NoticeListRow({required this.notice, required this.selected, required this.onTap, this.showBottomBorder = true});
  final CommunityNotice notice;
  final bool selected;
  final bool showBottomBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? _orange50 : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundDecoration: BoxDecoration(border: showBottomBorder ? const Border(bottom: BorderSide(color: _gray100)) : null),
        child: Row(
          children: [
            if (selected) ...[
              Container(width: 2, height: 16, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(999))),
              const SizedBox(width: 8),
            ],
            if (notice.important) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _orange100, borderRadius: BorderRadius.circular(4)),
                child: const Text('중요', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _orange)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                notice.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: selected ? _orangeText : _text2),
              ),
            ),
            const SizedBox(width: 12),
            Text(notice.date, style: const TextStyle(fontSize: 11, color: _gray400)),
          ],
        ),
      ),
    );
  }
}
