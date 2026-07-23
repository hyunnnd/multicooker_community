part of '../settings_screen.dart';

class _SettingsNotificationSection extends StatelessWidget {
  const _SettingsNotificationSection({
    required this.settings,
    required this.disabled,
    required this.onChanged,
  });

  final NotificationSettings settings;
  final bool disabled;
  final void Function(NotificationSettings next, bool requestPermission) onChanged;

  ValueChanged<bool> _handler(NotificationSettings Function(bool value) builder) {
    if (disabled) return (_) {};
    return (value) => onChanged(builder(value), value);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return _SettingsSection(
      title: lang.t('알림', 'Notifications'),
      children: [
        _SettingsSwitchTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: lang.t('댓글·후기 알림', 'Comment & Review Notifications'),
          subtitle: lang.t(
            '내 게시글·레시피에 댓글 또는 후기가 등록될 때',
            'When a comment or review is added to my content',
          ),
          value: settings.comment,
          onChanged: _handler(
            (value) => settings.copyWith(comment: value),
          ),
        ),
        _SettingsSwitchTile(
          icon: Icons.subdirectory_arrow_right_rounded,
          title: lang.t('답글 알림', 'Reply Notifications'),
          subtitle: lang.t(
            '내 댓글에 새 답글이 달릴 때',
            'When someone replies to my comment',
          ),
          value: settings.reply,
          onChanged: _handler(
            (value) => settings.copyWith(reply: value),
          ),
        ),
        _SettingsSwitchTile(
          icon: Icons.favorite_border_rounded,
          title: lang.t('좋아요 알림', 'Like Notifications'),
          subtitle: lang.t(
            '내 게시글, 댓글, 후기 등에 좋아요가 눌릴 때',
            'When someone likes my community content',
          ),
          value: settings.like,
          onChanged: _handler(
            (value) => settings.copyWith(like: value),
          ),
        ),
        _SettingsSwitchTile(
          icon: Icons.campaign_outlined,
          title: lang.t('공지사항 알림', 'Notice Notifications'),
          subtitle: lang.t(
            '새로운 공지사항이 등록될 때',
            'When a new notice is published',
          ),
          value: settings.notice,
          onChanged: _handler(
            (value) => settings.copyWith(notice: value),
          ),
        ),
        _SettingsSwitchTile(
          icon: Icons.soup_kitchen_outlined,
          title: lang.t('조리 알림', 'Cooking Alerts'),
          subtitle: lang.t(
            '예열 완료와 조리 완료 알림 표시',
            'Show preheat and cooking completion alerts',
          ),
          value: settings.cooking,
          onChanged: disabled
              ? (_) {}
              : (value) => onChanged(
                    settings.copyWith(cooking: value),
                    value,
                  ),
        ),
      ],
    );
  }
}
