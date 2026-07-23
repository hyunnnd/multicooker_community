import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../../community/data/models/community_models.dart';
import '../../community/provider/community_provider.dart';
import '../../cooking/data/models/cooking_session_state.dart';
import '../../cooking/provider/cooking_session_provider.dart';
import '../data/models/recipe.dart';
import '../provider/recipe_provider.dart';
import 'widgets/compatibility_badge.dart';
import 'widgets/cooker_step_card.dart';
import 'widgets/instruction_step_card.dart';

const _orange = Color(0xFFF97316);
const _ink = Color(0xFF292929);
const _border = Color(0xFFE8E2D7);

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({required this.recipeId, super.key});

  final String recipeId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  static const _labels = ['소개', '재료', '조리방법', '쿠커 설정'];
  final _controller = ScrollController();
  final _sectionKeys = List.generate(4, (_) => GlobalKey());
  int _activeSection = 0;
  double _progress = .25;
  bool _liked = false;
  bool _lookupStarted = false;
  bool _lookupInProgress = false;
  String? _lookupError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateAnchor);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRecipe());
  }

  Future<void> _ensureRecipe({bool retry = false}) async {
    if (!mounted || _lookupInProgress) return;
    final provider = context.read<RecipeProvider>();
    if (!retry && provider.recipeById(widget.recipeId) != null) return;

    setState(() {
      _lookupStarted = true;
      _lookupInProgress = true;
      _lookupError = null;
    });
    final found = await provider.ensureRecipeLoaded(widget.recipeId);
    if (!mounted) return;
    setState(() {
      _lookupInProgress = false;
      _lookupError = found
          ? null
          : provider.errorMessage ?? '레시피 상세 정보를 불러오지 못했습니다.';
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateAnchor)
      ..dispose();
    super.dispose();
  }

  void _updateAnchor() {
    final positions = _sectionKeys.map((key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      return box?.localToGlobal(Offset.zero).dy;
    }).toList();
    if (positions.any((position) => position == null)) return;

    const marker = 112.0;
    var section = 0;
    for (var index = 0; index < positions.length; index++) {
      if (positions[index]! <= marker) section = index;
    }
    final next = section + 1;
    final fraction = next < positions.length
        ? ((marker - positions[section]!) /
                  (positions[next]! - positions[section]!))
              .clamp(0.0, 1.0)
        : 0.0;
    final progress =
        (next < positions.length
                ? (section + 1 + fraction) / positions.length
                : 1.0)
            .toDouble();
    if (section != _activeSection || (progress - _progress).abs() > .005) {
      setState(() {
        _activeSection = section;
        _progress = progress;
      });
    }
  }

  Future<void> _goToSection(int index) async {
    final target = _sectionKeys[index].currentContext;
    if (target == null) return;
    setState(() {
      _activeSection = index;
      _progress = (index + 1) / _labels.length;
    });
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: .45,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final recipe = provider.recipeById(widget.recipeId);
    final isOwnedRecipe = provider.personalRecipes.any(
      (item) => item.id == widget.recipeId,
    );
    if (recipe == null) {
      if (!_lookupStarted || _lookupInProgress || provider.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('레시피')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _lookupError ?? '레시피를 찾을 수 없습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _ensureRecipe(retry: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 불러오기'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFF5),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: recipe.supportsCooker
                ? () {
                    final session = context.read<CookingSessionProvider>();
                    final sameRecipe = session.currentRecipe?.id == recipe.id;
                    final phase = session.state.phase;
                    if (!sameRecipe ||
                        phase == CookingPhase.idle ||
                        phase == CookingPhase.completed) {
                      session.prepareRecipe(recipe);
                    }
                    context.push('/recipes/${recipe.id}/cook');
                  }
                : null,
            icon: const Icon(Icons.soup_kitchen_outlined),
            label: const Text('이 레시피로 조리하기'),
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _controller,
        slivers: [
          _Hero(
            recipe: recipe,
            liked: _liked,
            onLike: () => setState(() => _liked = !_liked),
            onSave: () => provider.toggleSaved(recipe.id),
            onEdit: isOwnedRecipe
                ? () => context.push(
                    '/my/recipes/${Uri.encodeComponent(recipe.id)}/edit',
                    extra: recipe,
                  )
                : null,
            onShare: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('공유 링크를 준비했습니다.'))),
          ),
          SliverToBoxAdapter(child: _Summary(recipe: recipe)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _AnchorHeader(
              labels: _labels,
              active: _activeSection,
              progress: _progress,
              onTap: _goToSection,
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              key: _sectionKeys[0],
              title: '레시피 소개',
              child: Text(
                recipe.description,
                style: const TextStyle(color: Color(0xFF77736C), height: 1.55),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              key: _sectionKeys[1],
              title: '재료',
              child: Column(
                children: [
                  if (recipe.ingredients.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '등록된 재료 정보가 없습니다.',
                        style: TextStyle(color: Color(0xFF77736C)),
                      ),
                    ),
                  for (final ingredient in recipe.ingredients)
                    _IngredientRow(
                      name: ingredient.name,
                      amount: ingredient.amount,
                      optional: !ingredient.isRequired,
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              key: _sectionKeys[2],
              title: '조리방법',
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < recipe.instructionSteps.length;
                    index++
                  ) ...[
                    InstructionStepCard(step: recipe.instructionSteps[index]),
                    if (index < recipe.instructionSteps.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              key: _sectionKeys[3],
              title: '쿠커 설정',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '조리 시작 시 아래 값이 쿠커에 전송됩니다.',
                    style: TextStyle(color: Color(0xFF77736C)),
                  ),
                  const SizedBox(height: 12),
                  for (
                    var index = 0;
                    index < recipe.cookerSteps.length;
                    index++
                  ) ...[
                    CookerStepCard(step: recipe.cookerSteps[index]),
                    if (index < recipe.cookerSteps.length - 1)
                      const SizedBox(height: 10),
                  ],
                  if (recipe.id == 'rice') ...[
                    const SizedBox(height: 12),
                    const Text(
                      '가열 완료 후에는 전원을 추가로 가열하지 않고 5분간 뜸을 들입니다.',
                      style: TextStyle(color: Color(0xFF77736C)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _CommunitySection(recipe: recipe)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.name,
    required this.amount,
    required this.optional,
  });

  final String name;
  final String amount;
  final bool optional;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9ED),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
          ),
        ),
        if (optional) ...[
          const Text(
            '선택',
            style: TextStyle(color: Color(0xFF77736C), fontSize: 12),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          amount,
          style: const TextStyle(color: _orange, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.recipe,
    required this.liked,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    this.onEdit,
  });

  final Recipe recipe;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => SliverAppBar(
    expandedHeight: 250,
    leadingWidth: 56,
    leading: const Padding(
      padding: EdgeInsets.only(left: 16),
      child: AppBackButton(heroOverlay: true),
    ),
    actionsPadding: const EdgeInsets.only(right: 12),
    actions: [
      if (onEdit != null)
        _HeroActionButton(
          tooltip: '내 레시피 수정',
          onPressed: onEdit!,
          icon: Icons.edit_outlined,
        ),
      _HeroActionButton(
        tooltip: liked ? '좋아요 취소' : '좋아요',
        onPressed: onLike,
        icon: liked ? Icons.favorite : Icons.favorite_border,
      ),
      _HeroActionButton(
        tooltip: recipe.isSaved ? '저장 취소' : '저장',
        onPressed: onSave,
        icon: recipe.isSaved ? Icons.bookmark : Icons.bookmark_border,
      ),
      _HeroActionButton(
        tooltip: '공유',
        onPressed: onShare,
        icon: Icons.ios_share,
      ),
    ],
    iconTheme: const IconThemeData(color: Colors.white),
    flexibleSpace: FlexibleSpaceBar(
      background: Stack(
        fit: StackFit.expand,
        children: [
          if (recipe.thumbnailUrl != null)
            Image.network(
              recipe.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: _ink),
            )
          else
            const ColoredBox(color: _ink),
          const ColoredBox(color: Color(0x52000000)),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompatibilityBadge(type: recipe.compatibilityType),
                const SizedBox(height: 8),
                Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (recipe.isOfficial) ...[
                      const Icon(
                        Icons.verified,
                        size: 15,
                        color: Color(0xFF2BAE66),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      recipe.author,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    child: Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0x99505050),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 21, color: Colors.white),
        ),
      ),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(Icons.schedule, '${recipe.totalTimeMin}분', '조리 시간'),
        _Stat(Icons.restaurant_menu, recipe.difficulty, '난이도'),
        _Stat(Icons.people_outline, '${recipe.servings}인분', '인원'),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label);

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 19, color: _orange),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF77736C)),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _AnchorHeader extends SliverPersistentHeaderDelegate {
  const _AnchorHeader({
    required this.labels,
    required this.active,
    required this.progress,
    required this.onTap,
  });

  final List<String> labels;
  final int active;
  final double progress;
  final ValueChanged<int> onTap;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Colors.white,
      elevation: overlapsContent ? 1 : 0,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(
                    child: TextButton(
                      onPressed: () => onTap(index),
                      child: Text(
                        labels[index],
                        style: TextStyle(
                          color: active == index
                              ? _orange
                              : const Color(0xFF77736C),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: const Color(0xFFF1EEE8),
              color: _orange,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AnchorHeader oldDelegate) =>
      active != oldDelegate.active || progress != oldDelegate.progress;
}

class _CommunitySection extends StatefulWidget {
  const _CommunitySection({required this.recipe});

  final Recipe recipe;

  @override
  State<_CommunitySection> createState() => _CommunitySectionState();
}

class _CommunitySectionState extends State<_CommunitySection> {
  final _commentController = TextEditingController();
  bool _reviews = true;
  bool _latest = true;
  bool _submittingComment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CommunityProvider>().loadRecipeCommunity(widget.recipe.id);
    });
  }

  @override
  void didUpdateWidget(covariant _CommunitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe.id != widget.recipe.id) {
      _commentController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CommunityProvider>().loadRecipeCommunity(widget.recipe.id);
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final reviews = provider.reviewsForRecipe(widget.recipe.id).toList();
    final comments = provider.commentsForRecipe(widget.recipe.id).toList();
    final loading = provider.isRecipeCommunityLoading(widget.recipe.id);
    final error = provider.recipeCommunityError(widget.recipe.id);

    reviews.sort((a, b) {
      if (_latest) {
        final byTime = (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      }
      final byLikes = b.likes.compareTo(a.likes);
      return byLikes != 0 ? byLikes : b.id.compareTo(a.id);
    });
    comments.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _latest ? bTime.compareTo(aTime) : aTime.compareTo(bTime);
    });

    return _Section(
      title: '후기 · 댓글',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text('후기 ${reviews.length}')),
              ButtonSegment(value: false, label: Text('댓글 ${comments.length}')),
            ],
            selected: {_reviews},
            onSelectionChanged: (value) =>
                setState(() => _reviews = value.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_reviews)
                FilledButton.icon(
                  onPressed: _openReviewWriter,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('후기 작성'),
                )
              else
                const Expanded(
                  child: Text(
                    '레시피에 대한 질문이나 조리 팁을 남겨보세요.',
                    style: TextStyle(color: Color(0xFF77736C), fontSize: 12),
                  ),
                ),
              if (_reviews) const Spacer(),
              DropdownButton<bool>(
                value: _latest,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: true, child: Text('최신순')),
                  DropdownMenuItem(
                    value: false,
                    child: Text(_reviews ? '인기순' : '오래된순'),
                  ),
                ],
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 4,
                iconEnabledColor: const Color(0xFF6B7280),
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                onChanged: (value) => setState(() => _latest = value ?? true),
              ),
            ],
          ),
          if (!_reviews) ...[
            const SizedBox(height: 10),
            _buildCommentComposer(),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '후기와 댓글을 불러오지 못했습니다.',
                      style: TextStyle(color: Color(0xFFBE123C)),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        provider.loadRecipeCommunity(widget.recipe.id),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (loading && reviews.isEmpty && comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_reviews)
            _buildReviews(reviews)
          else
            _buildComments(comments),
        ],
      ),
    );
  }

  Widget _buildReviews(List<CommunityReview> reviews) {
    if (reviews.isEmpty) {
      return const _RecipeCommunityEmpty(
        icon: Icons.rate_review_outlined,
        message: '아직 등록된 후기가 없습니다.\n첫 후기를 작성해 보세요.',
      );
    }
    return Column(
      children: [
        for (final review in reviews)
          _RecipeReviewTile(
            review: review,
            onLike: () =>
                context.read<CommunityProvider>().toggleReviewLike(review.id),
          ),
      ],
    );
  }

  Widget _buildComments(List<RecipeCommunityComment> comments) {
    if (comments.isEmpty) {
      return const _RecipeCommunityEmpty(
        icon: Icons.chat_bubble_outline,
        message: '아직 등록된 댓글이 없습니다.\n레시피에 대한 질문이나 팁을 남겨보세요.',
      );
    }
    return Column(
      children: [
        for (final comment in comments)
          _RecipeCommentTile(
            comment: comment,
            onEdit: comment.isMine ? () => _editComment(comment) : null,
            onDelete: comment.isMine ? () => _deleteComment(comment) : null,
          ),
      ],
    );
  }

  Widget _buildCommentComposer() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F5F1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFFE7E2D8),
          child: Icon(Icons.person_outline, size: 19, color: Color(0xFF77736C)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: TextField(
            controller: _commentController,
            minLines: 1,
            maxLines: 4,
            maxLength: 500,
            textAlignVertical: TextAlignVertical.center,
            decoration: const InputDecoration(
              hintText: '댓글을 입력하세요.',
              counterText: '',
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        IconButton.filled(
          onPressed: _submittingComment ? null : _submitComment,
          style: IconButton.styleFrom(backgroundColor: _orange),
          icon: _submittingComment
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 19),
        ),
      ],
    ),
  );

  Future<void> _openReviewWriter() async {
    final params = <String, String>{
      'write': '1',
      'recipeId': widget.recipe.id,
      'recipeTitle': widget.recipe.title,
      if ((widget.recipe.thumbnailUrl ?? '').trim().isNotEmpty)
        'recipeImage': widget.recipe.thumbnailUrl!.trim(),
    };
    final created = await context.push<bool>(
      Uri(path: '/community', queryParameters: params).toString(),
    );
    if (!mounted || created != true) return;
    await context.read<CommunityProvider>().loadRecipeCommunity(
      widget.recipe.id,
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _submittingComment = true);
    final ok = await context.read<CommunityProvider>().addRecipeComment(
      recipeId: widget.recipe.id,
      recipeTitle: widget.recipe.title,
      content: content,
    );
    if (!mounted) return;
    setState(() => _submittingComment = false);
    if (ok) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } else {
      _showMessage(
        context.read<CommunityProvider>().recipeCommunityError(
              widget.recipe.id,
            ) ??
            '댓글을 등록하지 못했습니다.',
      );
    }
  }

  Future<void> _editComment(RecipeCommunityComment comment) async {
    final controller = TextEditingController(text: comment.content);
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || content == null || content.isEmpty) return;
    final ok = await context.read<CommunityProvider>().updateRecipeComment(
      widget.recipe.id,
      comment.id,
      content,
    );
    if (!ok && mounted) {
      _showMessage('댓글을 수정하지 못했습니다.');
    }
  }

  Future<void> _deleteComment(RecipeCommunityComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<CommunityProvider>().deleteRecipeComment(
      widget.recipe.id,
      comment.id,
    );
    if (!ok && mounted) _showMessage('댓글을 삭제하지 못했습니다.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RecipeReviewTile extends StatelessWidget {
  const _RecipeReviewTile({required this.review, required this.onLike});

  final CommunityReview review;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _border)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: Color(review.avatarColor),
          child: Text(
            review.username.isEmpty ? '?' : review.username.characters.first,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.username,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    review.relativeTime,
                    style: const TextStyle(
                      color: Color(0xFF99948B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var value = 1; value <= 5; value++)
                    Icon(
                      value <= review.rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 17,
                      color: _orange,
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                review.content,
                style: const TextStyle(color: Color(0xFF55514B), height: 1.45),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onLike,
                style: TextButton.styleFrom(
                  foregroundColor: review.isLiked
                      ? _orange
                      : const Color(0xFF77736C),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  review.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 17,
                ),
                label: Text('좋아요 ${review.likes}'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RecipeCommentTile extends StatelessWidget {
  const _RecipeCommentTile({required this.comment, this.onEdit, this.onDelete});

  final RecipeCommunityComment comment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _border)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: Color(comment.avatarColor),
          child: Text(
            comment.username.isEmpty ? '?' : comment.username.characters.first,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.username,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    comment.relativeTime,
                    style: const TextStyle(
                      color: Color(0xFF99948B),
                      fontSize: 12,
                    ),
                  ),
                  if (comment.isMine)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 19,
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('수정')),
                        PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                comment.content,
                style: const TextStyle(color: Color(0xFF55514B), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RecipeCommunityEmpty extends StatelessWidget {
  const _RecipeCommunityEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFFB8B2A8), size: 34),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF77736C), height: 1.5),
        ),
      ],
    ),
  );
}
