import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/recipe.dart';
import '../provider/recipe_provider.dart';
import 'widgets/figma_recipe_widgets.dart';

class CookMethodScreen extends StatelessWidget {
  const CookMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const [
      _MethodItem('🤖', 'Full Auto', '재료를 넣고 바로 조리', '중간 조작 없이 쿠커가 자동으로 진행합니다.', ['계란찜', '솥밥', '야채찜'], figmaBlueLight, 'Full Auto'),
      _MethodItem('👨‍🍳', 'Guided Cook', '단계별 안내 조리', '중간에 뒤집기·섞기·재료 추가가 필요한 레시피입니다.', ['삼겹살 구이', '마늘 버터 새우', '허브 스테이크'], figmaOrangeLight, 'Guided'),
      _MethodItem('⚡', 'Quick Cook', '15분 이하 빠른 조리', '짧은 시간 안에 간단히 완성할 수 있는 레시피입니다.', ['10분 새우구이', '간단 볶음밥', '혼밥 스테이크'], figmaGreenLight, '간편'),
      _MethodItem('🔬', 'Professional', '온도·시간 세부 설정', '여러 단계의 온도와 시간을 세밀하게 조정하는 고급 레시피입니다.', ['닭갈비', '리조또', '전문가 스테이크'], figmaPurpleLight, 'Professional'),
    ];
    return Scaffold(
      backgroundColor: figmaBg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            FigmaHeader(title: '조리 방식으로 찾기', onBack: () => context.pop()),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text('원하는 조리 방식에 맞춰 레시피를 찾아보세요.', style: TextStyle(fontSize: 14, color: figmaGray500)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final item in items) ...[
                    _MethodCard(item: item, onTap: () => context.push('/recipes/browse?type=${Uri.encodeComponent(item.filter)}&title=${Uri.encodeComponent('조리 방식별 레시피')}')),
                    const SizedBox(height: 12),
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

class _MethodItem {
  const _MethodItem(this.emoji, this.label, this.sub, this.desc, this.examples, this.color, this.filter);
  final String emoji;
  final String label;
  final String sub;
  final String desc;
  final List<String> examples;
  final Color color;
  final String filter;
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.item, required this.onTap});
  final _MethodItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: figmaGray100),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 30, height: 1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(item.label, style: const TextStyle(fontSize: 14, color: figmaGray900, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 6),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(item.sub, style: const TextStyle(fontSize: 12, color: figmaGray700, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(item.desc, style: const TextStyle(fontSize: 12, color: figmaGray500, height: 1.25)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: item.examples.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(999)),
                      child: Text(e, style: const TextStyle(fontSize: 11, color: figmaGray500)),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: figmaGray400),
          ],
        ),
      ),
    );
  }
}

class FoodTypeScreen extends StatelessWidget {
  const FoodTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final recipes = provider.recipes;
    final cats = [
      _FoodCat('구이', '🥩', _imageForTitle(recipes, '삼겹')), _FoodCat('볶음', '🥘', _imageForTitle(recipes, '닭갈비')),
      _FoodCat('솥밥', '🍚', _imageForTitle(recipes, '솥밥')), _FoodCat('찜', '♨️', _imageForTitle(recipes, '계란')),
      _FoodCat('간편식', '⚡', _imageForTitle(recipes, '새우')), _FoodCat('디저트', '🍮', null),
      _FoodCat('한식', '🥢', _imageForTitle(recipes, '고기')), _FoodCat('양식', '🍝', _imageForTitle(recipes, '리조또')),
    ];
    return Scaffold(
      backgroundColor: figmaBg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            FigmaHeader(title: '음식 종류', onBack: () => context.pop()),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text('지금 먹고 싶은 음식 종류를 선택해보세요.', style: TextStyle(fontSize: 14, color: figmaGray500)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: cats.map((cat) => _FoodCatCard(cat: cat, onTap: () => context.push('/recipes/browse?type=${Uri.encodeComponent(cat.label)}&title=${Uri.encodeComponent('${cat.label} 레시피')}'))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodCat {
  const _FoodCat(this.label, this.emoji, this.image);
  final String label;
  final String emoji;
  final String? image;
}

class _FoodCatCard extends StatelessWidget {
  const _FoodCatCard({required this.cat, required this.onTap});
  final _FoodCat cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: figmaGray100), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))]),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cat.image != null)
              FigmaRecipeImage(source: cat.image)
            else
              Container(color: figmaGray100, alignment: Alignment.center, child: Text(cat.emoji, style: const TextStyle(fontSize: 36))),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x99000000)]))),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(cat.label, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w900))),
                  Text(cat.emoji, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeSelectScreen extends StatelessWidget {
  const ThemeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipes = context.watch<RecipeProvider>().recipes;
    final themes = [
      _ThemeItem('퇴근 후 15분 요리', '⏰', '빠르게 완성하는 간편 요리', _imageForTitle(recipes, '새우')),
      _ThemeItem('재료만 넣고 끝', '🤖', 'Full Auto 자동 조리', _imageForTitle(recipes, '계란')),
      _ThemeItem('고기 굽기 좋은 날', '🥩', 'Guided Cook 고기 특선', _imageForTitle(recipes, '삼겹')),
      _ThemeItem('혼밥 레시피', '🍱', '1인분 간편 레시피', _imageForTitle(recipes, '솥밥')),
      _ThemeItem('손님 초대 요리', '🎉', '분위기 있는 특별 요리', _imageForTitle(recipes, '스테이크')),
      _ThemeItem('아이와 함께', '👶', '순하고 건강한 레시피', _imageForTitle(recipes, '계란')),
    ];
    return Scaffold(
      backgroundColor: figmaBg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            FigmaHeader(title: '상황별 테마', onBack: () => context.pop()),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text('지금 상황에 맞는 레시피를 찾아보세요.', style: TextStyle(fontSize: 14, color: figmaGray500)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final theme in themes) ...[
                    _ThemeCard(theme: theme, onTap: () => context.push('/recipes/browse?type=${Uri.encodeComponent(theme.label)}&title=${Uri.encodeComponent(theme.label)}')),
                    const SizedBox(height: 12),
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

class _ThemeItem {
  const _ThemeItem(this.label, this.emoji, this.sub, this.image);
  final String label;
  final String emoji;
  final String sub;
  final String? image;
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme, required this.onTap});
  final _ThemeItem theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 80,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: figmaGray100), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))]),
        child: Row(
          children: [
            SizedBox(width: 96, height: double.infinity, child: theme.image == null ? Center(child: Text(theme.emoji, style: const TextStyle(fontSize: 30))) : FigmaRecipeImage(source: theme.image)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(theme.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: figmaGray900, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(theme.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: figmaGray400)),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: figmaGray200),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class RecipeBrowseListScreen extends StatefulWidget {
  const RecipeBrowseListScreen({required this.title, required this.type, super.key});
  final String title;
  final String type;

  @override
  State<RecipeBrowseListScreen> createState() => _RecipeBrowseListScreenState();
}

class _RecipeBrowseListScreenState extends State<RecipeBrowseListScreen> {
  String _filter = '전체';
  final _chips = const ['전체', '공식', '사용자 공유', '인기', '최신'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final recipes = _filtered(provider.recipes);
    return Scaffold(
      backgroundColor: figmaBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  FigmaHeader(title: widget.title, onBack: () => context.pop()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SizedBox(
                      height: 30,
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
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemBuilder: (_, index) {
                  final recipe = recipes[index];
                  return FigmaRecipeCard(recipe: recipe, onTap: () => _open(context, provider, recipe), onSave: () => provider.toggleSaved(recipe.id));
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: recipes.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Recipe> _filtered(List<Recipe> all) {
    var list = all.toList();
    if (widget.type == '공식') list = list.where((r) => r.isOfficial).toList();
    if (widget.type == 'Full Auto') list = list.where((r) => methodLabel(r) == 'Full Auto').toList();
    if (widget.type == 'Guided') list = list.where((r) => methodLabel(r) == 'Guided Cook').toList();
    if (widget.type == '간편') list = list.where((r) => r.totalTimeMin <= 15).toList();
    if (widget.type == '구이') list = list.where((r) => r.title.contains('구이')).toList();
    switch (_filter) {
      case '공식':
        list = list.where((r) => r.isOfficial).toList();
        break;
      case '사용자 공유':
        list = list.where((r) => !r.isOfficial).toList();
        break;
      case '인기':
        list.sort((a, b) => recipeUses(b).compareTo(recipeUses(a)));
        break;
    }
    return list.isEmpty ? all : list;
  }

  void _open(BuildContext context, RecipeProvider provider, Recipe recipe) {
    provider.selectRecipe(recipe.id);
    context.push('/recipes/${recipe.id}');
  }
}

String? _imageForTitle(List<Recipe> recipes, String keyword) {
  for (final recipe in recipes) {
    if (recipe.title.contains(keyword)) return recipe.thumbnailUrl;
  }
  return recipes.isNotEmpty ? recipes.first.thumbnailUrl : null;
}
