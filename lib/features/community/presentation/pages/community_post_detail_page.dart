part of '../community_screen.dart';

class _PostDetailPage extends StatefulWidget {
  const _PostDetailPage({required this.postId, required this.onBack, required this.onEdit, required this.onDeleted});
  final int postId;
  final VoidCallback onBack;
  final ValueChanged<int> onEdit;
  final VoidCallback onDeleted;

  @override
  State<_PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<_PostDetailPage> {
  final _inputController = TextEditingController();
  bool _showDeleteConfirm = false;
  String _sort = '등록순';

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
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
    final provider = context.watch<CommunityProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final currentUserName = profile.summary?.nickname ?? auth.currentNickname ?? '나';
    final currentAvatarColor = profile.summary?.avatarColor ?? auth.currentAvatarColor;
    final post = provider.postById(widget.postId);
    if (post == null) {
      return Column(
        children: [
          _SimpleHeader(title: '게시글', onBack: widget.onBack),
          const Expanded(child: Center(child: Text('게시글을 찾을 수 없습니다.', style: TextStyle(color: _gray500)))),
        ],
      );
    }
    final liked = provider.likedPostIds.contains(post.id) || post.isLiked;
    var comments = post.comments;
    if (_sort == '최신순') {
      comments = [...comments]..sort((a, b) => b.id.compareTo(a.id));
    }

    return Stack(
      children: [
        Column(
          children: [
            _SimpleHeader(
              title: '게시글',
              onBack: widget.onBack,
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
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Avatar(name: post.username, color: Color(post.avatarColor), size: 40, fontSize: 15),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(post.username, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _text)),
                                  const SizedBox(height: 3),
                                  Text(post.relativeTime, style: const TextStyle(fontSize: 12, color: _gray400)),
                                ],
                              ),
                            ),
                            if (post.likes >= 100) ...[
                              _Pill(label: '🔥 인기', bg: const Color(0xFFFEE2E2), fg: _red, fontSize: 11, weight: FontWeight.w800),
                              const SizedBox(width: 6),
                            ],
                            _CategoryPill(category: post.category),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.35, color: _text)),
                        const SizedBox(height: 12),
                        Text(post.content, style: const TextStyle(fontSize: 14, height: 1.85, color: _text2)),
                        if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _NetworkImageBox(url: post.imageUrl!, width: double.infinity, height: 240),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const Divider(height: 1, color: _gray100),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _SmallActionIcon(
                              icon: liked ? Icons.favorite : Icons.favorite_border,
                              label: '${post.likes + (liked && !post.isLiked ? 1 : 0)}',
                              color: liked ? _red : _gray400,
                              iconSize: 18,
                              fontSize: 13,
                              onTap: () => provider.togglePostLike(post.id),
                            ),
                            const SizedBox(width: 20),
                            _SmallActionIcon(icon: Icons.mode_comment_outlined, label: '${post.commentCount}', color: _gray400, iconSize: 18, fontSize: 13),
                            if (post.reportCount != null) ...[
                              const SizedBox(width: 20),
                              _SmallActionIcon(
                                icon: Icons.flag_outlined,
                                label: '신고 ${post.reportCount}',
                                color: post.reportCount! > 0 ? _red : _gray400,
                                iconSize: 18,
                                fontSize: 13,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: _bg,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle)),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(s, style: TextStyle(fontSize: 13, fontWeight: _sort == s ? FontWeight.w700 : FontWeight.w400, color: _sort == s ? _text : _gray400)),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text('댓글 ${post.commentCount}', style: const TextStyle(fontSize: 12, color: _gray400)),
                      ],
                    ),
                  ),
                  if (comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 52),
                      child: Column(
                        children: [
                          Icon(Icons.mode_comment_outlined, size: 28, color: _gray300),
                          SizedBox(height: 8),
                          Text('첫 댓글을 남겨보세요!', style: TextStyle(fontSize: 13, color: _gray400)),
                        ],
                      ),
                    )
                  else
                    for (final comment in comments)
                      if (!provider.hiddenCommentIds.contains(comment.id))
                        _CommentTile(postId: post.id, comment: comment),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(color: _gray100, border: Border(top: BorderSide(color: _gray200))),
              child: Row(
                children: [
                  _Avatar(name: currentUserName, color: Color(currentAvatarColor), size: 30, fontSize: 11),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _gray100, borderRadius: BorderRadius.circular(999)),
                      child: Center(
                        child: TextField(
                          controller: _inputController,
                          maxLines: 1,
                          cursorHeight: 17,
                          textAlignVertical: TextAlignVertical.center,
                          strutStyle: const StrutStyle(fontSize: 13, height: 1, forceStrutHeight: true),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: _gray100,
                            hintText: '따뜻한 댓글을 남겨보세요 :)',
                            hintStyle: TextStyle(fontSize: 13, height: 1, color: _gray400),
                          ),
                          style: const TextStyle(fontSize: 13, height: 1, color: _text2),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _inputController.text.trim().isEmpty ? _gray100 : _orange,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('등록', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _inputController.text.trim().isEmpty ? _gray400 : Colors.white)),
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
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({required this.postId, required this.comment});
  final int postId;
  final CommunityComment comment;

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
    final provider = context.watch<CommunityProvider>();
    final comment = widget.comment;
    final liked = provider.likedCommentIds.contains(comment.id) || comment.isLiked;

    return Stack(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: comment.username, color: Color(comment.avatarColor), size: 36, fontSize: 13),
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
                                  Text(comment.username, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _text2)),
                                  const SizedBox(height: 2),
                                  Text(comment.relativeTime, style: const TextStyle(fontSize: 11, color: _gray400)),
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
                            if (comment.reportCount != null) ...[
                              const SizedBox(width: 16),
                              _SmallActionIcon(
                                icon: Icons.flag_outlined,
                                label: '신고 ${comment.reportCount}',
                                color: comment.reportCount! > 0 ? _red : _gray400,
                              ),
                            ],
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
                                    _ReplyTile(postId: widget.postId, commentId: comment.id, reply: reply),
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
              const Divider(height: 1, color: _gray100),
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
  const _ReplyTile({required this.postId, required this.commentId, required this.reply});
  final int postId;
  final int commentId;
  final CommunityReply reply;

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
    final provider = context.watch<CommunityProvider>();
    final reply = widget.reply;
    final liked = provider.likedReplyIds.contains(reply.id) || reply.isLiked;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 32),
              _Avatar(name: reply.username, color: Color(reply.avatarColor), size: 28, fontSize: 11),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(reply.username, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _text2)),
                        const SizedBox(width: 6),
                        Text(reply.relativeTime, style: const TextStyle(fontSize: 11, color: _gray400)),
                        const Spacer(),
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
                          if (reply.reportCount != null) ...[
                            const SizedBox(width: 16),
                            _SmallActionIcon(
                              icon: Icons.flag_outlined,
                              label: '신고 ${reply.reportCount}',
                              color: reply.reportCount! > 0 ? _red : _gray400,
                            ),
                          ],
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
