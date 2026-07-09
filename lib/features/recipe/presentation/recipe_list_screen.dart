import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';
import '../data/models/recipe.dart';
import '../provider/recipe_provider.dart';
import 'widgets/figma_recipe_widgets.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  String _filter = '추천';
  final _filters = const ['추천', '공식', '인기', '간편', 'Full Auto', 'Guided', '사용자 공유'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final recipes = _filtered(provider.recipes);
    final featured = figmaFeaturedRecipe(recipes);
    final official = recipes.where((recipe) => recipe.isOfficial).toList();
    final user = recipes.where((recipe) => !recipe.isOfficial).toList();

    return MainRouteBackScope(
      child: Scaffold(
        backgroundColor: figmaBg,
        bottomNavigationBar: const MainNavigationBar(currentIndex: 1),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: figmaGray100, width: 1)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('레시피', style: TextStyle(fontSize: 18, height: 1.2, fontWeight: FontWeight.w900, color: figmaGray900))),
                        FigmaIconBox(icon: Icons.search_rounded, onTap: () => context.push('/recipes/search')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => context.push('/recipes/search'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: figmaGray100, borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          children: [
                            Icon(Icons.search_rounded, size: 15, color: figmaGray400),
                            SizedBox(width: 8),
                            Expanded(child: Text('레시피, 재료, 조리방식을 검색해보세요', style: TextStyle(fontSize: 14, color: figmaGray400))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 30,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, index) {
                          final filter = _filters[index];
                          return FigmaFilterChip(label: filter, active: _filter == filter, onTap: () => setState(() => _filter = filter));
                        },
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemCount: _filters.length,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    if (featured != null) ...[
                      const Text('오늘의 추천', style: TextStyle(fontSize: 12, color: figmaGray400, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      FigmaFeaturedRecipeCard(recipe: featured, onTap: () => _open(context, provider, featured), onSave: () => provider.toggleSaved(featured.id)),
                      const SizedBox(height: 20),
                    ],
                    const Text('빠른 탐색', style: TextStyle(fontSize: 12, color: figmaGray400, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.56,
                      ),
                      children: [
                        FigmaQuickBrowseCard(emoji: '🏅', title: '공식 레시피', subtitle: '검증된 조리값', color: figmaOrangeLight, onTap: () => setState(() => _filter = '공식')),
                        FigmaQuickBrowseCard(emoji: '⚙️', title: '조리 방식', subtitle: 'Full Auto / Guided', color: figmaBlueLight, onTap: () => context.push('/recipes/cook-method')),
                        FigmaQuickBrowseCard(emoji: '🍽', title: '음식 종류', subtitle: '구이 / 볶음 / 솥밥', color: figmaGreenLight, onTap: () => context.push('/recipes/food-type')),
                        FigmaQuickBrowseCard(emoji: '🌟', title: '상황별 테마', subtitle: '퇴근 후 / 혼밥', color: figmaPurpleLight, onTap: () => context.push('/recipes/themes')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (official.isNotEmpty) ...[
                      FigmaSectionHeader(title: 'Graphene Square 공식 레시피', subtitle: '검증된 쿠커 조리값으로 안전하게 시작하세요.', action: '전체', onAction: () => setState(() => _filter = '공식')),
                      const SizedBox(height: 10),
                      for (final recipe in official.take(3)) ...[
                        FigmaRecipeCard(recipe: recipe, onTap: () => _open(context, provider, recipe), onSave: () => provider.toggleSaved(recipe.id)),
                        const SizedBox(height: 12),
                      ],
                    ],
                    if (user.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      FigmaSectionHeader(title: '사용자 공유 레시피', subtitle: '다른 사용자가 응용한 조리법을 확인해보세요.', action: '전체', onAction: () => setState(() => _filter = '사용자 공유')),
                      const SizedBox(height: 10),
                      for (final recipe in user.take(3)) ...[
                        FigmaRecipeCard(recipe: recipe, onTap: () => _open(context, provider, recipe), onSave: () => provider.toggleSaved(recipe.id)),
                        const SizedBox(height: 12),
                      ],
                    ],
                    if (recipes.isEmpty) const _EmptyRecipes(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Recipe> _filtered(List<Recipe> recipes) {
    switch (_filter) {
      case '공식':
        return recipes.where((recipe) => recipe.isOfficial).toList();
      case '사용자 공유':
        return recipes.where((recipe) => !recipe.isOfficial).toList();
      case '간편':
        return recipes.where((recipe) => recipe.totalTimeMin <= 15).toList();
      case 'Full Auto':
        return recipes.where((recipe) => methodLabel(recipe) == 'Full Auto').toList();
      case 'Guided':
        return recipes.where((recipe) => methodLabel(recipe) == 'Guided Cook').toList();
      case '인기':
        final sorted = [...recipes]..sort((a, b) => recipeUses(b).compareTo(recipeUses(a)));
        return sorted;
      default:
        return recipes;
    }
  }

  void _open(BuildContext context, RecipeProvider provider, Recipe recipe) {
    provider.selectRecipe(recipe.id);
    context.push('/recipes/${recipe.id}');
  }
}

class _EmptyRecipes extends StatelessWidget {
  const _EmptyRecipes();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Text('🔍', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('검색 결과가 없어요', style: TextStyle(fontSize: 18, color: figmaGray900, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('검색어를 다시 확인하거나 다른 키워드로 검색해보세요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: figmaGray400)),
        ],
      ),
    );
  }
}
