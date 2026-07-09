import 'package:dio/dio.dart';

import 'models/cooker_step.dart';
import 'models/recipe.dart';
import 'models/recipe_compatibility_type.dart';
import 'models/recipe_ingredient.dart';
import 'models/recipe_instruction_step.dart';
import 'recipe_mock_data.dart';
import 'recipe_repository.dart';
import 'recipe_image_assets.dart';

class ApiRecipeRepository implements RecipeRepository {
  ApiRecipeRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Recipe>> getRecipes() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/recipe/gsq_suggest_recipes/50',
      );
      final items = response.data?['recipes'] as List<dynamic>? ?? const [];
      final recipes = items
          .map((item) => _recipeFromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
      if (recipes.isNotEmpty) return _mergeWithFigmaDefaults(recipes);
    } catch (_) {
      // 로컬 서버가 꺼져 있거나 API가 없으면 앱 화면 확인을 위해 mock으로 fallback합니다.
    }
    return RecipeMockData.recipes;
  }


  List<Recipe> _mergeWithFigmaDefaults(List<Recipe> serverRecipes) {
    final result = <Recipe>[...RecipeMockData.recipes];
    final seen = result.map((recipe) => recipe.title.replaceAll(' ', '').toLowerCase()).toSet();
    for (final recipe in serverRecipes) {
      final key = recipe.title.replaceAll(' ', '').toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      result.add(recipe);
      seen.add(key);
    }
    return result;
  }

  Recipe _recipeFromJson(Map<String, dynamic> json) {
    final rawSteps = ((json['steps'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    final cookerSteps = _toCookerSteps('${json['id'] ?? json['title']}', rawSteps);
    final totalTime = cookerSteps.fold<int>(0, (sum, step) => sum + step.timeMin);

    return Recipe(
      id: '${json['id'] ?? json['title']}',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: RecipeImageAssets.resolve(json['title'] as String? ?? '', json['thumbnail_url'] as String?),
      totalTimeMin: totalTime == 0 ? 10 : totalTime,
      difficulty: _difficultyFromTitle(json['title'] as String? ?? ''),
      servings: 2,
      compatibilityType: _compatibilityFromTitle(json['title'] as String? ?? ''),
      isOfficial: json['is_official'] as bool? ?? json['is_gsq_suggested'] as bool? ?? false,
      author: json['author'] as String? ?? 'Graphene Square',
      ingredients: const [RecipeIngredient(name: '레시피 재료', amount: '상세 참고')],
      instructionSteps: cookerSteps
          .map(
            (step) => RecipeInstructionStep(
              id: '${step.id}-instruction',
              stepNo: step.stepNo,
              title: step.label,
              description: '${step.temperature}℃로 ${step.timeMin}분 조리합니다.',
              linkedCookerStepId: step.id,
              estimatedTimeMin: step.timeMin,
            ),
          )
          .toList(growable: false),
      cookerSteps: cookerSteps,
    );
  }

  RecipeCompatibilityType _compatibilityFromTitle(String title) {
    final value = title.replaceAll(' ', '').toLowerCase();
    if (value.contains('계란') || value.contains('솥밥') || value == '밥') return RecipeCompatibilityType.fullAuto;
    if (value.contains('10분') || value.contains('quick')) return RecipeCompatibilityType.manualOnly;
    if (value.contains('닭갈비') || value.contains('리조또')) return RecipeCompatibilityType.complexGuidedCook;
    return RecipeCompatibilityType.guidedCook;
  }

  String _difficultyFromTitle(String title) {
    final value = title.replaceAll(' ', '').toLowerCase();
    if (value.contains('스테이크') || value.contains('닭갈비') || value.contains('리조또')) return '보통';
    return '쉬움';
  }

  List<CookerStep> _toCookerSteps(String recipeId, List<Map<String, dynamic>> rawSteps) {
    if (rawSteps.isEmpty) {
      return [
        CookerStep(
          id: '$recipeId-c1',
          stepNo: 1,
          label: '조리',
          temperature: 180,
          timeMin: 10,
        ),
      ];
    }

    final offsets = rawSteps
        .map((step) => (step['time_offset'] as num?)?.toDouble() ?? 0)
        .toList(growable: false);

    return List.generate(rawSteps.length, (index) {
      final currentOffset = offsets[index];
      final nextOffset = index + 1 < offsets.length ? offsets[index + 1] : null;
      final durationSeconds = nextOffset != null
          ? nextOffset - currentOffset
          : (currentOffset <= 0 ? 600.0 : 300.0);
      final timeMin = (durationSeconds / 60).round().clamp(1, 999);
      final temperature = ((rawSteps[index]['temperature'] as num?)?.round() ?? 180)
          .clamp(0, 300);
      return CookerStep(
        id: '$recipeId-c${index + 1}',
        stepNo: index + 1,
        label: 'Step ${index + 1}',
        temperature: temperature,
        timeMin: timeMin,
      );
    });
  }
}
