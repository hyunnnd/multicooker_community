class NotificationSettings {
  const NotificationSettings({
    this.cooking = true,
    this.community = true,
    this.comment = true,
    this.reply = true,
    this.like = true,
    this.notice = true,
    this.marketing = false,
  });

  final bool cooking;
  final bool community;
  final bool comment;
  final bool reply;
  final bool like;
  final bool notice;
  final bool marketing;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final community = _settingsBool(json['community_notification'], fallback: true);
    return NotificationSettings(
      cooking: _settingsBool(json['cooking_notification'], fallback: true),
      community: community,
      comment: _settingsBool(json['comment_notification'], fallback: community),
      reply: _settingsBool(json['reply_notification'], fallback: community),
      like: _settingsBool(json['like_notification'], fallback: community),
      notice: _settingsBool(json['notice_notification'], fallback: community),
      marketing: _settingsBool(json['marketing_notification']),
    );
  }

  Map<String, dynamic> toJson() => {
        'cooking_notification': cooking,
        'community_notification': community,
        'comment_notification': comment,
        'reply_notification': reply,
        'like_notification': like,
        'notice_notification': notice,
        'marketing_notification': marketing,
      };

  NotificationSettings copyWith({
    bool? cooking,
    bool? community,
    bool? comment,
    bool? reply,
    bool? like,
    bool? notice,
    bool? marketing,
  }) {
    final nextComment = comment ?? this.comment;
    final nextReply = reply ?? this.reply;
    final nextLike = like ?? this.like;
    final nextNotice = notice ?? this.notice;
    return NotificationSettings(
      cooking: cooking ?? this.cooking,
      community: community ?? (nextComment || nextReply || nextLike || nextNotice),
      comment: nextComment,
      reply: nextReply,
      like: nextLike,
      notice: nextNotice,
      marketing: marketing ?? this.marketing,
    );
  }
}

class BehaviorSettings {
  const BehaviorSettings({
    this.autoReconnect = true,
    this.slimeEnabled = true,
  });

  final bool autoReconnect;
  final bool slimeEnabled;

  factory BehaviorSettings.fromJson(Map<String, dynamic> json) => BehaviorSettings(
        autoReconnect: _settingsBool(json['auto_reconnect'], fallback: true),
        slimeEnabled: _settingsBool(json['slime_enabled'], fallback: true),
      );

  Map<String, dynamic> toJson() => {
        'auto_reconnect': autoReconnect,
        'slime_enabled': slimeEnabled,
      };

  BehaviorSettings copyWith({bool? autoReconnect, bool? slimeEnabled}) =>
      BehaviorSettings(
        autoReconnect: autoReconnect ?? this.autoReconnect,
        slimeEnabled: slimeEnabled ?? this.slimeEnabled,
      );
}

class LocalizationSettings {
  const LocalizationSettings({this.language = 'ko'});

  final String language;

  factory LocalizationSettings.fromJson(Map<String, dynamic> json) =>
      LocalizationSettings(
        language: _settingsString(json['language'], fallback: 'ko'),
      );

  Map<String, dynamic> toJson() => {'language': language};

  LocalizationSettings copyWith({String? language}) =>
      LocalizationSettings(language: language ?? this.language);
}

class TutorialSettings {
  const TutorialSettings({this.completed = false});

  final bool completed;

  factory TutorialSettings.fromJson(Map<String, dynamic> json) => TutorialSettings(
        completed: _settingsBool(json['tutorial_completed']),
      );

  Map<String, dynamic> toJson() => {'tutorial_completed': completed};

  TutorialSettings copyWith({bool? completed}) =>
      TutorialSettings(completed: completed ?? this.completed);
}

class ProfileSettings {
  const ProfileSettings({
    this.notifications = const NotificationSettings(),
    this.behavior = const BehaviorSettings(),
    this.localization = const LocalizationSettings(),
    this.tutorial = const TutorialSettings(),
  });

  final NotificationSettings notifications;
  final BehaviorSettings behavior;
  final LocalizationSettings localization;
  final TutorialSettings tutorial;

  static const defaults = ProfileSettings();

  // 기존 사용처와의 호환용 읽기 전용 getter입니다.
  bool get cookingNotification => notifications.cooking;
  bool get communityNotification => notifications.community;
  bool get commentNotification => notifications.comment;
  bool get replyNotification => notifications.reply;
  bool get likeNotification => notifications.like;
  bool get noticeNotification => notifications.notice;
  bool get marketingNotification => notifications.marketing;
  bool get autoReconnect => behavior.autoReconnect;
  bool get slimeEnabled => behavior.slimeEnabled;
  String get language => localization.language;
  bool get tutorialCompleted => tutorial.completed;

  factory ProfileSettings.fromJson(Map<String, dynamic> json) => ProfileSettings(
        notifications: NotificationSettings.fromJson(json),
        behavior: BehaviorSettings.fromJson(json),
        localization: LocalizationSettings.fromJson(json),
        tutorial: TutorialSettings.fromJson(json),
      );

  Map<String, dynamic> toJson() => {
        ...notifications.toJson(),
        ...behavior.toJson(),
        ...localization.toJson(),
        ...tutorial.toJson(),
      };

  ProfileSettings copyWith({
    NotificationSettings? notifications,
    BehaviorSettings? behavior,
    LocalizationSettings? localization,
    TutorialSettings? tutorial,
    // 호환용 flat 인자입니다. 새 코드는 기능별 모델을 전달하는 방식을 사용합니다.
    bool? cookingNotification,
    bool? communityNotification,
    bool? commentNotification,
    bool? replyNotification,
    bool? likeNotification,
    bool? noticeNotification,
    bool? marketingNotification,
    bool? autoReconnect,
    bool? slimeEnabled,
    String? language,
    bool? tutorialCompleted,
  }) {
    final nextNotifications = (notifications ?? this.notifications).copyWith(
      cooking: cookingNotification,
      community: communityNotification,
      comment: commentNotification,
      reply: replyNotification,
      like: likeNotification,
      notice: noticeNotification,
      marketing: marketingNotification,
    );
    return ProfileSettings(
      notifications: nextNotifications,
      behavior: (behavior ?? this.behavior).copyWith(
        autoReconnect: autoReconnect,
        slimeEnabled: slimeEnabled,
      ),
      localization: (localization ?? this.localization).copyWith(language: language),
      tutorial: (tutorial ?? this.tutorial).copyWith(completed: tutorialCompleted),
    );
  }

  ProfileSettings withCommunityNotificationType({
    bool? comment,
    bool? reply,
    bool? like,
    bool? notice,
  }) => copyWith(
        notifications: notifications.copyWith(
          comment: comment,
          reply: reply,
          like: like,
          notice: notice,
        ),
      );
}

bool _settingsBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

String _settingsString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}
