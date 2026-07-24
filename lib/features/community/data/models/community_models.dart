import 'package:flutter/foundation.dart';

String communityRelativeTime(DateTime? createdAt, {String fallback = ''}) {
  if (createdAt == null) return fallback;

  final now = DateTime.now();
  var difference = now.difference(createdAt.toLocal());
  if (difference.isNegative) difference = Duration.zero;

  if (difference.inSeconds < 60) return '방금 전';
  if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
  if (difference.inHours < 24) return '${difference.inHours}시간 전';
  if (difference.inDays == 1) return '어제';
  if (difference.inDays < 7) return '${difference.inDays}일 전';

  final local = createdAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
}


String communityDateTimeLabel(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}.$month.$day $hour:$minute';
}

bool communityWasEdited(DateTime? createdAt, DateTime? updatedAt) {
  if (createdAt == null || updatedAt == null) return false;
  return updatedAt.difference(createdAt).abs() > const Duration(seconds: 1);
}

enum CommunityTab {
  all('전체'),
  popular('인기'),
  free('자유'),
  review('후기'),
  qa('Q&A');

  const CommunityTab(this.label);
  final String label;
}

enum PostCategory {
  free('자유'),
  qa('Q&A');

  const PostCategory(this.label);
  final String label;
}

@immutable
class ActivityWindow {
  const ActivityWindow({required this.likes, required this.comments});

  final int likes;
  final int comments;

  int get score => likes + comments * 2;
}

@immutable
class ActivitySet {
  const ActivitySet({
    required this.d3,
    required this.d6,
    required this.d9,
    required this.d12,
  });

  final ActivityWindow d3;
  final ActivityWindow d6;
  final ActivityWindow d9;
  final ActivityWindow d12;

  ActivityWindow forDays(int days) => switch (days) {
        3 => d3,
        6 => d6,
        9 => d9,
        12 => d12,
        _ => d12,
      };
}

@immutable
class CommunityReply {
  const CommunityReply({
    required this.id,
    this.authorUserId,
    required this.username,
    required this.avatarColor,
    this.avatarImageUrl,
    required this.content,
    required this.timeAgo,
    this.createdAt,
    this.updatedAt,
    this.isAdmin = false,
    required this.likes,
    this.reportCount,
    this.isLiked = false,
    this.isMine = false,
  });

  final int id;
  final int? authorUserId;
  final String username;
  final int avatarColor;
  final String? avatarImageUrl;
  final String content;
  final String timeAgo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAdmin;
  String get relativeTime => communityRelativeTime(createdAt, fallback: timeAgo);
  bool get wasEdited => communityWasEdited(createdAt, updatedAt);
  final int likes;
  final int? reportCount;
  final bool isLiked;
  final bool isMine;

  CommunityReply copyWith({
    int? id,
    int? authorUserId,
    String? username,
    int? avatarColor,
    String? avatarImageUrl,
    String? content,
    String? timeAgo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdmin,
    int? likes,
    int? reportCount,
    bool? isLiked,
    bool? isMine,
  }) =>
      CommunityReply(
        id: id ?? this.id,
        authorUserId: authorUserId ?? this.authorUserId,
        username: username ?? this.username,
        avatarColor: avatarColor ?? this.avatarColor,
        avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
        content: content ?? this.content,
        timeAgo: timeAgo ?? this.timeAgo,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isAdmin: isAdmin ?? this.isAdmin,
        likes: likes ?? this.likes,
        reportCount: reportCount ?? this.reportCount,
        isLiked: isLiked ?? this.isLiked,
        isMine: isMine ?? this.isMine,
      );
}

@immutable
class CommunityComment {
  const CommunityComment({
    required this.id,
    this.authorUserId,
    required this.username,
    required this.avatarColor,
    this.avatarImageUrl,
    required this.content,
    required this.timeAgo,
    this.createdAt,
    this.updatedAt,
    this.isAdmin = false,
    required this.likes,
    required this.replies,
    this.reportCount,
    this.isLiked = false,
    this.isMine = false,
  });

  final int id;
  final int? authorUserId;
  final String username;
  final int avatarColor;
  final String? avatarImageUrl;
  final String content;
  final String timeAgo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAdmin;
  String get relativeTime => communityRelativeTime(createdAt, fallback: timeAgo);
  bool get wasEdited => communityWasEdited(createdAt, updatedAt);
  final int likes;
  final int? reportCount;
  final bool isLiked;
  final bool isMine;
  final List<CommunityReply> replies;

  CommunityComment copyWith({
    int? id,
    int? authorUserId,
    String? username,
    int? avatarColor,
    String? avatarImageUrl,
    String? content,
    String? timeAgo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdmin,
    int? likes,
    int? reportCount,
    bool? isLiked,
    bool? isMine,
    List<CommunityReply>? replies,
  }) =>
      CommunityComment(
        id: id ?? this.id,
        authorUserId: authorUserId ?? this.authorUserId,
        username: username ?? this.username,
        avatarColor: avatarColor ?? this.avatarColor,
        avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
        content: content ?? this.content,
        timeAgo: timeAgo ?? this.timeAgo,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isAdmin: isAdmin ?? this.isAdmin,
        likes: likes ?? this.likes,
        reportCount: reportCount ?? this.reportCount,
        isLiked: isLiked ?? this.isLiked,
        isMine: isMine ?? this.isMine,
        replies: replies ?? this.replies,
      );
}

@immutable
class CommunityPost {
  const CommunityPost({
    required this.id,
    this.authorUserId,
    required this.category,
    required this.username,
    required this.avatarColor,
    this.avatarImageUrl,
    required this.timeAgo,
    this.createdAt,
    this.updatedAt,
    this.isAdmin = false,
    required this.title,
    required this.content,
    required this.likes,
    required this.comments,
    required this.activity,
    this.imageUrl,
    this.tags = const [],
    this.reportCount,
    this.canAdminister = false,
    this.popularityScore = 0,
    this.adminPopularityBoost = 0,
    this.forcePopular = false,
    this.isPopular = false,
    this.isLiked = false,
    this.isMine = false,
  });

  final int id;
  final int? authorUserId;
  final PostCategory category;
  final String username;
  final int avatarColor;
  final String? avatarImageUrl;
  final String timeAgo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAdmin;
  String get relativeTime => communityRelativeTime(createdAt, fallback: timeAgo);
  bool get wasEdited => communityWasEdited(createdAt, updatedAt);
  String get editedLabel => communityDateTimeLabel(updatedAt);
  final String title;
  final String content;
  final int likes;
  final List<CommunityComment> comments;
  final String? imageUrl;
  final List<String> tags;
  final ActivitySet activity;
  final int? reportCount;
  final bool canAdminister;
  final int popularityScore;
  final int adminPopularityBoost;
  final bool forcePopular;
  final bool isPopular;
  final bool isLiked;
  final bool isMine;

  int get commentCount => comments.fold<int>(0, (sum, comment) => sum + 1 + comment.replies.length);
  String get searchableText => [
        username,
        category.label,
        title,
        content,
        ...tags,
      ].join(' ').toLowerCase();

  CommunityPost copyWith({
    int? id,
    int? authorUserId,
    PostCategory? category,
    String? username,
    int? avatarColor,
    String? avatarImageUrl,
    String? timeAgo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdmin,
    String? title,
    String? content,
    int? likes,
    List<CommunityComment>? comments,
    String? imageUrl,
    List<String>? tags,
    ActivitySet? activity,
    int? reportCount,
    bool? canAdminister,
    int? popularityScore,
    int? adminPopularityBoost,
    bool? forcePopular,
    bool? isPopular,
    bool? isLiked,
    bool? isMine,
  }) =>
      CommunityPost(
        id: id ?? this.id,
        authorUserId: authorUserId ?? this.authorUserId,
        category: category ?? this.category,
        username: username ?? this.username,
        avatarColor: avatarColor ?? this.avatarColor,
        avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
        timeAgo: timeAgo ?? this.timeAgo,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isAdmin: isAdmin ?? this.isAdmin,
        title: title ?? this.title,
        content: content ?? this.content,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        imageUrl: imageUrl ?? this.imageUrl,
        tags: tags ?? this.tags,
        activity: activity ?? this.activity,
        reportCount: reportCount ?? this.reportCount,
        canAdminister: canAdminister ?? this.canAdminister,
        popularityScore: popularityScore ?? this.popularityScore,
        adminPopularityBoost: adminPopularityBoost ?? this.adminPopularityBoost,
        forcePopular: forcePopular ?? this.forcePopular,
        isPopular: isPopular ?? this.isPopular,
        isLiked: isLiked ?? this.isLiked,
        isMine: isMine ?? this.isMine,
      );
}

@immutable
class CommunityReview {
  const CommunityReview({
    required this.id,
    this.authorUserId,
    required this.username,
    required this.avatarColor,
    this.avatarImageUrl,
    required this.recipeTitle,
    required this.recipeImage,
    this.reviewImageUrl,
    required this.rating,
    required this.content,
    required this.date,
    this.createdAt,
    this.updatedAt,
    this.isAdmin = false,
    required this.likes,
    required this.commentCount,
    required this.recipeId,
    this.recipeSource = '',
    this.cookingMode = '',
    this.foodCategory = '',
    this.themeTags = const [],
    this.isLiked = false,
    this.isMine = false,
  });

  final int id;
  final int? authorUserId;
  final String username;
  final int avatarColor;
  final String? avatarImageUrl;
  final String recipeTitle;
  final String recipeImage;
  final String? reviewImageUrl;
  final int rating;
  final String content;
  final String date;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAdmin;
  String get relativeTime => communityRelativeTime(createdAt, fallback: date);
  bool get wasEdited => communityWasEdited(createdAt, updatedAt);
  final int likes;
  final int commentCount;
  final String recipeId;
  final String recipeSource;
  final String cookingMode;
  final String foodCategory;
  final List<String> themeTags;
  final bool isLiked;
  final bool isMine;

  String get sourceLabel {
    if (recipeSource.trim().isNotEmpty) return recipeSource;
    final key = '$recipeId $recipeTitle'.toLowerCase();
    if (key.contains('user') || key.contains('10분') || key.contains('리조또') || key.contains('닭갈비')) {
      return '사용자 공유';
    }
    return '공식';
  }

  String get cookingModeLabel {
    if (cookingMode.trim().isNotEmpty) return cookingMode;
    final key = '$recipeId $recipeTitle $content'.toLowerCase();
    if (key.contains('full') || key.contains('auto') || recipeTitle.contains('밥') || recipeTitle.contains('계란')) return 'Full Auto';
    if (key.contains('quick') || recipeTitle.contains('10분')) return 'Quick Cook';
    if (key.contains('professional') || recipeTitle.contains('리조또') || recipeTitle.contains('닭갈비')) return 'Professional';
    return 'Guided Cook';
  }

  String get foodCategoryLabel {
    if (foodCategory.trim().isNotEmpty) return foodCategory;
    final key = '$recipeId $recipeTitle $content';
    if (key.contains('삼겹') || key.contains('스테이크') || key.contains('수육') || key.contains('닭')) return '고기';
    if (key.contains('밥') || key.contains('리조또')) return '밥/면';
    if (key.contains('새우') || key.contains('해산물')) return '해산물';
    if (key.contains('계란') || key.contains('찜')) return '찜/계란';
    return '기타';
  }

  List<String> get effectiveThemeTags {
    if (themeTags.isNotEmpty) return themeTags;
    final tags = <String>[];
    if (date.isNotEmpty) tags.add('최근 후기');
    final key = '$recipeTitle $content';
    if (key.contains('간편') || key.contains('짧') || key.contains('10분')) tags.add('간단요리');
    if (key.contains('가족') || key.contains('남편') || key.contains('저녁')) tags.add('한끼식사');
    if (key.contains('스테이크') || key.contains('식당') || key.contains('프리미엄')) tags.add('고급요리');
    if (key.contains('아이') || key.contains('계란')) tags.add('아이간식');
    return tags.isEmpty ? const ['한끼식사'] : tags;
  }

  bool matchesRecipe(String recipeIdFilter, String? recipeTitleFilter) {
    final idMatch = recipeIdFilter.isNotEmpty && recipeId == recipeIdFilter;
    final title = recipeTitleFilter?.trim();
    final titleMatch = title != null && title.isNotEmpty && recipeTitle.contains(title);
    return idMatch || titleMatch;
  }

  CommunityReview copyWith({
    String? username,
    int? avatarColor,
    String? avatarImageUrl,
    int? likes,
    bool? isLiked,
  }) => CommunityReview(
        id: id,
        authorUserId: authorUserId,
        username: username ?? this.username,
        avatarColor: avatarColor ?? this.avatarColor,
        avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
        recipeTitle: recipeTitle,
        recipeImage: recipeImage,
        reviewImageUrl: reviewImageUrl,
        rating: rating,
        content: content,
        date: date,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isAdmin: isAdmin,
        likes: likes ?? this.likes,
        commentCount: commentCount,
        recipeId: recipeId,
        recipeSource: recipeSource,
        cookingMode: cookingMode,
        foodCategory: foodCategory,
        themeTags: themeTags,
        isLiked: isLiked ?? this.isLiked,
        isMine: isMine,
      );
}

@immutable
class RecipeCommunityComment {
  const RecipeCommunityComment({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    this.authorUserId,
    required this.username,
    required this.avatarColor,
    this.avatarImageUrl,
    required this.content,
    this.createdAt,
    this.isMine = false,
    this.isRecipeAuthor = false,
  });

  final int id;
  final String recipeId;
  final String recipeTitle;
  final int? authorUserId;
  final String username;
  final int avatarColor;
  final String? avatarImageUrl;
  final String content;
  final DateTime? createdAt;
  final bool isMine;
  final bool isRecipeAuthor;

  String get relativeTime => communityRelativeTime(createdAt);

  RecipeCommunityComment copyWith({
    String? username,
    int? avatarColor,
    String? avatarImageUrl,
    String? content,
  }) => RecipeCommunityComment(
        id: id,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        authorUserId: authorUserId,
        username: username ?? this.username,
        avatarColor: avatarColor ?? this.avatarColor,
        avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
        content: content ?? this.content,
        createdAt: createdAt,
        isMine: isMine,
        isRecipeAuthor: isRecipeAuthor,
      );
}

@immutable
class CommunityNotice {
  const CommunityNotice({
    required this.id,
    required this.title,
    required this.date,
    required this.summary,
    required this.content,
    required this.important,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String date;
  final String summary;
  final String content;
  final bool important;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get wasEdited => communityWasEdited(createdAt, updatedAt);
  String get editedLabel => communityDateTimeLabel(updatedAt);
}

@immutable
class AdminCommunityReport {
  const AdminCommunityReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.reporter,
    required this.targetTitle,
    required this.targetContent,
    required this.targetAuthor,
    required this.targetReportCount,
    required this.targetExists,
    required this.createdAt,
    this.adminNote = '',
    this.processedBy = '',
    this.processedAt,
  });

  final int id;
  final String targetType;
  final int targetId;
  final String reason;
  final String status;
  final String reporter;
  final String targetTitle;
  final String targetContent;
  final String targetAuthor;
  final int targetReportCount;
  final bool targetExists;
  final DateTime? createdAt;
  final String adminNote;
  final String processedBy;
  final DateTime? processedAt;

  String get typeLabel => switch (targetType) {
        'comment' => '댓글',
        'reply' => '답글',
        _ => '게시글',
      };

  String get statusLabel => switch (status) {
        'resolved' => '처리 완료',
        'rejected' => '반려',
        _ => '미처리',
      };
}

@immutable
class AdminReportSummary {
  const AdminReportSummary({
    this.total = 0,
    this.pending = 0,
    this.resolved = 0,
    this.rejected = 0,
  });

  final int total;
  final int pending;
  final int resolved;
  final int rejected;
}

class CommunityBlockedUser {
  const CommunityBlockedUser({
    required this.id,
    this.userId,
    required this.username,
    this.createdAt,
  });

  final int id;
  final int? userId;
  final String username;
  final DateTime? createdAt;
}

@immutable
class CommunityAuthorRecipe {
  const CommunityAuthorRecipe({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    this.thumbnailUrl,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String author;
  final String? thumbnailUrl;
  final DateTime? createdAt;
}

@immutable
class CommunityAuthorProfile {
  const CommunityAuthorProfile({
    required this.userId,
    required this.nickname,
    required this.avatarColor,
    this.avatarImageUrl,
    this.isAdmin = false,
    this.posts = const [],
    this.publicRecipes = const [],
  });

  final int userId;
  final String nickname;
  final int avatarColor;
  final String? avatarImageUrl;
  final bool isAdmin;
  final List<CommunityPost> posts;
  final List<CommunityAuthorRecipe> publicRecipes;

  int get postCount => posts.length;
  int get publicRecipeCount => publicRecipes.length;
}

enum NotificationType { comment, reply, recipeComment, recipeReview, like, notice }

@immutable
class CommunityNotification {
  const CommunityNotification({
    required this.id,
    required this.type,
    required this.fromUser,
    this.fromUserId,
    required this.avatarColor,
    this.avatarImageUrl,
    required this.postTitle,
    this.contextText = '',
    required this.postId,
    this.recipeId = '',
    this.noticeId,
    this.targetCommentId,
    this.targetReplyId,
    this.targetRecipeCommentId,
    this.targetReviewId,
    required this.timeAgo,
    this.createdAt,
    required this.read,
  });

  final int id;
  final NotificationType type;
  final String fromUser;
  final int? fromUserId;
  final int avatarColor;
  final String? avatarImageUrl;
  final String postTitle;
  final String contextText;
  final int postId;
  final String recipeId;
  final int? noticeId;
  final int? targetCommentId;
  final int? targetReplyId;
  final int? targetRecipeCommentId;
  final int? targetReviewId;
  final String timeAgo;
  final DateTime? createdAt;
  String get relativeTime => communityRelativeTime(createdAt, fallback: timeAgo);

  /// 알림을 발생시킨 사용자가 새로 작성한 내용을 표시합니다.
  /// 댓글 알림은 새 댓글, 답글 알림은 새 답글 내용입니다.
  /// 게시글 제목이나 원댓글 대신 실제 등록된 내용을 보여줍니다.
  String get postContextText {
    String clean(String value) => value
        .trim()
        .replaceAll(RegExp(r'^[|ㅣ｜\s]+'), '')
        .replaceAll(RegExp(r'[|ㅣ｜\s]+$'), '')
        .trim();

    final context = clean(contextText);
    if (context.isNotEmpty) return context;

    final legacyTitle = clean(postTitle);
    return legacyTitle.isEmpty ? '게시글' : legacyTitle;
  }

  final bool read;

  bool get isRecipeNotification => recipeId.trim().isNotEmpty;
  bool get isNoticeNotification => type == NotificationType.notice && noticeId != null;

  String get phoneMessage => switch (type) {
        NotificationType.reply => '$fromUser님이 내 댓글에 답글을 달았습니다.',
        NotificationType.recipeComment => '$fromUser님이 내 레시피에 댓글을 남겼습니다.',
        NotificationType.recipeReview => '$fromUser님이 내 레시피에 후기를 남겼습니다.',
        NotificationType.like => '$fromUser님이 내 글에 좋아요를 눌렀습니다.',
        NotificationType.notice => '새 공지사항이 등록되었습니다.',
        NotificationType.comment => '$fromUser님이 내 글에 댓글을 달았습니다.',
      };

  String get routePath => isNoticeNotification
      ? '/community?noticeId=$noticeId'
      : isRecipeNotification
          ? '/recipes/${Uri.encodeComponent(recipeId.trim())}'
          : Uri(
              path: '/community',
              queryParameters: {
                'postId': '$postId',
                if (targetCommentId != null) 'commentId': '$targetCommentId',
                if (targetReplyId != null) 'replyId': '$targetReplyId',
              },
            ).toString();

  CommunityNotification copyWith({
    String? fromUser,
    int? avatarColor,
    String? avatarImageUrl,
    bool? read,
  }) => CommunityNotification(
        id: id,
        type: type,
        fromUser: fromUser ?? this.fromUser,
        fromUserId: fromUserId,
        avatarColor: avatarColor ?? this.avatarColor,
        avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
        postTitle: postTitle,
        contextText: contextText,
        postId: postId,
        recipeId: recipeId,
        noticeId: noticeId,
        targetCommentId: targetCommentId,
        targetReplyId: targetReplyId,
        targetRecipeCommentId: targetRecipeCommentId,
        targetReviewId: targetReviewId,
        timeAgo: timeAgo,
        createdAt: createdAt,
        read: read ?? this.read,
      );
}
