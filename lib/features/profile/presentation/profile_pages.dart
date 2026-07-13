import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../recipe/provider/recipe_provider.dart';
import '../data/profile_models.dart';
import '../provider/profile_provider.dart';

const _orange = Color(0xFFF97316);
const _bg = Color(0xFFF8FAFC);
const _line = Color(0xFFE5E7EB);
const _muted = Color(0xFF6B7280);
const _text = Color(0xFF111827);
const _danger = Color(0xFFDC2626);

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ProfileProvider>().loadMyRecipes());
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    return _PageScaffold(
      title: '내가 올린 레시피',
      actions: [
        IconButton(
          tooltip: '레시피 등록',
          onPressed: () => context.push('/my/recipes/new'),
          icon: const Icon(Icons.add),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/my/recipes/new'),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('레시피 등록'),
      ),
      child: _AsyncBody(
        loading: profile.isLoading && profile.myRecipes.isEmpty,
        error: profile.errorMessage,
        onRefresh: () => context.read<ProfileProvider>().loadMyRecipes(),
        child: profile.myRecipes.isEmpty
            ? _EmptyState(
                icon: Icons.restaurant_menu,
                title: '등록한 레시피가 없습니다',
                description: '직접 레시피를 등록하거나 조리 이력에서 레시피로 저장하면 여기에 표시됩니다.',
                actionLabel: '레시피 등록하기',
                onAction: () => context.push('/my/recipes/new'),
              )
            : _RecipeList(
                items: profile.myRecipes,
                trailingBuilder: (item) => const Icon(
                  Icons.chevron_right,
                  color: _muted,
                ),
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
                trailingBuilder: (item) => IconButton(
                  tooltip: '저장 해제',
                  icon: const Icon(Icons.bookmark, color: _orange),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ProfileProvider>().loadMyReviews());
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    return _PageScaffold(
      title: '내가 쓴 후기',
      child: _AsyncBody(
        loading: profile.isLoading && profile.reviews.isEmpty,
        error: profile.errorMessage,
        onRefresh: () => context.read<ProfileProvider>().loadMyReviews(),
        child: profile.reviews.isEmpty
            ? const _EmptyState(icon: Icons.rate_review_outlined, title: '작성한 후기가 없습니다', description: '조리한 레시피에 첫 후기를 남겨 보십시오.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: profile.reviews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = profile.reviews[i];
                  return _Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text(r.recipeTitle, style: const TextStyle(fontWeight: FontWeight.w900))), Text(r.date, style: const TextStyle(fontSize: 12, color: _muted))]),
                        const SizedBox(height: 8),
                        Text('★' * r.rating, style: const TextStyle(color: Color(0xFFF59E0B))),
                        const SizedBox(height: 8),
                        Text(r.content, style: const TextStyle(height: 1.45)),
                        const SizedBox(height: 10),
                        Row(children: [
                          TextButton(onPressed: () => context.push('/recipes/${r.recipeId}'), child: const Text('레시피 보기')),
                          const Spacer(),
                          Text('좋아요 ${r.likes} · 댓글 ${r.commentCount}', style: const TextStyle(fontSize: 12, color: _muted)),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _editReview(context, r);
                              if (value == 'delete') _confirm(context, title: '후기 삭제', message: '후기를 삭제하시겠습니까?', onOk: () => context.read<ProfileProvider>().deleteReview(r.id));
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('수정')),
                              PopupMenuItem(value: 'delete', child: Text('삭제')),
                            ],
                          ),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _editReview(BuildContext context, MyReviewItem review) async {
    var rating = review.rating;
    final controller = TextEditingController(text: review.content);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('후기 수정'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++) IconButton(icon: Icon(i <= rating ? Icons.star : Icons.star_border, color: const Color(0xFFF59E0B)), onPressed: () => setDialogState(() => rating = i)),
            ]),
            TextField(controller: controller, minLines: 3, maxLines: 5, decoration: const InputDecoration(hintText: '후기 내용')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                final ok = await context.read<ProfileProvider>().updateReview(review.id, rating: rating, content: controller.text.trim());
                if (dialogContext.mounted && ok) Navigator.pop(dialogContext);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
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
                padding: const EdgeInsets.all(16),
                itemCount: profile.comments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final row = profile.comments[i];
                  final openPath = '/community?postId=${row.postId}';
                  return _Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                            Text(row.timeAgo, style: const TextStyle(fontSize: 12, color: _muted)),
                          ],
                        ),
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
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
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ProfileProvider>().loadCookingHistories());
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
            ? const _EmptyState(icon: Icons.history, title: '조리 이력이 없습니다', description: '조리가 완료되면 이력이 자동으로 표시됩니다.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: profile.histories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = profile.histories[i];
                  final completed = item.completed;
                  return _Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: completed ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), child: Icon(completed ? Icons.check : Icons.stop, color: completed ? const Color(0xFF16A34A) : _danger)),
                      title: Text(item.recipeTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text('${_formatDate(item.startedAt)} · ${item.deviceName}\n${item.maxTemperature}℃ · ${item.totalTimeMin}분'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'cook') {
                            if (item.recipeId != null) {
                              context.push('/recipes/${item.recipeId}/prepare');
                            } else {
                              context.go('/device');
                            }
                          }
                          if (value == 'save') {
                            final ok = await context
                                .read<ProfileProvider>()
                                .saveHistoryAsRecipe(item.id);
                            if (context.mounted && ok) {
                              await context.read<RecipeProvider>().loadRecipes();
                            }
                            if (context.mounted && ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('회사 개인 레시피로 저장했습니다.'),
                                ),
                              );
                            }
                          }
                          if (value == 'delete') _confirm(context, title: '이력 삭제', message: '조리 이력을 삭제하시겠습니까?', onOk: () => context.read<ProfileProvider>().deleteCookingHistory(item.id));
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'cook', child: Text('같은 설정으로 조리')),
                          PopupMenuItem(value: 'save', child: Text('레시피로 저장')),
                          PopupMenuItem(value: 'delete', child: Text('삭제')),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
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
        title: '튜토리얼',
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('멀티쿠커 사용 안내', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('아래 순서대로 진행하면 조리를 시작할 수 있습니다.', style: TextStyle(color: _muted)),
          const SizedBox(height: 24),
          for (var i = 0; i < steps.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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


class _MiniPill extends StatelessWidget {
  const _MiniPill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(fontSize: 11, color: _orange, fontWeight: FontWeight.w800)),
      );
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({required this.items, required this.trailingBuilder});
  final List<ProfileRecipeItem> items;
  final Widget Function(ProfileRecipeItem item) trailingBuilder;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final recipe = items[index];
          return _Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: _RecipeThumb(url: recipe.thumbnailUrl),
              title: Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${recipe.maxTemperature}℃ · ${recipe.totalTimeMin}분\n${recipe.author}', maxLines: 2),
              isThreeLine: true,
              trailing: trailingBuilder(recipe),
              onTap: () => context.push('/recipes/${recipe.id}'),
            ),
          );
        },
      );
}

class _RecipeThumb extends StatelessWidget {
  const _RecipeThumb({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    final value = url;
    if (value == null || value.isEmpty) return const SizedBox(width: 68, height: 68, child: Icon(Icons.restaurant));
    if (value.startsWith('http')) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(value, width: 68, height: 68, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 68, height: 68, child: Icon(Icons.restaurant))));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(value, width: 68, height: 68, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 68, height: 68, child: Icon(Icons.restaurant))));
  }
}

class _AsyncBody extends StatelessWidget {
  const _AsyncBody({required this.loading, required this.error, required this.onRefresh, required this.child});
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: error != null
          ? ListView(padding: const EdgeInsets.all(16), children: [_ErrorBanner(message: error!), const SizedBox(height: 12), child])
          : child,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFECACA))),
        child: Text(message, style: const TextStyle(color: _danger, fontSize: 12)),
      );
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.title, required this.child, this.actions, this.floatingActionButton});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), actions: actions),
        body: child,
        floatingActionButton: floatingActionButton,
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 4))]), child: child);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.description, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(32), children: [
        SizedBox(height: MediaQuery.of(context).size.height * .18),
        Icon(icon, size: 58, color: _orange),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          Center(child: FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add), label: Text(actionLabel!))),
        ],
      ]);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _text)));
}

Future<void> _confirm(BuildContext context, {required String title, required String message, required Future<bool> Function() onOk}) async {
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
      FilledButton(onPressed: () async {
        final ok = await onOk();
        if (dialogContext.mounted && ok) Navigator.pop(dialogContext);
      }, child: const Text('확인')),
    ],
  ));
}

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
