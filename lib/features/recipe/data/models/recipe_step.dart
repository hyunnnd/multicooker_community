class RecipeStep {
  const RecipeStep({required this.temperature, required this.timeOffset});

  final double temperature;
  final double timeOffset;

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      temperature: (json['temperature'] as num).toDouble(),
      timeOffset: (json['time_offset'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'time_offset': timeOffset,
  };
}
