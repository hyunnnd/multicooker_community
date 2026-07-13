import 'package:flutter/foundation.dart';

import '../data/profile_models.dart';
import '../data/profile_repository.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._repository);

  final ProfileRepository _repository;

  ProfileSummary? summary;
  ProfileSettings settings = const ProfileSettings(
    cookingNotification: true,
    communityNotification: true,
    marketingNotification: false,
    language: 'ko',
    tutorialCompleted: false,
  );
  List<ProfileRecipeItem> myRecipes = const [];
  List<ProfileRecipeItem> savedRecipes = const [];
  List<MyReviewItem> reviews = const [];
  List<MyCommentItem> comments = const [];
  List<CookingHistoryItem> histories = const [];
  List<RegisteredDeviceItem> devices = const [];

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  bool _loadedOnce = false;
  int _loadingCount = 0;

  Future<void> ensureLoaded({bool force = false}) async {
    if (!force && (_loadedOnce || isLoading)) return;
    await loadAll();
  }

  Future<void> loadAll() async {
    _startLoading(clearError: true);
    final errors = <String>[];
    await Future.wait([
      _capture('프로필', () async => summary = await _repository.fetchSummary(), errors),
      _capture('설정', () async => settings = await _repository.fetchSettings(), errors),
      _capture('내 레시피', () async => myRecipes = await _repository.fetchMyRecipes(), errors),
      _capture('저장 레시피', () async => savedRecipes = await _repository.fetchSavedRecipes(), errors),
      _capture('후기', () async => reviews = await _repository.fetchMyReviews(), errors),
      _capture('댓글', () async => comments = await _repository.fetchMyComments(), errors),
      _capture('조리 이력', () async => histories = await _repository.fetchCookingHistories(), errors),
      _capture('기기', () async => devices = await _repository.fetchDevices(), errors),
    ]);
    _loadedOnce = true;
    errorMessage = errors.isEmpty ? null : '일부 데이터를 불러오지 못했습니다: ${errors.join(' / ')}';
    _finishLoading();
  }

  Future<void> loadOverview() async {
    _startLoading(clearError: true);
    final errors = <String>[];
    await Future.wait([
      _capture('프로필', () async => summary = await _repository.fetchSummary(), errors),
      _capture('내 레시피', () async => myRecipes = await _repository.fetchMyRecipes(), errors),
      _capture('후기', () async => reviews = await _repository.fetchMyReviews(), errors),
      _capture('조리 이력', () async => histories = await _repository.fetchCookingHistories(), errors),
    ]);
    errorMessage = errors.isEmpty ? null : '일부 데이터를 불러오지 못했습니다: ${errors.join(' / ')}';
    _finishLoading();
  }

  Future<void> loadMyRecipes() => _loadSection(
        '내가 올린 레시피',
        () async => myRecipes = await _repository.fetchMyRecipes(),
      );

  Future<void> loadSavedRecipes() => _loadSection(
        '저장한 레시피',
        () async => savedRecipes = await _repository.fetchSavedRecipes(),
      );

  Future<void> loadMyReviews() => _loadSection(
        '내가 쓴 후기',
        () async => reviews = await _repository.fetchMyReviews(),
      );

  Future<void> loadMyComments() => _loadSection(
        '내가 쓴 댓글',
        () async => comments = await _repository.fetchMyComments(),
      );

  Future<void> loadCookingHistories() => _loadSection(
        '조리 이력',
        () async => histories = await _repository.fetchCookingHistories(),
      );

  Future<void> loadPreferences() async {
    _startLoading(clearError: true);
    final errors = <String>[];
    await Future.wait([
      _capture('설정', () async => settings = await _repository.fetchSettings(), errors),
      _capture('기기', () async => devices = await _repository.fetchDevices(), errors),
    ]);
    errorMessage = errors.isEmpty ? null : '설정 일부를 불러오지 못했습니다: ${errors.join(' / ')}';
    _finishLoading();
  }

  Future<bool> updateNickname(String nickname) => _run(() async {
        summary = await _repository.updateNickname(nickname);
      });

  Future<bool> updateSettings(ProfileSettings next) => _run(() async {
        final previous = settings;
        settings = next;
        notifyListeners();
        try {
          settings = await _repository.updateSettings(next);
        } catch (_) {
          settings = previous;
          rethrow;
        }
      });

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _run(
        () => _repository.updatePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );

  Future<bool> deleteAccount() => _run(_repository.deleteAccount);

  Future<bool> deleteMyRecipe(String recipeId) => _run(() async {
        await _repository.deleteMyRecipe(recipeId);
        myRecipes = myRecipes.where((item) => item.id != recipeId).toList(growable: false);
      });

  Future<bool> createMyRecipe({
    required String title,
    required String description,
    required List<Map<String, dynamic>> steps,
  }) =>
      _run(() async {
        final recipe = await _repository.createMyRecipe(
          title: title,
          description: description,
          steps: steps,
        );
        myRecipes = [recipe, ...myRecipes];
      });

  Future<bool> unsaveRecipe(String recipeId) => _run(() async {
        await _repository.unsaveRecipe(recipeId);
        savedRecipes = savedRecipes.where((item) => item.id != recipeId).toList(growable: false);
        await refreshSummary();
      });

  Future<bool> updateReview(
    int reviewId, {
    required int rating,
    required String content,
  }) =>
      _run(() async {
        final updated = await _repository.updateReview(
          reviewId,
          rating: rating,
          content: content,
        );
        reviews = [for (final item in reviews) if (item.id == reviewId) updated else item];
      });

  Future<bool> deleteReview(int reviewId) => _run(() async {
        await _repository.deleteReview(reviewId);
        reviews = reviews.where((item) => item.id != reviewId).toList(growable: false);
        await refreshSummary();
      });

  Future<bool> updateComment(MyCommentItem item, String content) => _run(() async {
        await _repository.updateComment(item, content);
        comments = comments
            .map(
              (old) => old.id == item.id && old.type == item.type
                  ? MyCommentItem(
                      id: old.id,
                      type: old.type,
                      postId: old.postId,
                      postTitle: old.postTitle,
                      postCategory: old.postCategory,
                      content: content,
                      timeAgo: old.timeAgo,
                      commentId: old.commentId,
                      createdAt: old.createdAt,
                    )
                  : old,
            )
            .toList(growable: false);
      });

  Future<bool> deleteComment(MyCommentItem item) => _run(() async {
        await _repository.deleteComment(item);
        comments = comments
            .where((old) => !(old.id == item.id && old.type == item.type))
            .toList(growable: false);
        await refreshSummary();
      });

  Future<bool> createCookingHistory({
    required String? recipeId,
    required String recipeTitle,
    required String deviceName,
    required String status,
    required int totalTimeMin,
    required int maxTemperature,
    required List<Map<String, dynamic>> steps,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) =>
      _run(() async {
        final history = await _repository.createCookingHistory(
          recipeId: recipeId,
          recipeTitle: recipeTitle,
          deviceName: deviceName,
          status: status,
          totalTimeMin: totalTimeMin,
          maxTemperature: maxTemperature,
          steps: steps,
          startedAt: startedAt,
          finishedAt: finishedAt,
        );
        histories = [history, ...histories];
        await refreshSummary();
      });

  Future<bool> deleteCookingHistory(int historyId) => _run(() async {
        await _repository.deleteCookingHistory(historyId);
        histories = histories.where((item) => item.id != historyId).toList(growable: false);
        await refreshSummary();
      });

  Future<bool> saveHistoryAsRecipe(int historyId) => _run(() async {
        final recipe = await _repository.saveHistoryAsRecipe(historyId);
        myRecipes = [recipe, ...myRecipes];
        await refreshSummary();
      });

  Future<bool> updateDeviceAlias(int deviceId, String alias) => _run(() async {
        final updated = await _repository.updateDevice(deviceId, alias: alias);
        devices = [for (final item in devices) if (item.id == deviceId) updated else item];
      });

  Future<bool> toggleDeviceAutoReconnect(
    RegisteredDeviceItem device,
    bool value,
  ) =>
      _run(() async {
        final updated = await _repository.updateDevice(
          device.id,
          autoReconnect: value,
        );
        devices = [for (final item in devices) if (item.id == device.id) updated else item];
      });

  Future<bool> deleteDevice(int deviceId) => _run(() async {
        await _repository.deleteDevice(deviceId);
        devices = devices.where((item) => item.id != deviceId).toList(growable: false);
        await refreshSummary();
      });

  Future<void> refreshSummary() async {
    try {
      summary = await _repository.fetchSummary();
      notifyListeners();
    } catch (_) {
      // 세부 기능 성공 후 요약 조회만 실패하면 현재 상태를 유지합니다.
    }
  }

  Future<void> _loadSection(String label, Future<void> Function() action) async {
    _startLoading(clearError: true);
    try {
      await action();
    } catch (error) {
      errorMessage = '$label 데이터를 불러오지 못했습니다: $error';
    } finally {
      _finishLoading();
    }
  }

  Future<void> _capture(
    String label,
    Future<void> Function() action,
    List<String> errors,
  ) async {
    try {
      await action();
    } catch (error) {
      errors.add('$label($error)');
    }
  }

  void _startLoading({required bool clearError}) {
    _loadingCount++;
    isLoading = true;
    if (clearError) errorMessage = null;
    notifyListeners();
  }

  void _finishLoading() {
    _loadingCount = (_loadingCount - 1).clamp(0, 999).toInt();
    isLoading = _loadingCount > 0;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
