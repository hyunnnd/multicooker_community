import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../data/ai_recommend_result.dart';
import '../provider/ai_recommend_provider.dart';

const _orange = Color(0xFFF97316);
const _orangeSoft = Color(0xFFFFF1E6);
const _ink = Color(0xFF111827);
const _sub = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);
const _background = Color(0xFFF8FAFC);

class AiRecipeRecommendationScreen extends StatelessWidget {
  const AiRecipeRecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AiRecommendProvider>().result;
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const MainNavigationBar(currentIndex: 0),
      body: SafeArea(
        child: Column(
          children: [
            const _RecommendationHeader(),
            Expanded(
              child: result == null
                  ? const _EmptyResult()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        _ResultSummary(
                          ingredientCount: result.ingredients.length,
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          '인식한 식재료',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: result.ingredients
                              .map(
                                (item) => _IngredientChip(
                                  name: item.name,
                                  confidence: item.confidence,
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Text(
                              '추천 레시피',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${result.recipes.length}개',
                              style: const TextStyle(
                                color: _sub,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final recipe in result.recipes) ...[
                          _RecipeResultCard(recipe: recipe),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationHeader extends StatelessWidget {
  const _RecommendationHeader();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          tooltip: '뒤로가기',
        ),
        const SizedBox(width: 4),
        const Text(
          'AI 추천 결과',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _orangeSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_awesome, color: _orange),
          ),
          const SizedBox(height: 14),
          const Text(
            '추천 결과가 없어요',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '식재료를 촬영하면 맞춤 레시피를 추천해 드릴게요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _sub, fontSize: 13),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.go('/ai-scan'),
            style: FilledButton.styleFrom(backgroundColor: _orange),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('식재료 촬영하기'),
          ),
        ],
      ),
    ),
  );
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.ingredientCount});

  final int ingredientCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _orangeSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_awesome, color: _orange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '식재료 분석 완료',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '$ingredientCount개의 식재료로 추천을 준비했어요.',
                style: const TextStyle(color: _sub, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.name, required this.confidence});

  final String name;
  final double confidence;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFFED7AA)),
    ),
    child: Text(
      '$name ${(confidence * 100).round()}%',
      style: const TextStyle(
        color: Color(0xFFC2410C),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _RecipeResultCard extends StatelessWidget {
  const _RecipeResultCard({required this.recipe});

  final AiRecommendedRecipe recipe;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _orangeSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant_menu_outlined,
                color: _orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                recipe.title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${(recipe.similarity * 100).round()}% 일치',
              style: const TextStyle(
                color: _orange,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (recipe.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            recipe.description,
            style: const TextStyle(color: _sub, fontSize: 13),
          ),
        ],
        if (recipe.steps.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 10),
          for (var index = 0; index < recipe.steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '단계 ${index + 1}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${recipe.steps[index].temperature.round()}°C · '
                    '${_offset(recipe.steps[index].timeOffset)}',
                    style: const TextStyle(color: _sub, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );

  static String _offset(double seconds) =>
      seconds == 0 ? '바로 시작' : '${(seconds / 60).round()}분 후';
}
