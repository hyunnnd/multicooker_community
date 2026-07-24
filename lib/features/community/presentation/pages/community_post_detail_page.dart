part of '../community_screen.dart';

class _PostDetailPage extends StatefulWidget {
  const _PostDetailPage({
    required this.postId,
    required this.onBack,
    required this.onEdit,
    required this.onDeleted,
    required this.onAuthorTap,
    this.highlightCommentId,
    this.highlightReplyId,
  });
  final int postId;
  final VoidCallback onBack;
  final ValueChanged<int> onEdit;
  final VoidCallback onDeleted;
  final ValueChanged<int> onAuthorTap;
  final int? highlightCommentId;
  final int? highlightReplyId;

  @override
  State<_PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<_PostDetailPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _commentKeys = <int, GlobalKey>{};
  final Map<int, GlobalKey> _replyKeys = <int, GlobalKey>{};
  bool _showDeleteConfirm = false;
  bool _targetScrollScheduled = false;
  bool _showTargetHighlight = true;
  Timer? _highlightTimer;
  String _sort = '등록순';

  @override
  void didUpdateWidget(covariant _PostDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.highlightCommentId != widget.highlightCommentId ||
        oldWidget.highlightReplyId != widget.highlightReplyId) {
      _targetScrollScheduled = false;
      _showTargetHighlight = true;
      _commentKeys.clear();
      _replyKeys.clear();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  int? _targetCommentId(CommunityPost post) {
    if (widget.highlightCommentId != null) return widget.highlightCommentId;
    final targetReply = widget.highlightReplyId;
    if (targetReply == null) return null;
    for (final comment in post.comments) {
      if (comment.replies.any((reply) => reply.id == targetReply)) {
        return comment.id;
      }
    }
    return null;
  }

  void _scheduleTargetScroll(CommunityPost post, List<CommunityComment> comments) {
    if (_targetScrollScheduled) return;
    final targetId = _targetCommentId(post);
    if (targetId == null) return;
    _targetScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      final index = comments.indexWhere((comment) => comment.id == targetId);
      if (index >= 0) {
        final estimated = (360 + index * 250).toDouble();
        await _scrollController.animateTo(
          estimated
              .clamp(0, _scrollController.position.maxScrollExtent)
              .toDouble(),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final targetContext = _commentKeys[targetId]?.currentContext;
      if (mounted && targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.18,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final targetReplyId = widget.highlightReplyId;
      final replyContext = targetReplyId == null
          ? null
          : _replyKeys[targetReplyId]?.currentContext;
      if (mounted && replyContext != null) {
        await Scrollable.ensureVisible(
          replyContext,
          alignment: 0.45,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showTargetHighlight = false);
      });
    });
  }

  Future<void> _showAdminLikeDialog(CommunityPost post) async {
    final controller = TextEditingController(text: '${post.likes}');
    var applyToPopular = true;
    final result = await showDialog<({int count, bool applyToPopular})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('관리자 좋아요 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '표시할 좋아요 수를 입력하세요. 실제 계정별 좋아요 상태는 그대로 유지됩니다.',
                style: TextStyle(fontSize: 12, height: 1.5, color: _gray500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '좋아요 수',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: applyToPopular,
                title: const Text('인기글 테스트 점수에도 반영'),
                subtitle: const Text('두 계정만으로 인기글 화면을 확인할 때 사용합니다.'),
                onChanged: (value) =>
                    setDialogState(() => applyToPopular = value ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final count = int.tryParse(controller.text.trim());
                if (count == null || count < 0) return;
                Navigator.pop(
                  dialogContext,
                  (count: count, applyToPopular: applyToPopular),
                );
              },
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;

    final provider = context.read<CommunityProvider>();
    final ok = await provider.setAdminPostLikes(
      post.id,
      likeCount: result.count,
      applyToPopularTest: result.applyToPopular,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '좋아요 수를 변경했습니다.'
              : (provider.errorMessage ?? '변경하지 못했습니다.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final currentUserName = profile.summary?.nickname ?? auth.currentNickname ?? '나';
    final currentAvatarColor = profile.summary?.avatarColor ?? auth.currentAvatarColor;
    final currentAvatarImageUrl = profile.summary?.avatarImageUrl;
    final post = provider.postById(widget.postId);
    if (post == null) {
      return ColoredBox(
        color: _bg,
        child: Column(
          children: [
            _CommunityDetailHeader(
              title: '',
              onBack: widget.onBack,
              backgroundColor: _bg,
              showBorder: false,
            ),
            const Expanded(
              child: Center(
                child: Text(
                  '게시글을 찾을 수 없습니다.',
                  style: TextStyle(color: _gray500),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final liked = provider.likedPostIds.contains(post.id) || post.isLiked;
    var comments = post.comments;
    if (_sort == '최신순') {
      comments = [...comments]..sort((a, b) => b.id.compareTo(a.id));
    }
    _scheduleTargetScroll(post, comments);

    return ColoredBox(
      color: _bg,
      child: Stack(
        children: [
          Column(
            children: [
              _CommunityDetailHeader(
                title: '',
                onBack: widget.onBack,
                backgroundColor: _bg,
                showBorder: false,
                trailing: _PostMenu(
                  isMine: post.isMine,
                  onEdit: () => widget.onEdit(post.id),
                  onDelete: () => setState(() => _showDeleteConfirm = true),
                  onReport: () => provider.reportPost(post.id),
                  onBlock: () => provider.blockPost(post.id),
                  canAdminister: post.canAdminister,
                  onAdminSetLikes: () => _showAdminLikeDialog(post),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _gray200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: post.authorUserId == null
                                    ? null
                                    : () => widget.onAuthorTap(post.authorUserId!),
                                child: _Avatar(
                                  name: post.username,
                                  color: Color(post.avatarColor),
                                  imageUrl: post.avatarImageUrl,
                                  size: 40,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: post.authorUserId == null
                                      ? null
                                      : () => widget.onAuthorTap(post.authorUserId!),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              post.username,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: _text,
                                              ),
                                            ),
                                          ),
                                          if (post.isAdmin) ...[
                                            const SizedBox(width: 7),
                                            const _AuthorRoleBadge(
                                              label: '관리자',
                                              admin: true,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${post.relativeTime}${post.wasEdited ? ' · 수정됨 ${post.editedLabel}' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _gray400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (post.isPopular) ...[
                                    _Pill(
                                      label: '🔥 인기',
                                      bg: const Color(0xFFFEE2E2),
                                      fg: _red,
                                      fontSize: 11,
                                      weight: FontWeight.w800,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  _CategoryPill(category: post.category),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            post.content,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.85,
                              color: _text2,
                            ),
                          ),
                          if (post.imageUrl != null &&
                              post.imageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => _showCommunityImageViewer(
                                context,
                                [post.imageUrl!],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _NetworkImageBox(
                                  url: post.imageUrl!,
                                  width: double.infinity,
                                  height: 240,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          const Divider(height: 1, color: _gray200),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _SmallActionIcon(
                                icon: liked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                label:
                                    '${post.likes + (liked && !post.isLiked ? 1 : 0)}',
                                color: liked ? _red : _gray400,
                                iconSize: 18,
                                fontSize: 13,
                                onTap: provider.isPostLikePending(post.id)
                                    ? null
                                    : () => provider.togglePostLike(post.id),
                              ),
                              const SizedBox(width: 20),
                              _SmallActionIcon(
                                icon: Icons.mode_comment_outlined,
                                label: '${post.commentCount}',
                                color: _gray400,
                                iconSize: 18,
                                fontSize: 13,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _gray200),
                      ),
                      child: Row(
                        children: [
                          for (final s in const ['등록순', '최신순'])
                            GestureDetector(
                              onTap: () => setState(() => _sort = s),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Row(
                                  children: [
                                    if (_sort == s) ...[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: _orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(
                                      s,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _sort == s
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: _sort == s
                                            ? _text
                                            : _gray400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            '댓글 ${post.commentCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _gray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (comments.isEmpty)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _gray200),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.mode_comment_outlined,
                              size: 28,
                              color: _gray300,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '첫 댓글을 남겨보세요!',
                              style: TextStyle(
                                fontSize: 13,
                                color: _gray400,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final comment in comments)
                        if (!provider.hiddenCommentIds.contains(comment.id))
                          _CommentTile(
                            key: _commentKeys.putIfAbsent(
                              comment.id,
                              () => GlobalKey(),
                            ),
                            postId: post.id,
                            postAuthorUserId: post.authorUserId,
                            comment: comment,
                            highlighted: _showTargetHighlight &&
                                (_targetCommentId(post) == comment.id),
                            highlightedReplyId: widget.highlightReplyId,
                            highlightedReplyKey: widget.highlightReplyId == null
                                ? null
                                : _replyKeys.putIfAbsent(
                                    widget.highlightReplyId!,
                                    () => GlobalKey(),
                                  ),
                            onAuthorTap: widget.onAuthorTap,
                          ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _gray200)),
                ),
                child: Row(
                  children: [
                    _Avatar(
                      name: currentUserName,
                      color: Color(currentAvatarColor),
                      imageUrl: currentAvatarImageUrl,
                      size: 30,
                      fontSize: 11,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _gray100,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _gray200),
                        ),
                        child: Center(
                          child: TextField(
                            controller: _inputController,
                            maxLines: 1,
                            cursorHeight: 17,
                            textAlignVertical: TextAlignVertical.center,
                            strutStyle: const StrutStyle(
                              fontSize: 13,
                              height: 1,
                              forceStrutHeight: true,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: _gray100,
                              hintText: '따뜻한 댓글을 남겨보세요 :)',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                height: 1,
                                color: _gray400,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1,
                              color: _text2,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _inputController.text.trim().isEmpty
                          ? null
                          : () async {
                              final text = _inputController.text.trim();
                              _inputController.clear();
                              setState(() {});
                              await provider.addComment(post.id, text);
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _inputController.text.trim().isEmpty
                              ? _gray100
                              : _orange,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _inputController.text.trim().isEmpty
                                ? _gray200
                                : _orange,
                          ),
                        ),
                        child: Text(
                          '등록',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _inputController.text.trim().isEmpty
                                ? _gray400
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showDeleteConfirm)
            _ConfirmDialog(
              title: '게시글 삭제',
              message: '삭제된 게시글은 복구할 수 없어요.\n삭제하시겠어요?',
              confirmLabel: '삭제',
              onCancel: () => setState(() => _showDeleteConfirm = false),
              onConfirm: () async {
                setState(() => _showDeleteConfirm = false);
                await provider.deletePost(post.id);
                widget.onDeleted();
              },
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    super.key,
    required this.postId,
    required this.postAuthorUserId,
    required this.comment,
    required this.highlighted,
    required this.highlightedReplyId,
    required this.highlightedReplyKey,
    required this.onAuthorTap,
  });
  final int postId;
  final int? postAuthorUserId;
  final CommunityComment comment;
  final bool highlighted;
  final int? highlightedReplyId;
  final GlobalKey? highlightedReplyKey;
  final ValueChanged<int> onAuthorTap;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _showReply = false;
  bool _editing = false;
  bool _deleteConfirm = false;
  final _replyController = TextEditingController();
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.comment.content);
  }

  @override
  void dispose() {
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final comment = widget.comment;
    final liked = provider.likedCommentIds.contains(comment.id) || comment.isLiked;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          decoration: BoxDecoration(
            color: widget.highlighted ? _orange50 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.highlighted ? _orange : _gray200,
              width: widget.highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: comment.authorUserId == null
                        ? null
                        : () => widget.onAuthorTap(comment.authorUserId!),
                    child: _Avatar(
                      name: comment.username,
                      color: Color(comment.avatarColor),
                      imageUrl: comment.avatarImageUrl,
                      size: 36,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: comment.authorUserId == null
                                        ? null
                                        : () => widget.onAuthorTap(comment.authorUserId!),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            comment.username,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _text2),
                                          ),
                                        ),
                                        if (comment.isAdmin ||
                                            (widget.postAuthorUserId != null &&
                                                comment.authorUserId == widget.postAuthorUserId)) ...[
                                          const SizedBox(width: 6),
                                          _AuthorRoleBadge(
                                            label: comment.isAdmin ? '관리자' : '작성자',
                                            admin: comment.isAdmin,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${comment.relativeTime}${comment.wasEdited ? ' · 수정됨' : ''}',
                                    style: const TextStyle(fontSize: 11, color: _gray400),
                                  ),
                                ],
                              ),
                            ),
                            _CommentMenu(
                              isMine: comment.isMine,
                              onEdit: () => setState(() => _editing = true),
                              onDelete: () => setState(() => _deleteConfirm = true),
                              onReport: () => provider.reportComment(comment.id),
                              onBlock: () => provider.blockComment(comment.id),
                            ),
                          ],
                        ),
                        if (_editing) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: _gray100, borderRadius: BorderRadius.circular(12)),
                            child: TextField(
                              controller: _editController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isCollapsed: true,
                                filled: true,
                                fillColor: _gray100,
                              ),
                              style: const TextStyle(fontSize: 13, height: 1.65, color: _text2),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(onPressed: () => setState(() => _editing = false), child: const Text('취소', style: TextStyle(fontSize: 12, color: _gray400))),
                              TextButton(
                                onPressed: () async {
                                  await provider.editComment(widget.postId, comment.id, _editController.text);
                                  if (mounted) setState(() => _editing = false);
                                },
                                child: const Text('저장', style: TextStyle(fontSize: 12, color: _orange, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(comment.content, style: const TextStyle(fontSize: 13, height: 1.7, color: _text2)),
                        ],
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            _SmallActionIcon(
                              icon: liked ? Icons.favorite : Icons.favorite_border,
                              label: '${comment.likes + (liked && !comment.isLiked ? 1 : 0)}',
                              color: liked ? _red : _gray400,
                              onTap: () => provider.toggleCommentLike(comment.id),
                            ),
                            const SizedBox(width: 16),
                            _SmallActionIcon(
                              icon: Icons.mode_comment_outlined,
                              label: '답글',
                              color: _showReply ? _orange : _gray400,
                              onTap: () => setState(() => _showReply = !_showReply),
                            ),
                          ],
                        ),
                        if (comment.replies.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _gray100))),
                            child: Column(
                              children: [
                                for (final reply in comment.replies)
                                  if (!provider.hiddenReplyIds.contains(reply.id))
                                    _ReplyTile(
                                      key: widget.highlightedReplyId == reply.id
                                          ? widget.highlightedReplyKey
                                          : ValueKey('community-reply-${reply.id}'),
                                      postId: widget.postId,
                                      postAuthorUserId: widget.postAuthorUserId,
                                      commentId: comment.id,
                                      reply: reply,
                                      highlighted: widget.highlighted &&
                                          widget.highlightedReplyId == reply.id,
                                      onAuthorTap: widget.onAuthorTap,
                                    ),
                              ],
                            ),
                          ),
                        ],
                        if (_showReply) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: _gray100, borderRadius: BorderRadius.circular(12)),
                                  child: Center(
                                    child: TextField(
                                      controller: _replyController,
                                      maxLines: 1,
                                      cursorHeight: 16,
                                      textAlignVertical: TextAlignVertical.center,
                                      strutStyle: const StrutStyle(fontSize: 12, height: 1, forceStrutHeight: true),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        isCollapsed: true,
                                        contentPadding: EdgeInsets.zero,
                                        filled: true,
                                        fillColor: _gray100,
                                        hintText: '답글 입력...',
                                        hintStyle: TextStyle(fontSize: 12, height: 1, color: _gray400),
                                      ),
                                      style: const TextStyle(fontSize: 12, height: 1, color: _text2),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _replyController.text.trim().isEmpty
                                    ? null
                                    : () async {
                                        final text = _replyController.text.trim();
                                        _replyController.clear();
                                        setState(() {});
                                        await provider.addReply(widget.postId, comment.id, text);
                                      },
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(color: _replyController.text.trim().isEmpty ? _gray300 : _orange, borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_deleteConfirm)
          _ConfirmDialog(
            title: '댓글 삭제',
            message: '댓글을 삭제하시겠어요?',
            confirmLabel: '삭제',
            onCancel: () => setState(() => _deleteConfirm = false),
            onConfirm: () async {
              setState(() => _deleteConfirm = false);
              await provider.deleteComment(widget.postId, comment.id);
            },
          ),
      ],
    );
  }
}

class _ReplyTile extends StatefulWidget {
  const _ReplyTile({
    super.key,
    required this.postId,
    required this.postAuthorUserId,
    required this.commentId,
    required this.reply,
    required this.highlighted,
    required this.onAuthorTap,
  });
  final int postId;
  final int? postAuthorUserId;
  final int commentId;
  final CommunityReply reply;
  final bool highlighted;
  final ValueChanged<int> onAuthorTap;

  @override
  State<_ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends State<_ReplyTile> {
  bool _editing = false;
  bool _deleteConfirm = false;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.reply.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final reply = widget.reply;
    final liked = provider.likedReplyIds.contains(reply.id) || reply.isLiked;
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          decoration: BoxDecoration(
            color: widget.highlighted ? _orange50 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: widget.highlighted ? Border.all(color: _orange100) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 32),
              GestureDetector(
                onTap: reply.authorUserId == null
                    ? null
                    : () => widget.onAuthorTap(reply.authorUserId!),
                child: _Avatar(
                  name: reply.username,
                  color: Color(reply.avatarColor),
                  imageUrl: reply.avatarImageUrl,
                  size: 28,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: reply.authorUserId == null
                                ? null
                                : () => widget.onAuthorTap(reply.authorUserId!),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        reply.username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _text2),
                                      ),
                                    ),
                                    if (reply.isAdmin ||
                                        (widget.postAuthorUserId != null &&
                                            reply.authorUserId == widget.postAuthorUserId)) ...[
                                      const SizedBox(width: 6),
                                      _AuthorRoleBadge(
                                        label: reply.isAdmin ? '관리자' : '작성자',
                                        admin: reply.isAdmin,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${reply.relativeTime}${reply.wasEdited ? ' · 수정됨' : ''}',
                                  style: const TextStyle(fontSize: 11, color: _gray400),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _CommentMenu(
                          isMine: reply.isMine,
                          small: true,
                          onEdit: () => setState(() => _editing = true),
                          onDelete: () => setState(() => _deleteConfirm = true),
                          onReport: () => provider.reportReply(reply.id),
                          onBlock: () => provider.blockReply(reply.id),
                        ),
                      ],
                    ),
                    if (_editing) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: _gray100, borderRadius: BorderRadius.circular(10)),
                        child: TextField(
                          controller: _editController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isCollapsed: true,
                            filled: true,
                            fillColor: _gray100,
                          ),
                          style: const TextStyle(fontSize: 12, color: _text2),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => setState(() => _editing = false), child: const Text('취소', style: TextStyle(fontSize: 11, color: _gray400))),
                          TextButton(
                            onPressed: () async {
                              await provider.editReply(widget.postId, widget.commentId, reply.id, _editController.text);
                              if (mounted) setState(() => _editing = false);
                            },
                            child: const Text('저장', style: TextStyle(fontSize: 11, color: _orange, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 5),
                      Text(reply.content, style: const TextStyle(fontSize: 12, height: 1.55, color: _text2)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _SmallActionIcon(
                            icon: liked ? Icons.favorite : Icons.favorite_border,
                            label: '${reply.likes + (liked && !reply.isLiked ? 1 : 0)}',
                            color: liked ? _red : _gray400,
                            onTap: () => provider.toggleReplyLike(reply.id),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_deleteConfirm)
          _ConfirmDialog(
            title: '답글 삭제',
            message: '답글을 삭제하시겠어요?',
            confirmLabel: '삭제',
            onCancel: () => setState(() => _deleteConfirm = false),
            onConfirm: () async {
              setState(() => _deleteConfirm = false);
              await provider.deleteReply(widget.postId, widget.commentId, reply.id);
            },
          ),
      ],
    );
  }
}

const _noticePerPage = 4;
