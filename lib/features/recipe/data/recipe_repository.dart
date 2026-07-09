import 'models/recipe.dart';

abstract class RecipeRepository {
  Future<List<Recipe>> getRecipes();
}
