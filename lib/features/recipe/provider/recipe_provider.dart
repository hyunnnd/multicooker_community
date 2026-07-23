import 'package:flutter/foundation.dart';

import '../data/models/recipe.dart';
import '../data/models/recipe_compatibility_type.dart';
import '../data/models/recipe_step.dart';
import '../data/recipe_repository.dart';

class RecipeProvider extends ChangeNotifier {
  RecipeProvider(this.repository);

  final RecipeRepository repository;

  /// Public/catalog recipes and current-user recipes are stored separately.
  /// Ownership is determined only by the authenticated `/users/me/recipes`
  /// response, never by `isOfficial` or another display flag.
  List<Recipe> _catalogRecipes = const [];
  List<Recipe> _myRecipes = const [];

  Recipe? selectedRecipe;
  Recipe? lastUploadedRecipe;
  RecipeCompatibilityType? selectedCompatibilityFilter;
  String searchQuery = '';
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  int _accountGeneration = 0;

  List<Recipe> get personalRecipes =>
      List<Recipe>.unmodifiable(_myRecipes);

  List<Recipe> get recipes {
    final query = searchQuery.trim().toLowerCase();
    return _combinedRecipes
        .where((recipe) {
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
  }

  List<Recipe> get _combinedRecipes {
    final byId = <String, Recipe>{};
    for (final recipe in _catalogRecipes) {
      byId[recipe.id] = recipe;
    }
    // Current-user recipes win if an id ever collides with catalog data.
    for (final recipe in _myRecipes) {
      byId[recipe.id] = recipe;
    }
    return byId.values.toList(growable: false);
  }

  /// Loads the catalog, current user's recipes, and saved-state snapshot.
  Future<void> loadRecipes() async {
    final generation = _accountGeneration;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final catalog = await repository.getRecipes();
      var mine = <Recipe>[];
      var savedIds = <String>{};
      final errors = <String>[];

      try {
        mine = await repository.getMyRecipes();
      } catch (error) {
        errors.add('내가 올린 레시피: $error');
      }

      try {
        savedIds = await repository.getSavedRecipeIds();
      } catch (error) {
        errors.add('저장 상태: $error');
      }

      if (generation != _accountGeneration) return;
      _catalogRecipes = _applySavedState(catalog, savedIds);
      _myRecipes = _applySavedState(mine, savedIds);
      errorMessage = errors.isEmpty
          ? null
          : '일부 레시피 데이터를 불러오지 못했습니다: ${errors.join(' / ')}';
      _refreshSelectedRecipe();
    } catch (error) {
      if (generation == _accountGeneration) {
        errorMessage = '레시피를 불러오지 못했습니다: $error';
      }
    } finally {
      if (generation == _accountGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Loads only the current user's `/users/me/recipes` list.
  ///
  /// This is the sole data source for the "내가 올린 레시피" screen.
  Future<void> loadMyRecipes() async {
    final generation = _accountGeneration;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final mine = await repository.getMyRecipes();
      var savedIds = <String>{};
      try {
        savedIds = await repository.getSavedRecipeIds();
      } catch (_) {
        // The ownership list is still valid even if saved-state loading fails.
      }
      if (generation != _accountGeneration) return;
      _myRecipes = _applySavedState(mine, savedIds);
      _refreshSelectedRecipe();
    } catch (error) {
      if (generation == _accountGeneration) {
        errorMessage = '내가 올린 레시피를 불러오지 못했습니다: $error';
      }
    } finally {
      if (generation == _accountGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Clears all account-scoped data when the authenticated email changes.
  void resetForAccountChange() {
    _accountGeneration += 1;
    _myRecipes = const [];
    _catalogRecipes = _catalogRecipes
        .map((recipe) => recipe.copyWith(isSaved: false))
        .toList(growable: false);
    selectedRecipe = null;
    lastUploadedRecipe = null;
    selectedCompatibilityFilter = null;
    searchQuery = '';
    isLoading = false;
    isSaving = false;
    errorMessage = null;
    notifyListeners();
  }

  /// Ensures a recipe is available for the detail route.
  Future<bool> ensureRecipeLoaded(String recipeId) async {
    if (recipeById(recipeId) != null) return true;
    await loadMyRecipes();
    if (recipeById(recipeId) != null) return true;
    await loadRecipes();
    return recipeById(recipeId) != null;
  }

  Future<bool> uploadRecipe({
    required String title,
    String? description,
    required List<RecipeStep> steps,
  }) async {
    final generation = _accountGeneration;
    isLoading = true;
    errorMessage = null;
    lastUploadedRecipe = null;
    notifyListeners();

    try {
      final created = await repository.uploadRecipe(
        title: title,
        description: description,
        steps: steps,
      );
      if (generation != _accountGeneration) return false;

      if (created != null) {
        lastUploadedRecipe = created;
        _myRecipes = [
          created,
          ..._myRecipes.where((recipe) => recipe.id != created.id),
        ];
      } else {
        final mine = await repository.getMyRecipes();
        if (generation != _accountGeneration) return false;
        _myRecipes = mine;
        lastUploadedRecipe = _myRecipes.isEmpty ? null : _myRecipes.first;
      }
      _refreshSelectedRecipe();
      return true;
    } catch (error) {
      if (generation == _accountGeneration) {
        errorMessage = '개인 레시피 DB에 저장하지 못했습니다: $error';
      }
      return false;
    } finally {
      if (generation == _accountGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateMyRecipe({
    required String recipeId,
    required String title,
    String? description,
    required List<RecipeStep> steps,
  }) async {
    if (isSaving) return false;
    final generation = _accountGeneration;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final updated = await repository.updateMyRecipe(
        recipeId: recipeId,
        title: title,
        description: description,
        steps: steps,
      );
      if (generation != _accountGeneration) return false;
      _myRecipes = _myRecipes
          .map((recipe) => recipe.id == recipeId ? updated : recipe)
          .toList(growable: false);
      selectedRecipe = selectedRecipe?.id == recipeId
          ? updated
          : selectedRecipe;
      lastUploadedRecipe = updated;
      return true;
    } catch (error) {
      if (generation == _accountGeneration) {
        errorMessage = '내 레시피를 수정하지 못했습니다: $error';
      }
      return false;
    } finally {
      if (generation == _accountGeneration) {
        isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> setMyRecipeVisibility(
    String recipeId,
    String visibility,
  ) async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final updated = await repository.updateMyRecipeVisibility(
        recipeId: recipeId,
        visibility: visibility,
      );
      _myRecipes = _myRecipes
          .map((recipe) => recipe.id == recipeId ? updated : recipe)
          .toList(growable: false);
      _catalogRecipes = updated.isPublic
          ? [
              updated,
              ..._catalogRecipes.where((recipe) => recipe.id != recipeId),
            ]
          : _catalogRecipes
              .where((recipe) => recipe.id != recipeId)
              .toList(growable: false);
      if (selectedRecipe?.id == recipeId) selectedRecipe = updated;
      if (lastUploadedRecipe?.id == recipeId) lastUploadedRecipe = updated;
      return true;
    } catch (error) {
      errorMessage = '레시피 공개 범위를 변경하지 못했습니다: $error';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMyRecipe(String recipeId) async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.deleteMyRecipe(recipeId);
      _myRecipes = _myRecipes
          .where((recipe) => recipe.id != recipeId)
          .toList(growable: false);
      if (selectedRecipe?.id == recipeId) selectedRecipe = null;
      if (lastUploadedRecipe?.id == recipeId) lastUploadedRecipe = null;
      return true;
    } catch (error) {
      errorMessage = '내 레시피를 삭제하지 못했습니다: $error';
      return false;
    } finally {
      isSaving = false;
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
      _catalogRecipes = _applySavedState(_catalogRecipes, savedIds);
      _myRecipes = _applySavedState(_myRecipes, savedIds);
      _refreshSelectedRecipe();
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
    for (final recipe in _myRecipes) {
      if (recipe.id == id) return recipe;
    }
    for (final recipe in _catalogRecipes) {
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

  List<Recipe> _applySavedState(List<Recipe> source, Set<String> savedIds) {
    return source
        .map(
          (recipe) => recipe.copyWith(isSaved: savedIds.contains(recipe.id)),
        )
        .toList(growable: false);
  }

  void _refreshSelectedRecipe() {
    if (selectedRecipe != null) {
      selectedRecipe = recipeById(selectedRecipe!.id);
    }
  }

  void _replaceRecipe(
    String id,
    Recipe Function(Recipe recipe) update, {
    bool notify = true,
  }) {
    _catalogRecipes = _catalogRecipes
        .map((recipe) => recipe.id == id ? update(recipe) : recipe)
        .toList(growable: false);
    _myRecipes = _myRecipes
        .map((recipe) => recipe.id == id ? update(recipe) : recipe)
        .toList(growable: false);
    if (selectedRecipe?.id == id) selectedRecipe = recipeById(id);
    if (lastUploadedRecipe?.id == id) lastUploadedRecipe = recipeById(id);
    if (notify) notifyListeners();
  }
}
