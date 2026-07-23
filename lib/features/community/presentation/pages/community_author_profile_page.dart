part of '../community_screen.dart';

class _CommunityAuthorProfilePage extends StatefulWidget {
  const _CommunityAuthorProfilePage({
    required this.userId,
    required this.onBack,
    required this.onOpenPost,
    required this.onOpenRecipe,
    this.onEdit,
  });

  final int userId;
  final VoidCallback onBack;
  final ValueChanged<int> onOpenPost;
  final ValueChanged<String> onOpenRecipe;
  final VoidCallback? onEdit;

  @override
  State<_CommunityAuthorProfilePage> createState() =>
      _CommunityAuthorProfilePageState();
}

class _CommunityAuthorProfilePageState
    extends State<_CommunityAuthorProfilePage> {
  bool _showPosts = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CommunityProvider>().loadAuthorProfile(widget.userId);
    });
  }

  @override
  void didUpdateWidget(covariant _CommunityAuthorProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CommunityProvider>().loadAuthorProfile(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final profile = provider.authorProfile(widget.userId);
    final loading = provider.isAuthorProfileLoading(widget.userId);
    final error = provider.authorProfileError(widget.userId);

    return ColoredBox(
      color: _bg,
      child: Column(
        children: [
          _CommunityDetailHeader(title: '작성자 프로필', onBack: widget.onBack),
          Expanded(
            child: loading && profile == null
                ? const Center(
                    child: CircularProgressIndicator(color: _orange),
                  )
                : error != null && profile == null
                    ? _ErrorBlock(
                        message: error,
                        onRetry: () => provider.loadAuthorProfile(
                          widget.userId,
                          force: true,
                        ),
                      )
                    : profile == null
                        ? const Center(
                            child: Text(
                              '작성자 정보를 찾을 수 없습니다.',
                              style: TextStyle(color: _gray500),
                            ),
                          )
                        : RefreshIndicator(
                            color: _orange,
                            onRefresh: () => provider.loadAuthorProfile(
                              widget.userId,
                              force: true,
                            ),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              children: [
                                _AuthorProfileSummary(profile: profile, onEdit: widget.onEdit),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _gray100,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _AuthorProfileTab(
                                          label: '게시글 ${profile.postCount}',
                                          selected: _showPosts,
                                          onTap: () =>
                                              setState(() => _showPosts = true),
                                        ),
                                      ),
                                      Expanded(
                                        child: _AuthorProfileTab(
                                          label:
                                              '공개 레시피 ${profile.publicRecipeCount}',
                                          selected: !_showPosts,
                                          onTap: () =>
                                              setState(() => _showPosts = false),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_showPosts)
                                  if (profile.posts.isEmpty)
                                    const _AuthorEmptyState(
                                      icon: Icons.article_outlined,
                                      text: '작성한 게시글이 없습니다.',
                                    )
                                  else
                                    for (final post in profile.posts) ...[
                                      _AuthorPostTile(
                                        post: post,
                                        onTap: () => widget.onOpenPost(post.id),
                                      ),
                                      const SizedBox(height: 10),
                                    ]
                                else if (profile.publicRecipes.isEmpty)
                                  const _AuthorEmptyState(
                                    icon: Icons.menu_book_outlined,
                                    text: '공개한 레시피가 없습니다.',
                                  )
                                else
                                  for (final recipe in profile.publicRecipes) ...[
                                    _AuthorRecipeTile(
                                      recipe: recipe,
                                      onTap: () =>
                                          widget.onOpenRecipe(recipe.id),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _AuthorProfileSummary extends StatelessWidget {
  const _AuthorProfileSummary({required this.profile, this.onEdit});

  final CommunityAuthorProfile profile;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gray200),
      ),
      child: Row(
        children: [
          _Avatar(
            name: profile.nickname,
            color: Color(profile.avatarColor),
            imageUrl: profile.avatarImageUrl,
            size: 58,
            fontSize: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _text,
                        ),
                      ),
                    ),
                    if (profile.isAdmin) ...[
                      const SizedBox(width: 8),
                      const _AuthorRoleBadge(
                        label: '관리자',
                        admin: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '게시글 ${profile.postCount} · 공개 레시피 ${profile.publicRecipeCount}',
                  style: const TextStyle(fontSize: 12, color: _gray500),
                ),
              ],
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            Material(
              color: _orange50,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: onEdit,
                tooltip: '프로필 수정',
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: _orangeText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthorProfileTab extends StatelessWidget {
  const _AuthorProfileTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? _orangeText : _gray500,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorPostTile extends StatelessWidget {
  const _AuthorPostTile({required this.post, required this.onTap});

  final CommunityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gray200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryPill(category: post.category),
                        const SizedBox(width: 7),
                        Text(
                          '${post.relativeTime}${post.wasEdited ? ' · 수정됨' : ''}',
                          style: const TextStyle(fontSize: 11, color: _gray400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _text,
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
              if (post.imageUrl?.isNotEmpty == true) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _NetworkImageBox(
                    url: post.imageUrl!,
                    width: 64,
                    height: 64,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorRecipeTile extends StatelessWidget {
  const _AuthorRecipeTile({required this.recipe, required this.onTap});

  final CommunityAuthorRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gray200),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: recipe.thumbnailUrl?.isNotEmpty == true
                    ? _NetworkImageBox(
                        url: recipe.thumbnailUrl!,
                        width: 72,
                        height: 72,
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: _gray100,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: _gray400,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recipe.description.isEmpty
                          ? '공개 레시피'
                          : recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: _gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _gray400),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorEmptyState extends StatelessWidget {
  const _AuthorEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gray200),
      ),
      child: Column(
        children: [
          Icon(icon, color: _gray300, size: 30),
          const SizedBox(height: 9),
          Text(text, style: const TextStyle(fontSize: 13, color: _gray400)),
        ],
      ),
    );
  }
}
