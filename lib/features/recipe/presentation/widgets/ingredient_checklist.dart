import 'package:flutter/material.dart';

import '../../data/models/recipe_ingredient.dart';

class IngredientChecklist extends StatelessWidget {
  const IngredientChecklist({
    required this.ingredients,
    required this.onChanged,
    super.key,
  });

  final List<RecipeIngredient> ingredients;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(20),
    itemCount: ingredients.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final ingredient = ingredients[index];
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: ingredient.isPrepared,
        onChanged: (_) => onChanged(ingredient.name),
        title: Text(ingredient.name),
        subtitle: ingredient.isRequired ? null : const Text('선택 재료'),
        secondary: Text(
          ingredient.amount,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    },
  );
}
