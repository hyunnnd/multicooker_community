class AiRecommendResult {
  const AiRecommendResult({
    required this.photoUrl,
    required this.ingredients,
    required this.recipes,
  });

  factory AiRecommendResult.fromJson(Map<String, dynamic> json) =>
      AiRecommendResult(
        photoUrl: json['photo_url'] as String?,
        ingredients: ((json['ingredients'] as List?) ?? const [])
            .map(
              (item) =>
                  AiIngredient.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(growable: false),
        recipes: ((json['recipes'] as List?) ?? const [])
            .map(
              (item) => AiRecommendedRecipe.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );

  final String? photoUrl;
  final List<AiIngredient> ingredients;
  final List<AiRecommendedRecipe> recipes;
}

class AiIngredient {
  const AiIngredient({required this.name, required this.confidence});

  factory AiIngredient.fromJson(Map<String, dynamic> json) => AiIngredient(
    name: json['name'] as String? ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
  );

  final String name;
  final double confidence;
}

class AiRecommendedRecipe {
  const AiRecommendedRecipe({
    required this.title,
    required this.description,
    required this.similarity,
    required this.steps,
  });

  factory AiRecommendedRecipe.fromJson(Map<String, dynamic> json) =>
      AiRecommendedRecipe(
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
        steps: ((json['steps'] as List?) ?? const [])
            .map(
              (item) =>
                  AiRecipeStep.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(growable: false),
      );

  final String title;
  final String description;
  final double similarity;
  final List<AiRecipeStep> steps;
}

class AiRecipeStep {
  const AiRecipeStep({required this.temperature, required this.timeOffset});

  factory AiRecipeStep.fromJson(Map<String, dynamic> json) => AiRecipeStep(
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
    timeOffset: (json['time_offset'] as num?)?.toDouble() ?? 0,
  );

  final double temperature;
  final double timeOffset;
}
