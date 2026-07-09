part of '../community_screen.dart';

class _CommunityList extends StatelessWidget {
  const _CommunityList({
    required this.showSearch,
    required this.searchController,
    required this.onSearchToggle,
    required this.onNoticeTap,
    required this.onPostTap,
    required this.onWriteTap,
    required this.onWriteReviewTap,
    required this.onNotificationTap,
    required this.onRecipeTap,
  });

  final bool showSearch;
  final TextEditingController searchController;
  final ValueChanged<bool> onSearchToggle;
  final ValueChanged<int> onNoticeTap;
  final ValueChanged<int> onPostTap;
  final VoidCallback onWriteTap;
  final VoidCallback onWriteReviewTap;
  final VoidCallback onNotificationTap;
  final ValueChanged<String> onRecipeTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final posts = provider.filteredPosts();
    final popular = provider.popularPosts();
    final notice = provider.pinnedNotice;
    final query = provider.searchQuery;

    return Stack(
      children: [
        Column(
          children: [
            _CommunityHeader(
              showSearch: showSearch,
              searchController: searchController,
              onSearchToggle: onSearchToggle,
              onNotificationTap: onNotificationTap,
            ),
            Expanded(
              child: RefreshIndicator(
                color: _orange,
                onRefresh: () => context.read<CommunityProvider>().load(),
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (provider.activeTab == CommunityTab.all && query.isEmpty && notice != null)
                      _PinnedNotice(notice: notice, onTap: () => onNoticeTap(notice.id)),
                    if (provider.errorMessage != null)
                      _ErrorBlock(message: provider.errorMessage!, onRetry: () => provider.load())
                    else if (posts.isEmpty)
                      _EmptyBlock(searching: query.isNotEmpty)
                    else ...[
                      if (provider.activeTab == CommunityTab.popular && popular.days > 0)
                        _PopularInfo(days: popular.days),
                      const SizedBox(height: 8),
                      for (final post in posts) ...[
                        _PostCard(
                          post: post,
                          onTap: () => onPostTap(post.id),
                          onLike: () => provider.togglePostLike(post.id),
                          onBookmark: () => provider.toggleBookmark(post.id),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 88),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
            right: 16,
            bottom: 16,
            child: Material(
              color: _orange,
              borderRadius: BorderRadius.circular(999),
              elevation: 3,
              child: InkWell(
                onTap: onWriteTap,
                borderRadius: BorderRadius.circular(999),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Text('+', style: TextStyle(fontSize: 24, height: 1, color: Colors.white, fontWeight: FontWeight.w400)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({
    required this.showSearch,
    required this.searchController,
    required this.onSearchToggle,
    required this.onNotificationTap,
  });

  final bool showSearch;
  final TextEditingController searchController;
  final ValueChanged<bool> onSearchToggle;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          if (showSearch)
            Row(
              children: [
                GestureDetector(
                  onTap: () => onSearchToggle(false),
                  child: const SizedBox(width: 28, height: 36, child: Icon(Icons.arrow_back, size: 20, color: _text2)),
                ),
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: _gray100, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 15, color: _gray400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            onChanged: context.read<CommunityProvider>().setSearchQuery,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              hintText: '제목, 내용으로 검색...',
                              hintStyle: TextStyle(fontSize: 13, color: _gray400),
                            ),
                            style: const TextStyle(fontSize: 13, color: _text2),
                          ),
                        ),
                        if (searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              searchController.clear();
                              context.read<CommunityProvider>().setSearchQuery('');
                            },
                            child: const Icon(Icons.close, size: 14, color: _gray400),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Expanded(child: SizedBox()),
                const Text('커뮤니티', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _text)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: onNotificationTap,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.notifications_none, size: 21, color: _text2),
                            ),
                            if (provider.unreadCount > 0)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
                                  child: Text('${provider.unreadCount}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      GestureDetector(
                        onTap: () => onSearchToggle(true),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.search, size: 21, color: _text2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 11),
          Row(
            children: [
              for (final tab in _tabOrder)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.read<CommunityProvider>().setTab(tab),
                    child: SizedBox(
                      height: 38,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.1,
                              fontWeight: provider.activeTab == tab ? FontWeight.w700 : FontWeight.w400,
                              color: provider.activeTab == tab ? _orange : _gray500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: provider.activeTab == tab ? 20 : 0,
                            height: 2,
                            decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(999)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (provider.searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    text: '"',
                    children: [
                      TextSpan(text: provider.searchQuery, style: const TextStyle(color: _orange, fontWeight: FontWeight.w600)),
                      TextSpan(text: '" 결과 ${provider.filteredPosts().length}건'),
                    ],
                  ),
                  style: const TextStyle(fontSize: 12, color: _gray500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinnedNotice extends StatelessWidget {
  const _PinnedNotice({required this.notice, required this.onTap});
  final CommunityNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: _orange50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.campaign, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📢 공지', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _orangeText)),
                  const SizedBox(height: 2),
                  Text(notice.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: _text2)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _orange),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap, required this.onLike, required this.onBookmark});
  final CommunityPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final popular = post.likes >= 100;
    final liked = post.isLiked || context.watch<CommunityProvider>().likedPostIds.contains(post.id);
    final bookmarked = post.isBookmarked || context.watch<CommunityProvider>().bookmarkedPostIds.contains(post.id);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(name: post.username, color: Color(post.avatarColor), size: 22, fontSize: 10),
                  const SizedBox(width: 6),
                  Text(post.username, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text2)),
                  const SizedBox(width: 5),
                  const Text('·', style: TextStyle(fontSize: 11, color: _gray300)),
                  const SizedBox(width: 5),
                  Text(post.timeAgo, style: const TextStyle(fontSize: 11, color: _gray400)),
                  const Spacer(),
                  if (popular) ...[
                    _Pill(label: '🔥 인기', bg: const Color(0xFFFEE2E2), fg: _red, fontSize: 10, weight: FontWeight.w800),
                    const SizedBox(width: 5),
                  ],
                  _CategoryPill(category: post.category),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text, height: 1.25)),
                        const SizedBox(height: 4),
                        Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.5, color: _gray500)),
                      ],
                    ),
                  ),
                  if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _NetworkImageBox(url: post.imageUrl!, width: 80, height: 80),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: _gray100),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SmallActionIcon(
                    icon: liked ? Icons.favorite : Icons.favorite_border,
                    label: '${post.likes + (liked && !post.isLiked ? 1 : 0)}',
                    color: liked ? _red : _gray400,
                    onTap: onLike,
                  ),
                  const SizedBox(width: 16),
                  _SmallActionIcon(icon: Icons.mode_comment_outlined, label: '${post.comments.length}', color: _gray400),
                  const Spacer(),
                  GestureDetector(
                    onTap: onBookmark,
                    child: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border, size: 18, color: bookmarked ? _orange : _gray400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
