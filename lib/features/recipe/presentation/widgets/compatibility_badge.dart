import 'package:flutter/material.dart';

import '../../data/models/recipe_compatibility_type.dart';

class CompatibilityBadge extends StatelessWidget {
  const CompatibilityBadge({required this.type, super.key});

  final RecipeCompatibilityType type;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (type) {
      RecipeCompatibilityType.fullAuto => (
        const Color(0xFFEAF2FF),
        const Color(0xFF3378C0),
      ),
      RecipeCompatibilityType.guidedCook => (
        const Color(0xFFFFF7D6),
        const Color(0xFFA16207),
      ),
      RecipeCompatibilityType.complexGuidedCook => (
        const Color(0xFFFFEDD5),
        const Color(0xFFC2410C),
      ),
      RecipeCompatibilityType.partialCook => (
        const Color(0xFFF3E8FF),
        const Color(0xFF7E22CE),
      ),
      RecipeCompatibilityType.manualOnly => (
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          type.label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
