import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/language/language_provider.dart';
import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';
import '../../auth/provider/auth_provider.dart';
import '../../profile/data/profile_models.dart';
import '../../profile/provider/profile_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final summary = profile.summary;
    final nickname = summary?.nickname ?? auth.currentNickname ?? 'GrapheneUser';
    final email = summary?.email ?? auth.currentEmail ?? '';
    final avatarColor = summary?.avatarColor ?? auth.currentAvatarColor;
    final initial = nickname.isNotEmpty ? nickname.substring(0, 1).toUpperCase() : 'U';
    final menuItems = [
      _MyMenu('🍳', '내가 올린 레시피', '내가 등록한 레시피 관리', () => context.push('/my/recipes')),
      _MyMenu('🔖', '저장한 레시피', '내가 저장한 레시피', () => context.push('/my/saved-recipes')),
      _MyMenu('✍️', '내가 쓴 후기', '작성한 후기 모아보기', () => context.push('/my/reviews')),
      _MyMenu('💬', '내가 쓴 댓글', '댓글 내역', () => context.push('/my/comments')),
      _MyMenu('🕐', '조리 이력', '지난 조리 기록', () => context.push('/my/cooking-history')),
      _MyMenu('⚙️', '기기 관리', '쿠커 연결 설정', () => context.go('/device')),
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
                          Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Color(avatarColor),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [BoxShadow(color: Color(0x33222222), blurRadius: 16, offset: Offset(0, 8))],
                            ),
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
                          IconButton(onPressed: profile.isLoading ? null : () => context.read<ProfileProvider>().loadOverview(), icon: const Icon(Icons.refresh)),
                        ],
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

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  var _notifications = true;
  var _cookingAlerts = true;
  var _autoReconnect = true;

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: const AppBackButton(),
        title: Text(lang.t('설정', 'Settings')),
      ),
      bottomNavigationBar: const MainNavigationBar(currentIndex: 4),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: lang.t('언어', 'Language'),
            children: [
              _LanguageTile(
                label: '한국어',
                selected: !lang.isEnglish,
                onTap: () => lang.setEnglish(false),
              ),
              _LanguageTile(
                label: 'English',
                selected: lang.isEnglish,
                onTap: () => lang.setEnglish(true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: lang.t('계정', 'Account'),
            children: [
              _InfoTile(
                icon: Icons.person_outline,
                title: auth.isAuthenticated ? 'GrapheneUser' : 'Guest',
                subtitle: auth.isAuthenticated
                    ? lang.t('로그인됨', 'Signed in')
                    : lang.t('로그인이 필요합니다', 'Sign in required'),
              ),
              _ActionTile(
                icon: Icons.login_rounded,
                title: auth.isAuthenticated
                    ? lang.t('인증 상태 확인', 'Check Verification')
                    : lang.t('로그인', 'Sign in'),
                subtitle: auth.isAuthenticated
                    ? lang.t(
                        '현재 계정 인증 상태가 유효합니다',
                        'Your account session is valid',
                      )
                    : lang.t(
                        '이메일 또는 Google 계정으로 로그인',
                        'Sign in with email or Google',
                      ),
                onTap: () => auth.isAuthenticated
                    ? _message(lang.t('현재 로그인 상태입니다.', 'You are signed in.'))
                    : context.go('/login'),
              ),
              _ActionTile(
                icon: Icons.verified_user_outlined,
                title: lang.t('이메일 인증', 'Email Verification'),
                subtitle: lang.t(
                  '회원가입 이메일 인증을 다시 진행합니다',
                  'Start the email verification flow',
                ),
                onTap: () => context.go('/register'),
              ),
              _ActionTile(
                icon: Icons.lock_reset_rounded,
                title: lang.t('암호 변경', 'Change Password'),
                subtitle: lang.t(
                  '인증코드로 비밀번호를 재설정합니다',
                  'Reset your password with a verification code',
                ),
                onTap: () => context.go('/reset'),
              ),
              if (auth.isAuthenticated)
                _ActionTile(
                  icon: Icons.logout_rounded,
                  title: lang.t('로그아웃', 'Sign out'),
                  subtitle: lang.t('현재 계정에서 나갑니다', 'Sign out of this account'),
                  danger: true,
                  onTap: auth.isLoading ? null : () => _logout(context),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: lang.t('앱 동작', 'App Behavior'),
            children: [
              _SwitchTile(
                title: lang.t('알림', 'Notifications'),
                subtitle: lang.t(
                  '레시피와 커뮤니티 알림 받기',
                  'Receive recipe and community notifications',
                ),
                value: _notifications,
                onChanged: (value) => setState(() => _notifications = value),
              ),
              _SwitchTile(
                title: lang.t('조리 알림', 'Cooking Alerts'),
                subtitle: lang.t(
                  '예열 완료와 조리 완료 알림 표시',
                  'Show preheat and cooking completion alerts',
                ),
                value: _cookingAlerts,
                onChanged: (value) => setState(() => _cookingAlerts = value),
              ),
              _SwitchTile(
                title: lang.t('쿠커 자동 재연결', 'Auto Reconnect Cooker'),
                subtitle: lang.t(
                  '신호가 끊기면 자동으로 다시 연결 시도',
                  'Try reconnecting when the signal is lost',
                ),
                value: _autoReconnect,
                onChanged: (value) => setState(() => _autoReconnect = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: lang.t('정보', 'About'),
            children: [
              const _InfoTile(
                icon: Icons.info_outline,
                title: 'Graphene Multi-Cooker',
                subtitle: 'Prototype · v0.1',
              ),
              _InfoTile(
                icon: Icons.policy_outlined,
                title: lang.t('개인정보 및 약관', 'Privacy and Terms'),
                subtitle: lang.t(
                  '서비스 정책 문서 연결 예정',
                  'Service policy documents will be linked later',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: _gray900,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gray100),
        ),
        child: Column(children: children),
      ),
    ],
  );
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return _BaseTile(
      icon: Icons.language_rounded,
      title: label,
      subtitle: selected
          ? lang.t('선택됨', 'Selected')
          : lang.t('탭하여 변경', 'Tap to change'),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: _orange)
          : const Icon(Icons.radio_button_unchecked_rounded, color: _gray400),
      onTap: onTap,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => _BaseTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    color: danger ? const Color(0xFFEF4444) : _gray800,
    trailing: const Icon(Icons.chevron_right_rounded, color: _gray400),
    onTap: onTap,
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) =>
      _BaseTile(icon: icon, title: title, subtitle: subtitle);
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _BaseTile(
    icon: Icons.tune_rounded,
    title: title,
    subtitle: subtitle,
    trailing: Switch(value: value, activeColor: _orange, onChanged: onChanged),
    onTap: () => onChanged(!value),
  );
}

class _BaseTile extends StatelessWidget {
  const _BaseTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.color = _gray800,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _gray400, fontSize: 12),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    ),
  );
}
