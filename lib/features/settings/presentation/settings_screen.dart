import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';
import '../../auth/provider/auth_provider.dart';

const _orange = Color(0xFFF97316);
const _bg = Color(0xFFF8FAFC);
const _gray100 = Color(0xFFF3F4F6);
const _gray400 = Color(0xFF9CA3AF);
const _gray500 = Color(0xFF6B7280);
const _gray800 = Color(0xFF1F2937);
const _gray900 = Color(0xFF111827);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nickname = auth.currentNickname ?? 'GrapheneUser';
    final email = auth.currentEmail ?? '';
    final initial = nickname.isNotEmpty ? nickname.substring(0, 1).toUpperCase() : 'U';
    final menuItems = [
      _MyMenu('🔖', '저장한 레시피', '내가 저장한 레시피', () => context.go('/recipes')),
      _MyMenu('✍️', '내가 쓴 후기', '작성한 후기 모아보기', () => context.go('/community')),
      _MyMenu('💬', '내가 쓴 댓글', '댓글 내역', () => context.go('/community')),
      _MyMenu('🕐', '조리 이력', '지난 조리 기록', () {}),
      _MyMenu('⚙️', '기기 관리', '쿠커 연결 설정', () => context.go('/device')),
      _MyMenu('🔧', '설정', '알림, 언어, 계정', () {}),
    ];

    return MainRouteBackScope(
      child: Scaffold(
        backgroundColor: _bg,
      bottomNavigationBar: const MainNavigationBar(currentIndex: 4),
        body: SafeArea(
          child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Color(auth.currentAvatarColor), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x33222222), blurRadius: 16, offset: Offset(0, 8))]),
                        child: Text(initial, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nickname, style: const TextStyle(fontSize: 16, color: _gray900, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(email, style: const TextStyle(fontSize: 12, color: _gray400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      _StatBox(label: '레시피', value: '12'),
                      SizedBox(width: 8),
                      _StatBox(label: '후기', value: '8'),
                      SizedBox(width: 8),
                      _StatBox(label: '이력', value: '34'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  for (final item in menuItems) ...[
                    _MenuTile(item: item),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFEE2E2), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: auth.isLoading ? null : () => _logout(context),
                    icon: auth.isLoading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.logout, size: 17),
                    label: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gray100)),
          child: Column(children: [Text(value, style: const TextStyle(fontSize: 20, color: _gray900, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 12, color: _gray400))]),
        ),
      );
}

class _MyMenu {
  const _MyMenu(this.emoji, this.label, this.sub, this.action);
  final String emoji;
  final String label;
  final String sub;
  final VoidCallback action;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});
  final _MyMenu item;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: item.action,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _gray100), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))]),
          child: Row(
            children: [
              SizedBox(width: 34, child: Text(item.emoji, style: const TextStyle(fontSize: 21))),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: const TextStyle(fontSize: 14, color: _gray800, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(item.sub, style: const TextStyle(fontSize: 12, color: _gray400))])),
              const Icon(Icons.chevron_right, size: 18, color: _gray400),
            ],
          ),
        ),
      );
}
