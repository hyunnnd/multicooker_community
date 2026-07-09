import 'package:flutter/material.dart';

import '../../data/models/recipe.dart';
import 'figma_recipe_widgets.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({required this.recipe, required this.onTap, super.key});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FigmaRecipeCard(recipe: recipe, onTap: onTap);
  }
}
