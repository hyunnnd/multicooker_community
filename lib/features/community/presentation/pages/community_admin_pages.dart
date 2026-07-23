part of '../community_screen.dart';

class _CommunityAdminPage extends StatefulWidget {
  const _CommunityAdminPage({
    required this.onBack,
    required this.onOpenPost,
  });

  final VoidCallback onBack;
  final ValueChanged<int> onOpenPost;

  @override
  State<_CommunityAdminPage> createState() => _CommunityAdminPageState();
}

class _CommunityAdminPageState extends State<_CommunityAdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<CommunityProvider>();
      provider.load(silent: true);
      provider.loadAdminReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final provider = context.read<CommunityProvider>();
    final isAdmin = profile.summary?.isAdmin == true || provider.isAdmin;

    if (!isAdmin && profile.summary != null) {
      return Column(
        children: [
          _SimpleHeader(title: '관리자', onBack: widget.onBack),
          const Expanded(
            child: Center(
              child: Text(
                '관리자 계정만 접근할 수 있습니다.',
                style: TextStyle(color: _gray500),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _SimpleHeader(title: '커뮤니티 관리자', onBack: widget.onBack),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: _orangeText,
            unselectedLabelColor: _gray500,
            indicatorColor: _orange,
            tabs: const [
              Tab(text: '공지 관리'),
              Tab(text: '신고 관리'),
              Tab(text: '인기 관리'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _AdminNoticeTab(onOpenEditor: _openNoticeEditor),
              const _AdminReportTab(),
              _AdminPopularityTab(onOpenPost: widget.onOpenPost),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openNoticeEditor([CommunityNotice? notice]) async {
    final provider = context.read<CommunityProvider>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      builder: (_) => _NoticeEditorSheet(
        provider: provider,
        notice: notice,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notice == null ? '공지를 등록했습니다.' : '공지를 수정했습니다.',
          ),
        ),
      );
    }
  }

}

class _NoticeEditorSheet extends StatefulWidget {
  const _NoticeEditorSheet({
    required this.provider,
    required this.notice,
  });

  final CommunityProvider provider;
  final CommunityNotice? notice;

  @override
  State<_NoticeEditorSheet> createState() => _NoticeEditorSheetState();
}

class _NoticeEditorSheetState extends State<_NoticeEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _contentController;
  late bool _important;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final notice = widget.notice;
    _titleController = TextEditingController(text: notice?.title ?? '');
    _summaryController = TextEditingController(text: notice?.summary ?? '');
    _contentController = TextEditingController(text: notice?.content ?? '');
    _important = notice?.important ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해 주세요.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final notice = widget.notice;
    final ok = notice == null
        ? await widget.provider.createAdminNotice(
            title: title,
            summary: _summaryController.text,
            content: content,
            important: _important,
          )
        : await widget.provider.updateAdminNotice(
            notice.id,
            title: title,
            summary: _summaryController.text,
            content: content,
            important: _important,
          );

    if (!mounted) return;
    if (!ok) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.provider.errorMessage ?? '공지를 저장하지 못했습니다.',
          ),
        ),
      );
      return;
    }

    // provider 갱신 프레임과 모달 제거 프레임이 겹치지 않도록 분리합니다.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    widget.notice == null ? '공지 작성' : '공지 수정',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                maxLength: 80,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _summaryController,
                maxLength: 160,
                decoration: const InputDecoration(labelText: '요약'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                minLines: 7,
                maxLines: 14,
                maxLength: 5000,
                decoration: const InputDecoration(labelText: '공지 내용'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('중요 공지로 상단 고정'),
                value: _important,
                activeThumbColor: _orange,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _important = value),
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _orange),
                onPressed: _submitting ? null : _submit,
                child: Text(
                  _submitting
                      ? '저장 중...'
                      : (widget.notice == null ? '공지 등록' : '변경 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNoticeTab extends StatelessWidget {
  const _AdminNoticeTab({required this.onOpenEditor});

  final ValueChanged<CommunityNotice?> onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final notices = [...provider.notices]
      ..sort((a, b) {
        final important = (b.important ? 1 : 0) - (a.important ? 1 : 0);
        if (important != 0) return important;
        return b.id.compareTo(a.id);
      });

    return RefreshIndicator(
      color: _orange,
      onRefresh: () => context.read<CommunityProvider>().load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '공지사항 작성·수정·삭제',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _orange),
                onPressed: () => onOpenEditor(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('새 공지'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (notices.isEmpty)
            const _AdminEmpty(
              icon: Icons.campaign_outlined,
              text: '등록된 공지가 없습니다.',
            )
          else
            for (final notice in notices) ...[
              Card(
                key: ValueKey('admin-notice-${notice.id}'),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: _gray200),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (notice.important)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.push_pin, size: 16, color: _orange),
                            ),
                          Expanded(
                            child: Text(
                              notice.title,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          AppMoreMenuButton<String>(
                            tooltip: '공지 관리',
                            onSelected: (value) async {
                              if (value == 'edit') {
                                onOpenEditor(notice);
                                return;
                              }
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('공지 삭제'),
                                  content: Text('“${notice.title}” 공지를 삭제하시겠습니까?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext, false),
                                      child: const Text('취소'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(dialogContext, true),
                                      child: const Text('삭제'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && context.mounted) {
                                await context
                                    .read<CommunityProvider>()
                                    .deleteAdminNotice(notice.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('수정')),
                              PopupMenuItem(value: 'delete', child: Text('삭제')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice.summary.isEmpty ? notice.content : notice.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _gray500, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notice.date,
                        style: const TextStyle(fontSize: 12, color: _gray400),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _AdminReportTab extends StatelessWidget {
  const _AdminReportTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final summary = provider.adminReportSummary;

    return RefreshIndicator(
      color: _orange,
      onRefresh: () => context.read<CommunityProvider>().loadAdminReports(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(child: _AdminMetric(label: '전체', value: summary.total)),
              const SizedBox(width: 8),
              Expanded(child: _AdminMetric(label: '미처리', value: summary.pending, emphasized: true)),
              const SizedBox(width: 8),
              Expanded(child: _AdminMetric(label: '완료', value: summary.resolved)),
              const SizedBox(width: 8),
              Expanded(child: _AdminMetric(label: '반려', value: summary.rejected)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '신고 내역',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              DropdownButton<String>(
                value: provider.adminReportFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('전체')),
                  DropdownMenuItem(value: 'pending', child: Text('미처리')),
                  DropdownMenuItem(value: 'resolved', child: Text('처리 완료')),
                  DropdownMenuItem(value: 'rejected', child: Text('반려')),
                ],
                onChanged: (value) {
                  if (value != null) provider.loadAdminReports(status: value);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (provider.adminLoading && provider.adminReports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: _orange)),
            )
          else if (provider.adminReports.isEmpty)
            const _AdminEmpty(
              icon: Icons.flag_outlined,
              text: '조건에 맞는 신고가 없습니다.',
            )
          else
            for (final report in provider.adminReports) ...[
              _AdminReportCard(report: report),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _AdminReportCard extends StatefulWidget {
  const _AdminReportCard({required this.report});

  final AdminCommunityReport report;

  @override
  State<_AdminReportCard> createState() => _AdminReportCardState();
}

class _AdminReportCardState extends State<_AdminReportCard> {
  bool _submitting = false;

  AdminCommunityReport get report => widget.report;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (report.status) {
      'resolved' => const Color(0xFF059669),
      'rejected' => _gray500,
      _ => _red,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor.withOpacity(0.28)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AdminPill(label: report.typeLabel, color: _orangeText),
                const SizedBox(width: 6),
                _AdminPill(label: report.statusLabel, color: statusColor),
                const Spacer(),
                Text(
                  '누적 ${report.targetReportCount}건',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.targetTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              report.targetContent.isEmpty
                  ? '내용을 확인할 수 없습니다.'
                  : report.targetContent,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _gray500, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              '작성자: ${report.targetAuthor.isEmpty ? '-' : report.targetAuthor} · 신고자: ${report.reporter}',
              style: const TextStyle(fontSize: 12, color: _gray500),
            ),
            const SizedBox(height: 4),
            Text(
              '사유: ${report.reason}',
              style: const TextStyle(fontSize: 12, color: _text2),
            ),
            if (report.status == 'pending') ...[
              const SizedBox(height: 12),
              if (_submitting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _orange,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '처리 중...',
                        style: TextStyle(fontSize: 12, color: _gray500),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _handleReport(
                        status: 'rejected',
                      ),
                      child: const Text('반려'),
                    ),
                    OutlinedButton.icon(
                      onPressed: report.targetExists
                          ? () => _handleReport(
                                status: 'resolved',
                                deleteContent: true,
                              )
                          : null,
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: const Text('삭제'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleReport({
    required String status,
    bool deleteContent = false,
  }) async {
    if (_submitting) return;

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(deleteContent ? '신고 콘텐츠 삭제' : '신고 반려'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deleteContent
                  ? '신고된 콘텐츠를 삭제하고 관련 미처리 신고를 함께 완료 처리합니다.'
                  : '신고를 반려 상태로 변경합니다.',
              style: const TextStyle(fontSize: 13, color: _gray500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '관리자 메모(선택)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: deleteContent ? _red : _orange,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(deleteContent ? '삭제' : '확인'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      noteController.dispose();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    final provider = context.read<CommunityProvider>();
    final ok = await provider.updateAdminReport(
      report.id,
      status: status,
      adminNote: noteController.text.trim(),
      deleteContent: deleteContent,
    );
    noteController.dispose();

    if (mounted) setState(() => _submitting = false);
    if (!messenger.mounted) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (deleteContent
                  ? '신고된 콘텐츠를 삭제했습니다.'
                  : '신고를 반려했습니다.')
              : (provider.errorMessage ?? '신고를 처리하지 못했습니다.'),
        ),
        backgroundColor: ok ? null : _red,
      ),
    );
  }
}

class _AdminPopularityTab extends StatelessWidget {
  const _AdminPopularityTab({required this.onOpenPost});

  final ValueChanged<int> onOpenPost;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final posts = [...provider.posts]
      ..sort((a, b) {
        final forced = (b.forcePopular ? 1 : 0) - (a.forcePopular ? 1 : 0);
        if (forced != 0) return forced;
        return b.popularityScore.compareTo(a.popularityScore);
      });

    return RefreshIndicator(
      color: _orange,
      onRefresh: () => context.read<CommunityProvider>().load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _orange50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '인기 점수 = 최근 3일 좋아요 + (댓글·답글 × 2) + 관리자 보정값입니다. 강제 인기를 켜면 점수와 관계없이 인기 목록 상단에 표시됩니다.',
              style: TextStyle(fontSize: 12, color: _orangeText, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          if (posts.isEmpty)
            const _AdminEmpty(
              icon: Icons.local_fire_department_outlined,
              text: '관리할 게시글이 없습니다.',
            )
          else
            for (final post in posts) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: post.forcePopular ? _orange : _gray200,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpenPost(post.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (post.forcePopular)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.local_fire_department,
                                  size: 17,
                                  color: _orange,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                post.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            IconButton(
                              tooltip: '인기도 설정',
                              onPressed: () => _openPopularityDialog(context, post),
                              icon: const Icon(Icons.tune, color: _orangeText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _AdminPill(label: '인기 점수 ${post.popularityScore}', color: _orangeText),
                            _AdminPill(label: '좋아요 ${post.likes}', color: _red),
                            _AdminPill(
                              label: '3일 댓글 ${post.activity.d3.comments}',
                              color: const Color(0xFF2563EB),
                            ),
                            _AdminPill(
                              label: '보정 +${post.adminPopularityBoost}',
                              color: _gray500,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _openPopularityDialog(
    BuildContext context,
    CommunityPost post,
  ) async {
    final likeController = TextEditingController(text: '${post.likes}');
    final boostController = TextEditingController(text: '${post.adminPopularityBoost}');
    var forcePopular = post.forcePopular;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('게시글 인기도 관리'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: likeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '표시 좋아요 수'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: boostController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '관리자 인기도 보정값',
                    helperText: '실제 최근 활동 점수에 더해집니다.',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('강제 인기 게시글'),
                  subtitle: const Text('인기 목록 최상단에 우선 배치'),
                  value: forcePopular,
                  activeThumbColor: _orange,
                  onChanged: (value) =>
                      setDialogState(() => forcePopular = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && context.mounted) {
      final likes = int.tryParse(likeController.text.trim());
      final boost = int.tryParse(boostController.text.trim());
      if (likes == null || likes < 0 || boost == null || boost < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('0 이상의 숫자를 입력해 주세요.')),
        );
      } else {
        await context.read<CommunityProvider>().setAdminPostPopularity(
              post.id,
              likeCount: likes,
              adminPopularityBoost: boost,
              forcePopular: forcePopular,
            );
      }
    }
    likeController.dispose();
    boostController.dispose();
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: emphasized ? _orange50 : Colors.white,
        border: Border.all(color: emphasized ? _orange100 : _gray200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: emphasized ? _orangeText : _text,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: _gray500)),
        ],
      ),
    );
  }
}

class _AdminPill extends StatelessWidget {
  const _AdminPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _AdminEmpty extends StatelessWidget {
  const _AdminEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54),
      child: Column(
        children: [
          Icon(icon, size: 42, color: _gray300),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: _gray500)),
        ],
      ),
    );
  }
}
