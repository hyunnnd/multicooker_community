import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/app_more_menu_button.dart';
import '../../../../core/widgets/main_navigation.dart';
import '../../data/models/community_models.dart';
import '../../provider/community_provider.dart';
import '../bottom_sheets/community_post_sheet.dart';
import '../community_styles.dart';
import '../widgets/community_avatar.dart';
import 'community_comment_section.dart';

enum CommentSortType { registration, newest }

class CommunityPostDetailSection extends StatefulWidget {
  const CommunityPostDetailSection({required this.postId, required this.onBack, required this.onEdit, super.key});

  final int postId;
  final VoidCallback onBack;
  final ValueChanged<int> onEdit;

  @override
  State<CommunityPostDetailSection> createState() => _CommunityPostDetailSectionState();
}

class _CommunityPostDetailSectionState extends State<CommunityPostDetailSection> {
  final _commentController = TextEditingController();
  var _sort = CommentSortType.registration;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final post = provider.postById(widget.postId);
    if (post == null) {
      return Scaffold(
        backgroundColor: kCommunityBackground,
        appBar: AppBar(leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)), title: const Text('게시글')),
        body: const Center(child: Text('게시글을 찾을 수 없습니다.')),
        bottomNavigationBar: const MainNavigationBar(currentIndex: 3),
      );
    }
    final liked = provider.likedPostIds.contains(post.id);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: const Text('게시글', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          AppMoreMenuButton<String>(
            tooltip: '게시글 메뉴',
            itemBuilder: (_) => [
              if (post.isMine) const PopupMenuItem(value: 'edit', child: Text('수정')),
              if (post.isMine) const PopupMenuItem(value: 'delete', child: Text('삭제')),
              if (!post.isMine) const PopupMenuItem(value: 'report', child: Text('신고')),
              if (!post.isMine) const PopupMenuItem(value: 'block', child: Text('차단')),
            ],
            onSelected: (value) async {
              if (value == 'edit') {
                widget.onEdit(post.id);
              } else if (value == 'delete') {
                final ok = await _confirmDelete(context);
                if (ok && context.mounted) {
                  provider.deletePost(post.id);
                  widget.onBack();
                }
              } else if (value == 'report') {
                provider.reportPost(post.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
                  widget.onBack();
                }
              } else if (value == 'block') {
                provider.blockPost(post.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단되었습니다.')));
                  widget.onBack();
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CommunityAvatar(username: post.username, colorValue: post.avatarColor, imageUrl: post.avatarImageUrl, size: 34),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post.username, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                              Text(post.relativeTime, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(color: post.category == PostCategory.qa ? const Color(0xFFFFEDD5) : const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(20)),
                            child: Text(post.category.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: post.category == PostCategory.qa ? const Color(0xFFEA580C) : const Color(0xFF2563EB))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(post.title, style: const TextStyle(fontSize: 21, height: 1.25, fontWeight: FontWeight.w900, color: kCommunityText)),
                      const SizedBox(height: 12),
                      Text(post.content, style: const TextStyle(fontSize: 14, height: 1.65, color: kCommunityText)),
                      if (post.imageUrl != null) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppImage(source: post.imageUrl, width: double.infinity, fit: BoxFit.cover, placeholder: const SizedBox.shrink()),
                        ),
                      ],
                      if (post.tags.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(spacing: 6, runSpacing: 4, children: [for (final tag in post.tags) Text('#$tag', style: const TextStyle(fontSize: 12, color: kCommunityOrangeDark, fontWeight: FontWeight.w800))]),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _PostAction(icon: liked ? Icons.favorite : Icons.favorite_border, text: '${post.likes}', color: liked ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF), onTap: () => provider.togglePostLike(post.id)),
                          const SizedBox(width: 18),
                          _PostAction(icon: Icons.mode_comment_outlined, text: '${post.commentCount}', color: const Color(0xFF9CA3AF), onTap: () {}),

                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  color: const Color(0xFFF9FAFB),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      _SortButton(label: '등록순', selected: _sort == CommentSortType.registration, onTap: () => setState(() => _sort = CommentSortType.registration)),
                      const SizedBox(width: 14),
                      _SortButton(label: '최신순', selected: _sort == CommentSortType.newest, onTap: () => setState(() => _sort = CommentSortType.newest)),
                      const Spacer(),
                      Text('댓글 ${post.commentCount}', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  child: CommunityCommentSection(post: post, sortNewestFirst: _sort == CommentSortType.newest),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kCommunityBorder))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '따뜻한 댓글을 남겨보세요 :)',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      provider.addComment(post.id, _commentController.text);
                      _commentController.clear();
                    },
                    icon: const Icon(Icons.send, color: kCommunityOrange),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    return result ?? false;
  }
}

class CommunityPostEditSection extends StatelessWidget {
  const CommunityPostEditSection({required this.postId, required this.onBack, super.key});

  final int postId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final post = provider.postById(postId);
    if (post == null) return const SizedBox.shrink();
    return CommunityPostSheet(
      title: '게시글 수정',
      initialPost: post,
      onBack: onBack,
      onSubmit: (category, title, content, imageUrl) {
        provider.editPost(post.id, category: category, title: title, content: content, imageUrl: imageUrl);
        onBack();
      },
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({required this.icon, required this.text, required this.color, required this.onTap});

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Row(
          children: [Icon(icon, size: 19, color: color), const SizedBox(width: 5), Text(text, style: const TextStyle(fontSize: 13, color: kCommunitySubtext))],
        ),
      );
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(Icons.circle, size: 6, color: selected ? kCommunityOrange : const Color(0xFFD1D5DB)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w900 : FontWeight.w600, color: selected ? kCommunityText : kCommunitySubtext)),
          ],
        ),
      );
}
