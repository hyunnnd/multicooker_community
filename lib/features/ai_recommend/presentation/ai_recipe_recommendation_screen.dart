import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../data/ai_recommend_result.dart';
import '../provider/ai_recommend_provider.dart';

const _blue = Color(0xFF2F80ED);
const _blueSoft = Color(0xFFEAF2FF);
const _ink = Color(0xFF292929);
const _sub = Color(0xFF77736C);
const _border = Color(0xFFE8E2D7);

class AiRecipeRecommendationScreen extends StatelessWidget {
  const AiRecipeRecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AiRecommendProvider>().result;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('AI 추천 결과'),
      ),
      bottomNavigationBar: const MainNavigationBar(currentIndex: 0),
      body: result == null
          ? Center(
              child: FilledButton.icon(
                onPressed: () => context.go('/ai-scan'),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('식재료 사진 선택'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '인식한 식재료',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.ingredients
                      .map(
                        (item) => Chip(
                          avatar: const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: _blue,
                          ),
                          label: Text(
                            '${item.name} ${(item.confidence * 100).round()}%',
                          ),
                          backgroundColor: _blueSoft,
                          side: const BorderSide(color: _border),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 24),
                const Text(
                  '추천 레시피',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                for (final recipe in result.recipes) ...[
                  _RecipeResultCard(recipe: recipe),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _RecipeResultCard extends StatelessWidget {
  const _RecipeResultCard({required this.recipe});

  final AiRecommendedRecipe recipe;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                recipe.title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${(recipe.similarity * 100).round()}% 일치',
              style: const TextStyle(color: _blue, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(recipe.description, style: const TextStyle(color: _sub)),
        const SizedBox(height: 14),
        for (var index = 0; index < recipe.steps.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(
                  'Step ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${recipe.steps[index].temperature.round()}°C · '
                  '${_offset(recipe.steps[index].timeOffset)}',
                  style: const TextStyle(color: _sub),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  static String _offset(double seconds) =>
      seconds == 0 ? '바로 시작' : '${(seconds / 60).round()}분 후';
}
