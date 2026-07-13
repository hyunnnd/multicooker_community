import 'package:flutter/foundation.dart';

import '../data/models/recipe.dart';
import '../data/models/recipe_compatibility_type.dart';
import '../data/models/recipe_step.dart';
import '../data/recipe_repository.dart';

class RecipeProvider extends ChangeNotifier {
  RecipeProvider(this.repository);

  final RecipeRepository repository;
  List<Recipe> _allRecipes = const [];
  Recipe? selectedRecipe;
  RecipeCompatibilityType? selectedCompatibilityFilter;
  String searchQuery = '';
  bool isLoading = false;
  bool isSaving = false;
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

  Future<void> loadRecipes() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final officialRecipes = await repository.getRecipes();
      var sharedRecipes = <Recipe>[];
      try {
        sharedRecipes = await repository.getSharedRecipes();
      } catch (error) {
        errorMessage = '회사 서버의 개인 레시피를 불러오지 못했습니다: $error';
      }
      var savedIds = <String>{};
      try {
        savedIds = await repository.getSavedRecipeIds();
      } catch (error) {
        errorMessage ??= '저장한 레시피 상태를 불러오지 못했습니다: $error';
      }
      _allRecipes = [
        ...officialRecipes,
        ...sharedRecipes,
      ]
          .map(
            (recipe) => recipe.copyWith(
              isSaved: savedIds.contains(recipe.id),
            ),
          )
          .toList(growable: false);
      if (selectedRecipe != null) {
        selectedRecipe = recipeById(selectedRecipe!.id);
      }
    } catch (error) {
      errorMessage = '레시피를 불러오지 못했습니다: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadRecipe({
    required String title,
    String? description,
    required List<RecipeStep> steps,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.uploadRecipe(
        title: title,
        description: description,
        steps: steps,
      );
      await loadRecipes();
      return true;
    } catch (error) {
      errorMessage = '회사 레시피 DB에 저장하지 못했습니다: $error';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleSaved(String recipeId) async {
    final recipe = recipeById(recipeId);
    if (recipe == null || isSaving) return false;
    final nextValue = !recipe.isSaved;
    isSaving = true;
    errorMessage = null;
    _replaceRecipe(
      recipeId,
      (current) => current.copyWith(isSaved: nextValue),
      notify: false,
    );
    notifyListeners();
    try {
      if (nextValue) {
        await repository.saveRecipe(recipe);
      } else {
        await repository.unsaveRecipe(recipeId);
      }
      return true;
    } catch (error) {
      _replaceRecipe(
        recipeId,
        (current) => current.copyWith(isSaved: !nextValue),
        notify: false,
      );
      errorMessage = nextValue
          ? '레시피 저장에 실패했습니다: $error'
          : '레시피 저장 해제에 실패했습니다: $error';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> refreshSavedState() async {
    try {
      final savedIds = await repository.getSavedRecipeIds();
      _allRecipes = _allRecipes
          .map(
            (recipe) => recipe.copyWith(
              isSaved: savedIds.contains(recipe.id),
            ),
          )
          .toList(growable: false);
      if (selectedRecipe != null) {
        selectedRecipe = recipeById(selectedRecipe!.id);
      }
      notifyListeners();
    } catch (error) {
      errorMessage = '저장 상태를 새로고침하지 못했습니다: $error';
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

  void _replaceRecipe(
    String id,
    Recipe Function(Recipe recipe) update, {
    bool notify = true,
  }) {
    _allRecipes = _allRecipes
        .map((recipe) => recipe.id == id ? update(recipe) : recipe)
        .toList(growable: false);
    if (selectedRecipe?.id == id) selectedRecipe = recipeById(id);
    if (notify) notifyListeners();
  }
}
