import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/language/language_provider.dart';
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
  final _filters = const [
    '추천',
    '공식',
    '인기',
    '간편',
    'Full Auto',
    'Guided',
    '사용자 공유',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<RecipeProvider>().loadRecipes(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final recipes = _filtered(provider.recipes);
    final featured = figmaFeaturedRecipe(recipes);
    final official = recipes.where((recipe) => recipe.isOfficial).toList();
    final user = recipes.where((recipe) => !recipe.isOfficial).toList();
    final lang = context.watch<LanguageProvider>();

    return MainRouteBackScope(
      backToHomeWhenUnhandled: true,
      child: Scaffold(
        backgroundColor: figmaBg,
        bottomNavigationBar: const MainNavigationBar(currentIndex: 1),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: figmaGray100, width: 1),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lang.t('레시피', 'Recipes'),
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                              color: figmaGray900,
                            ),
                          ),
                        ),
                        FigmaIconBox(
                          icon: Icons.search_rounded,
                          onTap: () => context.push('/recipes/search'),
                        ),
                        const SizedBox(width: 8),
                        FigmaIconBox(
                          icon: Icons.add_rounded,
                          onTap: () => context.push('/recipes/upload'),
                        ),
                        const SizedBox(width: 8),
                        FigmaIconBox(
                          icon: Icons.refresh_rounded,
                          onTap: () => provider.loadRecipes(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => context.push('/recipes/search'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: figmaGray100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              size: 15,
                              color: figmaGray400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lang.t(
                                  '레시피, 재료, 조리방식을 검색해보세요',
                                  'Search recipes, ingredients, or cooking methods',
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: figmaGray400,
                                ),
                              ),
                            ),
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
                          return FigmaFilterChip(
                            label: _filterLabel(lang, filter),
                            active: _filter == filter,
                            onTap: () => setState(() => _filter = filter),
                          );
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
                      Text(
                        lang.t('오늘의 추천', 'Today’s Pick'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: figmaGray400,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FigmaFeaturedRecipeCard(
                        recipe: featured,
                        onTap: () => _open(context, provider, featured),
                        onSave: () => provider.toggleSaved(featured.id),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      lang.t('빠른 탐색', 'Quick Browse'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: figmaGray400,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.56,
                          ),
                      children: [
                        FigmaQuickBrowseCard(
                          emoji: '🏅',
                          title: lang.t('공식 레시피', 'Official Recipes'),
                          subtitle: lang.t(
                            '검증된 조리값',
                            'Verified cooker settings',
                          ),
                          color: figmaOrangeLight,
                          onTap: () => setState(() => _filter = '공식'),
                        ),
                        FigmaQuickBrowseCard(
                          emoji: '⚙️',
                          title: lang.t('조리 방식', 'Cooking Method'),
                          subtitle: 'Full Auto / Guided',
                          color: figmaBlueLight,
                          onTap: () => context.push('/recipes/cook-method'),
                        ),
                        FigmaQuickBrowseCard(
                          emoji: '🍽',
                          title: lang.t('음식 종류', 'Food Type'),
                          subtitle: lang.t(
                            '구이 / 볶음 / 솥밥',
                            'Grill / Stir-fry / Rice',
                          ),
                          color: figmaGreenLight,
                          onTap: () => context.push('/recipes/food-type'),
                        ),
                        FigmaQuickBrowseCard(
                          emoji: '🌟',
                          title: lang.t('상황별 테마', 'Themes'),
                          subtitle: lang.t(
                            '퇴근 후 / 혼밥',
                            'After work / Solo meal',
                          ),
                          color: figmaPurpleLight,
                          onTap: () => context.push('/recipes/themes'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (official.isNotEmpty) ...[
                      FigmaSectionHeader(
                        title: lang.t(
                          'Graphene Square 공식 레시피',
                          'Graphene Square Official Recipes',
                        ),
                        subtitle: lang.t(
                          '검증된 쿠커 조리값으로 안전하게 시작하세요.',
                          'Start safely with verified cooker settings.',
                        ),
                        action: lang.t('전체', 'All'),
                        onAction: () => setState(() => _filter = '공식'),
                      ),
                      const SizedBox(height: 10),
                      for (final recipe in official.take(3)) ...[
                        FigmaRecipeCard(
                          recipe: recipe,
                          onTap: () => _open(context, provider, recipe),
                          onSave: () => provider.toggleSaved(recipe.id),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    if (user.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      FigmaSectionHeader(
                        title: lang.t('사용자 공유 레시피', 'Shared Recipes'),
                        subtitle: lang.t(
                          '다른 사용자가 응용한 조리법을 확인해보세요.',
                          'Explore recipes shared by other users.',
                        ),
                        action: lang.t('전체', 'All'),
                        onAction: () => setState(() => _filter = '사용자 공유'),
                      ),
                      const SizedBox(height: 10),
                      for (final recipe in user.take(3)) ...[
                        FigmaRecipeCard(
                          recipe: recipe,
                          onTap: () => _open(context, provider, recipe),
                          onSave: () => provider.toggleSaved(recipe.id),
                        ),
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

  String _filterLabel(LanguageProvider lang, String filter) {
    return switch (filter) {
      '추천' => lang.t('추천', 'Recommended'),
      '공식' => lang.t('공식', 'Official'),
      '인기' => lang.t('인기', 'Popular'),
      '간편' => lang.t('간편', 'Quick'),
      '사용자 공유' => lang.t('사용자 공유', 'Shared'),
      _ => filter,
    };
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
        return recipes
            .where((recipe) => methodLabel(recipe) == 'Full Auto')
            .toList();
      case 'Guided':
        return recipes
            .where((recipe) => methodLabel(recipe) == 'Guided Cook')
            .toList();
      case '인기':
        final sorted = [...recipes]
          ..sort((a, b) => recipeUses(b).compareTo(recipeUses(a)));
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
    final lang = context.watch<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            lang.t('검색 결과가 없어요', 'No results found'),
            style: const TextStyle(
              fontSize: 18,
              color: figmaGray900,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lang.t(
              '검색어를 다시 확인하거나 다른 키워드로 검색해보세요.',
              'Check your search term or try another keyword.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: figmaGray400),
          ),
        ],
      ),
    );
  }
}
