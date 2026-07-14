import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/community_repository.dart';
import '../data/models/community_models.dart';

class PopularPostsResult {
  const PopularPostsResult({required this.posts, required this.days});

  final List<CommunityPost> posts;
  final int days;
}

class CommunityProvider extends ChangeNotifier {
  CommunityProvider(this._repository) {
    _relativeTimeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_disposed) notifyListeners();
    });
  }

  final CommunityRepository _repository;
  late final Timer _relativeTimeTimer;
  bool _refreshing = false;
  bool _disposed = false;

  var _posts = <CommunityPost>[];
  var _reviews = <CommunityReview>[];
  final Map<String, List<CommunityReview>> _recipeReviews =
      <String, List<CommunityReview>>{};
  final Map<String, List<RecipeCommunityComment>> _recipeComments =
      <String, List<RecipeCommunityComment>>{};
  final Set<String> _recipeCommunityLoading = <String>{};
  final Map<String, String> _recipeCommunityErrors = <String, String>{};
  var _notices = <CommunityNotice>[];
  var _notifications = <CommunityNotification>[];
  var _adminReports = <AdminCommunityReport>[];
  var _adminReportSummary = const AdminReportSummary();
  bool adminLoading = false;
  String adminReportFilter = 'all';

  final likedPostIds = <int>{};
  final likedCommentIds = <int>{};
  final likedReplyIds = <int>{};
  final likedReviewIds = <int>{};
  final hiddenPostIds = <int>{};
  final hiddenCommentIds = <int>{};
  final hiddenReplyIds = <int>{};

  CommunityTab activeTab = CommunityTab.all;
  String searchQuery = '';
  String reviewSourceFilter = '전체';
  String reviewModeFilter = '전체';
  String reviewFoodFilter = '전체';
  String reviewThemeFilter = '전체';
  final Set<String> reviewSourceFilters = <String>{};
  final Set<String> reviewModeFilters = <String>{};
  final Set<String> reviewFoodFilters = <String>{};
  final Set<String> reviewThemeFilters = <String>{};
  String? reviewRecipeIdFilter;
  String? reviewRecipeTitleFilter;
  bool isLoading = true;
  String? errorMessage;

  List<CommunityPost> get posts => _posts.where((p) => !hiddenPostIds.contains(p.id)).toList(growable: false);
  List<CommunityReview> get reviews => _reviews;
  List<CommunityReview> reviewsForRecipe(String recipeId) =>
      List<CommunityReview>.unmodifiable(
        _recipeReviews[recipeId] ?? const <CommunityReview>[],
      );
  List<RecipeCommunityComment> commentsForRecipe(String recipeId) =>
      List<RecipeCommunityComment>.unmodifiable(
        _recipeComments[recipeId] ?? const <RecipeCommunityComment>[],
      );
  bool isRecipeCommunityLoading(String recipeId) =>
      _recipeCommunityLoading.contains(recipeId);
  String? recipeCommunityError(String recipeId) =>
      _recipeCommunityErrors[recipeId];
  List<CommunityNotice> get notices => _notices;
  List<CommunityNotification> get notifications => _notifications;
  List<AdminCommunityReport> get adminReports => _adminReports;
  AdminReportSummary get adminReportSummary => _adminReportSummary;
  bool get isAdmin => _posts.any((post) => post.canAdminister);
  int get unreadCount => _notifications.where((n) => !n.read).length;
  CommunityNotice? get pinnedNotice => _notices.where((n) => n.important).isNotEmpty ? _notices.firstWhere((n) => n.important) : (_notices.isEmpty ? null : _notices.first);


  void resetForAccountChange() {
    _posts = <CommunityPost>[];
    _reviews = <CommunityReview>[];
    _recipeReviews.clear();
    _recipeComments.clear();
    _recipeCommunityLoading.clear();
    _recipeCommunityErrors.clear();
    _notices = <CommunityNotice>[];
    _notifications = <CommunityNotification>[];
    _adminReports = <AdminCommunityReport>[];
    _adminReportSummary = const AdminReportSummary();
    adminLoading = false;
    adminReportFilter = 'all';
    likedPostIds.clear();
    likedCommentIds.clear();
    likedReplyIds.clear();
    likedReviewIds.clear();
    hiddenPostIds.clear();
    hiddenCommentIds.clear();
    hiddenReplyIds.clear();
    isLoading = true;
    errorMessage = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> refreshNotifications({bool silent = true}) async {
    try {
      _notifications = await _repository.fetchNotifications();
      errorMessage = null;
    } catch (error) {
      if (!silent) errorMessage = '알림을 가져오지 못했습니다. $error';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _relativeTimeTimer.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }
    try {
      final nextPosts = await _repository.fetchPosts();
      final nextReviews = await _repository.fetchReviews();
      final nextNotices = await _repository.fetchNotices();
      final nextNotifications = await _repository.fetchNotifications();
      _posts = nextPosts;
      _reviews = nextReviews;
      _notices = nextNotices;
      _notifications = nextNotifications;
      errorMessage = null;
      _syncReactionSetsFromDb();
    } catch (error) {
      if (!silent || _posts.isEmpty && _reviews.isEmpty && _notices.isEmpty) {
        errorMessage = '로컬 FastAPI 서버에서 커뮤니티 데이터를 가져오지 못했습니다. 서버가 켜져 있는지 확인해 주세요. $error';
        if (!silent) {
          _posts = const [];
          _reviews = const [];
          _notices = const [];
          _notifications = const [];
          likedPostIds.clear();
          likedCommentIds.clear();
          likedReplyIds.clear();
          likedReviewIds.clear();
        }
      }
    } finally {
      _refreshing = false;
      if (!silent) isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _syncReactionSetsFromDb() {
    likedPostIds
      ..clear()
      ..addAll(_posts.where((post) => post.isLiked).map((post) => post.id));
    likedCommentIds.clear();
    likedReplyIds.clear();
    for (final post in _posts) {
      for (final comment in post.comments) {
        if (comment.isLiked) likedCommentIds.add(comment.id);
        for (final reply in comment.replies) {
          if (reply.isLiked) likedReplyIds.add(reply.id);
        }
      }
    }
    likedReviewIds
      ..clear()
      ..addAll(_reviews.where((review) => review.isLiked).map((review) => review.id));
  }

  Future<void> refreshPost(int postId) async {
    try {
      final post = await _repository.fetchPost(postId);
      _replacePost(post);
      _syncReactionSetsFromDb();
      notifyListeners();
    } catch (_) {
      await load();
    }
  }

  void _replacePost(CommunityPost updated) {
    final index = _posts.indexWhere((post) => post.id == updated.id);
    if (index == -1) {
      _posts = [updated, ..._posts];
    } else {
      _posts = [
        for (final post in _posts) if (post.id == updated.id) updated else post,
      ];
    }
  }

  int? _postIdForComment(int commentId) {
    for (final post in _posts) {
      if (post.comments.any((comment) => comment.id == commentId)) return post.id;
    }
    return null;
  }

  ({int postId, int commentId})? _locationForReply(int replyId) {
    for (final post in _posts) {
      for (final comment in post.comments) {
        if (comment.replies.any((reply) => reply.id == replyId)) {
          return (postId: post.id, commentId: comment.id);
        }
      }
    }
    return null;
  }

  Future<void> loadRecipeCommunity(
    String recipeId, {
    bool silent = false,
  }) async {
    final id = recipeId.trim();
    if (id.isEmpty || _recipeCommunityLoading.contains(id)) return;
    _recipeCommunityLoading.add(id);
    if (!silent) notifyListeners();
    try {
      final nextReviews = await _repository.fetchReviews(recipeId: id);
      final nextComments = await _repository.fetchRecipeComments(id);
      _recipeReviews[id] = nextReviews;
      _recipeComments[id] = nextComments;
      _recipeCommunityErrors.remove(id);
      for (final review in nextReviews) {
        final index = _reviews.indexWhere((item) => item.id == review.id);
        if (index < 0) {
          _reviews.add(review);
        } else {
          _reviews[index] = review;
        }
      }
      _syncReactionSetsFromDb();
    } catch (error) {
      _recipeCommunityErrors[id] = '후기와 댓글을 불러오지 못했습니다. $error';
    } finally {
      _recipeCommunityLoading.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> addRecipeComment({
    required String recipeId,
    required String recipeTitle,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    try {
      final created = await _repository.createRecipeComment(
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        content: trimmed,
      );
      _recipeComments[recipeId] = <RecipeCommunityComment>[
        created,
        ...(_recipeComments[recipeId] ?? const <RecipeCommunityComment>[]),
      ];
      _recipeCommunityErrors.remove(recipeId);
      notifyListeners();
      return true;
    } catch (error) {
      _recipeCommunityErrors[recipeId] = '댓글 등록 실패: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRecipeComment(
    String recipeId,
    int commentId,
    String content,
  ) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    try {
      final updated = await _repository.updateRecipeComment(
        commentId,
        trimmed,
      );
      _recipeComments[recipeId] = [
        for (final item
            in _recipeComments[recipeId] ?? const <RecipeCommunityComment>[])
          if (item.id == commentId) updated else item,
      ];
      _recipeCommunityErrors.remove(recipeId);
      notifyListeners();
      return true;
    } catch (error) {
      _recipeCommunityErrors[recipeId] = '댓글 수정 실패: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecipeComment(
    String recipeId,
    int commentId,
  ) async {
    try {
      await _repository.deleteRecipeComment(commentId);
      _recipeComments[recipeId] = (
        _recipeComments[recipeId] ?? const <RecipeCommunityComment>[]
      ).where((item) => item.id != commentId).toList(growable: false);
      _recipeCommunityErrors.remove(recipeId);
      notifyListeners();
      return true;
    } catch (error) {
      _recipeCommunityErrors[recipeId] = '댓글 삭제 실패: $error';
      notifyListeners();
      return false;
    }
  }

  void setTab(CommunityTab tab) {
    activeTab = tab;
    notifyListeners();
  }

  void setReviewRecipeFilter({String? recipeId, String? recipeTitle}) {
    reviewRecipeIdFilter = recipeId?.trim().isEmpty == true ? null : recipeId?.trim();
    reviewRecipeTitleFilter = recipeTitle?.trim().isEmpty == true ? null : recipeTitle?.trim();
    notifyListeners();
  }

  void clearReviewRecipeFilter() {
    reviewRecipeIdFilter = null;
    reviewRecipeTitleFilter = null;
    notifyListeners();
  }

  void setReviewSourceFilter(String value) {
    reviewSourceFilter = value;
    reviewSourceFilters
      ..clear()
      ..addAll(value == '전체' ? const <String>[] : <String>[value]);
    notifyListeners();
  }

  void setReviewModeFilter(String value) {
    reviewModeFilter = value;
    reviewModeFilters
      ..clear()
      ..addAll(value == '전체' ? const <String>[] : <String>[value]);
    notifyListeners();
  }

  void setReviewFoodFilter(String value) {
    reviewFoodFilter = value;
    reviewFoodFilters
      ..clear()
      ..addAll(value == '전체' ? const <String>[] : <String>[value]);
    notifyListeners();
  }

  void setReviewThemeFilter(String value) {
    reviewThemeFilter = value;
    reviewThemeFilters
      ..clear()
      ..addAll(value == '전체' ? const <String>[] : <String>[value]);
    notifyListeners();
  }

  void clearReviewCategoryFilters({bool notify = true}) {
    reviewSourceFilter = '전체';
    reviewModeFilter = '전체';
    reviewFoodFilter = '전체';
    reviewThemeFilter = '전체';
    reviewSourceFilters.clear();
    reviewModeFilters.clear();
    reviewFoodFilters.clear();
    reviewThemeFilters.clear();
    if (notify) notifyListeners();
  }

  void setReviewDropdownFilter(String group, String value) {
    // 이전 드롭다운 방식과의 호환용입니다. 새 UI는 다중 선택 필터를 사용합니다.
    switch (group) {
      case 'source':
        setReviewSourceFilter(value);
        break;
      case 'mode':
        setReviewModeFilter(value);
        break;
      case 'food':
        setReviewFoodFilter(value);
        break;
      case 'theme':
        setReviewThemeFilter(value);
        break;
    }
  }

  void setReviewFilterSelections({
    required Set<String> sources,
    required Set<String> modes,
    required Set<String> foods,
    required Set<String> themes,
  }) {
    reviewSourceFilters
      ..clear()
      ..addAll(sources.where((value) => value != '전체'));
    reviewModeFilters
      ..clear()
      ..addAll(modes.where((value) => value != '전체'));
    reviewFoodFilters
      ..clear()
      ..addAll(foods.where((value) => value != '전체'));
    reviewThemeFilters
      ..clear()
      ..addAll(themes.where((value) => value != '전체'));

    reviewSourceFilter = reviewSourceFilters.isEmpty ? '전체' : reviewSourceFilters.join(', ');
    reviewModeFilter = reviewModeFilters.isEmpty ? '전체' : reviewModeFilters.join(', ');
    reviewFoodFilter = reviewFoodFilters.isEmpty ? '전체' : reviewFoodFilters.join(', ');
    reviewThemeFilter = reviewThemeFilters.isEmpty ? '전체' : reviewThemeFilters.join(', ');
    notifyListeners();
  }

  void removeReviewFilterSelection(String group, String value) {
    switch (group) {
      case 'source':
        reviewSourceFilters.remove(value);
        reviewSourceFilter = reviewSourceFilters.isEmpty ? '전체' : reviewSourceFilters.join(', ');
        break;
      case 'mode':
        reviewModeFilters.remove(value);
        reviewModeFilter = reviewModeFilters.isEmpty ? '전체' : reviewModeFilters.join(', ');
        break;
      case 'food':
        reviewFoodFilters.remove(value);
        reviewFoodFilter = reviewFoodFilters.isEmpty ? '전체' : reviewFoodFilters.join(', ');
        break;
      case 'theme':
        reviewThemeFilters.remove(value);
        reviewThemeFilter = reviewThemeFilters.isEmpty ? '전체' : reviewThemeFilters.join(', ');
        break;
    }
    notifyListeners();
  }

  void clearReviewFilters() {
    reviewSourceFilter = '전체';
    reviewModeFilter = '전체';
    reviewFoodFilter = '전체';
    reviewThemeFilter = '전체';
    reviewSourceFilters.clear();
    reviewModeFilters.clear();
    reviewFoodFilters.clear();
    reviewThemeFilters.clear();
    reviewRecipeIdFilter = null;
    reviewRecipeTitleFilter = null;
    notifyListeners();
  }

  List<CommunityReview> filteredReviews() {
    var list = _reviews;
    final recipeId = reviewRecipeIdFilter;
    final recipeTitle = reviewRecipeTitleFilter;
    if (recipeId != null || recipeTitle != null) {
      list = list.where((review) => review.matchesRecipe(recipeId ?? '', recipeTitle)).toList();
    }
    if (reviewSourceFilters.isNotEmpty) {
      list = list.where((review) => reviewSourceFilters.contains(review.sourceLabel)).toList();
    }
    if (reviewModeFilters.isNotEmpty) {
      list = list.where((review) => reviewModeFilters.contains(review.cookingModeLabel)).toList();
    }
    if (reviewFoodFilters.isNotEmpty) {
      list = list.where((review) => reviewFoodFilters.contains(review.foodCategoryLabel)).toList();
    }
    if (reviewThemeFilters.isNotEmpty) {
      list = list.where((review) => review.effectiveThemeTags.any(reviewThemeFilters.contains)).toList();
    }
    if (searchQuery.isNotEmpty) {
      list = list.where((review) => [
        review.username,
        review.recipeTitle,
        review.content,
        review.sourceLabel,
        review.cookingModeLabel,
        review.foodCategoryLabel,
        ...review.effectiveThemeTags,
      ].join(' ').toLowerCase().contains(searchQuery)).toList();
    }
    return list;
  }

  void setSearchQuery(String value) {
    searchQuery = value.trim().toLowerCase();
    notifyListeners();
  }

  PopularPostsResult popularPosts() {
    const windows = [3, 6, 9, 12];
    for (final days in windows) {
      final scored = posts
          .map(
            (post) => _ScoredPost(
              post,
              post.activity.forDays(days).score + post.adminPopularityBoost,
            ),
          )
          .where((entry) => entry.post.forcePopular || entry.score > 0)
          .toList()
        ..sort((a, b) {
          final forced = (b.post.forcePopular ? 1 : 0) -
              (a.post.forcePopular ? 1 : 0);
          if (forced != 0) return forced;
          final score = b.score.compareTo(a.score);
          if (score != 0) return score;
          return b.post.likes.compareTo(a.post.likes);
        });
      if (scored.isNotEmpty) {
        return PopularPostsResult(
          posts: scored.map((e) => e.post).toList(),
          days: days,
        );
      }
    }
    return const PopularPostsResult(posts: [], days: 0);
  }

  List<CommunityPost> filteredPosts() {
    var list = switch (activeTab) {
      CommunityTab.all => posts,
      CommunityTab.popular => popularPosts().posts,
      CommunityTab.free => posts.where((p) => p.category == PostCategory.free).toList(),
      CommunityTab.qa => posts.where((p) => p.category == PostCategory.qa).toList(),
      CommunityTab.review => posts,
    };

    if (searchQuery.isNotEmpty) {
      list = list.where((p) => p.searchableText.contains(searchQuery)).toList();
    }
    return list;
  }

  CommunityPost? postById(int id) {
    try {
      return _posts.firstWhere((p) => p.id == id && !hiddenPostIds.contains(id));
    } catch (_) {
      return null;
    }
  }

  CommunityNotice? noticeById(int id) {
    try {
      return _notices.firstWhere((notice) => notice.id == id);
    } catch (_) {
      return null;
    }
  }

  List<CommunityNotice> filteredNotices(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _notices;
    return _notices.where((notice) => [notice.title, notice.summary, notice.content].join(' ').toLowerCase().contains(q)).toList();
  }

  Future<bool> createAdminNotice({
    required String title,
    required String summary,
    required String content,
    required bool important,
  }) async {
    if (title.trim().isEmpty || content.trim().isEmpty) return false;
    try {
      final notice = await _repository.createAdminNotice(
        title: title.trim(),
        summary: summary.trim(),
        content: content.trim(),
        important: important,
      );
      _notices = [notice, ..._notices];
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = '공지 등록 실패: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAdminNotice(
    int noticeId, {
    required String title,
    required String summary,
    required String content,
    required bool important,
  }) async {
    try {
      final updated = await _repository.updateAdminNotice(
        noticeId,
        title: title.trim(),
        summary: summary.trim(),
        content: content.trim(),
        important: important,
      );
      _notices = [
        for (final notice in _notices)
          if (notice.id == noticeId) updated else notice,
      ];
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = '공지 수정 실패: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAdminNotice(int noticeId) async {
    try {
      await _repository.deleteAdminNotice(noticeId);
      _notices = _notices.where((notice) => notice.id != noticeId).toList();
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = '공지 삭제 실패: $error';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAdminReports({String? status}) async {
    adminLoading = true;
    if (status != null) adminReportFilter = status;
    notifyListeners();
    try {
      final result = await _repository.fetchAdminReports(
        status: adminReportFilter,
      );
      _adminReports = result.reports;
      _adminReportSummary = result.summary;
      errorMessage = null;
    } catch (error) {
      errorMessage = '신고 목록 조회 실패: $error';
    } finally {
      adminLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAdminReport(
    int reportId, {
    required String status,
    String adminNote = '',
    bool deleteContent = false,
  }) async {
    try {
      await _repository.updateAdminReport(
        reportId,
        status: status,
        adminNote: adminNote,
        deleteContent: deleteContent,
      );
      await loadAdminReports();
      if (deleteContent) await load(silent: true);
      return true;
    } catch (error) {
      errorMessage = '신고 처리 실패: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setAdminPostPopularity(
    int postId, {
    required int likeCount,
    required int adminPopularityBoost,
    required bool forcePopular,
  }) async {
    try {
      final updated = await _repository.setAdminPostPopularity(
        postId,
        likeCount: likeCount,
        adminPopularityBoost: adminPopularityBoost,
        forcePopular: forcePopular,
      );
      _replacePost(updated);
      _syncReactionSetsFromDb();
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = '인기도 설정 실패: $error';
      notifyListeners();
      return false;
    }
  }

  Future<void> togglePostLike(int id) async {
    final wasLiked = likedPostIds.contains(id);
    try {
      final updated = wasLiked ? await _repository.unlikePost(id) : await _repository.likePost(id);
      _replacePost(updated);
      _syncReactionSetsFromDb();
    } catch (error) {
      errorMessage = '좋아요 저장 실패: $error';
    }
    notifyListeners();
  }

  Future<void> createReview({
    required String recipeId,
    required String recipeTitle,
    required String recipeImage,
    required int rating,
    required String content,
  }) async {
    if (recipeTitle.trim().isEmpty || content.trim().isEmpty) return;
    try {
      final review = await _repository.createReview(
        recipeId: recipeId.trim(),
        recipeTitle: recipeTitle.trim(),
        recipeImage: recipeImage.trim(),
        rating: rating,
        content: content.trim(),
      );
      _reviews = [review, ..._reviews.where((item) => item.id != review.id)];
      _recipeReviews[review.recipeId] = <CommunityReview>[
        review,
        ...(_recipeReviews[review.recipeId] ?? const <CommunityReview>[])
            .where((item) => item.id != review.id),
      ];
      _syncReactionSetsFromDb();
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      errorMessage = '후기 등록 실패: $error';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleReviewLike(int id) async {
    final wasLiked = likedReviewIds.contains(id);
    String? recipeId;
    for (final review in _reviews) {
      if (review.id == id) {
        recipeId = review.recipeId;
        break;
      }
    }
    if (recipeId == null) {
      for (final list in _recipeReviews.values) {
        for (final review in list) {
          if (review.id == id) {
            recipeId = review.recipeId;
            break;
          }
        }
        if (recipeId != null) break;
      }
    }
    try {
      wasLiked ? await _repository.unlikeReview(id) : await _repository.likeReview(id);
      _reviews = await _repository.fetchReviews();
      if (recipeId != null && recipeId.isNotEmpty) {
        _recipeReviews[recipeId] =
            await _repository.fetchReviews(recipeId: recipeId);
      }
      _syncReactionSetsFromDb();
    } catch (error) {
      errorMessage = '후기 좋아요 저장 실패: $error';
    }
    notifyListeners();
  }

  Future<void> toggleCommentLike(int id) async {
    final postId = _postIdForComment(id);
    final wasLiked = likedCommentIds.contains(id);
    try {
      wasLiked ? await _repository.unlikeComment(id) : await _repository.likeComment(id);
      if (postId != null) await refreshPost(postId);
    } catch (error) {
      errorMessage = '댓글 좋아요 저장 실패: $error';
      notifyListeners();
    }
  }

  Future<void> toggleReplyLike(int id) async {
    final loc = _locationForReply(id);
    final wasLiked = likedReplyIds.contains(id);
    try {
      wasLiked ? await _repository.unlikeReply(id) : await _repository.likeReply(id);
      if (loc != null) await refreshPost(loc.postId);
    } catch (error) {
      errorMessage = '답글 좋아요 저장 실패: $error';
      notifyListeners();
    }
  }

  Future<String> uploadPostImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final imageUrl = await _repository.uploadPostImage(
        bytes: bytes,
        filename: filename,
      );
      errorMessage = null;
      return imageUrl;
    } catch (error) {
      errorMessage = '사진 업로드 실패: $error';
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> setAdminPostLikes(
    int postId, {
    required int likeCount,
    bool applyToPopularTest = true,
  }) async {
    try {
      final updated = await _repository.setAdminPostLikes(
        postId,
        likeCount: likeCount,
        applyToPopularTest: applyToPopularTest,
      );
      _replacePost(updated);
      _syncReactionSetsFromDb();
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = '관리자 좋아요 설정 실패: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> createPost({required PostCategory category, required String title, required String content, String? imageUrl}) async {
    if (title.trim().isEmpty || content.trim().isEmpty) return false;
    try {
      final post = await _repository.createPost(
        category: category,
        title: title.trim(),
        content: content.trim(),
        imageUrl: imageUrl,
      );
      _posts = [post, ..._posts];
      _syncReactionSetsFromDb();
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = '게시글 등록 실패: $error';
      notifyListeners();
      return false;
    }
  }

  Future<void> editPost(int postId, {required PostCategory category, required String title, required String content, String? imageUrl}) async {
    try {
      final updated = await _repository.editPost(postId, category: category, title: title.trim(), content: content.trim(), imageUrl: imageUrl);
      _replacePost(updated);
      _syncReactionSetsFromDb();
    } catch (error) {
      errorMessage = '게시글 수정 실패: $error';
    }
    notifyListeners();
  }

  Future<void> deletePost(int postId) async {
    try {
      await _repository.deletePost(postId);
      _posts = _posts.where((post) => post.id != postId).toList();
      likedPostIds.remove(postId);
    } catch (error) {
      errorMessage = '게시글 삭제 실패: $error';
    }
    notifyListeners();
  }

  Future<void> reportPost(int postId) async {
    try {
      await _repository.reportPost(postId);
      await refreshPost(postId);
    } catch (error) {
      errorMessage = '게시글 신고 실패: $error';
      notifyListeners();
    }
  }

  Future<void> blockPost(int postId) async {
    try {
      await _repository.blockContent(targetType: 'post', targetId: postId);
      await load(silent: true);
    } catch (error) {
      errorMessage = '사용자 차단 실패: $error';
      notifyListeners();
    }
  }

  Future<void> addComment(int postId, String content) async {
    if (content.trim().isEmpty) return;
    try {
      await _repository.addComment(postId, content.trim());
      await refreshPost(postId);
    } catch (error) {
      errorMessage = '댓글 등록 실패: $error';
      notifyListeners();
    }
  }

  Future<void> editComment(int postId, int commentId, String content) async {
    try {
      await _repository.editComment(commentId, content.trim());
      await refreshPost(postId);
    } catch (error) {
      errorMessage = '댓글 수정 실패: $error';
      notifyListeners();
    }
  }

  Future<void> deleteComment(int postId, int commentId) async {
    try {
      await _repository.deleteComment(commentId);
      await refreshPost(postId);
    } catch (error) {
      errorMessage = '댓글 삭제 실패: $error';
      notifyListeners();
    }
  }

  Future<void> reportComment(int commentId) async {
    final postId = _postIdForComment(commentId);
    try {
      await _repository.reportComment(commentId);
      if (postId != null) await refreshPost(postId);
    } catch (error) {
      errorMessage = '댓글 신고 실패: $error';
      notifyListeners();
    }
  }

  Future<void> blockComment(int commentId) async {
    try {
      await _repository.blockContent(targetType: 'comment', targetId: commentId);
      await load(silent: true);
    } catch (error) {
      errorMessage = '사용자 차단 실패: $error';
      notifyListeners();
    }
  }

  Future<void> addReply(int postId, int commentId, String content) async {
    if (content.trim().isEmpty) return;
    try {
      await _repository.addReply(commentId, content.trim());
      await refreshPost(postId);
    } catch (error) {
      errorMessage = '답글 등록 실패: $error';
      notifyListeners();
    }
  }

  Future<void> editReply(int postId, int commentId, int replyId, String content) async {
    try {
      await _repository.editReply(replyId, content.trim());
      await refreshPost(postId);
    } catch (error) {
      errorMessage = '답글 수정 실패: $error';
      notifyListeners();
    }
  }

  Future<void> deleteReply(int postId, int commentId, int replyId) async {
    try {
      await _repository.deleteReply(replyId);
      await refreshPost(postId);
    } catch (error) {
      errorMessage = '답글 삭제 실패: $error';
      notifyListeners();
    }
  }

  Future<void> reportReply(int replyId) async {
    final location = _locationForReply(replyId);
    try {
      await _repository.reportReply(replyId);
      if (location != null) await refreshPost(location.postId);
    } catch (error) {
      errorMessage = '답글 신고 실패: $error';
      notifyListeners();
    }
  }

  Future<void> blockReply(int replyId) async {
    try {
      await _repository.blockContent(targetType: 'reply', targetId: replyId);
      await load(silent: true);
    } catch (error) {
      errorMessage = '사용자 차단 실패: $error';
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _repository.markAllNotificationsRead();
      _notifications = await _repository.fetchNotifications();
    } catch (error) {
      errorMessage = '알림 읽음 처리 실패: $error';
    }
    notifyListeners();
  }

  Future<void> openNotification(int notificationId) async {
    try {
      await _repository.markNotificationRead(notificationId);
      _notifications = await _repository.fetchNotifications();
    } catch (error) {
      errorMessage = '알림 읽음 처리 실패: $error';
    }
    notifyListeners();
  }
}

class _ScoredPost {
  const _ScoredPost(this.post, this.score);

  final CommunityPost post;
  final int score;
}
