import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../../device/provider/device_provider.dart';
import '../../recipe/data/models/recipe.dart';
import '../../recipe/provider/recipe_provider.dart';
import '../../recipe/presentation/widgets/compatibility_badge.dart';
import '../provider/cooking_session_provider.dart';

class CookingPreparationScreen extends StatefulWidget {
  const CookingPreparationScreen({required this.recipeId, super.key});

  final String recipeId;

  @override
  State<CookingPreparationScreen> createState() =>
      _CookingPreparationScreenState();
}

class _CookingPreparationScreenState extends State<CookingPreparationScreen> {
  final _checked = [false, false, false];

  @override
  Widget build(BuildContext context) {
    final recipe = context.watch<RecipeProvider>().recipeById(widget.recipeId);
    final device = context.watch<DeviceProvider>();
    if (recipe == null) {
      return const Scaffold(body: Center(child: Text('레시피가 없습니다.')));
    }
    final ready = device.isConnected && _checked.every((value) => value);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('조리 준비 확인'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant,
                  color: Color(0xFF3378C0),
                  size: 34,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('${recipe.totalTimeMin}분  '),
                          CompatibilityBadge(type: recipe.compatibilityType),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '준비 체크리스트',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _CheckItem(
            label: '재료를 모두 준비했어요',
            value: _checked[0],
            onChanged: () => _toggle(0),
          ),
          _ConnectionItem(
            isConnected: device.isConnected,
            onConnect: () => context.push('/device'),
          ),
          _CheckItem(
            label: recipe.id == 'pork'
                ? '쿠커 예열을 완료하고 재료를 올렸어요'
                : '쿠커 위에 재료를 올렸어요',
            value: _checked[1],
            onChanged: () => _toggle(1),
          ),
          _CheckItem(
            label: '고온 주의 안내를 확인했어요',
            value: _checked[2],
            onChanged: () => _toggle(2),
          ),
          const SizedBox(height: 14),
          const Card(
            color: Color(0xFFFFFBEB),
            child: ListTile(
              leading: Icon(Icons.warning_amber, color: Color(0xFFD97706)),
              title: Text('고온 주의'),
              subtitle: Text('조리 중 쿠커 표면이 뜨거워집니다. 어린이의 접근과 직접 접촉을 피하세요.'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF3378C0),
              ),
              title: Text('기기 인증 상태'),
              trailing: Text(
                '쿠커 연결 확인 완료',
                style: TextStyle(
                  color: Color(0xFF15803D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: device.isConnected
              ? FilledButton.icon(
                  onPressed: ready ? () => _start(context, recipe) : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('조리 시작'),
                )
              : OutlinedButton.icon(
                  onPressed: () => context.push('/device'),
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('쿠커 연결하기'),
                ),
        ),
      ),
    );
  }

  void _toggle(int index) => setState(() => _checked[index] = !_checked[index]);

  Future<void> _start(BuildContext context, Recipe recipe) async {
    final session = context.read<CookingSessionProvider>();
    try {
      session.prepareRecipe(recipe);
      await session.startCooking();
      if (context.mounted) context.push('/cooking');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('쿠커에 조리 설정을 보내지 못했습니다: $error')));
    }
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: value,
    onChanged: (_) => onChanged(),
    title: Text(label),
    contentPadding: EdgeInsets.zero,
  );
}

class _ConnectionItem extends StatelessWidget {
  const _ConnectionItem({required this.isConnected, required this.onConnect});
  final bool isConnected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      isConnected ? Icons.check_circle : Icons.circle_outlined,
      color: isConnected ? const Color(0xFF16A34A) : null,
    ),
    title: Text(isConnected ? '쿠커가 연결되어 있어요' : '쿠커 연결이 필요해요'),
    trailing: isConnected
        ? null
        : TextButton(onPressed: onConnect, child: const Text('연결')),
  );
}
