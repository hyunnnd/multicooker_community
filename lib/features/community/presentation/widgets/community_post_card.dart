import 'package:flutter/material.dart';

import '../../../../core/widgets/app_image.dart';

import '../../data/models/community_models.dart';
import '../community_styles.dart';
import 'community_avatar.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    required this.post,
    required this.liked,
    required this.bookmarked,
    required this.onLike,
    required this.onBookmark,
    required this.onTap,
    super.key,
  });

  final CommunityPost post;
  final bool liked;
  final bool bookmarked;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totalLikes = post.likes;
    final isPopular = totalLikes >= 100;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CommunityAvatar(username: post.username, colorValue: post.avatarColor, size: 22),
                const SizedBox(width: 6),
                Text(post.username, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                const Text('·', style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB))),
                const SizedBox(width: 4),
                Text(post.timeAgo, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                const Spacer(),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(20)),
                    child: const Text('🔥 인기', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.w800)),
                  ),
                if (isPopular) const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: post.category == PostCategory.qa ? const Color(0xFFFFEDD5) : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    post.category.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: post.category == PostCategory.qa ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kCommunityText)),
                      const SizedBox(height: 5),
                      Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.45, color: kCommunitySubtext)),
                    ],
                  ),
                ),
                if (post.imageUrl != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppImage(
                      source: post.imageUrl,
                      width: 78,
                      height: 78,
                      fit: BoxFit.cover,
                      placeholder: Container(width: 78, height: 78, color: const Color(0xFFF3F4F6), child: const Icon(Icons.image_not_supported_outlined, color: kCommunitySubtext)),
                    ),
                  ),
                ],
              ],
            ),
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [for (final tag in post.tags) Text('#$tag', style: const TextStyle(fontSize: 11, color: kCommunityOrangeDark, fontWeight: FontWeight.w600))],
              ),
            ],
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionButton(icon: liked ? Icons.favorite : Icons.favorite_border, label: '$totalLikes', active: liked, activeColor: const Color(0xFFEF4444), onTap: onLike),
                const SizedBox(width: 18),
                const Icon(Icons.mode_comment_outlined, size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: const TextStyle(fontSize: 12, color: kCommunitySubtext)),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border, size: 18, color: bookmarked ? kCommunityOrange : const Color(0xFF9CA3AF)),
                  onPressed: onBookmark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.active, required this.activeColor, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? activeColor : const Color(0xFF9CA3AF)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: kCommunitySubtext)),
          ],
        ),
      );
}
