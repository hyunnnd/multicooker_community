import 'package:dio/dio.dart';

import 'models/cooker_step.dart';
import 'models/recipe.dart';
import 'models/recipe_compatibility_type.dart';
import 'models/recipe_ingredient.dart';
import 'models/recipe_instruction_step.dart';
import 'models/recipe_step.dart';
import 'recipe_identity.dart';
import 'recipe_repository.dart';

class ApiRecipeRepository extends RecipeRepository {
  ApiRecipeRepository(
    this._companyDio,
    this._localDio,
    this._officialRepository,
  );

  final Dio _companyDio;
  final Dio _localDio;
  final RecipeRepository _officialRepository;

  @override
  Future<List<Recipe>> getRecipes() => _officialRepository.getRecipes();

  @override
  Future<List<Recipe>> getSharedRecipes() async {
    final response = await _companyDio.get<Object>(
      '/recipe/personal_recipes/100',
    );
    final recipes = recipeMapsFromResponse(response.data);
    return [
      for (var index = 0; index < recipes.length; index++)
        _fromCompanyApi(recipes[index], index),
    ];
  }

  @override
  Future<void> uploadRecipe({
    required String title,
    String? description,
    required List<RecipeStep> steps,
  }) async {
    await _companyDio.post<Object>(
      '/recipe/upload',
      data: {
        'title': title,
        if (description?.trim().isNotEmpty ?? false)
          'description': description,
        'steps': steps.map((step) => step.toJson()).toList(growable: false),
      },
    );
  }

  @override
  Future<Set<String>> getSavedRecipeIds() async {
    final response = await _localDio.get<Map<String, dynamic>>(
      '/users/me/saved-recipes',
    );
    final raw = response.data?['recipes'];
    if (raw is! List) return const <String>{};
    return raw
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return (map['client_id'] ?? map['id'] ?? '').toString();
        })
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    var elapsedSeconds = 0;
    final steps = <Map<String, dynamic>>[];
    for (final step in recipe.cookerSteps) {
      elapsedSeconds += step.timeMin * 60;
      steps.add({
        'temperature': step.temperature,
        'time_offset': elapsedSeconds,
        'label': step.label,
      });
    }
    await _localDio.post<Object>(
      '/users/me/saved-recipes/by-client-id',
      data: {
        'client_id': recipe.id,
        'title': recipe.title,
        'description': recipe.description,
        'thumbnail_url': recipe.thumbnailUrl,
        'author': recipe.author,
        'is_official': recipe.isOfficial,
        'is_personal': !recipe.isOfficial,
        'total_time_min': recipe.totalTimeMin,
        'max_temperature': recipe.cookerSteps.isEmpty
            ? 0
            : recipe.cookerSteps
                .map((step) => step.temperature)
                .reduce((a, b) => a > b ? a : b),
        'steps': steps,
      },
    );
  }

  @override
  Future<void> unsaveRecipe(String recipeId) async {
    await _localDio.delete<Object>(
      '/users/me/saved-recipes/by-client-id/${Uri.encodeComponent(recipeId)}',
    );
  }

  Recipe _fromCompanyApi(Map<String, dynamic> json, int index) {
    final rawSteps = recipeStepsFromJson(json);
    final steps = rawSteps
        .map(
          (step) => RecipeStep(
            temperature: numberAsDouble(
              step['temperature'] ?? step['temp'],
              fallback: 180,
            ),
            timeOffset: numberAsDouble(
              step['time_offset'] ?? step['timeOffset'] ?? step['seconds'],
            ),
          ),
        )
        .toList(growable: false);

    final cookerSteps = <CookerStep>[];
    for (var stepIndex = 0; stepIndex < steps.length; stepIndex++) {
      cookerSteps.add(
        CookerStep(
          id: '${companyRecipeClientId(json, index)}-c$stepIndex',
          stepNo: stepIndex + 1,
          label: (rawSteps[stepIndex]['label'] ?? '${stepIndex + 1}단계 조리')
              .toString(),
          temperature: steps[stepIndex].temperature.round(),
          timeMin: _stepMinutes(steps, stepIndex),
        ),
      );
    }

    final rawDescription =
        (json['description'] ?? '사용자가 공유한 멀티쿠커 레시피입니다.')
            .toString();
    final instructionTexts = _instructionTexts(rawDescription);
    final totalMinutes = cookerSteps.fold<int>(
      0,
      (sum, step) => sum + step.timeMin,
    );
    final id = companyRecipeClientId(json, index);
    final title = (json['title'] ?? json['name'] ?? '사용자 레시피').toString();

    return Recipe(
      id: id,
      title: title,
      description: _visibleDescription(rawDescription),
      thumbnailUrl: _nullableString(
        json['thumbnail_url'] ?? json['image_url'] ?? json['image'],
      ),
      totalTimeMin: totalMinutes <= 0 ? 10 : totalMinutes,
      difficulty: (json['difficulty'] ?? '보통').toString(),
      servings: numberAsInt(json['servings'], fallback: 1).clamp(1, 99).toInt(),
      compatibilityType: RecipeCompatibilityType.fullAuto,
      ingredients: _ingredientsFromDescription(rawDescription),
      instructionSteps: [
        for (var stepIndex = 0; stepIndex < cookerSteps.length; stepIndex++)
          RecipeInstructionStep(
            id: '$id-i$stepIndex',
            stepNo: stepIndex + 1,
            title:
                instructionTexts[stepIndex]?.$1 ?? cookerSteps[stepIndex].label,
            description:
                instructionTexts[stepIndex]?.$2 ??
                '${cookerSteps[stepIndex].temperature}°C에서 ${cookerSteps[stepIndex].timeMin}분 조리합니다.',
            linkedCookerStepId: cookerSteps[stepIndex].id,
          ),
      ],
      cookerSteps: cookerSteps,
      author: (json['author'] ?? json['nickname'] ?? '나의 레시피').toString(),
    );
  }

  int _stepMinutes(List<RecipeStep> steps, int index) {
    if (steps.isEmpty) return 1;
    final current = steps[index].timeOffset;
    final previous = index == 0 ? 0 : steps[index - 1].timeOffset;
    var seconds = current - previous;
    if (seconds <= 0 && index + 1 < steps.length) {
      seconds = steps[index + 1].timeOffset - current;
    }
    if (seconds <= 0) seconds = 300;
    return (seconds / 60).ceil().clamp(1, 999).toInt();
  }

  String _visibleDescription(String description) {
    final markers = [
      description.indexOf('\n\n재료\n'),
      description.indexOf('\n\n조리 단계\n'),
    ].where((index) => index != -1).toList();
    if (markers.isEmpty) return description;
    markers.sort();
    return description.substring(0, markers.first);
  }

  List<RecipeIngredient> _ingredientsFromDescription(String description) {
    final marker = description.indexOf('\n\n재료\n');
    if (marker == -1) return const [];
    final section = description.substring(marker + '\n\n재료\n'.length);
    final end = section.indexOf('\n\n조리 단계\n');
    final ingredientText = end == -1 ? section : section.substring(0, end);
    return ingredientText
        .split('\n')
        .where((line) => line.trim().startsWith('- '))
        .map((line) {
          final value = line.trim().substring(2).trim();
          final parts = value.split(RegExp(r'\s+'));
          return RecipeIngredient(
            name: parts.first,
            amount: parts.length > 1 ? parts.skip(1).join(' ') : '',
          );
        })
        .toList(growable: false);
  }

  Map<int, (String, String)> _instructionTexts(String description) {
    final marker = description.indexOf('\n\n조리 단계\n');
    if (marker == -1) return const {};
    final lines = description
        .substring(marker + '\n\n조리 단계\n'.length)
        .split('\n');
    final result = <int, (String, String)>{};
    for (var i = 0; i < lines.length; i += 2) {
      final match = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(lines[i].trim());
      if (match == null) continue;
      final stepIndex = int.parse(match.group(1)!) - 1;
      final title = match.group(2)!.trim();
      final body = i + 1 < lines.length ? lines[i + 1].trim() : '';
      result[stepIndex] = (
        title.isEmpty ? '${stepIndex + 1}단계 조리' : title,
        body,
      );
    }
    return result;
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
