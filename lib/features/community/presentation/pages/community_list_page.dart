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
    required this.onAdminTap,
    required this.onRecipeTap,
    required this.onAuthorTap,
  });

  final bool showSearch;
  final TextEditingController searchController;
  final ValueChanged<bool> onSearchToggle;
  final ValueChanged<int> onNoticeTap;
  final ValueChanged<int> onPostTap;
  final VoidCallback onWriteTap;
  final VoidCallback onWriteReviewTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onAdminTap;
  final ValueChanged<String> onRecipeTap;
  final ValueChanged<int> onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
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
              onAdminTap: onAdminTap,
            ),
            Expanded(
              child: RefreshIndicator(
                color: _orange,
                onRefresh: () => context.read<CommunityProvider>().load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (provider.activeTab == CommunityTab.all && query.isEmpty && notice != null) ...[
                      _PinnedNotice(
                        notice: notice,
                        onTap: () => onNoticeTap(notice.id),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (provider.errorMessage != null)
                      _ErrorBlock(
                        message: provider.errorMessage!,
                        onRetry: () => provider.load(),
                      )
                    else if (posts.isEmpty)
                      _EmptyBlock(searching: query.isNotEmpty)
                    else ...[
                      if (provider.activeTab == CommunityTab.popular && popular.days > 0)
                        _PopularInfo(days: popular.days),
                      if (provider.activeTab == CommunityTab.popular && popular.days > 0)
                        const SizedBox(height: 12),
                      for (final post in posts) ...[
                        _PostCard(
                          key: ValueKey('community-post-${post.id}'),
                          post: post,
                          liked: provider.likedPostIds.contains(post.id),
                          likePending: provider.isPostLikePending(post.id),
                          onTap: () => onPostTap(post.id),
                          onLike: () => provider.togglePostLike(post.id),
                          onAuthorTap: post.authorUserId == null
                              ? null
                              : () => onAuthorTap(post.authorUserId!),
                        ),
                        const SizedBox(height: 12),
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
    required this.onAdminTap,
  });

  final bool showSearch;
  final TextEditingController searchController;
  final ValueChanged<bool> onSearchToggle;
  final VoidCallback onNotificationTap;
  final VoidCallback onAdminTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final profile = context.watch<ProfileProvider>();
    final isAdmin = profile.summary?.isAdmin == true || provider.isAdmin;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _gray200, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        children: [
          if (showSearch)
            Row(
              children: [
                AppBackButton(
                  onPressed: () => onSearchToggle(false),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: _gray100,
                      border: Border.all(color: _gray200),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 18, color: _gray500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            minLines: 1,
                            maxLines: 1,
                            textAlignVertical: TextAlignVertical.center,
                            onChanged: context.read<CommunityProvider>().setSearchQuery,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText: switch (provider.searchScope) {
                                CommunitySearchScope.titleContent => '제목과 내용으로 검색...',
                                CommunitySearchScope.title => '제목으로 검색...',
                                CommunitySearchScope.author => '작성자로 검색...',
                              },
                              hintStyle: const TextStyle(fontSize: 13, color: _gray400),
                            ),
                            style: const TextStyle(fontSize: 13, color: _text),
                          ),
                        ),
                        if (searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              searchController.clear();
                              context.read<CommunityProvider>().setSearchQuery('');
                            },
                            child: const Icon(
                              Icons.cancel_rounded,
                              size: 17,
                              color: _gray400,
                            ),
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
                const Expanded(
                  child: Text(
                    '커뮤니티',
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: _text,
                    ),
                  ),
                ),
                if (isAdmin) ...[
                  _CommunityHeaderIconBox(
                    icon: Icons.admin_panel_settings_outlined,
                    tooltip: '커뮤니티 관리자',
                    onTap: onAdminTap,
                    iconColor: _orangeText,
                  ),
                  const SizedBox(width: 8),
                ],
                _CommunityHeaderIconBox(
                  icon: Icons.notifications_none_rounded,
                  tooltip: '알림',
                  onTap: onNotificationTap,
                  badgeCount: provider.unreadCount,
                ),
                const SizedBox(width: 8),
                _CommunityHeaderIconBox(
                  icon: Icons.search_rounded,
                  tooltip: '검색',
                  onTap: () => onSearchToggle(true),
                ),
              ],
            ),
          if (showSearch) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SearchFilterDropdown<CommunitySearchScope>(
                    value: provider.searchScope,
                    label: '검색 범위',
                    items: CommunitySearchScope.values,
                    itemLabel: (item) => item.label,
                    onChanged: provider.setSearchScope,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SearchFilterDropdown<CommunitySortOrder>(
                    value: provider.sortOrder,
                    label: '정렬',
                    items: CommunitySortOrder.values,
                    itemLabel: (item) => item.label,
                    onChanged: provider.setSortOrder,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
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
                              fontWeight: provider.activeTab == tab
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: provider.activeTab == tab
                                  ? _orange
                                  : _gray500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: provider.activeTab == tab ? 24 : 0,
                            height: 2,
                            decoration: BoxDecoration(
                              color: _orange,
                              borderRadius: BorderRadius.circular(999),
                            ),
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
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    text: '"',
                    children: [
                      TextSpan(
                        text: provider.searchQuery,
                        style: const TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: '" 결과 ${provider.filteredPosts().length}건',
                      ),
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

class _SearchFilterDropdown<T> extends StatelessWidget {
  const _SearchFilterDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final T value;
  final String label;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _gray200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('$label · ', style: const TextStyle(fontSize: 11, color: _gray400)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _gray500),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text2),
                items: [
                  for (final item in items)
                    DropdownMenuItem<T>(
                      value: item,
                      child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (next) {
                  if (next != null) onChanged(next);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityHeaderIconBox extends StatelessWidget {
  const _CommunityHeaderIconBox({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor = _gray500,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color iconColor;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _gray100,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 18, color: iconColor),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _red,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          fontSize: 8,
                          height: 1,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
                  Row(
                    children: [
                      const Text('📢 공지', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _orangeText)),
                      if (notice.wasEdited) ...[
                        const SizedBox(width: 6),
                        const Text('수정됨', style: TextStyle(fontSize: 10, color: _gray400)),
                      ],
                    ],
                  ),
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
  const _PostCard({
    super.key,
    required this.post,
    required this.liked,
    required this.likePending,
    required this.onTap,
    required this.onLike,
    this.onAuthorTap,
  });

  final CommunityPost post;
  final bool liked;
  final bool likePending;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final popular = post.isPopular;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onAuthorTap,
                      child: Row(
                        children: [
                          _Avatar(
                            name: post.username,
                            color: Color(post.avatarColor),
                            imageUrl: post.avatarImageUrl,
                            size: 24,
                            fontSize: 10,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        post.username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: _text2,
                                        ),
                                      ),
                                    ),
                                    if (post.isAdmin) ...[
                                      const SizedBox(width: 6),
                                      const _AuthorRoleBadge(
                                        label: '관리자',
                                        admin: true,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${post.relativeTime}${post.wasEdited ? ' · 수정됨' : ''}',
                                  style: const TextStyle(fontSize: 11, color: _gray400),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (popular) ...[
                        _Pill(
                          label: '🔥 인기',
                          bg: const Color(0xFFFEE2E2),
                          fg: _red,
                          fontSize: 10,
                          weight: FontWeight.w800,
                        ),
                        const SizedBox(width: 5),
                      ],
                      _CategoryPill(category: post.category),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _text,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          post.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: _gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showCommunityImageViewer(
                        context,
                        [post.imageUrl!],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _NetworkImageBox(
                          url: post.imageUrl!,
                          width: 76,
                          height: 76,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: _gray100),
              const SizedBox(height: 11),
              Row(
                children: [
                  _SmallActionIcon(
                    icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: '${post.likes + (liked && !post.isLiked ? 1 : 0)}',
                    color: liked ? _red : _gray400,
                    onTap: likePending ? null : onLike,
                  ),
                  const SizedBox(width: 16),
                  _SmallActionIcon(
                    icon: Icons.mode_comment_outlined,
                    label: '${post.commentCount}',
                    color: _gray400,
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
