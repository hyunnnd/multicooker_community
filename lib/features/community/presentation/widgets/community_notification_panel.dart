part of '../community_screen.dart';

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({required this.onClose, required this.onOpenPost});
  final VoidCallback onClose;
  final ValueChanged<int> onOpenPost;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final unread = provider.unreadCount;
    return Stack(
      children: [
        Positioned.fill(child: GestureDetector(onTap: onClose, child: Container(color: Colors.black.withOpacity(0.30)))),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 560),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      const Text('알림', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _text)),
                      if (unread > 0) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(999)),
                          child: Text('$unread', style: const TextStyle(fontSize: 10, color: Colors.white, height: 1)),
                        ),
                      ],
                      const Spacer(),
                      if (unread > 0)
                        GestureDetector(onTap: provider.markAllNotificationsRead, child: const Text('모두 읽음', style: TextStyle(fontSize: 12, color: _orange))),
                      const SizedBox(width: 18),
                      GestureDetector(onTap: onClose, child: const Icon(Icons.close, size: 18, color: _gray400)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _gray100),
                Flexible(
                  child: provider.notifications.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Column(children: [Icon(Icons.notifications_none, size: 28, color: _gray300), SizedBox(height: 8), Text('알림이 없습니다', style: TextStyle(fontSize: 13, color: _gray400))]),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: provider.notifications.length,
                          itemBuilder: (context, index) {
                            final item = provider.notifications[index];
                            return InkWell(
                              onTap: () async {
                                await provider.openNotification(item.id);
                                onClose();
                                onOpenPost(item.postId);
                              },
                              child: Container(
                                color: item.read ? Colors.white : _orange50,
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _Avatar(name: item.fromUser, color: Color(item.avatarColor), size: 36, fontSize: 13),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              text: item.fromUser,
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                              children: [TextSpan(text: item.type == NotificationType.reply ? '님이 내 댓글에 답글을 달았어요' : '님이 내 글에 댓글을 달았어요', style: const TextStyle(fontWeight: FontWeight.w400))],
                                            ),
                                            style: const TextStyle(fontSize: 13, height: 1.5, color: _text2),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(item.postContextText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _gray400)),
                                          const SizedBox(height: 2),
                                          Text(item.relativeTime, style: const TextStyle(fontSize: 11, color: _gray300)),
                                        ],
                                      ),
                                    ),
                                    if (!item.read) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 8), decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
