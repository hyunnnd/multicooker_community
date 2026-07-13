import 'package:dio/dio.dart';

import '../../recipe/data/recipe_identity.dart';
import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._localDio, this._companyDio);

  final Dio _localDio;
  final Dio _companyDio;

  Future<ProfileSummary> fetchSummary() async {
    final response = await _localDio.get<Map<String, dynamic>>('/users/me');
    return ProfileSummary.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ProfileSummary> updateNickname(String nickname) async {
    final response = await _localDio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'nickname': nickname},
    );
    return ProfileSummary.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _localDio.patch<void>(
      '/users/me/password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<void> deleteAccount() async {
    await _localDio.delete<void>('/users/me');
  }

  Future<ProfileSettings> fetchSettings() async {
    final response = await _localDio.get<Map<String, dynamic>>(
      '/users/me/settings',
    );
    final data = Map<String, dynamic>.from(
      response.data?['settings'] as Map? ?? const {},
    );
    return ProfileSettings.fromJson(data);
  }

  Future<ProfileSettings> updateSettings(ProfileSettings settings) async {
    final response = await _localDio.patch<Map<String, dynamic>>(
      '/users/me/settings',
      data: settings.toJson(),
    );
    final data = Map<String, dynamic>.from(
      response.data?['settings'] as Map? ?? const {},
    );
    return ProfileSettings.fromJson(data);
  }

  /// 회사 서버에 로그인한 사용자가 직접 업로드한 개인 레시피입니다.
  Future<List<ProfileRecipeItem>> fetchMyRecipes() async {
    final response = await _companyDio.get<Object>(
      '/recipe/personal_recipes/100',
    );
    final items = recipeMapsFromResponse(response.data);
    return [
      for (var index = 0; index < items.length; index++)
        _companyRecipeItem(items[index], index),
    ];
  }

  Future<ProfileRecipeItem> createMyRecipe({
    required String title,
    required String description,
    required List<Map<String, dynamic>> steps,
  }) async {
    await _companyDio.post<Object>(
      '/recipe/upload',
      data: {
        'title': title,
        'description': description,
        'steps': steps,
      },
    );
    final recipes = await fetchMyRecipes();
    for (final recipe in recipes) {
      if (recipe.title == title) return recipe;
    }
    return ProfileRecipeItem(
      id: 'company-title-${Uri.encodeComponent(title)}',
      title: title,
      description: description,
      author: '나의 레시피',
      totalTimeMin: _totalMinutesFromSteps(steps),
      maxTemperature: _maxTemperatureFromSteps(steps),
      isPersonal: true,
    );
  }

  /// 현재 회사 서버에는 개인 레시피 삭제 API가 없으므로 호출하지 않습니다.
  Future<void> deleteMyRecipe(String recipeId) async {
    throw UnsupportedError('회사 서버에서 개인 레시피 삭제 API를 지원하지 않습니다.');
  }

  Future<List<ProfileRecipeItem>> fetchSavedRecipes() async {
    final response = await _localDio.get<Map<String, dynamic>>(
      '/users/me/saved-recipes',
    );
    return _recipeItems(response.data?['recipes']);
  }

  Future<void> unsaveRecipe(String recipeId) async {
    await _localDio.delete<void>(
      '/users/me/saved-recipes/by-client-id/${Uri.encodeComponent(recipeId)}',
    );
  }

  Future<List<MyReviewItem>> fetchMyReviews() async {
    final response = await _localDio.get<Map<String, dynamic>>(
      '/users/me/reviews',
    );
    final items = response.data?['reviews'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => MyReviewItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<MyReviewItem> updateReview(
    int reviewId, {
    required int rating,
    required String content,
  }) async {
    final response = await _localDio.patch<Map<String, dynamic>>(
      '/reviews/$reviewId',
      data: {'rating': rating, 'content': content},
    );
    final data = Map<String, dynamic>.from(
      response.data?['review'] as Map? ?? const {},
    );
    return MyReviewItem.fromJson(data);
  }

  Future<void> deleteReview(int reviewId) async {
    await _localDio.delete<void>('/reviews/$reviewId');
  }

  Future<List<MyCommentItem>> fetchMyComments() async {
    final response = await _localDio.get<Map<String, dynamic>>(
      '/users/me/comments',
    );
    final items = response.data?['comments'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => MyCommentItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> updateComment(MyCommentItem item, String content) async {
    if (item.isReply) {
      await _localDio.patch<void>(
        '/community/replies/${item.id}',
        data: {'content': content},
      );
    } else {
      await _localDio.patch<void>(
        '/community/comments/${item.id}',
        data: {'content': content},
      );
    }
  }

  Future<void> deleteComment(MyCommentItem item) async {
    if (item.isReply) {
      await _localDio.delete<void>('/community/replies/${item.id}');
    } else {
      await _localDio.delete<void>('/community/comments/${item.id}');
    }
  }

  Future<CookingHistoryItem> createCookingHistory({
    required String? recipeId,
    required String recipeTitle,
    required String deviceName,
    required String status,
    required int totalTimeMin,
    required int maxTemperature,
    required List<Map<String, dynamic>> steps,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) async {
    final rawRecipeId = recipeId?.trim();
    final companyNumericId = rawRecipeId != null &&
            rawRecipeId.startsWith('company-')
        ? int.tryParse(rawRecipeId.substring('company-'.length))
        : null;
    final parsedRecipeId = int.tryParse(rawRecipeId ?? '') ?? companyNumericId;
    final response = await _localDio.post<Map<String, dynamic>>(
      '/users/me/cooking-histories',
      data: {
        'recipe_id': parsedRecipeId,
        'client_recipe_id': rawRecipeId,
        'recipe_title': recipeTitle,
        'device_name': deviceName,
        'status': status,
        'started_at': startedAt?.toUtc().toIso8601String(),
        'finished_at': finishedAt?.toUtc().toIso8601String(),
        'total_time_min': totalTimeMin,
        'max_temperature': maxTemperature,
        'steps': steps,
      },
    );
    final data = Map<String, dynamic>.from(
      response.data?['history'] as Map? ?? const {},
    );
    return CookingHistoryItem.fromJson(data);
  }

  Future<List<CookingHistoryItem>> fetchCookingHistories() async {
    final response = await _localDio.get<Map<String, dynamic>>(
      '/users/me/cooking-histories',
    );
    final items = response.data?['histories'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => CookingHistoryItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> deleteCookingHistory(int historyId) async {
    await _localDio.delete<void>(
      '/users/me/cooking-histories/$historyId',
    );
  }

  /// 조리 이력을 회사 개인 레시피 DB에 다시 등록합니다.
  Future<ProfileRecipeItem> saveHistoryAsRecipe(int historyId) async {
    final historyResponse = await _localDio.get<Map<String, dynamic>>(
      '/users/me/cooking-histories/$historyId',
    );
    final history = Map<String, dynamic>.from(
      historyResponse.data?['history'] as Map? ?? const {},
    );
    final title = '${(history['recipe_title'] ?? '직접 조리').toString()} 복사본';
    final rawSteps = history['steps'] as List<dynamic>? ?? const [];
    final steps = rawSteps
        .whereType<Map>()
        .map((raw) {
          final step = Map<String, dynamic>.from(raw);
          return <String, dynamic>{
            'temperature': numberAsDouble(
              step['temperature'] ?? step['temp'],
              fallback: numberAsDouble(history['max_temperature'], fallback: 180),
            ),
            'time_offset': numberAsDouble(
              step['time_offset'] ?? step['timeOffset'] ?? step['seconds'],
            ),
          };
        })
        .toList(growable: true);
    if (steps.isEmpty) {
      steps.add({
        'temperature': numberAsDouble(
          history['max_temperature'],
          fallback: 180,
        ),
        'time_offset': numberAsDouble(
          history['total_time_min'],
          fallback: 10,
        ) * 60,
      });
    }

    await _companyDio.post<Object>(
      '/recipe/upload',
      data: {
        'title': title,
        'description': '조리 이력에서 저장한 레시피입니다.',
        'steps': steps,
      },
    );
    final recipes = await fetchMyRecipes();
    for (final recipe in recipes) {
      if (recipe.title == title) return recipe;
    }
    return ProfileRecipeItem(
      id: 'company-title-${Uri.encodeComponent(title)}',
      title: title,
      description: '조리 이력에서 저장한 레시피입니다.',
      author: '나의 레시피',
      totalTimeMin: _totalMinutesFromSteps(steps),
      maxTemperature: _maxTemperatureFromSteps(steps),
      isPersonal: true,
    );
  }

  Future<List<RegisteredDeviceItem>> fetchDevices() async {
    final response = await _localDio.get<Map<String, dynamic>>(
      '/users/me/devices',
    );
    final items = response.data?['devices'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => RegisteredDeviceItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<RegisteredDeviceItem> updateDevice(
    int deviceId, {
    String? alias,
    bool? autoReconnect,
  }) async {
    final response = await _localDio.patch<Map<String, dynamic>>(
      '/users/me/devices/$deviceId',
      data: {
        if (alias != null) 'alias': alias,
        if (autoReconnect != null) 'auto_reconnect': autoReconnect,
      },
    );
    final data = Map<String, dynamic>.from(
      response.data?['device'] as Map? ?? const {},
    );
    return RegisteredDeviceItem.fromJson(data);
  }

  Future<void> deleteDevice(int deviceId) async {
    await _localDio.delete<void>('/users/me/devices/$deviceId');
  }

  ProfileRecipeItem _companyRecipeItem(
    Map<String, dynamic> json,
    int index,
  ) {
    final steps = recipeStepsFromJson(json);
    return ProfileRecipeItem(
      id: companyRecipeClientId(json, index),
      title: (json['title'] ?? json['name'] ?? '이름 없는 레시피').toString(),
      description: (json['description'] ?? '').toString(),
      author: (json['author'] ?? json['nickname'] ?? '나의 레시피').toString(),
      totalTimeMin: _totalMinutesFromSteps(steps),
      maxTemperature: _maxTemperatureFromSteps(steps),
      thumbnailUrl: _nullableString(
        json['thumbnail_url'] ?? json['image_url'] ?? json['image'],
      ),
      createdAt: _nullableString(json['created_at']),
      isOfficial: false,
      isPersonal: true,
    );
  }

  int _totalMinutesFromSteps(List<Map<String, dynamic>> steps) {
    if (steps.isEmpty) return 10;
    final offsets = steps
        .map(
          (step) => numberAsDouble(
            step['time_offset'] ?? step['timeOffset'] ?? step['seconds'],
          ),
        )
        .toList(growable: false);
    final maxOffset = offsets.fold<double>(0, (max, value) => value > max ? value : max);
    if (maxOffset > 0) return (maxOffset / 60).ceil().clamp(1, 999).toInt();
    return steps.length * 5;
  }

  int _maxTemperatureFromSteps(List<Map<String, dynamic>> steps) {
    var maxTemperature = 0;
    for (final step in steps) {
      final temperature = numberAsInt(
        step['temperature'] ?? step['temp'],
      );
      if (temperature > maxTemperature) maxTemperature = temperature;
    }
    return maxTemperature <= 0 ? 180 : maxTemperature;
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  List<ProfileRecipeItem> _recipeItems(Object? raw) {
    final items = raw as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => ProfileRecipeItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }
}
