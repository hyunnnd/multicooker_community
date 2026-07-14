import 'cooker_step.dart';
import 'recipe_compatibility_type.dart';
import 'recipe_ingredient.dart';
import 'recipe_instruction_step.dart';

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.totalTimeMin,
    required this.difficulty,
    required this.servings,
    required this.compatibilityType,
    required this.ingredients,
    required this.instructionSteps,
    required this.cookerSteps,
    this.thumbnailUrl,
    this.isSaved = false,
    this.isOfficial = false,
    this.author = 'Graphene Square',
  });

  final String id;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final int totalTimeMin;
  final String difficulty;
  final int servings;
  final RecipeCompatibilityType compatibilityType;
  final List<RecipeIngredient> ingredients;
  final List<RecipeInstructionStep> instructionSteps;
  final List<CookerStep> cookerSteps;
  final bool isSaved;
  final bool isOfficial;

  final String author;

  String get compatibilityLabel => compatibilityType.label;
  bool get supportsCooker =>
      compatibilityType != RecipeCompatibilityType.manualOnly;

  Recipe copyWith({List<RecipeIngredient>? ingredients, bool? isSaved}) =>
      Recipe(
        id: id,
        title: title,
        description: description,
        thumbnailUrl: thumbnailUrl,
        totalTimeMin: totalTimeMin,
        difficulty: difficulty,
        servings: servings,
        compatibilityType: compatibilityType,
        ingredients: ingredients ?? this.ingredients,
        instructionSteps: instructionSteps,
        cookerSteps: cookerSteps,
        isSaved: isSaved ?? this.isSaved,
        isOfficial: isOfficial,
        author: author,
      );
}
