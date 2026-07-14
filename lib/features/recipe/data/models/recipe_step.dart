class RecipeStep {
  const RecipeStep({
    required this.temperature,
    required this.timeOffset,
    this.title,
    this.description,
    this.imageUrl,
    this.localImagePath,
  });

  final double temperature;
  final double timeOffset;
  final String? title;
  final String? description;
  final String? imageUrl;

  /// Device-local image selected in the recipe editor.
  ///
  /// This path is uploaded first and is never sent directly to the API JSON.
  final String? localImagePath;

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      temperature: (json['temperature'] as num).toDouble(),
      timeOffset: (json['time_offset'] as num).toDouble(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
    );
  }

  RecipeStep copyWith({
    String? title,
    String? description,
    String? imageUrl,
    String? localImagePath,
    bool clearLocalImagePath = false,
  }) => RecipeStep(
    temperature: temperature,
    timeOffset: timeOffset,
    title: title ?? this.title,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    localImagePath: clearLocalImagePath
        ? null
        : (localImagePath ?? this.localImagePath),
  );

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'time_offset': timeOffset,
    if (title?.trim().isNotEmpty ?? false) 'title': title!.trim(),
    if (description?.trim().isNotEmpty ?? false)
      'description': description!.trim(),
    if (imageUrl?.trim().isNotEmpty ?? false) 'image_url': imageUrl!.trim(),
  };
}
