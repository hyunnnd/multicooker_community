import 'package:flutter/foundation.dart';

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
    required this.username,
    required this.avatarColor,
    required this.content,
    required this.timeAgo,
    required this.likes,
    this.isLiked = false,
    this.isMine = false,
  });

  final int id;
  final String username;
  final int avatarColor;
  final String content;
  final String timeAgo;
  final int likes;
  final bool isLiked;
  final bool isMine;

  CommunityReply copyWith({
    int? id,
    String? username,
    int? avatarColor,
    String? content,
    String? timeAgo,
    int? likes,
    bool? isLiked,
    bool? isMine,
  }) =>
      CommunityReply(
        id: id ?? this.id,
        username: username ?? this.username,
        avatarColor: avatarColor ?? this.avatarColor,
        content: content ?? this.content,
        timeAgo: timeAgo ?? this.timeAgo,
        likes: likes ?? this.likes,
        isLiked: isLiked ?? this.isLiked,
        isMine: isMine ?? this.isMine,
      );
}

@immutable
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.username,
    required this.avatarColor,
    required this.content,
    required this.timeAgo,
    required this.likes,
    required this.replies,
    this.isLiked = false,
    this.isMine = false,
  });

  final int id;
  final String username;
  final int avatarColor;
  final String content;
  final String timeAgo;
  final int likes;
  final bool isLiked;
  final bool isMine;
  final List<CommunityReply> replies;

  CommunityComment copyWith({
    int? id,
    String? username,
    int? avatarColor,
    String? content,
    String? timeAgo,
    int? likes,
    bool? isLiked,
    bool? isMine,
    List<CommunityReply>? replies,
  }) =>
      CommunityComment(
        id: id ?? this.id,
        username: username ?? this.username,
        avatarColor: avatarColor ?? this.avatarColor,
        content: content ?? this.content,
        timeAgo: timeAgo ?? this.timeAgo,
        likes: likes ?? this.likes,
        isLiked: isLiked ?? this.isLiked,
        isMine: isMine ?? this.isMine,
        replies: replies ?? this.replies,
      );
}

@immutable
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.category,
    required this.username,
    required this.avatarColor,
    required this.timeAgo,
    required this.title,
    required this.content,
    required this.likes,
    required this.comments,
    required this.activity,
    this.imageUrl,
    this.tags = const [],
    this.isLiked = false,
    this.isBookmarked = false,
    this.isMine = false,
  });

  final int id;
  final PostCategory category;
  final String username;
  final int avatarColor;
  final String timeAgo;
  final String title;
  final String content;
  final int likes;
  final List<CommunityComment> comments;
  final String? imageUrl;
  final List<String> tags;
  final ActivitySet activity;
  final bool isLiked;
  final bool isBookmarked;
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
    PostCategory? category,
    String? username,
    int? avatarColor,
    String? timeAgo,
    String? title,
    String? content,
    int? likes,
    List<CommunityComment>? comments,
    String? imageUrl,
    List<String>? tags,
    ActivitySet? activity,
    bool? isLiked,
    bool? isBookmarked,
    bool? isMine,
  }) =>
      CommunityPost(
        id: id ?? this.id,
        category: category ?? this.category,
        username: username ?? this.username,
        avatarColor: avatarColor ?? this.avatarColor,
        timeAgo: timeAgo ?? this.timeAgo,
        title: title ?? this.title,
        content: content ?? this.content,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        imageUrl: imageUrl ?? this.imageUrl,
        tags: tags ?? this.tags,
        activity: activity ?? this.activity,
        isLiked: isLiked ?? this.isLiked,
        isBookmarked: isBookmarked ?? this.isBookmarked,
        isMine: isMine ?? this.isMine,
      );
}

@immutable
class CommunityReview {
  const CommunityReview({
    required this.id,
    required this.username,
    required this.avatarColor,
    required this.recipeTitle,
    required this.recipeImage,
    required this.rating,
    required this.content,
    required this.date,
    required this.likes,
    required this.commentCount,
    required this.recipeId,
    this.recipeSource = '',
    this.cookingMode = '',
    this.foodCategory = '',
    this.themeTags = const [],
    this.isLiked = false,
  });

  final int id;
  final String username;
  final int avatarColor;
  final String recipeTitle;
  final String recipeImage;
  final int rating;
  final String content;
  final String date;
  final int likes;
  final int commentCount;
  final String recipeId;
  final String recipeSource;
  final String cookingMode;
  final String foodCategory;
  final List<String> themeTags;
  final bool isLiked;

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

  CommunityReview copyWith({int? likes, bool? isLiked}) => CommunityReview(
        id: id,
        username: username,
        avatarColor: avatarColor,
        recipeTitle: recipeTitle,
        recipeImage: recipeImage,
        rating: rating,
        content: content,
        date: date,
        likes: likes ?? this.likes,
        commentCount: commentCount,
        recipeId: recipeId,
        recipeSource: recipeSource,
        cookingMode: cookingMode,
        foodCategory: foodCategory,
        themeTags: themeTags,
        isLiked: isLiked ?? this.isLiked,
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
  });

  final int id;
  final String title;
  final String date;
  final String summary;
  final String content;
  final bool important;
}

enum NotificationType { comment, reply }

@immutable
class CommunityNotification {
  const CommunityNotification({
    required this.id,
    required this.type,
    required this.fromUser,
    required this.avatarColor,
    required this.postTitle,
    required this.postId,
    required this.timeAgo,
    required this.read,
  });

  final int id;
  final NotificationType type;
  final String fromUser;
  final int avatarColor;
  final String postTitle;
  final int postId;
  final String timeAgo;
  final bool read;

  CommunityNotification copyWith({bool? read}) => CommunityNotification(
        id: id,
        type: type,
        fromUser: fromUser,
        avatarColor: avatarColor,
        postTitle: postTitle,
        postId: postId,
        timeAgo: timeAgo,
        read: read ?? this.read,
      );
}
