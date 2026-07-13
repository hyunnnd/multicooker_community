import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
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
      alignment: .45,
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
          const SliverToBoxAdapter(child: _CommunitySection()),
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
  const _CommunitySection();

  @override
  State<_CommunitySection> createState() => _CommunitySectionState();
}

class _CommunitySectionState extends State<_CommunitySection> {
  bool _reviews = true;
  bool _latest = true;

  @override
  Widget build(BuildContext context) {
    final items = _latest
        ? const [
            ('지우', '방금 전', 5, '설정값대로 조리해 맛있게 완성했어요.'),
            ('현우', '어제', 4, '순서가 간단해서 따라 하기 쉬웠습니다.'),
          ]
        : const [
            ('현우', '어제', 4, '순서가 간단해서 따라 하기 쉬웠습니다.'),
            ('지우', '방금 전', 5, '설정값대로 조리해 맛있게 완성했어요.'),
          ];
    return _Section(
      title: '후기 · 댓글',
      child: Column(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('후기')),
              ButtonSegment(value: false, label: Text('댓글')),
            ],
            selected: {_reviews},
            onSelectionChanged: (value) =>
                setState(() => _reviews = value.first),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: DropdownButton<bool>(
              value: _latest,
              items: const [
                DropdownMenuItem(value: true, child: Text('최신순')),
                DropdownMenuItem(value: false, child: Text('인기순')),
              ],
              onChanged: (value) => setState(() => _latest = value ?? true),
            ),
          ),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Text(
                    item.$1,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF77736C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_reviews)
                    Text(
                      '★ ${item.$3}',
                      style: const TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_reviews ? item.$4 : '${item.$4} 조리 시간 조절이 가능할까요?'),
              ),
            ),
        ],
      ),
    );
  }
}
