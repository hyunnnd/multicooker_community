import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/models/community_models.dart';
import '../data/community_draft_storage.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_more_menu_button.dart';
import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';
import '../provider/community_provider.dart';
import '../../auth/provider/auth_provider.dart';
import '../../profile/provider/profile_provider.dart';
import '../../recipe/provider/recipe_provider.dart';
import 'widgets/community_avatar.dart';

part 'pages/community_list_page.dart';
part 'widgets/community_review_widgets.dart';
part 'pages/community_write_review_page.dart';
part 'pages/community_post_detail_page.dart';
part 'pages/community_notice_pages.dart';
part 'pages/community_write_post_page.dart';
part 'pages/community_admin_pages.dart';
part 'widgets/community_notification_panel.dart';
part 'widgets/community_shared_widgets.dart';
part 'widgets/community_image_viewer.dart';
part 'pages/community_author_profile_page.dart';

const _orange = Color(0xFFF97316);
const _orangeText = Color(0xFFEA580C);
const _orange50 = Color(0xFFFFF7ED);
const _orange100 = Color(0xFFFFEDD5);
const _bg = Color(0xFFF8FAFC);
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

enum _CommunityView { list, postDetail, noticeDetail, noticeList, writePost, editPost, writeReview, authorProfile, admin }

class _ViewState {
  const _ViewState(
    this.view, {
    this.id,
    this.category,
    this.commentId,
    this.replyId,
  });
  final _CommunityView view;
  final int? id;
  final PostCategory? category;
  final int? commentId;
  final int? replyId;
}

class CommunityAuthorProfileScreen extends StatefulWidget {
  const CommunityAuthorProfileScreen({
    required this.userId,
    this.editable = false,
    super.key,
  });

  final int userId;
  final bool editable;

  @override
  State<CommunityAuthorProfileScreen> createState() =>
      _CommunityAuthorProfileScreenState();
}

class _CommunityAuthorProfileScreenState
    extends State<CommunityAuthorProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = context.read<ProfileProvider>();
      if (profile.summary == null) {
        unawaited(profile.refreshSummary());
      }
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  Future<void> _editProfile() async {
    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.summary == null) {
      await profileProvider.refreshSummary();
    }
    if (!mounted) return;
    final summary = profileProvider.summary;
    if (summary == null || summary.id != widget.userId) return;

    final previousNickname = summary.nickname;
    final controller = TextEditingController(text: summary.nickname);
    XFile? selectedImage;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('프로필 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final image = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                    maxWidth: 1200,
                  );
                  if (image != null) {
                    setDialogState(() => selectedImage = image);
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(summary.avatarColor),
                      backgroundImage: selectedImage != null
                          ? FileImage(io.File(selectedImage!.path))
                          : (summary.avatarImageUrl != null &&
                                  summary.avatarImageUrl!.isNotEmpty
                              ? NetworkImage(summary.avatarImageUrl!)
                                  as ImageProvider
                              : null),
                      child: selectedImage == null &&
                              (summary.avatarImageUrl == null ||
                                  summary.avatarImageUrl!.isEmpty)
                          ? Text(
                              summary.nickname.isEmpty
                                  ? 'U'
                                  : summary.nickname.characters.first
                                      .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const Positioned(
                      right: -2,
                      bottom: -2,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: _orange,
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '사진을 눌러 프로필 이미지를 선택하십시오.',
                style: TextStyle(fontSize: 12, color: _gray500),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                final next = controller.text.trim();
                if (next.isEmpty) return;
                final ok = await profileProvider.updateProfile(
                  nickname: next,
                  imagePath: selectedImage?.path,
                );
                if (!ok || !mounted) return;

                final updated = profileProvider.summary;
                final community = context.read<CommunityProvider>();
                if (updated != null) {
                  context
                      .read<AuthProvider>()
                      .setLocalNickname(updated.nickname);
                  community.applyCurrentUserProfile(
                    userId: updated.id,
                    previousNickname: previousNickname,
                    nickname: updated.nickname,
                    avatarColor: updated.avatarColor,
                    avatarImageUrl: updated.avatarImageUrl,
                  );
                  await Future.wait([
                    community.load(silent: true),
                    context.read<RecipeProvider>().loadRecipes(),
                    community.loadAuthorProfile(
                      widget.userId,
                      force: true,
                    ),
                  ]);
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = context.watch<ProfileProvider>().summary;
    final canEdit = widget.editable && currentProfile?.id == widget.userId;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _CommunityAuthorProfilePage(
          userId: widget.userId,
          onBack: _back,
          onOpenPost: (postId) => context.push(
            '/community?postId=$postId',
          ),
          onOpenRecipe: (recipeId) => context.push('/recipes/$recipeId'),
          onEdit: canEdit ? _editProfile : null,
        ),
      ),
    );
  }
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    this.initialTab,
    this.initialRecipeId,
    this.initialRecipeTitle,
    this.initialRecipeImage,
    this.initialReviewRating = 5,
    this.initialWriteReview = false,
    this.initialPostId,
    this.initialCommentId,
    this.initialReplyId,
    this.initialNoticeId,
    super.key,
  });

  final String? initialTab;
  final String? initialRecipeId;
  final String? initialRecipeTitle;
  final String? initialRecipeImage;
  final int initialReviewRating;
  final bool initialWriteReview;
  final int? initialPostId;
  final int? initialCommentId;
  final int? initialReplyId;
  final int? initialNoticeId;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  var _state = const _ViewState(_CommunityView.list);
  var _stateBeforeAuthor = const _ViewState(_CommunityView.list);
  bool _showSearch = false;
  bool _showNotification = false;
  final _searchController = TextEditingController();
  final _writePostKey = GlobalKey<_WritePostPageState>();
  CommunityProvider? _communityProvider;
  bool _communityRebuildScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<CommunityProvider>();
    if (identical(_communityProvider, next)) return;
    _communityProvider?.removeListener(_scheduleCommunityRebuild);
    _communityProvider = next..addListener(_scheduleCommunityRebuild);
  }

  void _scheduleCommunityRebuild() {
    if (!mounted || _communityRebuildScheduled) return;
    _communityRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _communityRebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<CommunityProvider>();
      context.read<ProfileProvider>().refreshSummary();
      // 커뮤니티에서는 후기 탭을 사용하지 않습니다.
      // 예전 링크로 tab=review가 들어와도 일반 커뮤니티 목록을 보여줍니다.
      if (widget.initialTab == 'review') {
        provider.setTab(CommunityTab.all);
        provider.clearReviewFilters();
      }
      if (widget.initialWriteReview) {
        provider.load(silent: true);
        _openWriteReview();
      } else if (widget.initialNoticeId != null) {
        await provider.load(silent: true);
        if (mounted) _openNotice(widget.initialNoticeId!);
      } else if (widget.initialPostId != null) {
        await provider.load(silent: true);
        if (mounted) {
          _openPost(
            widget.initialPostId!,
            commentId: widget.initialCommentId,
            replyId: widget.initialReplyId,
          );
        }
      } else {
        provider.load();
      }
    });
  }

  @override
  void dispose() {
    _communityProvider?.removeListener(_scheduleCommunityRebuild);
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

  void _openPost(int id, {int? commentId, int? replyId}) {
    setState(() {
      _state = _ViewState(
        _CommunityView.postDetail,
        id: id,
        commentId: commentId,
        replyId: replyId,
      );
      _showNotification = false;
    });
    final provider = context.read<CommunityProvider>();
    unawaited(provider.refreshPost(id));
    unawaited(_markPostNotificationsSeen(id));
  }

  Future<void> _markPostNotificationsSeen(int postId) async {
    await context.read<CommunityProvider>().markPostNotificationsRead(postId);
    if (!mounted) return;
    await context.read<LocalNotificationService>().cancelCommunitySummary(
          accountEmail: context.read<AuthProvider>().currentEmail,
          resetState: false,
        );
  }

  void _openNotice(int id) {
    setState(() {
      _state = _ViewState(_CommunityView.noticeDetail, id: id);
      _showNotification = false;
    });
  }

  void _openNotification(CommunityNotification notification) {
    if (notification.isNoticeNotification && notification.noticeId != null) {
      setState(() => _showNotification = false);
      _openNotice(notification.noticeId!);
      return;
    }
    if (notification.isRecipeNotification &&
        notification.recipeId.trim().isNotEmpty) {
      setState(() => _showNotification = false);
      context.push(notification.routePath);
      return;
    }
    _openPost(
      notification.postId,
      commentId: notification.targetCommentId,
      replyId: notification.targetReplyId,
    );
  }

  void _openAuthorProfile(int userId) {
    if (userId <= 0) return;
    setState(() {
      if (_state.view != _CommunityView.authorProfile) {
        _stateBeforeAuthor = _state;
      }
      _state = _ViewState(_CommunityView.authorProfile, id: userId);
      _showNotification = false;
    });
    unawaited(context.read<CommunityProvider>().loadAuthorProfile(userId));
  }

  void _closeAuthorProfile() {
    setState(() {
      _state = _stateBeforeAuthor;
      _showNotification = false;
    });
  }

  void _openWrite({PostCategory? category}) {
    setState(() => _state = _ViewState(_CommunityView.writePost, category: category));
  }

  void _openWriteReview() {
    setState(() => _state = const _ViewState(_CommunityView.writeReview));
  }

  void _closeWriteReview({bool created = false}) {
    if (widget.initialWriteReview && context.canPop()) {
      context.pop(created);
      return;
    }
    _goList();
  }

  void _openAdmin() {
    setState(() {
      _state = const _ViewState(_CommunityView.admin);
      _showNotification = false;
    });
  }

  bool _handleSystemBack() {
    if (_state.view == _CommunityView.writePost ||
        _state.view == _CommunityView.editPost) {
      final handler = _writePostKey.currentState;
      if (handler != null) {
        unawaited(handler.requestBack());
      } else {
        _goList();
      }
      return true;
    }
    if (_state.view == _CommunityView.writeReview &&
        widget.initialWriteReview) {
      _closeWriteReview();
      return true;
    }
    if (_showNotification) {
      setState(() => _showNotification = false);
      return true;
    }

    if (_state.view == _CommunityView.authorProfile) {
      _closeAuthorProfile();
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
    final provider = _communityProvider ?? context.read<CommunityProvider>();
    final isLoading = provider.isLoading;

    Widget body;
    if (isLoading && _state.view != _CommunityView.writeReview) {
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
            onNotificationTap: () async {
              await context.read<CommunityProvider>().refreshNotifications();
              if (!mounted) return;
              setState(() => _showNotification = true);
            },
            onAdminTap: _openAdmin,
            onRecipeTap: (recipeId) => context.push(
              '/recipes/${Uri.encodeComponent(recipeId)}',
            ),
            onAuthorTap: _openAuthorProfile,
          ),
        _CommunityView.postDetail => _PostDetailPage(
            postId: _state.id!,
            onBack: _goList,
            onEdit: (id) => setState(() => _state = _ViewState(_CommunityView.editPost, id: id)),
            onDeleted: _goList,
            onAuthorTap: _openAuthorProfile,
            highlightCommentId: _state.commentId,
            highlightReplyId: _state.replyId,
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
            key: _writePostKey,
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
              if (!mounted) return created;
              if (!created) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(community.errorMessage ?? '게시글을 등록하지 못했습니다.'),
                  ),
                );
              }
              return created;
            },
          ),
        _CommunityView.writeReview => _WriteReviewPage(
            initialRecipeId: widget.initialRecipeId ?? '',
            initialRecipeTitle: widget.initialRecipeTitle ?? '',
            initialRecipeImage: widget.initialRecipeImage ?? '',
            initialRating: widget.initialReviewRating,
            onBack: () => _closeWriteReview(),
            onSubmit: (recipeId, recipeTitle, recipeImage, reviewImageUrl, rating, content) async {
              try {
                await context.read<CommunityProvider>().createReview(
                      recipeId: recipeId,
                      recipeTitle: recipeTitle,
                      recipeImage: recipeImage,
                      reviewImageUrl: reviewImageUrl,
                      rating: rating,
                      content: content,
                    );
                // 새 후기가 DB에 저장된 뒤 레시피 평균 별점과 후기 수를 즉시 갱신합니다.
                await context.read<RecipeProvider>().loadRecipes();
                if (mounted) _closeWriteReview(created: true);
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.read<CommunityProvider>().errorMessage ??
                          '후기를 등록하지 못했습니다.',
                    ),
                  ),
                );
              }
            },
          ),
        _CommunityView.authorProfile => _CommunityAuthorProfilePage(
            userId: _state.id!,
            onBack: _closeAuthorProfile,
            onOpenPost: _openPost,
            onOpenRecipe: (recipeId) => context.push(
              '/recipes/${Uri.encodeComponent(recipeId)}',
            ),
          ),
        _CommunityView.admin => _CommunityAdminPage(
            onBack: _goList,
            onOpenPost: _openPost,
          ),
        _CommunityView.editPost => _WritePostPage(
            key: _writePostKey,
            initialPost: provider.postById(_state.id!),
            onBack: () => _openPost(_state.id!),
            onSubmit: (category, title, content, imageUrl) async {
              final edited = await context.read<CommunityProvider>().editPost(
                    _state.id!,
                    category: category,
                    title: title,
                    content: content,
                    imageUrl: imageUrl,
                  );
              return edited;
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
                onOpenNotification: _openNotification,
                onOpenAuthor: _openAuthorProfile,
              ),
          ],
        ),
      ),
      ),
    );
  }
}
