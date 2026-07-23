import 'package:flutter/material.dart';

import '../../../../core/widgets/app_image.dart';

import '../../data/models/community_models.dart';
import '../community_styles.dart';
import 'community_avatar.dart';

class RecipeReviewCard extends StatelessWidget {
  const RecipeReviewCard({
    required this.review,
    required this.liked,
    required this.onLike,
    required this.onRecipeTap,
    super.key,
  });

  final CommunityReview review;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onRecipeTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommunityAvatar(username: review.username, colorValue: review.avatarColor, imageUrl: review.avatarImageUrl, size: 22),
              const SizedBox(width: 6),
              Text(review.username, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Text('·', style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB))),
              const SizedBox(width: 4),
              Text(review.date, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              const Spacer(),
              for (var i = 1; i <= 5; i++)
                Icon(Icons.star, size: 13, color: i <= review.rating ? const Color(0xFFFACC15) : const Color(0xFFE5E7EB)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImage(
                  source: review.recipeImage,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  placeholder: Container(width: 64, height: 64, color: const Color(0xFFF3F4F6)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('리뷰한 레시피', style: TextStyle(fontSize: 11, color: kCommunitySubtext)),
                    const SizedBox(height: 2),
                    Text(review.recipeTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kCommunityText)),
                    const SizedBox(height: 4),
                    Text(review.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.45, color: kCommunitySubtext)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onRecipeTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: kCommunityOrangeLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFEDD5))),
              child: Row(
                children: [
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: kCommunityOrange, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.menu_book, size: 15, color: Colors.white)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(review.recipeTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kCommunityText))),
                  const Text('레시피 보기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kCommunityOrangeDark)),
                  const Icon(Icons.chevron_right, size: 14, color: kCommunityOrangeDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFFF3F4F6)),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: onLike,
                child: Row(
                  children: [
                    Icon(liked ? Icons.favorite : Icons.favorite_border, size: 16, color: liked ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text('${review.likes}', style: const TextStyle(fontSize: 12, color: kCommunitySubtext)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              const Icon(Icons.mode_comment_outlined, size: 16, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text('${review.commentCount}', style: const TextStyle(fontSize: 12, color: kCommunitySubtext)),
            ],
          ),
        ],
      ),
    );
  }
}
