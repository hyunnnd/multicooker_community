import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/community_models.dart';
import '../../provider/community_provider.dart';
import '../community_styles.dart';
import '../widgets/community_post_card.dart';
import 'community_notice_section.dart';
import 'community_review_section.dart';

class CommunityHomeSection extends StatefulWidget {
  const CommunityHomeSection({
    required this.onOpenNotice,
    required this.onOpenPost,
    required this.onOpenRecipe,
    required this.onWritePost,
    required this.onOpenNotifications,
    super.key,
  });

  final ValueChanged<int> onOpenNotice;
  final ValueChanged<int> onOpenPost;
  final ValueChanged<String> onOpenRecipe;
  final VoidCallback onWritePost;
  final VoidCallback onOpenNotifications;

  @override
  State<CommunityHomeSection> createState() => _CommunityHomeSectionState();
}

class _CommunityHomeSectionState extends State<CommunityHomeSection> {
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final posts = provider.filteredPosts();
    final popular = provider.popularPosts();
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_showSearch)
                        IconButton(
                          onPressed: () {
                            setState(() => _showSearch = false);
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                          icon: const Icon(Icons.arrow_back),
                        )
                      else
                        const SizedBox(width: 4),
                      Expanded(
                        child: _showSearch
                            ? TextField(
                                controller: _searchController,
                                autofocus: true,
                                onChanged: provider.setSearchQuery,
                                decoration: InputDecoration(
                                  hintText: '게시글 검색',
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.search, size: 19),
                                  suffixIcon: _searchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.close, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            provider.setSearchQuery('');
                                            setState(() {});
                                          },
                                        ),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                                ),
                              )
                            : const Text('커뮤니티', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      ),
                      if (!_showSearch) ...[
                        Stack(
                          children: [
                            IconButton(onPressed: widget.onOpenNotifications, icon: const Icon(Icons.notifications_none)),
                            if (provider.unreadCount > 0)
                              Positioned(
                                right: 8,
                                top: 7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(color: kCommunityOrange, borderRadius: BorderRadius.circular(10)),
                                  child: Text('${provider.unreadCount}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900)),
                                ),
                              ),
                          ],
                        ),
                        IconButton(onPressed: () => setState(() => _showSearch = true), icon: const Icon(Icons.search)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final tab in CommunityTab.values)
                        Expanded(
                          child: InkWell(
                            onTap: () => provider.setTab(tab),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                children: [
                                  Text(tab.label, style: TextStyle(fontSize: 13, fontWeight: provider.activeTab == tab ? FontWeight.w900 : FontWeight.w600, color: provider.activeTab == tab ? kCommunityOrange : kCommunitySubtext)),
                                  const SizedBox(height: 6),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    height: 3,
                                    width: provider.activeTab == tab ? 24 : 0,
                                    decoration: BoxDecoration(color: kCommunityOrange, borderRadius: BorderRadius.circular(999)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (provider.pinnedNotice != null) NoticeBanner(notice: provider.pinnedNotice!, onTap: () => widget.onOpenNotice(provider.pinnedNotice!.id)),
            if (provider.activeTab == CommunityTab.popular && popular.days > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 5),
                    Text('최근 ${popular.days}일 활동량 기준 인기글', style: const TextStyle(fontSize: 12, color: kCommunitySubtext, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            if (provider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 86, 20, 0),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 34, color: kCommunitySubtext),
                    const SizedBox(height: 12),
                    Text(provider.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: kCommunitySubtext, height: 1.5)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => provider.load(),
                      style: FilledButton.styleFrom(backgroundColor: kCommunityOrange),
                      child: const Text('DB 다시 불러오기'),
                    ),
                  ],
                ),
              )
            else if (posts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 86),
                child: Center(child: Text('게시글이 없습니다.', style: TextStyle(color: kCommunitySubtext))),
              )
            else
              for (final post in posts) ...[
                CommunityPostCard(
                  post: post,
                  liked: provider.likedPostIds.contains(post.id),
                  onLike: () => provider.togglePostLike(post.id),
                  onTap: () => widget.onOpenPost(post.id),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            onPressed: widget.onWritePost,
            backgroundColor: kCommunityOrange,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('글쓰기', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}
