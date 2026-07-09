import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../recipe/provider/recipe_provider.dart';
import '../provider/cooking_session_provider.dart';
import '../../../core/widgets/app_image.dart';

class CookingCompleteScreen extends StatefulWidget {
  const CookingCompleteScreen({super.key});

  @override
  State<CookingCompleteScreen> createState() => _CookingCompleteScreenState();
}

class _CookingCompleteScreenState extends State<CookingCompleteScreen> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    final recipe = context.watch<CookingSessionProvider>().currentRecipe;
    if (recipe == null) {
      return const Scaffold(body: Center(child: Text('완료된 조리가 없습니다.')));
    }
    return Scaffold(
      body: ListView(
        children: [
          SizedBox(
            height: 250,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  source: recipe.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: const ColoredBox(color: Color(0xFF0A2540)),
                ),
                const ColoredBox(color: Color(0x55000000)),
                const Positioned(
                  top: 44,
                  right: 20,
                  child: CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.check,
                      color: Color(0xFF16A34A),
                      size: 32,
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '조리가 완료되었습니다',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: '총 조리 시간',
                        value: '${recipe.totalTimeMin}분',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        label: '쿠커 프로그램',
                        value: '${recipe.cookerSteps.length}단계',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  '오늘 요리는 어땠나요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var value = 1; value <= 5; value++)
                      IconButton(
                        onPressed: () => setState(() => _rating = value),
                        icon: Icon(
                          value <= _rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFF59E0B),
                          size: 30,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _message('후기 작성 기능은 API 연결 후 제공됩니다.'),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('후기 작성'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.read<RecipeProvider>().toggleSaved(recipe.id),
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('내 레시피 저장'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _message('커뮤니티 API 추가가 필요합니다.'),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('커뮤니티에 공유'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('홈으로 돌아가기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
