import 'models/recipe.dart';
import 'recipe_mock_data.dart';
import 'recipe_repository.dart';

class MockRecipeRepository extends RecipeRepository {
  @override
  Future<List<Recipe>> getRecipes() async => RecipeMockData.recipes;
}
