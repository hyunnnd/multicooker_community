import 'models/recipe.dart';
import 'models/recipe_step.dart';

abstract class RecipeRepository {
  /// Public/catalog recipes shown in the main recipe area.
  Future<List<Recipe>> getRecipes();

  /// Recipes owned by the currently authenticated personal-API user.
  ///
  /// The server endpoint must scope the result with the bearer token. The app
  /// must display this response directly and must not infer ownership from
  /// fields such as `isOfficial`.
  Future<List<Recipe>> getMyRecipes() async => const [];

  /// Uploads a recipe for the current personal-API user.
  ///
  /// Returns the newly created recipe when the API includes it in the response.
  Future<Recipe?> uploadRecipe({
    required String title,
    String? description,
    required List<RecipeStep> steps,
  }) => throw UnimplementedError('레시피 업로드를 지원하지 않습니다.');

  Future<Recipe> updateMyRecipe({
    required String recipeId,
    required String title,
    String? description,
    required List<RecipeStep> steps,
  }) => throw UnimplementedError('내 레시피 수정을 지원하지 않습니다.');

  Future<Recipe> updateMyRecipeVisibility({
    required String recipeId,
    required String visibility,
  }) => throw UnimplementedError('레시피 공개 범위 변경을 지원하지 않습니다.');

  Future<void> deleteMyRecipe(String recipeId) =>
      throw UnimplementedError('내 레시피 삭제를 지원하지 않습니다.');

  Future<Set<String>> getSavedRecipeIds() async => const <String>{};

  Future<void> saveRecipe(Recipe recipe) =>
      throw UnimplementedError('레시피 저장을 지원하지 않습니다.');

  Future<void> unsaveRecipe(String recipeId) =>
      throw UnimplementedError('레시피 저장 해제를 지원하지 않습니다.');
}
