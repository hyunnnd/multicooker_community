import 'dart:convert';

/// Returns the stable client-side id for a recipe stored in the personal API.
///
/// The local FastAPI uses numeric recipe ids, so the raw id is kept as-is.
/// A title-derived fallback is used only for legacy responses without an id.
String personalRecipeClientId(Map<String, dynamic> json, int index) {
  final rawId = json['id'] ?? json['recipe_id'] ?? json['recipeId'];
  if (rawId != null && rawId.toString().trim().isNotEmpty) {
    return rawId.toString().trim();
  }

  final title = (json['title'] ?? json['name'] ?? 'recipe-$index').toString().trim();
  final encoded = base64Url.encode(utf8.encode(title)).replaceAll('=', '');
  return 'local-title-$encoded';
}

List<Map<String, dynamic>> recipeMapsFromResponse(Object? data) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    for (final key in const ['recipes', 'data', 'items', 'results']) {
      final value = map[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }
    if (map.containsKey('title') || map.containsKey('name')) {
      return [map];
    }
  }
  return const [];
}

List<Map<String, dynamic>> recipeStepsFromJson(Map<String, dynamic> json) {
  final raw = json['steps'] ?? json['cooker_steps'] ?? json['cookerSteps'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

double numberAsDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int numberAsInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
