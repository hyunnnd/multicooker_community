import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';
import '../../device/provider/device_provider.dart';
import '../../recipe/data/models/recipe.dart';
import '../../recipe/presentation/widgets/figma_recipe_widgets.dart';
import '../../recipe/provider/recipe_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final recipeProvider = context.watch<RecipeProvider>();
    final recipes = recipeProvider.recipes;
    final featured = figmaFeaturedRecipe(recipes);
    final popularRecipes = figmaPopularRecipes(recipes);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? '좋은 아침이에요' : hour < 18 ? '좋은 오후예요' : '좋은 저녁이에요';

    return MainRouteBackScope(
      child: Scaffold(
        backgroundColor: figmaBg,
        bottomNavigationBar: const MainNavigationBar(currentIndex: 0),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: figmaGray100, width: 1)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$greeting 👋', style: const TextStyle(fontSize: 12, color: figmaGray400, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              const Text('오늘 뭐 드실래요?', style: TextStyle(fontSize: 20, height: 1.2, fontWeight: FontWeight.w900, color: figmaGray900)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            FigmaIconBox(icon: Icons.notifications_none_rounded, onTap: () => context.go('/community')),
                            const SizedBox(width: 8),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: figmaNavy, borderRadius: BorderRadius.circular(12)),
                              alignment: Alignment.center,
                              child: const Text('U', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.go('/device'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: device.isConnected ? figmaNavy : figmaGray50,
                          borderRadius: BorderRadius.circular(16),
                          border: device.isConnected ? null : Border.all(color: figmaGray100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: device.isConnected ? const Color(0xFF4ADE80) : const Color(0xFFD1D5DB),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                device.isConnected ? '${device.deviceName} 연결됨' : '쿠커 연결 안됨 — 연결하기',
                                style: TextStyle(fontSize: 12, color: device.isConnected ? Colors.white : figmaGray500, fontWeight: FontWeight.w900),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 14, color: device.isConnected ? Colors.white54 : figmaGray400),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (featured != null) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('오늘의 추천', style: TextStyle(fontSize: 12, color: figmaGray400, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FigmaFeaturedRecipeCard(
                    recipe: featured,
                    home: true,
                    onTap: () => _openRecipe(context, recipeProvider, featured),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(child: _QuickAction(emoji: '🤖', label: 'AI 추천', onTap: () => context.go('/recipes'))),
                    const SizedBox(width: 8),
                    Expanded(child: _QuickAction(emoji: '🔖', label: '저장한 레시피', onTap: () => context.go('/settings'))),
                    const SizedBox(width: 8),
                    Expanded(child: _QuickAction(emoji: '📖', label: '최근 조리', onTap: () => context.go('/settings'))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    const Expanded(child: Text('인기 레시피', style: TextStyle(fontSize: 14, color: figmaGray900, fontWeight: FontWeight.w900))),
                    InkWell(
                      onTap: () => context.go('/recipes'),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text('전체 보기', style: TextStyle(fontSize: 12, color: figmaOrange, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 172,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, index) {
                    final recipe = popularRecipes[index];
                    return FigmaRecipeCard(
                      recipe: recipe,
                      compact: true,
                      onTap: () => _openRecipe(context, recipeProvider, recipe),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemCount: popularRecipes.length > 5 ? 5 : popularRecipes.length,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const Expanded(child: Text('커뮤니티 최신글', style: TextStyle(fontSize: 14, color: figmaGray900, fontWeight: FontWeight.w900))),
                    InkWell(
                      onTap: () => context.go('/community'),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text('더보기', style: TextStyle(fontSize: 12, color: figmaOrange, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _CommunityPreview(author: '김미소', avatar: '😊', type: '후기', title: '갈바속 삼겹살 후기', body: '처음 해봤는데 완전 성공! 쿠커가 알아서 해줘서 편했어요.', likes: 24, comments: 8, date: '2일 전'),
                    SizedBox(height: 10),
                    _CommunityPreview(author: '박준혁', avatar: '🙂', type: 'Q&A', title: '계란찜 물 양 질문', body: '계란찜에서 물을 얼마나 넣어야 부드럽게 되나요?', likes: 5, comments: 12, date: '3일 전'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _openRecipe(BuildContext context, RecipeProvider provider, Recipe recipe) {
    provider.selectRecipe(recipe.id);
    context.push('/recipes/${recipe.id}');
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.emoji, required this.label, required this.onTap});
  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: figmaGray100),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24, height: 1)),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: figmaGray500, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _CommunityPreview extends StatelessWidget {
  const _CommunityPreview({required this.author, required this.avatar, required this.type, required this.title, required this.body, required this.likes, required this.comments, required this.date});
  final String author;
  final String avatar;
  final String type;
  final String title;
  final String body;
  final int likes;
  final int comments;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: figmaGray100),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(avatar, style: const TextStyle(fontSize: 16, height: 1)),
              const SizedBox(width: 8),
              Text(author, style: const TextStyle(fontSize: 12, color: figmaGray500, fontWeight: FontWeight.w700)),
              const Spacer(),
              _TypeChip(type),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: figmaGray900, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: figmaGray400)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.favorite_border_rounded, size: 12, color: figmaGray400),
              const SizedBox(width: 3),
              Text('$likes', style: const TextStyle(fontSize: 12, color: figmaGray400)),
              const SizedBox(width: 12),
              Icon(Icons.mode_comment_outlined, size: 12, color: figmaGray400),
              const SizedBox(width: 3),
              Text('$comments', style: const TextStyle(fontSize: 12, color: figmaGray400)),
              const Spacer(),
              Text(date, style: const TextStyle(fontSize: 12, color: figmaGray400)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final isQa = label == 'Q&A';
    final isFree = label == '자유';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isQa ? figmaBlueLight : isFree ? figmaGray100 : figmaOrangeLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: isQa ? const Color(0xFF2563EB) : isFree ? figmaGray500 : figmaOrange, fontWeight: FontWeight.w900)),
    );
  }
}
