import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../data/models/recipe.dart';
import '../provider/recipe_provider.dart';
import '../../community/provider/community_provider.dart';
import 'widgets/compatibility_badge.dart';
import 'widgets/cooker_step_card.dart';
import 'widgets/instruction_step_card.dart';
import '../../../core/widgets/app_image.dart';

const _orange = Color(0xFFF97316);
const _ink = Color(0xFF292929);
const _border = Color(0xFFE8E2D7);
const _yellow = Color(0xFFFACC15);
const _muted = Color(0xFF77736C);
const _softBg = Color(0xFFF9FAFB);

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateAnchor);
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
      alignment: .08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final recipe = provider.recipeById(widget.recipeId);
    if (recipe == null) {
      return const Scaffold(body: Center(child: Text('레시피를 찾을 수 없습니다.')));
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
                ? () => context.push('/recipes/${recipe.id}/cook')
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
                  for (final ingredient in recipe.ingredients)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: ingredient.isPrepared,
                      activeColor: _orange,
                      onChanged: (_) => provider.toggleIngredientPrepared(
                        recipe.id,
                        ingredient.name,
                      ),
                      title: Text(ingredient.name),
                      subtitle: ingredient.isRequired
                          ? null
                          : const Text('선택 재료'),
                      secondary: Text(
                        ingredient.amount,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
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
          SliverToBoxAdapter(child: _RecipeReviewSection(recipe: recipe)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.recipe,
    required this.liked,
    required this.onLike,
    required this.onSave,
    required this.onShare,
  });

  final Recipe recipe;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => SliverAppBar(
    expandedHeight: 250,
    leading: const AppBackButton(),
    actions: [
      IconButton(
        tooltip: liked ? '좋아요 취소' : '좋아요',
        onPressed: onLike,
        icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
      ),
      IconButton(
        tooltip: recipe.isSaved ? '저장 취소' : '저장',
        onPressed: onSave,
        icon: Icon(recipe.isSaved ? Icons.bookmark : Icons.bookmark_border),
      ),
      IconButton(
        tooltip: '공유',
        onPressed: onShare,
        icon: const Icon(Icons.ios_share),
      ),
    ],
    iconTheme: const IconThemeData(color: Colors.white),
    flexibleSpace: FlexibleSpaceBar(
      background: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(
            source: recipe.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: const ColoredBox(color: _ink),
          ),
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


class _RecipeReviewSection extends StatefulWidget {
  const _RecipeReviewSection({required this.recipe});

  final Recipe recipe;

  @override
  State<_RecipeReviewSection> createState() => _RecipeReviewSectionState();
}

class _RecipeReviewSectionState extends State<_RecipeReviewSection> {
  final _contentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;
  bool _showWriteForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final community = context.read<CommunityProvider>();
      if (community.reviews.isEmpty) community.load(silent: true);
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final community = context.watch<CommunityProvider>();
    final reviews = community.reviews
        .where((review) => review.matchesRecipe(widget.recipe.id, widget.recipe.title))
        .toList();
    final ratingAverage = reviews.isEmpty
        ? 0.0
        : reviews.map((review) => review.rating).reduce((a, b) => a + b) / reviews.length;

    return _Section(
      title: '후기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewSummaryCard(
            count: reviews.length,
            ratingAverage: ratingAverage,
            onWritePressed: () => setState(() => _showWriteForm = !_showWriteForm),
          ),
          if (_showWriteForm) ...[
            const SizedBox(height: 12),
            _ReviewWriteCard(
              rating: _rating,
              controller: _contentController,
              submitting: _submitting,
              onRatingChanged: (value) => setState(() => _rating = value),
              onCancel: () => setState(() {
                _showWriteForm = false;
                _contentController.clear();
                _rating = 5;
              }),
              onSubmit: _submitReview,
            ),
          ],
          const SizedBox(height: 14),
          if (reviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                color: _softBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: const Text(
                '아직 등록된 후기가 없습니다. 첫 후기를 남겨보세요.',
                style: TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w700),
              ),
            )
          else ...[
            const Text(
              '최근 후기',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _ink),
            ),
            const SizedBox(height: 10),
            for (final review in reviews.take(5)) ...[
              _RecipeReviewItem(
                username: review.username,
                date: review.date,
                rating: review.rating,
                content: review.content,
                likes: review.likes,
                liked: community.likedReviewIds.contains(review.id),
                onLike: () => community.toggleReviewLike(review.id),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _submitReview() async {
    final content = _contentController.text.trim();
    if (content.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await context.read<CommunityProvider>().createReview(
            recipeId: widget.recipe.id,
            recipeTitle: widget.recipe.title,
            recipeImage: widget.recipe.thumbnailUrl ?? '',
            rating: _rating,
            content: content,
          );
      if (!mounted) return;
      _contentController.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _rating = 5;
        _submitting = false;
        _showWriteForm = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('후기가 등록되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('후기 등록에 실패했습니다. 서버 연결을 확인해 주세요.')),
      );
    }
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({
    required this.count,
    required this.ratingAverage,
    required this.onWritePressed,
  });

  final int count;
  final double ratingAverage;
  final VoidCallback onWritePressed;

  @override
  Widget build(BuildContext context) {
    final hasReviews = count > 0;
    final averageText = hasReviews ? ratingAverage.toStringAsFixed(1) : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F2F4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.star_rounded, color: _orange, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      averageText,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        hasReviews ? '평균 별점' : '평가 대기',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: hasReviews && i <= ratingAverage.round()
                            ? _yellow
                            : const Color(0xFFE5E7EB),
                      ),
                    const SizedBox(width: 7),
                    Text(
                      '$count개 후기',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onWritePressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: _orange,
              side: const BorderSide(color: Color(0xFFFFD8B3)),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            icon: const Icon(Icons.edit_rounded, size: 15),
            label: const Text(
              '후기 작성',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewWriteCard extends StatelessWidget {
  const _ReviewWriteCard({
    required this.rating,
    required this.controller,
    required this.submitting,
    required this.onRatingChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final int rating;
  final TextEditingController controller;
  final bool submitting;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE4C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '레시피 후기 작성',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _ink),
                ),
              ),
              TextButton(
                onPressed: submitting ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9CA3AF),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('닫기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              children: [
                const Text(
                  '별점',
                  style: TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        GestureDetector(
                          onTap: () => onRatingChanged(i),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(
                              Icons.star_rounded,
                              size: 26,
                              color: i <= rating ? _yellow : const Color(0xFFE5E7EB),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '$rating점',
                  style: const TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: '맛, 조리 난이도, 온도·시간 팁을 간단히 남겨주세요.',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFFB978)),
              ),
              contentPadding: const EdgeInsets.all(12),
              counterStyle: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
            ),
            style: const TextStyle(fontSize: 13, height: 1.45, color: _ink),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _muted,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: submitting ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(
                    submitting ? '등록 중...' : '후기 등록',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecipeReviewItem extends StatelessWidget {
  const _RecipeReviewItem({
    required this.username,
    required this.date,
    required this.rating,
    required this.content,
    required this.likes,
    required this.liked,
    required this.onLike,
  });

  final String username;
  final String date;
  final int rating;
  final String content;
  final int likes;
  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFFFEDD5),
                child: Text(
                  username.trim().isEmpty ? '?' : username.trim().substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: _orange, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _ink)),
                    Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(Icons.star_rounded, size: 14, color: i <= rating ? _yellow : const Color(0xFFE5E7EB)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF4B5563))),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onLike,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(liked ? Icons.favorite : Icons.favorite_border, size: 15, color: liked ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text('$likes', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
