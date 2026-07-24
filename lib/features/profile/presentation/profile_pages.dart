import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_more_menu_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/section_page_app_bar.dart';

import '../../recipe/data/models/recipe.dart';
import '../../recipe/provider/recipe_provider.dart';
import '../data/profile_models.dart';
import '../provider/profile_provider.dart';

const _orange = Color(0xFFF97316);
const _bg = Color(0xFFF8FAFC);
const _line = Color(0xFFE5E7EB);
const _muted = Color(0xFF6B7280);
const _text = Color(0xFF111827);
const _danger = Color(0xFFDC2626);
const _orangeSoft = Color(0xFFFFF7ED);

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    await Future.wait([
      context.read<RecipeProvider>().loadMyRecipes(),
      context.read<ProfileProvider>().loadSavedRecipes(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final profile = context.watch<ProfileProvider>();
    final myRecipes = recipeProvider.personalRecipes;
    final savedRecipes = profile.savedRecipes;
    final loading = (recipeProvider.isLoading && myRecipes.isEmpty) ||
        (profile.isLoading && savedRecipes.isEmpty);
    final error = recipeProvider.errorMessage ?? profile.errorMessage;

    return _PageScaffold(
      title: '레시피 관리',
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/my/recipes/new'),
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                '레시피 등록',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _RecipeManagementHeader(
                myRecipeCount: myRecipes.length,
                savedRecipeCount: savedRecipes.length,
                selectedTab: _tab,
                onTabChanged: (value) => setState(() => _tab = value),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _AsyncBody(
                loading: loading,
                error: error,
                onRefresh: _reload,
                child: _tab == 0
                    ? (myRecipes.isEmpty
                        ? _EmptyState(
                            icon: Icons.restaurant_menu_rounded,
                            title: '등록한 레시피가 없습니다',
                            description:
                                '직접 만든 레시피를 등록하면 이곳에서 공개 범위와 내용을 관리할 수 있습니다.',
                            actionLabel: '레시피 등록하기',
                            onAction: () => context.push('/my/recipes/new'),
                          )
                        : _PersonalRecipeList(items: myRecipes))
                    : (savedRecipes.isEmpty
                        ? const _EmptyState(
                            icon: Icons.bookmark_border_rounded,
                            title: '저장한 레시피가 없습니다',
                            description:
                                '레시피 상세 화면에서 저장 버튼을 누르면 이곳에 모아볼 수 있습니다.',
                          )
                        : _RecipeList(
                            items: savedRecipes,
                            trailingBuilder: (item) => IconButton(
                            tooltip: '저장 해제',
                            style: IconButton.styleFrom(
                              backgroundColor: _orangeSoft,
                              foregroundColor: _orange,
                              minimumSize: const Size(36, 36),
                              padding: const EdgeInsets.all(6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.bookmark_rounded),
                            onPressed: () => _confirm(
                              context,
                              title: '저장 해제',
                              message: '저장한 레시피에서 제거하시겠습니까?',
                              onOk: () async {
                                final ok = await context
                                    .read<ProfileProvider>()
                                    .unsaveRecipe(item.id);
                                if (ok && context.mounted) {
                                  await context
                                      .read<RecipeProvider>()
                                      .refreshSavedState();
                                }
                                return ok;
                              },
                            ),
                            ),
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ProfileProvider>().loadSavedRecipes());
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    return _PageScaffold(
      title: '저장한 레시피',
      child: _AsyncBody(
        loading: profile.isLoading && profile.savedRecipes.isEmpty,
        error: profile.errorMessage,
        onRefresh: () => context.read<ProfileProvider>().loadSavedRecipes(),
        child: profile.savedRecipes.isEmpty
            ? const _EmptyState(icon: Icons.bookmark_border, title: '저장한 레시피가 없습니다', description: '레시피 화면에서 저장 버튼을 누르면 여기에 표시됩니다.')
            : _RecipeList(
                items: profile.savedRecipes,
                topPadding: 16,
                trailingBuilder: (item) => IconButton(
                  tooltip: '저장 해제',
                  style: IconButton.styleFrom(
                    backgroundColor: _orangeSoft,
                    foregroundColor: _orange,
                  ),
                  icon: const Icon(Icons.bookmark_rounded),
                  onPressed: () => _confirm(
                    context,
                    title: '저장 해제',
                    message: '저장한 레시피에서 제거하시겠습니까?',
                    onOk: () async {
                      final ok = await context
                          .read<ProfileProvider>()
                          .unsaveRecipe(item.id);
                      if (ok && context.mounted) {
                        await context
                            .read<RecipeProvider>()
                            .refreshSavedState();
                      }
                      return ok;
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProfileProvider>().loadMyReviews(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final reviews = profile.reviews;

    return _PageScaffold(
      title: '내가 쓴 후기',
      child: _AsyncBody(
        loading: profile.isLoading && reviews.isEmpty,
        error: profile.errorMessage,
        onRefresh: () => context.read<ProfileProvider>().loadMyReviews(),
        child: reviews.isEmpty
            ? const _EmptyState(
                icon: Icons.rate_review_outlined,
                title: '작성한 후기가 없습니다',
                description: '조리한 레시피에 첫 후기를 남기면 이곳에서 확인할 수 있습니다.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  return _MyReviewCard(
                    review: review,
                    onOpenRecipe: () => context.push(
                      '/recipes/${Uri.encodeComponent(review.recipeId)}',
                    ),
                    onEdit: () => _editReview(context, review),
                    onDelete: () => _confirm(
                      context,
                      title: '후기 삭제',
                      message: '후기를 삭제하시겠습니까?',
                      onOk: () => context
                          .read<ProfileProvider>()
                          .deleteReview(review.id),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _editReview(
    BuildContext context,
    MyReviewItem review,
  ) async {
    var rating = review.rating;
    final controller = TextEditingController(text: review.content);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _line),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: const Text(
            '후기 수정',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '별점',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                        onPressed: () => setDialogState(() => rating = i),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '후기 내용',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 6,
                style: const TextStyle(fontSize: 14, color: _text),
                decoration: InputDecoration(
                  hintText: '후기 내용을 입력해 주십시오.',
                  hintStyle: const TextStyle(color: _muted, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _orange, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(foregroundColor: _muted),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final ok = await context.read<ProfileProvider>().updateReview(
                      review.id,
                      rating: rating,
                      content: controller.text.trim(),
                    );
                if (dialogContext.mounted && ok) {
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
}

class MyCommentsScreen extends StatefulWidget {
  const MyCommentsScreen({super.key});

  @override
  State<MyCommentsScreen> createState() => _MyCommentsScreenState();
}

class _MyCommentsScreenState extends State<MyCommentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ProfileProvider>().loadMyComments());
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    return _PageScaffold(
      title: '내가 쓴 댓글',
      child: _AsyncBody(
        loading: profile.isLoading && profile.comments.isEmpty,
        error: profile.errorMessage,
        onRefresh: () => context.read<ProfileProvider>().loadMyComments(),
        child: profile.comments.isEmpty
            ? const _EmptyState(icon: Icons.chat_bubble_outline, title: '작성한 댓글이 없습니다', description: '커뮤니티에서 의견을 남기면 여기에 표시됩니다.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                itemCount: profile.comments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final row = profile.comments[i];
                  final openPath = '/community?postId=${row.postId}';
                  return _Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      title: Text(row.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              _MiniPill(row.postCategory),
                              _MiniPill(row.isReply ? '답글' : '댓글'),
                            ]),
                            const SizedBox(height: 6),
                            Text('게시글: ${row.postTitle}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(row.displayTime, style: const TextStyle(fontSize: 11, color: _muted)),
                          ],
                        ),
                      ),
                      isThreeLine: true,
                      trailing: AppMoreMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'open') context.push(openPath);
                          if (value == 'edit') _editComment(context, row);
                          if (value == 'delete') _confirm(context, title: '댓글 삭제', message: '댓글을 삭제하시겠습니까?', onOk: () => context.read<ProfileProvider>().deleteComment(row));
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'open', child: Text('게시글로 이동')),
                          PopupMenuItem(value: 'edit', child: Text('수정')),
                          PopupMenuItem(value: 'delete', child: Text('삭제')),
                        ],
                      ),
                      onTap: () => context.push(openPath),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _editComment(BuildContext context, MyCommentItem item) async {
    final controller = TextEditingController(text: item.content);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.isReply ? '답글 수정' : '댓글 수정'),
        content: TextField(controller: controller, minLines: 3, maxLines: 5, decoration: const InputDecoration(hintText: '내용')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final ok = await context.read<ProfileProvider>().updateComment(item, controller.text.trim());
              if (dialogContext.mounted && ok) Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class CookingHistoryScreen extends StatefulWidget {
  const CookingHistoryScreen({super.key});

  @override
  State<CookingHistoryScreen> createState() => _CookingHistoryScreenState();
}

class _CookingHistoryScreenState extends State<CookingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProfileProvider>().loadCookingHistories(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    return _PageScaffold(
      title: '조리 이력',
      child: _AsyncBody(
        loading: profile.isLoading && profile.histories.isEmpty,
        error: profile.errorMessage,
        onRefresh: () => context.read<ProfileProvider>().loadCookingHistories(),
        child: profile.histories.isEmpty
            ? const _EmptyState(
                icon: Icons.history,
                title: '조리 이력이 없습니다',
                description: '조리가 완료되면 이력이 자동으로 표시됩니다.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: profile.histories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = profile.histories[i];
                  return _Card(
                    child: _CookingHistoryCard(
                      item: item,
                      completed: item.completed,
                      onSelected: (value) async {
                        if (value == 'cook') {
                          final recipeId = item.recipeId?.trim();
                          if (recipeId != null && recipeId.isNotEmpty) {
                            context.go(
                              '/recipes/${Uri.encodeComponent(recipeId)}',
                            );
                          } else {
                            context.go('/recipes');
                          }
                          return;
                        }
                        if (value == 'save') {
                          final ok = await context
                              .read<ProfileProvider>()
                              .saveHistoryToSavedRecipes(item.id);
                          if (!context.mounted || !ok) return;
                          await context
                              .read<RecipeProvider>()
                              .refreshSavedState();
                          if (context.mounted) {
                            showAppToast(
                              context,
                              '저장한 레시피에 추가했습니다.',
                              success: true,
                            );
                          }
                          return;
                        }
                        if (value == 'delete' && context.mounted) {
                          await _confirm(
                            context,
                            title: '이력 삭제',
                            message: '조리 이력을 삭제하시겠습니까?',
                            onOk: () => context
                                .read<ProfileProvider>()
                                .deleteCookingHistory(item.id),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _CookingHistoryCard extends StatelessWidget {
  const _CookingHistoryCard({
    required this.item,
    required this.completed,
    required this.onSelected,
  });

  final CookingHistoryItem item;
  final bool completed;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: completed
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  child: Icon(
                    completed ? Icons.check_rounded : Icons.stop_rounded,
                    color: completed ? const Color(0xFF16A34A) : _danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.recipeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDate(item.startedAt)} · ${item.deviceName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _HistoryOptions(onSelected: onSelected),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.thermostat_rounded,
                    size: 16,
                    color: _muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.maxTemperature}℃',
                    style: const TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Icon(Icons.schedule_rounded, size: 16, color: _muted),
                  const SizedBox(width: 6),
                  Text(
                    '${item.totalTimeMin}분',
                    style: const TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _HistoryStatePill(completed: completed),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HistoryOptions extends StatelessWidget {
  const _HistoryOptions({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => AppMoreMenuButton<String>(
        tooltip: '조리 이력 메뉴',
        constraints: const BoxConstraints(minWidth: 224, maxWidth: 240),
        onSelected: onSelected,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'cook',
            height: 64,
            padding: EdgeInsets.fromLTRB(8, 6, 8, 2),
            child: _HistoryOption(
              icon: Icons.restaurant_menu_rounded,
              title: '레시피로 이동',
              subtitle: '해당 레시피 상세 화면에서 다시 조리',
              highlighted: true,
            ),
          ),
          PopupMenuItem(
            value: 'save',
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: _HistoryOption(
              icon: Icons.bookmark_add_outlined,
              title: '저장한 레시피에 추가',
              subtitle: '이 조리 설정을 저장 목록에 보관',
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            height: 64,
            padding: EdgeInsets.fromLTRB(8, 2, 8, 6),
            child: _HistoryOption(
              icon: Icons.delete_outline_rounded,
              title: '이력 삭제',
              subtitle: '삭제한 이력은 복구할 수 없어요',
              danger: true,
            ),
          ),
        ],
      );
}

class _HistoryOption extends StatelessWidget {
  const _HistoryOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlighted = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFF3F4F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? _danger : _muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: danger ? _danger : _text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: danger ? _danger : _muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HistoryStatePill extends StatelessWidget {
  const _HistoryStatePill({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: completed
              ? const Color(0xFFDCFCE7)
              : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          completed ? '완료' : '중단',
          style: TextStyle(
            color: completed ? const Color(0xFF15803D) : _danger,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});
  static const steps = [
    (Icons.bluetooth, '쿠커 연결', '기기 관리에서 주변 쿠커를 검색하고 연결합니다.'),
    (Icons.restaurant_menu, '레시피 선택', '자동·반자동 조리를 지원하는 레시피를 선택합니다.'),
    (Icons.tune, '온도와 시간 확인', '조리 단계별 온도와 시간을 확인하거나 수정합니다.'),
    (Icons.play_circle_outline, '조리 시작', '앱에서 전송한 뒤 쿠커의 시작 버튼을 눌러 조리를 시작합니다.'),
    (Icons.warning_amber, '냉각 확인', '조리 완료 후 고온 주의 안내와 냉각 상태를 확인합니다.'),
  ];
  @override
  Widget build(BuildContext context) => _PageScaffold(
        title: '튜토리얼 다시 보기',
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('멀티쿠커 사용 안내', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('아래 순서대로 진행하면 조리를 시작할 수 있습니다.', style: TextStyle(color: _muted)),
          const SizedBox(height: 24),
          for (var i = 0; i < steps.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(backgroundColor: const Color(0xFFFFEDD5), child: Icon(steps[i].$1, color: _orange)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${i + 1}. ${steps[i].$2}', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(steps[i].$3, style: const TextStyle(color: _muted, height: 1.4))])),
            ]))),
          ),
          FilledButton(onPressed: () async {
            final profile = context.read<ProfileProvider>();
            await profile.updateSettings(profile.settings.copyWith(tutorialCompleted: true));
            if (context.mounted) context.go('/home');
          }, child: const Text('시작하기')),
        ]),
      );
}


class _RecipeManagementHeader extends StatelessWidget {
  const _RecipeManagementHeader({
    required this.myRecipeCount,
    required this.savedRecipeCount,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final int myRecipeCount;
  final int savedRecipeCount;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _ManagementTabButton(
              label: '내 레시피',
              count: myRecipeCount,
              icon: Icons.restaurant_menu_rounded,
              selected: selectedTab == 0,
              onTap: () => onTabChanged(0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ManagementTabButton(
              label: '저장한 레시피',
              count: savedRecipeCount,
              icon: Icons.bookmark_rounded,
              selected: selectedTab == 1,
              onTap: () => onTabChanged(1),
            ),
          ),
        ],
      );
}

class _ManagementTabButton extends StatelessWidget {
  const _ManagementTabButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? _orangeSoft : _bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? _orange : _line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? _orange : _muted,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? _orange : _text,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: selected ? const Color(0xFFFED7AA) : _line,
                    ),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? _orange : _muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MyReviewCard extends StatelessWidget {
  const _MyReviewCard({
    required this.review,
    required this.onOpenRecipe,
    required this.onEdit,
    required this.onDelete,
  });

  final MyReviewItem review;
  final VoidCallback onOpenRecipe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => _Card(
        child: InkWell(
          onTap: onOpenRecipe,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                _RecipeThumb(
                  url: review.reviewImageUrl?.trim().isNotEmpty == true
                      ? review.reviewImageUrl
                      : review.recipeImage,
                  size: 48,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.recipeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _RatingStars(rating: review.rating),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              review.date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.favorite_border_rounded,
                            size: 14,
                            color: _muted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${review.likes}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppMoreMenuButton<String>(
                  tooltip: '후기 관리',
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 19),
                          SizedBox(width: 8),
                          Text('수정'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: _danger,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '삭제',
                            style: TextStyle(color: _danger),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 14,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(width: 3),
            Text(
              '$rating.0',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
          ],
        ),
      );
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _orangeSoft,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            height: 1,
            color: _orange,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _muted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ],
        ),
      );
}

class _PersonalRecipeList extends StatelessWidget {
  const _PersonalRecipeList({required this.items});

  final List<Recipe> items;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 7),
        itemBuilder: (context, index) {
          final recipe = items[index];
          return _Card(
            child: InkWell(
              onTap: () => context.push(
                '/recipes/${Uri.encodeComponent(recipe.id)}',
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RecipeThumb(url: recipe.thumbnailUrl, size: 54),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  recipe.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.3,
                                    fontWeight: FontWeight.w800,
                                    color: _text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _MiniPill(recipe.visibilityLabel),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _MetaPill(
                                icon: Icons.schedule_rounded,
                                label: '${recipe.totalTimeMin}분',
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  recipe.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    AppMoreMenuButton<String>(
                      tooltip: '레시피 관리',
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await context.push(
                            '/my/recipes/${Uri.encodeComponent(recipe.id)}/edit',
                            extra: recipe,
                          );
                          if (context.mounted) {
                            await context
                                .read<RecipeProvider>()
                                .loadMyRecipes();
                          }
                          return;
                        }
                        if (value == 'visibility') {
                          final nextVisibility =
                              recipe.isPublic ? 'private' : 'public';
                          final ok = await context
                              .read<RecipeProvider>()
                              .setMyRecipeVisibility(
                                recipe.id,
                                nextVisibility,
                              );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? (nextVisibility == 'public'
                                          ? '레시피를 공개했습니다.'
                                          : '레시피를 비공개로 변경했습니다.')
                                      : (context
                                              .read<RecipeProvider>()
                                              .errorMessage ??
                                          '공개 범위를 변경하지 못했습니다.'),
                                ),
                              ),
                            );
                          return;
                        }
                        if (value != 'delete') return;
                        await _confirm(
                          context,
                          title: '레시피 삭제',
                          message: '이 레시피를 삭제하시겠습니까?',
                          onOk: () => context
                              .read<RecipeProvider>()
                              .deleteMyRecipe(recipe.id),
                        );
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 19),
                              SizedBox(width: 8),
                              Text('수정'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'visibility',
                          child: Row(
                            children: [
                              Icon(Icons.public_outlined, size: 19),
                              SizedBox(width: 8),
                              Text('공개/비공개 변경'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: _danger,
                                size: 19,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '삭제',
                                style: TextStyle(color: _danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({
    required this.items,
    required this.trailingBuilder,
    this.topPadding = 0,
  });

  final List<ProfileRecipeItem> items;
  final Widget Function(ProfileRecipeItem item) trailingBuilder;
  final double topPadding;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 7),
        itemBuilder: (context, index) {
          final recipe = items[index];
          return _Card(
            child: InkWell(
              onTap: () async {
                final recipeProvider = context.read<RecipeProvider>();
                final found =
                    await recipeProvider.ensureRecipeLoaded(recipe.id);
                if (!context.mounted) return;
                if (!found) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          recipeProvider.errorMessage ??
                              '레시피 상세 정보를 불러오지 못했습니다. 다시 시도해 주십시오.',
                        ),
                      ),
                    );
                  return;
                }
                context.push(
                  '/recipes/${Uri.encodeComponent(recipe.id)}',
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RecipeThumb(url: recipe.thumbnailUrl, size: 54),
                    const SizedBox(width: 10),
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
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _MetaPill(
                                icon: Icons.schedule_rounded,
                                label: '${recipe.totalTimeMin}분',
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  recipe.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    trailingBuilder(recipe),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _RecipeThumb extends StatelessWidget {
  const _RecipeThumb({this.url, this.size = 56});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim();
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _orangeSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Icon(
        Icons.restaurant_rounded,
        color: _orange,
        size: 24,
      ),
    );
    if (value == null || value.isEmpty) return placeholder;

    final image = value.startsWith('http')
        ? Image.network(
            value,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          )
        : Image.asset(
            value,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: image,
    );
  }
}

class _AsyncBody extends StatelessWidget {
  const _AsyncBody({
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.child,
  });

  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: _orange),
      );
    }

    if (error != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _ErrorBanner(message: error!),
          ),
          Expanded(
            child: RefreshIndicator(
              color: _orange,
              onRefresh: onRefresh,
              child: child,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: _orange,
      onRefresh: onRefresh,
      child: child,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: _danger,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _danger,
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    required this.title,
    required this.child,
    this.floatingActionButton,
  });

  final String title;
  final Widget child;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: SectionPageAppBar(title: title),
        body: child,
        floatingActionButton: floatingActionButton,
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: child,
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _orangeSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, size: 30, color: _orange),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: _muted,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: Text(
                        actionLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _text)));
}

Future<void> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required Future<bool> Function() onOk,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _line),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _text,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: _muted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: TextButton.styleFrom(foregroundColor: _muted),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            final ok = await onOk();
            if (dialogContext.mounted && ok) {
              Navigator.pop(dialogContext);
            }
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
