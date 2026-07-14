import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import 'models/community_models.dart';

class CommunityRepository {
  CommunityRepository({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Content-Type': 'application/json',
                  'Cache-Control': 'no-cache, no-store, must-revalidate',
                  'Pragma': 'no-cache',
                  'Expires': '0',
                },
              ),
            );

  final Dio _dio;

  Future<List<CommunityPost>> fetchPosts() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/community/posts',
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    final data = response.data?['posts'] as List<dynamic>? ?? const [];
    return data.map((item) => _postFromJson(item as Map<String, dynamic>)).toList();
  }

  Future<CommunityPost> fetchPost(int postId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/community/posts/$postId',
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    return _postFromJson(response.data!['post'] as Map<String, dynamic>);
  }

  Future<List<CommunityReview>> fetchReviews({String? recipeId}) async {
    final query = <String, dynamic>{
      '_': DateTime.now().millisecondsSinceEpoch,
    };
    if (recipeId != null && recipeId.trim().isNotEmpty) {
      query['recipe_id'] = recipeId.trim();
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/community/reviews',
      queryParameters: query,
    );
    final data = response.data?['reviews'] as List<dynamic>? ?? const [];
    return data.map((item) => _reviewFromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<RecipeCommunityComment>> fetchRecipeComments(
    String recipeId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/community/recipes/${Uri.encodeComponent(recipeId)}/comments',
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    final data = response.data?['comments'] as List<dynamic>? ?? const [];
    return data
        .map(
          (item) => _recipeCommentFromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<CommunityNotice>> fetchNotices() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/community/notices',
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    final data = response.data?['notices'] as List<dynamic>? ?? const [];
    return data.map((item) => _noticeFromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<CommunityNotification>> fetchNotifications() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/community/notifications',
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    final data = response.data?['notifications'] as List<dynamic>? ?? const [];
    return data.map((item) => _notificationFromJson(item as Map<String, dynamic>)).toList();
  }

  Future<String> uploadPostImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/community/uploads/image',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
      options: Options(contentType: 'multipart/form-data'),
    );
    final imageUrl = response.data?['image_url'] as String?;
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw StateError('서버에서 이미지 주소를 받지 못했습니다.');
    }
    return imageUrl;
  }

  Future<void> blockContent({
    required String targetType,
    required int targetId,
  }) async {
    await _dio.post<void>(
      '/community/blocks/from-content',
      data: {'target_type': targetType, 'target_id': targetId},
    );
  }

  Future<CommunityPost> setAdminPostLikes(
    int postId, {
    required int likeCount,
    bool applyToPopularTest = true,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/community/posts/$postId/likes',
      data: {
        'like_count': likeCount,
        'apply_to_popular_test': applyToPopularTest,
      },
    );
    return _postFromJson(response.data!['post'] as Map<String, dynamic>);
  }

  Future<CommunityNotice> createAdminNotice({
    required String title,
    required String summary,
    required String content,
    required bool important,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/community/notices',
      data: {
        'title': title,
        'summary': summary,
        'content': content,
        'important': important,
      },
    );
    return _noticeFromJson(response.data!['notice'] as Map<String, dynamic>);
  }

  Future<CommunityNotice> updateAdminNotice(
    int noticeId, {
    required String title,
    required String summary,
    required String content,
    required bool important,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/community/notices/$noticeId',
      data: {
        'title': title,
        'summary': summary,
        'content': content,
        'important': important,
      },
    );
    return _noticeFromJson(response.data!['notice'] as Map<String, dynamic>);
  }

  Future<void> deleteAdminNotice(int noticeId) async {
    await _dio.delete<void>('/admin/community/notices/$noticeId');
  }

  Future<({List<AdminCommunityReport> reports, AdminReportSummary summary})>
      fetchAdminReports({String status = 'all'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/community/reports',
      queryParameters: {'status': status},
    );
    final data = response.data?['reports'] as List<dynamic>? ?? const [];
    final summaryJson = response.data?['summary'] as Map<String, dynamic>? ?? const {};
    return (
      reports: data
          .map((item) => _adminReportFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      summary: AdminReportSummary(
        total: _asInt(summaryJson['total']),
        pending: _asInt(summaryJson['pending']),
        resolved: _asInt(summaryJson['resolved']),
        rejected: _asInt(summaryJson['rejected']),
      ),
    );
  }

  Future<AdminCommunityReport> updateAdminReport(
    int reportId, {
    required String status,
    String adminNote = '',
    bool deleteContent = false,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/community/reports/$reportId',
      data: {
        'status': status,
        'admin_note': adminNote,
        'delete_content': deleteContent,
      },
    );
    return _adminReportFromJson(
      response.data!['report'] as Map<String, dynamic>,
    );
  }

  Future<CommunityPost> setAdminPostPopularity(
    int postId, {
    required int likeCount,
    required int adminPopularityBoost,
    required bool forcePopular,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/community/posts/$postId/popularity',
      data: {
        'like_count': likeCount,
        'admin_popularity_boost': adminPopularityBoost,
        'force_popular': forcePopular,
      },
    );
    return _postFromJson(response.data!['post'] as Map<String, dynamic>);
  }

  Future<CommunityPost> createPost({
    required PostCategory category,
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/community/posts',
      data: {
        'category': _categoryToApi(category),
        'title': title,
        'content': content,
        'image_url': imageUrl,
      },
    );
    return _postFromJson(response.data!['post'] as Map<String, dynamic>);
  }

  Future<CommunityPost> editPost(
    int postId, {
    required PostCategory category,
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/community/posts/$postId',
      data: {
        'category': _categoryToApi(category),
        'title': title,
        'content': content,
        'image_url': imageUrl,
      },
    );
    return _postFromJson(response.data!['post'] as Map<String, dynamic>);
  }

  Future<void> deletePost(int postId) async {
    await _dio.delete<void>('/community/posts/$postId');
  }

  Future<CommunityPost> likePost(int postId) async {
    final response = await _dio.post<Map<String, dynamic>>('/community/posts/$postId/like');
    return _postFromJson(response.data!['post'] as Map<String, dynamic>);
  }

  Future<CommunityPost> unlikePost(int postId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/community/posts/$postId/like');
    return _postFromJson(response.data!['post'] as Map<String, dynamic>);
  }

  Future<void> reportPost(int postId, {String reason = 'reported from app'}) async {
    await _dio.post<void>('/community/posts/$postId/report', data: {'reason': reason});
  }

  Future<CommunityComment> addComment(int postId, String content) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/community/posts/$postId/comments',
      data: {'content': content},
    );
    return _commentFromJson(response.data!['comment'] as Map<String, dynamic>);
  }

  Future<CommunityComment> editComment(int commentId, String content) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/community/comments/$commentId',
      data: {'content': content},
    );
    return _commentFromJson(response.data!['comment'] as Map<String, dynamic>);
  }

  Future<void> deleteComment(int commentId) async {
    await _dio.delete<void>('/community/comments/$commentId');
  }

  Future<CommunityComment> likeComment(int commentId) async {
    final response = await _dio.post<Map<String, dynamic>>('/community/comments/$commentId/like');
    return _commentFromJson(response.data!['comment'] as Map<String, dynamic>);
  }

  Future<CommunityComment> unlikeComment(int commentId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/community/comments/$commentId/like');
    return _commentFromJson(response.data!['comment'] as Map<String, dynamic>);
  }

  Future<void> reportComment(int commentId, {String reason = 'reported from app'}) async {
    await _dio.post<void>('/community/comments/$commentId/report', data: {'reason': reason});
  }

  Future<CommunityReply> addReply(int commentId, String content) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/community/comments/$commentId/replies',
      data: {'content': content},
    );
    return _replyFromJson(response.data!['reply'] as Map<String, dynamic>);
  }

  Future<CommunityReply> editReply(int replyId, String content) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/community/replies/$replyId',
      data: {'content': content},
    );
    return _replyFromJson(response.data!['reply'] as Map<String, dynamic>);
  }

  Future<void> deleteReply(int replyId) async {
    await _dio.delete<void>('/community/replies/$replyId');
  }

  Future<CommunityReply> likeReply(int replyId) async {
    final response = await _dio.post<Map<String, dynamic>>('/community/replies/$replyId/like');
    return _replyFromJson(response.data!['reply'] as Map<String, dynamic>);
  }

  Future<CommunityReply> unlikeReply(int replyId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/community/replies/$replyId/like');
    return _replyFromJson(response.data!['reply'] as Map<String, dynamic>);
  }

  Future<void> reportReply(int replyId, {String reason = 'reported from app'}) async {
    await _dio.post<void>('/community/replies/$replyId/report', data: {'reason': reason});
  }

  Future<CommunityReview> createReview({
    required String recipeId,
    required String recipeTitle,
    required String recipeImage,
    required int rating,
    required String content,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/community/reviews',
      data: {
        'recipe_id': recipeId,
        'recipe_title': recipeTitle,
        'recipe_image': recipeImage,
        'rating': rating,
        'content': content,
      },
    );
    return _reviewFromJson(response.data!['review'] as Map<String, dynamic>);
  }

  Future<void> likeReview(int reviewId) async {
    await _dio.post<void>('/community/reviews/$reviewId/like');
  }

  Future<void> unlikeReview(int reviewId) async {
    await _dio.delete<void>('/community/reviews/$reviewId/like');
  }

  Future<RecipeCommunityComment> createRecipeComment({
    required String recipeId,
    required String recipeTitle,
    required String content,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/community/recipes/${Uri.encodeComponent(recipeId)}/comments',
      data: {
        'recipe_title': recipeTitle,
        'content': content,
      },
    );
    return _recipeCommentFromJson(
      response.data!['comment'] as Map<String, dynamic>,
    );
  }

  Future<RecipeCommunityComment> updateRecipeComment(
    int commentId,
    String content,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/community/recipe-comments/$commentId',
      data: {'content': content},
    );
    return _recipeCommentFromJson(
      response.data!['comment'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteRecipeComment(int commentId) async {
    await _dio.delete<void>('/community/recipe-comments/$commentId');
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _dio.patch<void>('/community/notifications/$notificationId/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.patch<void>('/community/notifications/read_all');
  }

  CommunityPost _postFromJson(Map<String, dynamic> json) => CommunityPost(
        id: _asInt(json['id']),
        authorUserId: _asNullableInt(json['author_user_id']),
        category: _categoryFromApi(json['category']),
        username: json['username'] as String? ?? '익명',
        avatarColor: _asInt(json['avatar_color'], fallback: 0xFFFF8C42),
        timeAgo: json['time_ago'] as String? ?? '',
        createdAt: _asDateTime(json['created_at']),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        likes: _asInt(json['likes']),
        reportCount: _asNullableInt(json['report_count']),
        canAdminister: json['can_administer'] as bool? ?? false,
        popularityScore: _asInt(json['popularity_score']),
        adminPopularityBoost: _asInt(json['admin_popularity_boost']),
        forcePopular: json['force_popular'] as bool? ?? false,
        isPopular: json['is_popular'] as bool? ?? false,
        isLiked: json['is_liked'] as bool? ?? false,
        isMine: json['is_mine'] as bool? ?? false,
        comments: ((json['comments'] as List<dynamic>?) ?? const [])
            .map((item) => _commentFromJson(item as Map<String, dynamic>))
            .toList(),
        imageUrl: json['image_url'] as String?,
        tags: ((json['tags'] as List<dynamic>?) ?? const []).map((e) => '$e').toList(),
        activity: _activityFromJson(json['activity'] as Map<String, dynamic>?),
      );

  CommunityComment _commentFromJson(Map<String, dynamic> json) => CommunityComment(
        id: _asInt(json['id']),
        authorUserId: _asNullableInt(json['author_user_id']),
        username: json['username'] as String? ?? '익명',
        avatarColor: _asInt(json['avatar_color'], fallback: 0xFFFF8C42),
        content: json['content'] as String? ?? '',
        timeAgo: json['time_ago'] as String? ?? '',
        createdAt: _asDateTime(json['created_at']),
        likes: _asInt(json['likes']),
        reportCount: _asNullableInt(json['report_count']),
        isLiked: json['is_liked'] as bool? ?? false,
        isMine: json['is_mine'] as bool? ?? false,
        replies: ((json['replies'] as List<dynamic>?) ?? const [])
            .map((item) => _replyFromJson(item as Map<String, dynamic>))
            .toList(),
      );

  CommunityReply _replyFromJson(Map<String, dynamic> json) => CommunityReply(
        id: _asInt(json['id']),
        authorUserId: _asNullableInt(json['author_user_id']),
        username: json['username'] as String? ?? '익명',
        avatarColor: _asInt(json['avatar_color'], fallback: 0xFFFF8C42),
        content: json['content'] as String? ?? '',
        timeAgo: json['time_ago'] as String? ?? '',
        createdAt: _asDateTime(json['created_at']),
        likes: _asInt(json['likes']),
        reportCount: _asNullableInt(json['report_count']),
        isLiked: json['is_liked'] as bool? ?? false,
        isMine: json['is_mine'] as bool? ?? false,
      );

  CommunityReview _reviewFromJson(Map<String, dynamic> json) => CommunityReview(
        id: _asInt(json['id']),
        authorUserId: _asNullableInt(json['author_user_id']),
        username: json['username'] as String? ?? '익명',
        avatarColor: _asInt(json['avatar_color'], fallback: 0xFFFF8C42),
        recipeTitle: json['recipe_title'] as String? ?? '',
        recipeImage: json['recipe_image'] as String? ?? '',
        rating: _asInt(json['rating']),
        content: json['content'] as String? ?? '',
        date: json['date'] as String? ?? '',
        createdAt: _asDateTime(json['created_at']),
        likes: _asInt(json['likes']),
        commentCount: _asInt(json['comment_count']),
        recipeId: '${json['recipe_id'] ?? ''}',
        recipeSource: json['recipe_source'] as String? ?? '',
        cookingMode: json['cooking_mode'] as String? ?? '',
        foodCategory: json['food_category'] as String? ?? '',
        themeTags: ((json['theme_tags'] as List<dynamic>?) ?? const []).map((e) => '$e').toList(),
        isLiked: json['is_liked'] as bool? ?? false,
        isMine: json['is_mine'] as bool? ?? false,
      );

  RecipeCommunityComment _recipeCommentFromJson(
    Map<String, dynamic> json,
  ) =>
      RecipeCommunityComment(
        id: _asInt(json['id']),
        recipeId: '${json['recipe_id'] ?? ''}',
        recipeTitle: json['recipe_title'] as String? ?? '',
        authorUserId: _asNullableInt(json['author_user_id']),
        username: json['username'] as String? ?? '익명',
        avatarColor: _asInt(json['avatar_color'], fallback: 0xFFFF8C42),
        content: json['content'] as String? ?? '',
        createdAt: _asDateTime(json['created_at']),
        isMine: json['is_mine'] as bool? ?? false,
      );

  CommunityNotice _noticeFromJson(Map<String, dynamic> json) => CommunityNotice(
        id: _asInt(json['id']),
        title: json['title'] as String? ?? '',
        date: json['date'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        content: json['content'] as String? ?? '',
        important: json['important'] as bool? ?? false,
      );

  AdminCommunityReport _adminReportFromJson(Map<String, dynamic> json) {
    final target = json['target'] as Map<String, dynamic>? ?? const {};
    return AdminCommunityReport(
      id: _asInt(json['id']),
      targetType: json['target_type'] as String? ?? 'post',
      targetId: _asInt(json['target_id']),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      reporter: json['reporter'] as String? ?? '',
      targetTitle: target['title'] as String? ?? '',
      targetContent: target['content'] as String? ?? '',
      targetAuthor: target['author'] as String? ?? '',
      targetReportCount: _asInt(target['report_count']),
      targetExists: target['exists'] as bool? ?? false,
      createdAt: _asDateTime(json['created_at']),
      adminNote: json['admin_note'] as String? ?? '',
      processedBy: json['processed_by'] as String? ?? '',
      processedAt: _asDateTime(json['processed_at']),
    );
  }

  CommunityNotification _notificationFromJson(Map<String, dynamic> json) => CommunityNotification(
        id: _asInt(json['id']),
        type: (json['type'] as String?) == 'reply' ? NotificationType.reply : NotificationType.comment,
        fromUser: json['from_user'] as String? ?? '익명',
        avatarColor: _asInt(json['avatar_color'], fallback: 0xFFFF8C42),
        postTitle: json['post_title'] as String? ?? '',
        contextText: json['context_text'] as String? ?? '',
        postId: _asInt(json['post_id']),
        timeAgo: json['time_ago'] as String? ?? '',
        createdAt: _asDateTime(json['created_at']),
        read: json['read'] as bool? ?? false,
      );

  ActivitySet _activityFromJson(Map<String, dynamic>? json) {
    ActivityWindow read(String key) {
      final map = json?[key] as Map<String, dynamic>?;
      return ActivityWindow(likes: _asInt(map?['likes']), comments: _asInt(map?['comments']));
    }

    return ActivitySet(d3: read('d3'), d6: read('d6'), d9: read('d9'), d12: read('d12'));
  }

  PostCategory _categoryFromApi(dynamic value) => '$value' == 'Q&A' ? PostCategory.qa : PostCategory.free;
  String _categoryToApi(PostCategory category) => category.label;

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse('$value')?.toLocal();
  }

  int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
