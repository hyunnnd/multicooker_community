import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/community_provider.dart';
import '../widgets/recipe_review_card.dart';

class CommunityReviewSection extends StatelessWidget {
  const CommunityReviewSection({required this.onRecipeTap, super.key});

  final ValueChanged<String> onRecipeTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    return Column(
      children: [
        for (final review in provider.reviews) ...[
          RecipeReviewCard(
            review: review,
            liked: provider.likedReviewIds.contains(review.id),
            onLike: () => provider.toggleReviewLike(review.id),
            onRecipeTap: () => onRecipeTap(review.recipeId),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
