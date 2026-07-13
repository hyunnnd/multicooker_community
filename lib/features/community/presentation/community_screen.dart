import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/models/community_models.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';
import '../provider/community_provider.dart';
import '../../auth/provider/auth_provider.dart';
import '../../profile/provider/profile_provider.dart';

part 'pages/community_list_page.dart';
part 'widgets/community_review_widgets.dart';
part 'pages/community_write_review_page.dart';
part 'pages/community_post_detail_page.dart';
part 'pages/community_notice_pages.dart';
part 'pages/community_write_post_page.dart';
part 'widgets/community_notification_panel.dart';
part 'widgets/community_shared_widgets.dart';

const _orange = Color(0xFFF97316);
const _orangeText = Color(0xFFEA580C);
const _orange50 = Color(0xFFFFF7ED);
const _orange100 = Color(0xFFFFEDD5);
const _bg = Color(0xFFF9FAFB);
const _text = Color(0xFF111827);
const _text2 = Color(0xFF374151);
const _gray500 = Color(0xFF6B7280);
const _gray400 = Color(0xFF9CA3AF);
const _gray300 = Color(0xFFD1D5DB);
const _gray200 = Color(0xFFE5E7EB);
const _gray100 = Color(0xFFF3F4F6);
const _red = Color(0xFFEF4444);
const _yellow = Color(0xFFFACC15);

const _tabOrder = [
  CommunityTab.all,
  CommunityTab.popular,
  CommunityTab.free,
  CommunityTab.qa,
];

enum _CommunityView { list, postDetail, noticeDetail, noticeList, writePost, editPost, writeReview }

class _ViewState {
  const _ViewState(this.view, {this.id, this.category});
  final _CommunityView view;
  final int? id;
  final PostCategory? category;
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({this.initialTab, this.initialRecipeId, this.initialRecipeTitle, this.initialRecipeImage, this.initialWriteReview = false, this.initialPostId, super.key});

  final String? initialTab;
  final String? initialRecipeId;
  final String? initialRecipeTitle;
  final String? initialRecipeImage;
  final bool initialWriteReview;
  final int? initialPostId;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  var _state = const _ViewState(_CommunityView.list);
  bool _showSearch = false;
  bool _showNotification = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<CommunityProvider>();
      context.read<ProfileProvider>().refreshSummary();
      // 커뮤니티에서는 후기 탭을 사용하지 않습니다.
      // 예전 링크로 tab=review가 들어와도 일반 커뮤니티 목록을 보여줍니다.
      if (widget.initialTab == 'review') {
        provider.setTab(CommunityTab.all);
        provider.clearReviewFilters();
      }
      if (widget.initialPostId != null) {
        provider.load(silent: true);
        _openPost(widget.initialPostId!);
      } else {
        provider.load();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goList() {
    setState(() {
      _state = const _ViewState(_CommunityView.list);
      _showNotification = false;
    });
    context.read<CommunityProvider>().load(silent: true);
  }

  void _openPost(int id) {
    setState(() {
      _state = _ViewState(_CommunityView.postDetail, id: id);
      _showNotification = false;
    });
    context.read<CommunityProvider>().refreshPost(id);
  }

  void _openNotice(int id) {
    setState(() {
      _state = _ViewState(_CommunityView.noticeDetail, id: id);
      _showNotification = false;
    });
  }

  void _openWrite({PostCategory? category}) {
    setState(() => _state = _ViewState(_CommunityView.writePost, category: category));
  }

  void _openWriteReview() {
    setState(() => _state = const _ViewState(_CommunityView.writeReview));
  }

  bool _handleSystemBack() {
    if (_showNotification) {
      setState(() => _showNotification = false);
      return true;
    }

    if (_state.view == _CommunityView.editPost && _state.id != null) {
      _openPost(_state.id!);
      return true;
    }

    if (_state.view != _CommunityView.list) {
      _goList();
      return true;
    }

    if (_showSearch) {
      setState(() => _showSearch = false);
      _searchController.clear();
      context.read<CommunityProvider>().setSearchQuery('');
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();

    Widget body;
    if (provider.isLoading) {
      body = const Center(child: CircularProgressIndicator(color: _orange));
    } else {
      body = switch (_state.view) {
        _CommunityView.list => _CommunityList(
            showSearch: _showSearch,
            searchController: _searchController,
            onSearchToggle: (value) {
              setState(() => _showSearch = value);
              if (!value) {
                _searchController.clear();
                context.read<CommunityProvider>().setSearchQuery('');
              }
            },
            onNoticeTap: _openNotice,
            onPostTap: _openPost,
            onWriteTap: () => _openWrite(),
            onWriteReviewTap: _openWriteReview,
            onNotificationTap: () {
              context.read<CommunityProvider>().refreshNotifications();
              setState(() => _showNotification = true);
            },
            onRecipeTap: (recipeId) => context.push('/recipes/$recipeId'),
          ),
        _CommunityView.postDetail => _PostDetailPage(
            postId: _state.id!,
            onBack: _goList,
            onEdit: (id) => setState(() => _state = _ViewState(_CommunityView.editPost, id: id)),
            onDeleted: _goList,
          ),
        _CommunityView.noticeDetail => _NoticeDetailPage(
            noticeId: _state.id!,
            onBack: _goList,
            onNoticeTap: _openNotice,
            onViewAll: () => setState(() => _state = const _ViewState(_CommunityView.noticeList)),
          ),
        _CommunityView.noticeList => _NoticeListPage(
            onBack: _goList,
            onNoticeTap: _openNotice,
          ),
        _CommunityView.writePost => _WritePostPage(
            initialCategory: _state.category,
            onBack: _goList,
            onSubmit: (category, title, content, imageUrl) async {
              final community = context.read<CommunityProvider>();
              final created = await community.createPost(
                category: category,
                title: title,
                content: content,
                imageUrl: imageUrl,
              );
              if (!mounted) return;
              if (created) {
                _goList();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(community.errorMessage ?? '게시글을 등록하지 못했습니다.'),
                  ),
                );
              }
            },
          ),
        _CommunityView.writeReview => _WriteReviewPage(
            initialRecipeId: widget.initialRecipeId ?? '',
            initialRecipeTitle: widget.initialRecipeTitle ?? '',
            initialRecipeImage: widget.initialRecipeImage ?? '',
            onBack: _goList,
            onSubmit: (recipeId, recipeTitle, recipeImage, rating, content) async {
              await context.read<CommunityProvider>().createReview(
                    recipeId: recipeId,
                    recipeTitle: recipeTitle,
                    recipeImage: recipeImage,
                    rating: rating,
                    content: content,
                  );
              if (mounted) _goList();
            },
          ),
        _CommunityView.editPost => _WritePostPage(
            initialPost: provider.postById(_state.id!),
            onBack: () => _openPost(_state.id!),
            onSubmit: (category, title, content, imageUrl) async {
              await context.read<CommunityProvider>().editPost(
                    _state.id!,
                    category: category,
                    title: title,
                    content: content,
                    imageUrl: imageUrl,
                  );
              if (mounted) _openPost(_state.id!);
            },
          ),
      };
    }

    return MainRouteBackScope(
      backToHomeWhenUnhandled: true,
      onBackPressed: _handleSystemBack,
      child: Scaffold(
        backgroundColor: _state.view == _CommunityView.list ? _bg : Colors.white,
        bottomNavigationBar: const MainNavigationBar(currentIndex: 3),
        body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            body,
            if (_showNotification)
              _NotificationPanel(
                onClose: () => setState(() => _showNotification = false),
                onOpenPost: _openPost,
              ),
          ],
        ),
      ),
      ),
    );
  }
}
