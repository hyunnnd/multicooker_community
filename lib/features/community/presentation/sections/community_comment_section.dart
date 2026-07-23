import 'package:flutter/material.dart';

import '../../../../core/widgets/app_more_menu_button.dart';
import 'package:provider/provider.dart';

import '../../data/models/community_models.dart';
import '../../provider/community_provider.dart';
import '../community_styles.dart';
import '../widgets/community_avatar.dart';

class CommunityCommentSection extends StatelessWidget {
  const CommunityCommentSection({required this.post, required this.sortNewestFirst, super.key});

  final CommunityPost post;
  final bool sortNewestFirst;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final comments = post.comments.where((c) => !provider.hiddenCommentIds.contains(c.id)).toList();
    if (sortNewestFirst) comments.sort((a, b) => b.id.compareTo(a.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final comment in comments)
          _CommentCard(post: post, comment: comment),
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: Text('아직 댓글이 없습니다.', style: TextStyle(color: kCommunitySubtext))),
          ),
      ],
    );
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard({required this.post, required this.comment});

  final CommunityPost post;
  final CommunityComment comment;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  bool _showReplyInput = false;
  bool _editMode = false;
  late final TextEditingController _replyController;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
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
    final liked = provider.likedCommentIds.contains(widget.comment.id);
    final replies = widget.comment.replies.where((reply) => !provider.hiddenReplyIds.contains(reply.id)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommunityAvatar(username: widget.comment.username, colorValue: widget.comment.avatarColor, imageUrl: widget.comment.avatarImageUrl, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.comment.username, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 5),
                    Text(widget.comment.relativeTime, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    const Spacer(),
                    _DotMenu(
                      isOwn: widget.comment.isMine,
                      onEdit: () => setState(() => _editMode = true),
                      onDelete: () => provider.deleteComment(widget.post.id, widget.comment.id),
                      onReport: () {
                        provider.reportComment(widget.comment.id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
                      },
                      onBlock: () {
                        provider.blockComment(widget.comment.id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단되었습니다.')));
                      },
                    ),
                  ],
                ),
                if (_editMode)
                  _InlineEditField(
                    controller: _editController,
                    onCancel: () {
                      _editController.text = widget.comment.content;
                      setState(() => _editMode = false);
                    },
                    onSave: () {
                      provider.editComment(widget.post.id, widget.comment.id, _editController.text);
                      setState(() => _editMode = false);
                    },
                  )
                else
                  Text(widget.comment.content, style: const TextStyle(fontSize: 13, height: 1.45, color: kCommunityText)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () => provider.toggleCommentLike(widget.comment.id),
                      child: Row(
                        children: [
                          Icon(liked ? Icons.favorite : Icons.favorite_border, size: 15, color: liked ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Text('${widget.comment.likes}', style: const TextStyle(fontSize: 12, color: kCommunitySubtext)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    InkWell(
                      onTap: () => setState(() => _showReplyInput = !_showReplyInput),
                      child: const Text('답글', style: TextStyle(fontSize: 12, color: kCommunitySubtext, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (replies.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final reply in replies) _ReplyRow(post: widget.post, comment: widget.comment, reply: reply),
                ],
                if (_showReplyInput) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          textAlignVertical: TextAlignVertical.center,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: '답글을 입력하세요',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          provider.addReply(widget.post.id, widget.comment.id, _replyController.text);
                          _replyController.clear();
                          setState(() => _showReplyInput = false);
                        },
                        icon: const Icon(Icons.send, color: kCommunityOrange),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyRow extends StatefulWidget {
  const _ReplyRow({required this.post, required this.comment, required this.reply});

  final CommunityPost post;
  final CommunityComment comment;
  final CommunityReply reply;

  @override
  State<_ReplyRow> createState() => _ReplyRowState();
}

class _ReplyRowState extends State<_ReplyRow> {
  bool _editMode = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.reply.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final liked = provider.likedReplyIds.contains(widget.reply.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommunityAvatar(username: widget.reply.username, colorValue: widget.reply.avatarColor, imageUrl: widget.reply.avatarImageUrl, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.reply.username, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 5),
                    Text(widget.reply.relativeTime, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                    const Spacer(),
                    _DotMenu(
                      isOwn: widget.reply.isMine,
                      onEdit: () => setState(() => _editMode = true),
                      onDelete: () => provider.deleteReply(widget.post.id, widget.comment.id, widget.reply.id),
                      onReport: () {
                        provider.reportReply(widget.reply.id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
                      },
                      onBlock: () {
                        provider.blockReply(widget.reply.id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단되었습니다.')));
                      },
                    ),
                  ],
                ),
                if (_editMode)
                  _InlineEditField(
                    controller: _controller,
                    onCancel: () {
                      _controller.text = widget.reply.content;
                      setState(() => _editMode = false);
                    },
                    onSave: () {
                      provider.editReply(widget.post.id, widget.comment.id, widget.reply.id, _controller.text);
                      setState(() => _editMode = false);
                    },
                  )
                else
                  Text(widget.reply.content, style: const TextStyle(fontSize: 12, height: 1.4, color: kCommunityText)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => provider.toggleReplyLike(widget.reply.id),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(liked ? Icons.favorite : Icons.favorite_border, size: 14, color: liked ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text('${widget.reply.likes}', style: const TextStyle(fontSize: 11, color: kCommunitySubtext)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotMenu extends StatelessWidget {
  const _DotMenu({required this.isOwn, this.onEdit, this.onDelete, this.onReport, this.onBlock});

  final bool isOwn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    return AppMoreMenuButton<String>(
      tooltip: '댓글 메뉴',
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
      itemBuilder: (_) => [
        if (isOwn) const PopupMenuItem(value: 'edit', child: Text('수정')),
        if (isOwn) const PopupMenuItem(value: 'delete', child: Text('삭제')),
        if (!isOwn) const PopupMenuItem(value: 'report', child: Text('신고')),
        if (!isOwn) const PopupMenuItem(value: 'block', child: Text('차단')),
      ],
      onSelected: (value) {
        if (value == 'edit') {
          onEdit?.call();
        } else if (value == 'delete') {
          onDelete?.call();
        } else if (value == 'report') {
          onReport?.call();
        } else if (value == 'block') {
          onBlock?.call();
        }
      },
    );
  }
}

class _InlineEditField extends StatelessWidget {
  const _InlineEditField({required this.controller, required this.onCancel, required this.onSave});

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('취소')),
              FilledButton(onPressed: onSave, style: FilledButton.styleFrom(backgroundColor: kCommunityOrange), child: const Text('저장')),
            ],
          ),
        ],
      );
}
