part of '../community_screen.dart';

class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.onRecipeTap});
  final ValueChanged<String> onRecipeTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final reviews = provider.filteredReviews();
    if (provider.reviews.isEmpty) {
      return const _EmptyBlock(searching: false, text: '후기가 없습니다.');
    }
    return Column(
      children: [
        _ReviewCompactFilterHeader(count: reviews.length),
        if (reviews.isEmpty)
          const _EmptyBlock(searching: true, text: '조건에 맞는 후기가 없습니다.')
        else
          for (final review in reviews) ...[
            _ReviewCard(review: review, onRecipeTap: () => onRecipeTap(review.recipeId)),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 88),
      ],
    );
  }
}

class _ReviewCompactFilterHeader extends StatelessWidget {
  const _ReviewCompactFilterHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final hasFilter = _hasReviewFilter(provider);
    final filterCount = _activeReviewFilterCount(provider);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('후기 $count개', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _text)),
              const Spacer(),
              Material(
                color: hasFilter ? _orange50 : _gray100,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () => _showReviewFilterSheet(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: hasFilter ? _orange100 : _gray200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 15, color: hasFilter ? _orange : _gray500),
                        const SizedBox(width: 4),
                        Text('필터', style: TextStyle(fontSize: 12, color: hasFilter ? _orangeText : _gray500, fontWeight: FontWeight.w900)),
                        if (filterCount > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            width: 16,
                            height: 16,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                            child: Text('$filterCount', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (hasFilter) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (provider.reviewRecipeTitleFilter != null && provider.reviewRecipeTitleFilter!.isNotEmpty)
                    _AppliedReviewFilterChip(label: '레시피: ${provider.reviewRecipeTitleFilter}', onRemove: provider.clearReviewRecipeFilter),
                  for (final value in provider.reviewSourceFilters)
                    _AppliedReviewFilterChip(label: value, onRemove: () => provider.removeReviewFilterSelection('source', value)),
                  for (final value in provider.reviewModeFilters)
                    _AppliedReviewFilterChip(label: value, onRemove: () => provider.removeReviewFilterSelection('mode', value)),
                  for (final value in provider.reviewFoodFilters)
                    _AppliedReviewFilterChip(label: value, onRemove: () => provider.removeReviewFilterSelection('food', value)),
                  for (final value in provider.reviewThemeFilters)
                    _AppliedReviewFilterChip(label: value, onRemove: () => provider.removeReviewFilterSelection('theme', value)),
                  GestureDetector(
                    onTap: provider.clearReviewFilters,
                    child: Container(
                      height: 26,
                      margin: const EdgeInsets.only(left: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _gray100, borderRadius: BorderRadius.circular(999)),
                      child: const Text('초기화', style: TextStyle(fontSize: 11, color: _gray500, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppliedReviewFilterChip extends StatelessWidget {
  const _AppliedReviewFilterChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.only(left: 9, right: 6),
      decoration: BoxDecoration(
        color: _orange50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _orange100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _orangeText, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          GestureDetector(onTap: onRemove, child: const Icon(Icons.close_rounded, size: 13, color: _orange)),
        ],
      ),
    );
  }
}

bool _hasReviewFilter(CommunityProvider provider) =>
    provider.reviewSourceFilters.isNotEmpty ||
    provider.reviewModeFilters.isNotEmpty ||
    provider.reviewFoodFilters.isNotEmpty ||
    provider.reviewThemeFilters.isNotEmpty ||
    provider.reviewRecipeIdFilter != null ||
    provider.reviewRecipeTitleFilter != null;

int _activeReviewFilterCount(CommunityProvider provider) =>
    provider.reviewSourceFilters.length +
    provider.reviewModeFilters.length +
    provider.reviewFoodFilters.length +
    provider.reviewThemeFilters.length +
    (provider.reviewRecipeIdFilter != null || provider.reviewRecipeTitleFilter != null ? 1 : 0);

void _showReviewFilterSheet(BuildContext context) {
  final provider = context.read<CommunityProvider>();
  final tempSources = provider.reviewSourceFilters.toSet();
  final tempModes = provider.reviewModeFilters.toSet();
  final tempFoods = provider.reviewFoodFilters.toSet();
  final tempThemes = provider.reviewThemeFilters.toSet();
  String? openedGroup;

  void toggleValue(Set<String> target, String value) {
    if (value == '전체') {
      target.clear();
      return;
    }
    if (target.contains(value)) {
      target.remove(value);
    } else {
      target.add(value);
    }
  }

  String selectedSummary(Set<String> values) {
    if (values.isEmpty) return '전체';
    if (values.length == 1) return values.first;
    return '${values.first} 외 ${values.length - 1}개';
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.34,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(color: _gray200, borderRadius: BorderRadius.circular(999)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Text('후기 필터', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text)),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                                icon: const Icon(Icons.close_rounded, size: 20, color: _gray500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '분류 안에서는 여러 개 선택 가능, 분류끼리는 함께 만족하는 후기만 표시됩니다.',
                            style: TextStyle(fontSize: 11, color: _gray400, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          children: [
                            _ReviewFilterAccordionTile(
                              title: '레시피 구분',
                              summary: selectedSummary(tempSources),
                              opened: openedGroup == 'source',
                              selectedCount: tempSources.length,
                              onHeaderTap: () => setSheetState(() => openedGroup = openedGroup == 'source' ? null : 'source'),
                              options: const ['전체', '공식', '사용자 공유'],
                              selectedValues: tempSources,
                              onOptionTap: (value) => setSheetState(() => toggleValue(tempSources, value)),
                            ),
                            _ReviewFilterAccordionTile(
                              title: '조리 방식',
                              summary: selectedSummary(tempModes),
                              opened: openedGroup == 'mode',
                              selectedCount: tempModes.length,
                              onHeaderTap: () => setSheetState(() => openedGroup = openedGroup == 'mode' ? null : 'mode'),
                              options: const ['전체', 'Full Auto', 'Guided Cook', 'Professional', 'Quick Cook'],
                              selectedValues: tempModes,
                              onOptionTap: (value) => setSheetState(() => toggleValue(tempModes, value)),
                            ),
                            _ReviewFilterAccordionTile(
                              title: '음식 종류',
                              summary: selectedSummary(tempFoods),
                              opened: openedGroup == 'food',
                              selectedCount: tempFoods.length,
                              onHeaderTap: () => setSheetState(() => openedGroup = openedGroup == 'food' ? null : 'food'),
                              options: const ['전체', '고기', '밥/면', '해산물', '찜/계란'],
                              selectedValues: tempFoods,
                              onOptionTap: (value) => setSheetState(() => toggleValue(tempFoods, value)),
                            ),
                            _ReviewFilterAccordionTile(
                              title: '상황별 테마',
                              summary: selectedSummary(tempThemes),
                              opened: openedGroup == 'theme',
                              selectedCount: tempThemes.length,
                              onHeaderTap: () => setSheetState(() => openedGroup = openedGroup == 'theme' ? null : 'theme'),
                              options: const ['전체', '간단요리', '한끼식사', '고급요리', '아이간식', '최근 후기'],
                              selectedValues: tempThemes,
                              onOptionTap: (value) => setSheetState(() => toggleValue(tempThemes, value)),
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: _gray100)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  provider.clearReviewFilters();
                                  Navigator.pop(sheetContext);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _gray500,
                                  side: const BorderSide(color: _gray200),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('초기화', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  provider.setReviewFilterSelections(
                                    sources: tempSources,
                                    modes: tempModes,
                                    foods: tempFoods,
                                    themes: tempThemes,
                                  );
                                  Navigator.pop(sheetContext);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _orange,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('적용', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

class _ReviewFilterAccordionTile extends StatelessWidget {
  const _ReviewFilterAccordionTile({
    required this.title,
    required this.summary,
    required this.opened,
    required this.selectedCount,
    required this.onHeaderTap,
    required this.options,
    required this.selectedValues,
    required this.onOptionTap,
  });

  final String title;
  final String summary;
  final bool opened;
  final int selectedCount;
  final VoidCallback onHeaderTap;
  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<String> onOptionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: opened ? _orange50 : _gray100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: opened ? _orange100 : _gray200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onHeaderTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 13, color: _text, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: selectedCount > 0 ? _orangeText : _gray400, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    if (selectedCount > 0) ...[
                      Container(
                        height: 20,
                        constraints: const BoxConstraints(minWidth: 20),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: const BoxDecoration(color: _orange, shape: BoxShape.rectangle, borderRadius: BorderRadius.all(Radius.circular(999))),
                        child: Text('$selectedCount', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    AnimatedRotation(
                      turns: opened ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.keyboard_arrow_down_rounded, size: 21, color: opened ? _orange : _gray400),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            crossFadeState: opened ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final option in options)
                      _SheetFilterChip(
                        label: option,
                        selected: option == '전체' ? selectedValues.isEmpty : selectedValues.contains(option),
                        onTap: () => onOptionTap(option),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewFilterChipGroup extends StatelessWidget {
  const _ReviewFilterChipGroup({required this.title, required this.options, required this.selectedValues, required this.onTap});
  final String title;
  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _text2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final option in options)
                _SheetFilterChip(
                  label: option,
                  selected: option == '전체' ? selectedValues.isEmpty : selectedValues.contains(option),
                  onTap: () => onTap(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetFilterChip extends StatelessWidget {
  const _SheetFilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _orange50 : _gray100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _orange : _gray200),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: selected ? _orangeText : _gray500, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _ReviewFilterOption {
  const _ReviewFilterOption(this.value, this.label);
  final String value;
  final String label;
}

class _ReviewDropdown extends StatelessWidget {
  const _ReviewDropdown({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _gray500),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: _gray100,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _gray200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _orange100)),
      ),
      style: const TextStyle(fontSize: 12, color: _text, fontWeight: FontWeight.w800),
      dropdownColor: Colors.white,
      onChanged: onChanged,
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onRecipeTap});
  final CommunityReview review;
  final VoidCallback onRecipeTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final liked = provider.likedReviewIds.contains(review.id) || review.isLiked;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: review.username, color: Color(review.avatarColor), imageUrl: review.avatarImageUrl, size: 22, fontSize: 10),
              const SizedBox(width: 6),
              Text(review.username, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text2)),
              if (review.isAdmin) ...[
                const SizedBox(width: 6),
                const _AuthorRoleBadge(
                  label: '관리자',
                  admin: true,
                ),
              ],
              const SizedBox(width: 5),
              const Text('·', style: TextStyle(fontSize: 11, color: _gray300)),
              const SizedBox(width: 5),
              Text(
                '${review.relativeTime}${review.wasEdited ? ' · 수정됨' : ''}',
                style: const TextStyle(fontSize: 11, color: _gray400),
              ),
              const Spacer(),
              for (var i = 1; i <= 5; i++) Icon(Icons.star, size: 13, color: i <= review.rating ? _yellow : _gray200),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(label: review.sourceLabel, bg: _orange50, fg: _orange, fontSize: 10, weight: FontWeight.w900),
              _Pill(label: review.cookingModeLabel, bg: const Color(0xFFEFF6FF), fg: const Color(0xFF3B82F6), fontSize: 10, weight: FontWeight.w900),
              _Pill(label: review.foodCategoryLabel, bg: const Color(0xFFF3F4F6), fg: _gray500, fontSize: 10, weight: FontWeight.w800),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showCommunityImageViewer(
                  context,
                  [review.recipeImage],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _NetworkImageBox(
                    url: review.recipeImage,
                    width: 64,
                    height: 64,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('리뷰한 레시피', style: TextStyle(fontSize: 11, color: _gray500)),
                    const SizedBox(height: 2),
                    Text(review.recipeTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text)),
                    const SizedBox(height: 4),
                    Text(review.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.5, color: _gray500)),
                  ],
                ),
              ),
            ],
          ),
          if (review.reviewImageUrl?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showCommunityImageViewer(
                context,
                [review.reviewImageUrl!],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LayoutBuilder(
                  builder: (context, constraints) => _NetworkImageBox(
                    url: review.reviewImageUrl!,
                    width: constraints.maxWidth,
                    height: 190,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final tag in review.effectiveThemeTags.take(3))
                Text('#$tag', style: const TextStyle(fontSize: 11, color: _gray400, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onRecipeTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _orange50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orange100),
              ),
              child: Row(
                children: [
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.menu_book, size: 14, color: Colors.white)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(review.recipeTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text2))),
                  const Text('레시피 보기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _orange)),
                  const Icon(Icons.chevron_right, size: 13, color: _orange),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _gray100),
          const SizedBox(height: 12),
          Row(
            children: [
              _SmallActionIcon(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                label: '${review.likes + (liked && !review.isLiked ? 1 : 0)}',
                color: liked ? _red : _gray400,
                onTap: () => provider.toggleReviewLike(review.id),
              ),
              const SizedBox(width: 16),
              _SmallActionIcon(icon: Icons.mode_comment_outlined, label: '${review.commentCount}', color: _gray400),
            ],
          ),
        ],
      ),
    );
  }
}
