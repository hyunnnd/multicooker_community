import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/language/language_provider.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/notifications/remote_notification_service.dart';
import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';
import '../../../core/widgets/section_page_app_bar.dart';
import '../../auth/provider/auth_provider.dart';
import '../../community/provider/community_provider.dart';
import '../../device/provider/device_provider.dart';
import '../../profile/data/profile_models.dart';
import '../data/settings_models.dart';
import '../../profile/provider/profile_provider.dart';

part 'app_settings_screen.dart';
part 'blocked_users_screen.dart';
part 'sections/settings_language_section.dart';
part 'sections/settings_account_section.dart';
part 'sections/settings_notification_section.dart';
part 'sections/settings_behavior_section.dart';
part 'sections/settings_information_section.dart';
part 'widgets/settings_common_widgets.dart';

const _orange = Color(0xFFF97316);
const _bg = Color(0xFFF8FAFC);
const _gray100 = Color(0xFFF3F4F6);
const _gray400 = Color(0xFF9CA3AF);
const _gray500 = Color(0xFF6B7280);
const _gray800 = Color(0xFF1F2937);
const _gray900 = Color(0xFF111827);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _requested = false;
  bool _retryingLocalApi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileProvider>().loadOverview();
    });
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<RemoteNotificationService>().unregister();
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/login');
  }

  Future<void> _retryLocalApi() async {
    if (_retryingLocalApi) return;
    setState(() => _retryingLocalApi = true);
    final ok = await context.read<AuthProvider>().retryLocalApiSession();
    if (!mounted) return;
    if (ok) {
      await context.read<ProfileProvider>().loadOverview();
    }
    if (!mounted) return;
    setState(() => _retryingLocalApi = false);
  }


  Future<void> _openMyProfile() async {
    final profile = context.read<ProfileProvider>();
    if (profile.summary == null) {
      await profile.refreshSummary();
    }
    if (!mounted) return;
    final userId = profile.summary?.id;
    if (userId == null || userId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 정보를 불러오지 못했습니다.')),
      );
      return;
    }
    context.push('/community/profile/$userId?editable=1&from=settings');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final summary = profile.summary;
    final nickname = summary?.nickname ?? auth.currentNickname ?? 'GrapheneUser';
    final email = summary?.email ?? auth.currentEmail ?? '';
    final avatarColor = summary?.avatarColor ?? auth.currentAvatarColor;
    final avatarImageUrl = summary?.avatarImageUrl;
    final menuItems = [
      _MyMenu('🍳', '레시피 관리', '내가 올린 레시피와 저장한 레시피', () => context.push('/my/recipes')),
      _MyMenu('✍️', '내가 쓴 후기', '작성한 후기 모아보기', () => context.push('/my/reviews')),
      _MyMenu('🕐', '조리 이력', '지난 조리 기록', () => context.push('/my/cooking-history')),
      _MyMenu('⚙️', '기기 관리', '쿠커 연결 설정', () => context.push('/device')),
      _MyMenu('🔧', '설정', '알림, 언어, 계정', () => context.push('/settings/app')),
      _MyMenu('🎓', '튜토리얼 다시 보기', '앱 기능을 처음부터 다시 안내받습니다', () => context.push('/my/tutorial')),
    ];

    return MainRouteBackScope(
      backToHomeWhenUnhandled: true,
      child: Scaffold(
        backgroundColor: _bg,
        bottomNavigationBar: const MainNavigationBar(currentIndex: 4),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => context.read<ProfileProvider>().loadOverview(),
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
                          const Expanded(child: Text('마이', style: TextStyle(fontSize: 24, color: _gray900, fontWeight: FontWeight.w900))),

                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _openMyProfile,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Color(avatarColor),
                                  shape: BoxShape.circle,
                                ),
                                child: avatarImageUrl != null && avatarImageUrl.isNotEmpty
                                    ? Image.network(
                                        avatarImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                                      )
                                    : const Icon(Icons.person, color: Colors.white, size: 26),
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
                              const SizedBox(width: 8),
                              const Text(
                                '프로필 보기',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _gray400,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 22,
                                color: _gray400,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (profile.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(profile.errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _StatBox(label: '레시피', value: '${summary?.recipeCount ?? 0}', onTap: () => context.push('/my/recipes')),
                          const SizedBox(width: 8),
                          _StatBox(label: '후기', value: '${profile.reviews.length}', onTap: () => context.push('/my/reviews')),
                          const SizedBox(width: 8),
                          _StatBox(label: '이력', value: '${profile.histories.length}', onTap: () => context.push('/my/cooking-history')),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!auth.localApiReady)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_outlined, color: _orange),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '개인 API 로그인 정보를 복구하는 중입니다. 데이터가 보이지 않으면 다시 연결해 주십시오.',
                              style: TextStyle(fontSize: 12, color: _gray800),
                            ),
                          ),
                          TextButton(
                            onPressed: _retryingLocalApi ? null : _retryLocalApi,
                            child: _retryingLocalApi
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('다시 연결'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (profile.isLoading && summary == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
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
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gray100)),
            child: Column(children: [Text(value, style: const TextStyle(fontSize: 20, color: _gray900, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 12, color: _gray400))]),
          ),
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
