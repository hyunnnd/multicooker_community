import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/figma_recipe_widgets.dart';

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key});

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  final _controller = TextEditingController();
  final _recent = const ['삼겹살', '계란찜', '갈비찜', '수육'];
  final _popular = const ['삼겹살', '닭갈비', '계란찜', '갈비찜', '수육', '리조또'];
  final _suggested = const ['멀티쿠커 삼겹살 구이', '삼겹살 수육', '삼겹살 김치찜'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String keyword) {
    final q = keyword.trim();
    if (q.isEmpty) return;
    context.push('/recipes/results?q=${Uri.encodeQueryComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final q = _controller.text.trim();
    final matches = q.isEmpty
        ? const <String>[]
        : _suggested.where((e) => e.contains(q)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: figmaGray100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: figmaGray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: figmaGray400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _search,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: '레시피, 재료, 조리방식을 검색해보세요',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: figmaGray400,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: figmaGray900,
                              ),
                            ),
                          ),
                          if (q.isNotEmpty)
                            InkWell(
                              onTap: () => setState(_controller.clear),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: figmaGray400,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => context.go('/recipes'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 14,
                          color: figmaOrange,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (q.isNotEmpty) ...[
                    if (matches.isEmpty)
                      _SearchLine(
                        icon: Icons.search_rounded,
                        label: q,
                        onTap: () => _search(q),
                      )
                    else
                      for (final item in matches)
                        _SearchLine(
                          icon: Icons.search_rounded,
                          label: item,
                          onTap: () => _search(item),
                        ),
                  ] else ...[
                    const _SmallTitle('최근 검색어'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in _recent)
                          _RoundKeyword(
                            label: item,
                            onTap: () => setState(() {
                              _controller.text = item;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _SmallTitle('인기 검색어'),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _popular.length; i++)
                      InkWell(
                        onTap: () => _search(_popular[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: i < 3 ? figmaOrange : figmaGray400,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                _popular[i],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: figmaGray900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const _SmallTitle('추천 키워드'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in _suggested)
                          _OutlineKeyword(
                            label: item,
                            onTap: () => _search(item),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallTitle extends StatelessWidget {
  const _SmallTitle(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 12,
      color: figmaGray400,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
    ),
  );
}

class _RoundKeyword extends StatelessWidget {
  const _RoundKeyword({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: figmaGray100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: figmaGray700,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _OutlineKeyword extends StatelessWidget {
  const _OutlineKeyword({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: figmaOrange),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: figmaOrange,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _SearchLine extends StatelessWidget {
  const _SearchLine({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: figmaGray100)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: figmaGray400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: figmaGray700),
            ),
          ),
        ],
      ),
    ),
  );
}
