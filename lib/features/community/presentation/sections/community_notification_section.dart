import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/community_models.dart';
import '../../provider/community_provider.dart';
import '../community_styles.dart';
import '../widgets/community_avatar.dart';

class CommunityNotificationSheet extends StatelessWidget {
  const CommunityNotificationSheet({required this.onOpenPost, super.key});

  final ValueChanged<int> onOpenPost;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final unread = provider.unreadCount;
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                children: [
                  const Text('알림', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  if (unread > 0)
                    TextButton(
                      onPressed: provider.markAllNotificationsRead,
                      child: const Text('모두 읽음', style: TextStyle(color: kCommunityOrange, fontWeight: FontWeight.w800)),
                    ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: provider.notifications.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (_, index) {
                  final notification = provider.notifications[index];
                  return _NotificationTile(
                    notification: notification,
                    onTap: () {
                      provider.openNotification(notification.id);
                      Navigator.pop(context);
                      onOpenPost(notification.postId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final CommunityNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommunityAvatar(username: notification.fromUser, colorValue: notification.avatarColor, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: kCommunityText, height: 1.35),
                      children: [
                        TextSpan(text: notification.fromUser, style: const TextStyle(fontWeight: FontWeight.w900)),
                        TextSpan(text: notification.type == NotificationType.comment ? '님이 내 글에 댓글을 달았어요' : '님이 내 댓글에 답글을 달았어요'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(notification.postContextText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 3),
                  Text(notification.relativeTime, style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB))),
                ],
              ),
            ),
            if (!notification.read) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: kCommunityOrange, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}
