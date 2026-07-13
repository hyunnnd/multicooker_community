import 'models/recipe.dart';
import 'models/recipe_step.dart';

abstract class RecipeRepository {
  Future<List<Recipe>> getRecipes();

  Future<List<Recipe>> getSharedRecipes() async => const [];

  Future<void> uploadRecipe({
    required String title,
    String? description,
    required List<RecipeStep> steps,
  }) => throw UnimplementedError('레시피 업로드를 지원하지 않습니다.');

  Future<Set<String>> getSavedRecipeIds() async => const <String>{};

  Future<void> saveRecipe(Recipe recipe) =>
      throw UnimplementedError('레시피 저장을 지원하지 않습니다.');

  Future<void> unsaveRecipe(String recipeId) =>
      throw UnimplementedError('레시피 저장 해제를 지원하지 않습니다.');
}
