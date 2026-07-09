import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/recipe.dart';
import '../provider/recipe_provider.dart';
import 'widgets/figma_recipe_widgets.dart';

class RecipeResultsScreen extends StatefulWidget {
  const RecipeResultsScreen({required this.query, super.key});
  final String query;

  @override
  State<RecipeResultsScreen> createState() => _RecipeResultsScreenState();
}

class _RecipeResultsScreenState extends State<RecipeResultsScreen> {
  var _filter = '전체';
  final _chips = const ['전체', '공식', '사용자', 'Full Auto', 'Guided'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final results = _filtered(provider.recipes, widget.query);

    return Scaffold(
        backgroundColor: figmaBg,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        InkWell(onTap: () => context.go('/recipes/search'), child: const Icon(Icons.arrow_back_rounded, size: 22, color: figmaGray500)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => context.go('/recipes/search'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: figmaGray100, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  const Icon(Icons.search_rounded, size: 16, color: figmaGray400),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(widget.query.isEmpty ? '삼겹살' : widget.query, style: const TextStyle(fontSize: 14, color: figmaGray900))),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: figmaGray100, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.tune_rounded, size: 18, color: figmaGray500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, index) {
                          final chip = _chips[index];
                          return FigmaFilterChip(label: chip, active: _filter == chip, onTap: () => setState(() => _filter = chip));
                        },
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemCount: _chips.length,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _EmptyResult(onReset: () => setState(() => _filter = '전체'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          Text('검색 결과 ${results.length}개', style: const TextStyle(fontSize: 12, color: figmaGray400, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          for (final recipe in results.take(8)) ...[
                            FigmaRecipeCard(recipe: recipe, onTap: () => _open(context, provider, recipe), onSave: () => provider.toggleSaved(recipe.id)),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
  }

  List<Recipe> _filtered(List<Recipe> recipes, String query) {
    final q = query.trim().toLowerCase();
    var list = recipes.where((recipe) {
      if (q.isEmpty) return true;
      return recipe.title.toLowerCase().contains(q) || recipe.description.toLowerCase().contains(q) || recipe.ingredients.any((e) => e.name.toLowerCase().contains(q));
    }).toList();
    switch (_filter) {
      case '공식':
        list = list.where((e) => e.isOfficial).toList();
        break;
      case '사용자':
        list = list.where((e) => !e.isOfficial).toList();
        break;
      case 'Full Auto':
        list = list.where((e) => methodLabel(e) == 'Full Auto').toList();
        break;
      case 'Guided':
        list = list.where((e) => methodLabel(e) == 'Guided Cook').toList();
        break;
    }
    return list;
  }

  void _open(BuildContext context, RecipeProvider provider, Recipe recipe) {
    provider.selectRecipe(recipe.id);
    context.push('/recipes/${recipe.id}');
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          const Text('검색 결과가 없어요', style: TextStyle(fontSize: 18, color: figmaGray900, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('검색어를 다시 확인하거나 다른 키워드로 검색해보세요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: figmaGray400, height: 1.4)),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _KeywordChip('삼겹살'),
              _KeywordChip('계란찜'),
              _KeywordChip('갈비찜'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: figmaOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => context.go('/recipes'),
              child: const Text('추천 레시피 보기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              style: TextButton.styleFrom(backgroundColor: figmaGray100, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: onReset,
              child: const Text('필터 초기화', style: TextStyle(fontSize: 14, color: figmaGray500, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(border: Border.all(color: figmaOrange), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: const TextStyle(fontSize: 13, color: figmaOrange, fontWeight: FontWeight.w800)),
      );
}
