class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.email,
    required this.nickname,
    required this.avatarColor,
    required this.recipeCount,
    required this.reviewCount,
    required this.commentCount,
    required this.cookingHistoryCount,
    required this.savedRecipeCount,
    required this.deviceCount,
  });

  final int id;
  final String email;
  final String nickname;
  final int avatarColor;
  final int recipeCount;
  final int reviewCount;
  final int commentCount;
  final int cookingHistoryCount;
  final int savedRecipeCount;
  final int deviceCount;

  factory ProfileSummary.fromJson(Map<String, dynamic> json) => ProfileSummary(
        id: _asInt(json['id']),
        email: _asString(json['email']),
        nickname: _asString(json['nickname'], fallback: 'GrapheneUser'),
        avatarColor: _asInt(json['avatar_color'], fallback: 0xFFFF8C42),
        recipeCount: _asInt(json['recipe_count']),
        reviewCount: _asInt(json['review_count']),
        commentCount: _asInt(json['comment_count']),
        cookingHistoryCount: _asInt(json['cooking_history_count']),
        savedRecipeCount: _asInt(json['saved_recipe_count']),
        deviceCount: _asInt(json['device_count']),
      );
}

class ProfileRecipeItem {
  const ProfileRecipeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.totalTimeMin,
    required this.maxTemperature,
    this.thumbnailUrl,
    this.savedAt,
    this.createdAt,
    this.isOfficial = false,
    this.isPersonal = false,
  });

  final String id;
  final String title;
  final String description;
  final String author;
  final int totalTimeMin;
  final int maxTemperature;
  final String? thumbnailUrl;
  final String? savedAt;
  final String? createdAt;
  final bool isOfficial;
  final bool isPersonal;

  factory ProfileRecipeItem.fromJson(Map<String, dynamic> json) => ProfileRecipeItem(
        id: _asString(json['client_id'] ?? json['id']),
        title: _asString(json['title'], fallback: '이름 없는 레시피'),
        description: _asString(json['description']),
        author: _asString(json['author'], fallback: 'Graphene Square'),
        totalTimeMin: _asInt(json['total_time_min'], fallback: 10),
        maxTemperature: _asInt(json['max_temperature'], fallback: 180),
        thumbnailUrl: _nullableString(json['thumbnail_url']),
        savedAt: _nullableString(json['saved_at']),
        createdAt: _nullableString(json['created_at']),
        isOfficial: _asBool(json['is_official']),
        isPersonal: _asBool(json['is_personal']),
      );
}

class MyReviewItem {
  const MyReviewItem({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    required this.recipeImage,
    required this.rating,
    required this.content,
    required this.date,
    required this.likes,
    required this.commentCount,
  });

  final int id;
  final String recipeId;
  final String recipeTitle;
  final String recipeImage;
  final int rating;
  final String content;
  final String date;
  final int likes;
  final int commentCount;

  factory MyReviewItem.fromJson(Map<String, dynamic> json) => MyReviewItem(
        id: _asInt(json['id']),
        recipeId: _asString(json['recipe_id']),
        recipeTitle: _asString(json['recipe_title'], fallback: '레시피'),
        recipeImage: _asString(json['recipe_image']),
        rating: _asInt(json['rating'], fallback: 5),
        content: _asString(json['content']),
        date: _asString(json['date']),
        likes: _asInt(json['likes']),
        commentCount: _asInt(json['comment_count']),
      );
}

class MyCommentItem {
  const MyCommentItem({
    required this.id,
    required this.type,
    required this.postId,
    required this.postTitle,
    required this.postCategory,
    required this.content,
    required this.timeAgo,
    this.commentId,
    this.createdAt,
  });

  final int id;
  final String type;
  final int postId;
  final int? commentId;
  final String postTitle;
  final String postCategory;
  final String content;
  final String timeAgo;
  final String? createdAt;

  bool get isReply => type == 'reply';

  factory MyCommentItem.fromJson(Map<String, dynamic> json) => MyCommentItem(
        id: _asInt(json['id']),
        type: _asString(json['type'], fallback: 'comment'),
        postId: _asInt(json['post_id']),
        commentId: json['comment_id'] == null ? null : _asInt(json['comment_id']),
        postTitle: _asString(json['post_title'], fallback: '게시글'),
        postCategory: _asString(json['post_category'], fallback: '커뮤니티'),
        content: _asString(json['content']),
        timeAgo: _asString(json['time_ago']),
        createdAt: _nullableString(json['created_at']),
      );
}

class CookingHistoryItem {
  const CookingHistoryItem({
    required this.id,
    required this.recipeTitle,
    required this.deviceName,
    required this.status,
    required this.totalTimeMin,
    required this.maxTemperature,
    this.recipeId,
    this.startedAt,
    this.finishedAt,
    this.memo = '',
    this.steps = const [],
  });

  final int id;
  final String? recipeId;
  final String recipeTitle;
  final String deviceName;
  final String status;
  final int totalTimeMin;
  final int maxTemperature;
  final String? startedAt;
  final String? finishedAt;
  final String memo;
  final List<Map<String, dynamic>> steps;

  bool get completed => status == 'completed' || status == '완료';
  bool get cancelled => status == 'cancelled' || status == 'stopped' || status == '중단';

  factory CookingHistoryItem.fromJson(Map<String, dynamic> json) => CookingHistoryItem(
        id: _asInt(json['id']),
        recipeId: _nullableString(json['client_recipe_id'] ?? json['recipe_id']),
        recipeTitle: _asString(json['recipe_title'], fallback: '직접 조리'),
        deviceName: _asString(json['device_name'], fallback: 'Graphene Multi-Cooker'),
        status: _asString(json['status'], fallback: 'completed'),
        totalTimeMin: _asInt(json['total_time_min']),
        maxTemperature: _asInt(json['max_temperature']),
        startedAt: _nullableString(json['started_at']),
        finishedAt: _nullableString(json['finished_at']),
        memo: _asString(json['memo']),
        steps: (json['steps'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false),
      );
}

class ProfileSettings {
  const ProfileSettings({
    required this.cookingNotification,
    required this.communityNotification,
    required this.marketingNotification,
    required this.language,
    required this.tutorialCompleted,
  });

  final bool cookingNotification;
  final bool communityNotification;
  final bool marketingNotification;
  final String language;
  final bool tutorialCompleted;

  factory ProfileSettings.fromJson(Map<String, dynamic> json) => ProfileSettings(
        cookingNotification: _asBool(json['cooking_notification'], fallback: true),
        communityNotification: _asBool(json['community_notification'], fallback: true),
        marketingNotification: _asBool(json['marketing_notification']),
        language: _asString(json['language'], fallback: 'ko'),
        tutorialCompleted: _asBool(json['tutorial_completed']),
      );

  Map<String, dynamic> toJson() => {
        'cooking_notification': cookingNotification,
        'community_notification': communityNotification,
        'marketing_notification': marketingNotification,
        'language': language,
        'tutorial_completed': tutorialCompleted,
      };

  ProfileSettings copyWith({
    bool? cookingNotification,
    bool? communityNotification,
    bool? marketingNotification,
    String? language,
    bool? tutorialCompleted,
  }) =>
      ProfileSettings(
        cookingNotification: cookingNotification ?? this.cookingNotification,
        communityNotification: communityNotification ?? this.communityNotification,
        marketingNotification: marketingNotification ?? this.marketingNotification,
        language: language ?? this.language,
        tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      );
}

class RegisteredDeviceItem {
  const RegisteredDeviceItem({
    required this.id,
    required this.macAddress,
    required this.deviceName,
    required this.displayName,
    required this.serialNumber,
    required this.autoReconnect,
    required this.verified,
    this.alias = '',
    this.firmwareVersion = '',
    this.lastConnectedAt,
  });

  final int id;
  final String macAddress;
  final String deviceName;
  final String displayName;
  final String serialNumber;
  final String alias;
  final String firmwareVersion;
  final bool autoReconnect;
  final bool verified;
  final String? lastConnectedAt;

  factory RegisteredDeviceItem.fromJson(Map<String, dynamic> json) => RegisteredDeviceItem(
        id: _asInt(json['id']),
        macAddress: _asString(json['mac_address']),
        deviceName: _asString(json['device_name'], fallback: 'Graphene Multi-Cooker'),
        displayName: _asString(json['display_name'], fallback: 'Graphene Multi-Cooker'),
        serialNumber: _asString(json['serial_number']),
        alias: _asString(json['alias']),
        firmwareVersion: _asString(json['firmware_version']),
        autoReconnect: _asBool(json['auto_reconnect'], fallback: true),
        verified: _asBool(json['verified'], fallback: true),
        lastConnectedAt: _nullableString(json['last_connected_at']),
      );
}

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}
