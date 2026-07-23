part of 'settings_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _requested = false;
  final Set<int> _pending = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityProvider>().loadBlockedUsers();
    });
  }

  Future<void> _unblock(int blockId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('차단을 해제하시겠습니까?'),
        content: Text('$username님의 게시글과 댓글이 다시 표시됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('차단 해제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _pending.add(blockId));
    final ok = await context.read<CommunityProvider>().unblockUser(blockId);
    if (!mounted) return;
    setState(() => _pending.remove(blockId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '$username님의 차단을 해제했습니다.' : '차단을 해제하지 못했습니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final users = provider.blockedUsers;
    return Scaffold(
      backgroundColor: _bg,
      appBar: const SectionPageAppBar(title: '차단 사용자 관리'),
      body: RefreshIndicator(
        onRefresh: () => provider.loadBlockedUsers(),
        child: users.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                children: const [
                  Icon(Icons.person_off_outlined, size: 44, color: _gray400),
                  SizedBox(height: 14),
                  Text(
                    '차단한 사용자가 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _gray800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '커뮤니티에서 차단한 사용자가 여기에 표시됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: _gray400),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = users[index];
                  final username = item.username.trim().isEmpty
                      ? '알 수 없는 사용자'
                      : item.username;
                  final pending = _pending.contains(item.id);
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _gray100),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _gray100,
                          child: Text(
                            username.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: _gray500,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: _gray900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                '게시글·댓글·알림이 숨겨져 있습니다.',
                                style: TextStyle(fontSize: 12, color: _gray400),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: pending
                              ? null
                              : () => _unblock(item.id, username),
                          child: pending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('해제'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
