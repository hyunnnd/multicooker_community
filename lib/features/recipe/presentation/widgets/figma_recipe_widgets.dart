import 'package:flutter/material.dart';

import '../../../../core/widgets/app_image.dart';
import '../../data/models/recipe.dart';
import '../../data/models/recipe_compatibility_type.dart';

const figmaOrange = Color(0xFFF97316);
const figmaOrangeDark = Color(0xFFEA580C);
const figmaOrangeLight = Color(0xFFFFF7ED);
const figmaBg = Color(0xFFF8FAFC);
const figmaWhite = Color(0xFFFFFFFF);
const figmaGray50 = Color(0xFFF9FAFB);
const figmaGray100 = Color(0xFFF3F4F6);
const figmaGray200 = Color(0xFFE5E7EB);
const figmaGray400 = Color(0xFF9CA3AF);
const figmaGray500 = Color(0xFF6B7280);
const figmaGray700 = Color(0xFF374151);
const figmaGray900 = Color(0xFF111827);
const figmaGreen = Color(0xFF16A34A);
const figmaGreenLight = Color(0xFFDCFCE7);
const figmaYellow = Color(0xFFF59E0B);
const figmaBlue = Color(0xFF3B82F6);
const figmaBlueLight = Color(0xFFEFF6FF);
const figmaNavy = Color(0xFF0A2540);
const figmaPurpleLight = Color(0xFFFAF5FF);
const figmaPurple = Color(0xFF9333EA);

String formatK(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

String _recipeKey(Recipe recipe) => '${recipe.id} ${recipe.title}'.replaceAll(' ', '').toLowerCase();

int recipeUses(Recipe recipe) {
  final key = _recipeKey(recipe);
  if (key.contains('r1') || key.contains('갈바속') || key.contains('삼겹살구이')) return 2800;
  if (key.contains('r2') || key.contains('계란찜')) return 1900;
  if (key.contains('r3') || key.contains('솥밥')) return 1400;
  if (key.contains('r4') || key.contains('마늘버터새우')) return 1600;
  if (key.contains('r5') || key.contains('스테이크')) return 3200;
  if (key.contains('r6') || key.contains('10분새우')) return 920;
  if (key.contains('r7') || key.contains('닭갈비')) return 1100;
  if (key.contains('r8') || key.contains('리조또')) return 780;
  if (key.contains('r9') || key.contains('마늘듬뿍')) return 430;
  return 920;
}

int recipeReviews(Recipe recipe) {
  final key = _recipeKey(recipe);
  if (key.contains('r1') || key.contains('갈바속') || key.contains('삼겹살구이')) return 342;
  if (key.contains('r2') || key.contains('계란찜')) return 218;
  if (key.contains('r3') || key.contains('솥밥')) return 156;
  if (key.contains('r4') || key.contains('마늘버터새우')) return 189;
  if (key.contains('r5') || key.contains('스테이크')) return 421;
  if (key.contains('r6') || key.contains('10분새우')) return 87;
  if (key.contains('r7') || key.contains('닭갈비')) return 134;
  if (key.contains('r8') || key.contains('리조또')) return 98;
  if (key.contains('r9') || key.contains('마늘듬뿍')) return 18;
  return 98;
}

double recipeRating(Recipe recipe) {
  final key = _recipeKey(recipe);
  if (key.contains('r5') || key.contains('스테이크')) return 4.9;
  if (key.contains('r1') || key.contains('갈바속') || key.contains('삼겹살구이')) return 4.8;
  if (key.contains('r3') || key.contains('솥밥')) return 4.6;
  if (key.contains('r6') || key.contains('10분새우')) return 4.5;
  return 4.7;
}

Recipe? figmaFeaturedRecipe(List<Recipe> recipes) {
  if (recipes.isEmpty) return null;
  for (final recipe in recipes) {
    final key = _recipeKey(recipe);
    if (key.contains('r5') || key.contains('허브스테이크') || key.contains('스테이크')) {
      return recipe;
    }
  }
  return recipes.first;
}

List<Recipe> figmaPopularRecipes(List<Recipe> recipes) {
  final sorted = [...recipes];
  sorted.sort((a, b) => recipeUses(b).compareTo(recipeUses(a)));
  return sorted;
}

String methodLabel(Recipe recipe) {
  switch (recipe.compatibilityType) {
    case RecipeCompatibilityType.fullAuto:
      return 'Full Auto';
    case RecipeCompatibilityType.guidedCook:
      return 'Guided Cook';
    case RecipeCompatibilityType.partialCook:
      return 'Guided Cook';
    case RecipeCompatibilityType.complexGuidedCook:
      return 'Professional';
    case RecipeCompatibilityType.manualOnly:
      return 'Quick Cook';
  }
}

Color methodBg(Recipe recipe) {
  switch (recipe.compatibilityType) {
    case RecipeCompatibilityType.fullAuto:
      return figmaBlueLight;
    case RecipeCompatibilityType.guidedCook:
      return figmaOrangeLight;
    case RecipeCompatibilityType.partialCook:
      return figmaOrangeLight;
    case RecipeCompatibilityType.complexGuidedCook:
      return figmaPurpleLight;
    case RecipeCompatibilityType.manualOnly:
      return figmaGreenLight;
  }
}

Color methodText(Recipe recipe) {
  switch (recipe.compatibilityType) {
    case RecipeCompatibilityType.fullAuto:
      return figmaBlue;
    case RecipeCompatibilityType.guidedCook:
      return figmaOrange;
    case RecipeCompatibilityType.partialCook:
      return figmaOrange;
    case RecipeCompatibilityType.complexGuidedCook:
      return figmaPurple;
    case RecipeCompatibilityType.manualOnly:
      return figmaGreen;
  }
}

class FigmaIconBox extends StatelessWidget {
  const FigmaIconBox({required this.icon, required this.onTap, super.key});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: figmaGray100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: figmaGray500),
      ),
    );
  }
}

class OfficialBadge extends StatelessWidget {
  const OfficialBadge({this.tiny = false, super.key});
  final bool tiny;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tiny ? 6 : 8, vertical: tiny ? 2 : 2),
      decoration: BoxDecoration(
        color: figmaOrangeLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: tiny ? 9 : 11, color: figmaOrange),
          const SizedBox(width: 2),
          Text(
            '공식',
            style: TextStyle(
              color: figmaOrange,
              fontSize: tiny ? 10 : 12,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class UserBadge extends StatelessWidget {
  const UserBadge({this.tiny = false, super.key});
  final bool tiny;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tiny ? 6 : 8, vertical: tiny ? 2 : 4),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '사용자',
        style: TextStyle(color: Colors.white, fontSize: tiny ? 10 : 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class MethodBadge extends StatelessWidget {
  const MethodBadge({required this.recipe, super.key});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: methodBg(recipe),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 9, color: methodText(recipe)),
          const SizedBox(width: 2),
          Text(
            methodLabel(recipe),
            style: TextStyle(color: methodText(recipe), fontSize: 11, fontWeight: FontWeight.w900, height: 1.0),
          ),
        ],
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({required this.rating, this.count, this.size = 12, this.light = false, super.key});
  final double rating;
  final int? count;
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size, color: figmaYellow),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: 12, color: light ? Colors.white : figmaGray900, fontWeight: FontWeight.w900),
        ),
        if (count != null) ...[
          const SizedBox(width: 2),
          Text('(${formatK(count!)})', style: const TextStyle(fontSize: 12, color: figmaGray400)),
        ],
      ],
    );
  }
}

class FigmaFilterChip extends StatelessWidget {
  const FigmaFilterChip({required this.label, required this.active, required this.onTap, super.key});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? figmaOrange : figmaGray100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: active ? Colors.white : figmaGray500),
        ),
      ),
    );
  }
}

class FigmaRecipeImage extends StatelessWidget {
  const FigmaRecipeImage({required this.source, this.width, this.height, super.key});
  final String? source;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return AppImage(
      source: source,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: Container(
        width: width,
        height: height,
        color: figmaGray100,
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant_rounded, color: figmaGray400),
      ),
    );
  }
}

class FigmaRecipeCard extends StatelessWidget {
  const FigmaRecipeCard({
    required this.recipe,
    required this.onTap,
    this.compact = false,
    this.onSave,
    super.key,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final bool compact;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    if (compact) return _compactCard();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: figmaGray100),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 176,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FigmaRecipeImage(source: recipe.thumbnailUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x66000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        recipe.isOfficial ? const OfficialBadge() : const UserBadge(),
                        const SizedBox(width: 6),
                        MethodBadge(recipe: recipe),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _BookmarkButton(saved: recipe.isSaved, onTap: onSave),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: figmaGray900, fontWeight: FontWeight.w900)),
                  if (!recipe.isOfficial) ...[
                    const SizedBox(height: 2),
                    Text('by ${recipe.author}', style: const TextStyle(fontSize: 12, color: figmaGray400)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Meta(icon: Icons.schedule_rounded, label: '${recipe.totalTimeMin}분'),
                      const SizedBox(width: 12),
                      _Meta(icon: Icons.restaurant_menu_rounded, label: recipe.difficulty),
                      const SizedBox(width: 12),
                      _Meta(icon: Icons.local_fire_department_rounded, label: formatK(recipeUses(recipe))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StarRow(rating: recipeRating(recipe), count: recipeReviews(recipe)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactCard() {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: figmaGray100),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 88,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FigmaRecipeImage(source: recipe.thumbnailUrl),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: recipe.isOfficial ? const OfficialBadge(tiny: true) : const UserBadge(tiny: true),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.15, color: figmaGray900, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 9, color: figmaGray400),
                      const SizedBox(width: 2),
                      Text('${recipe.totalTimeMin}분', style: const TextStyle(fontSize: 10, color: figmaGray400, fontWeight: FontWeight.w600, height: 1.0)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(methodLabel(recipe), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: methodText(recipe), fontWeight: FontWeight.w800, height: 1.0)),
                  const SizedBox(height: 2),
                  StarRow(rating: recipeRating(recipe), size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FigmaFeaturedRecipeCard extends StatelessWidget {
  const FigmaFeaturedRecipeCard({required this.recipe, required this.onTap, this.onSave, this.home = false, super.key});
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onSave;
  final bool home;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: figmaGray100),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: home ? 160 : 176,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FigmaRecipeImage(source: recipe.thumbnailUrl),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: home
                        ? const [Colors.transparent, Color(0x99000000)]
                        : const [Color(0x00000000), Color(0x22000000), Color(0xAA000000)],
                  ),
                ),
              ),
              if (!home) ...[
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(children: [recipe.isOfficial ? const OfficialBadge() : const UserBadge(), const SizedBox(width: 6), MethodBadge(recipe: recipe)]),
                ),
                Positioned(top: 12, right: 12, child: _BookmarkButton(saved: recipe.isSaved, onTap: onSave)),
              ],
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (home) ...[
                      Row(children: [recipe.isOfficial ? const OfficialBadge(tiny: true) : const UserBadge(tiny: true), const SizedBox(width: 6), MethodBadge(recipe: recipe)]),
                      const SizedBox(height: 6),
                    ],
                    Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: home ? 16 : 16, color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StarRow(rating: recipeRating(recipe), size: 11, light: true),
                        const SizedBox(width: 12),
                        _LightMeta(icon: Icons.schedule_rounded, label: '${recipe.totalTimeMin}분'),
                        const SizedBox(width: 12),
                        _LightMeta(icon: Icons.local_fire_department_rounded, label: formatK(recipeUses(recipe))),
                        if (!home) ...[
                          const SizedBox(width: 12),
                          Flexible(child: Text(recipe.difficulty, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.saved, this.onTap});
  final bool saved;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 17, color: Colors.white),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 11, color: figmaGray500), const SizedBox(width: 3), Text(label, style: const TextStyle(fontSize: 12, color: figmaGray500, fontWeight: FontWeight.w600))],
      );
}

class _LightMeta extends StatelessWidget {
  const _LightMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 10, color: Colors.white70), const SizedBox(width: 2), Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600))],
      );
}


class FigmaSectionHeader extends StatelessWidget {
  const FigmaSectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, color: figmaGray900, fontWeight: FontWeight.w900)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: figmaGray400)),
              ],
            ],
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(action!, style: const TextStyle(fontSize: 12, color: figmaOrange, fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}

class FigmaQuickBrowseCard extends StatelessWidget {
  const FigmaQuickBrowseCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: figmaGray100),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24, height: 1)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14, color: figmaGray900, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: figmaGray500)),
          ],
        ),
      ),
    );
  }
}

class FigmaHeader extends StatelessWidget {
  const FigmaHeader({required this.title, this.onBack, this.right, super.key});
  final String title;
  final VoidCallback? onBack;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (onBack != null) ...[
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox(width: 36, height: 36, child: Icon(Icons.arrow_back_rounded, size: 20, color: figmaGray500)),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, color: figmaGray900, fontWeight: FontWeight.w900))),
          if (right != null) right!,
        ],
      ),
    );
  }
}
