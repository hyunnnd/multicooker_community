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
    this.visibility = 'public',
    this.author = 'Graphene Square',
    this.ratingAverage = 0,
    this.reviewCount = 0,
    this.usageCount = 0,
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

  /// `public`이면 다른 사용자에게 공개되고, `private`이면 작성자만 볼 수 있습니다.
  final String visibility;
  final String author;

  /// 실제 개인 API DB의 레시피 후기에서 계산된 평균 별점입니다.
  final double ratingAverage;

  /// 실제 개인 API DB에 저장된 해당 레시피 후기 개수입니다.
  final int reviewCount;

  /// 실제 개인 API DB의 완료된 조리 이력 개수입니다.
  final int usageCount;

  bool get isPublic => isOfficial || visibility == 'public';
  String get visibilityLabel => isPublic ? '공개' : '비공개';
  String get compatibilityLabel => compatibilityType.label;
  bool get supportsCooker =>
      compatibilityType != RecipeCompatibilityType.manualOnly;

  Recipe copyWith({
    List<RecipeIngredient>? ingredients,
    bool? isSaved,
    String? visibility,
    double? ratingAverage,
    int? reviewCount,
    int? usageCount,
  }) =>
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
        visibility: visibility ?? this.visibility,
        author: author,
        ratingAverage: ratingAverage ?? this.ratingAverage,
        reviewCount: reviewCount ?? this.reviewCount,
        usageCount: usageCount ?? this.usageCount,
      );
}
