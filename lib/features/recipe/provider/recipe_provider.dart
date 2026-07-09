import 'package:flutter/foundation.dart';

import '../data/models/recipe.dart';
import '../data/models/recipe_compatibility_type.dart';
import '../data/recipe_repository.dart';

class RecipeProvider extends ChangeNotifier {
  RecipeProvider(this.repository);

  final RecipeRepository repository;
  List<Recipe> _allRecipes = const [];
  Recipe? selectedRecipe;
  RecipeCompatibilityType? selectedCompatibilityFilter;
  String searchQuery = '';
  bool isLoading = false;
  String? errorMessage;

  List<Recipe> get recipes => _allRecipes
      .where((recipe) {
        final query = searchQuery.trim().toLowerCase();
        final matchesQuery =
            query.isEmpty ||
            recipe.title.toLowerCase().contains(query) ||
            recipe.description.toLowerCase().contains(query);
        final matchesFilter =
            selectedCompatibilityFilter == null ||
            recipe.compatibilityType == selectedCompatibilityFilter;
        return matchesQuery && matchesFilter;
      })
      .toList(growable: false);

  Future<void> loadMockRecipes() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _allRecipes = await repository.getRecipes();
    } catch (error) {
      errorMessage = '레시피를 불러오지 못했습니다: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void searchRecipes(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void filterByCompatibility(RecipeCompatibilityType? type) {
    selectedCompatibilityFilter = type;
    notifyListeners();
  }

  Recipe? recipeById(String id) {
    for (final recipe in _allRecipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  void selectRecipe(String recipeId) {
    selectedRecipe = recipeById(recipeId);
    notifyListeners();
  }

  void toggleIngredientPrepared(String recipeId, String ingredientName) {
    _replaceRecipe(recipeId, (recipe) {
      final ingredients = recipe.ingredients
          .map(
            (ingredient) => ingredient.name == ingredientName
                ? ingredient.copyWith(isPrepared: !ingredient.isPrepared)
                : ingredient,
          )
          .toList(growable: false);
      return recipe.copyWith(ingredients: ingredients);
    });
  }

  void toggleSaved(String recipeId) {
    _replaceRecipe(
      recipeId,
      (recipe) => recipe.copyWith(isSaved: !recipe.isSaved),
    );
  }

  void _replaceRecipe(String id, Recipe Function(Recipe recipe) update) {
    _allRecipes = _allRecipes
        .map((recipe) => recipe.id == id ? update(recipe) : recipe)
        .toList(growable: false);
    if (selectedRecipe?.id == id) selectedRecipe = recipeById(id);
    notifyListeners();
  }
}
