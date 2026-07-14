import 'package:dio/dio.dart';

import '../../recipe/data/recipe_identity.dart';
import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._localDio);

  final Dio _localDio;

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
    final parsedRecipeId = _numericRecipeId(rawRecipeId);
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

  /// 조리 이력을 현재 로그인 사용자의 개인 레시피로 등록합니다.
  Future<void> saveHistoryAsRecipe(int historyId) async {
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
              fallback: numberAsDouble(
                history['max_temperature'],
                fallback: 180,
              ),
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
            ) *
            60,
      });
    }

    await _localDio.post<Map<String, dynamic>>(
      '/recipe/upload',
      data: {
        'title': title,
        'description': '조리 이력에서 저장한 레시피입니다.',
        'steps': steps,
      },
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

  int? _numericRecipeId(String? recipeId) {
    final value = recipeId?.trim() ?? '';
    final direct = int.tryParse(value);
    if (direct != null) return direct;
    for (final prefix in const ['local-', 'company-']) {
      if (value.startsWith(prefix)) {
        return int.tryParse(value.substring(prefix.length));
      }
    }
    return null;
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
