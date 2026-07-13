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
                          _StatBox(label: '레시피', value: '${profile.myRecipes.length}', onTap: () => context.push('/my/recipes')),
                          const SizedBox(width: 8),
                          _StatBox(label: '후기', value: '${profile.reviews.length}', onTap: () => context.push('/my/reviews')),
                          const SizedBox(width: 8),
                          _StatBox(label: '이력', value: '${profile.histories.length}', onTap: () => context.push('/my/cooking-history')),
                        ],
                      ),
                    ],
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

class AppPreferencesScreen extends StatefulWidget {
  const AppPreferencesScreen({super.key});

  @override
  State<AppPreferencesScreen> createState() => _AppPreferencesScreenState();
}

class _AppPreferencesScreenState extends State<AppPreferencesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileProvider>().loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final settings = profile.settings;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: profile.loadPreferences,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (profile.errorMessage != null)
              _SettingsError(message: profile.errorMessage!),
            const _SettingsSectionTitle('알림'),
            _SettingsCard(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('조리 알림'),
                    subtitle: const Text('조리 시작, 단계 변경, 완료 알림'),
                    value: settings.cookingNotification,
                    onChanged: profile.isSaving
                        ? null
                        : (value) => profile.updateSettings(
                              settings.copyWith(cookingNotification: value),
                            ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('커뮤니티 알림'),
                    subtitle: const Text('좋아요, 댓글, 답글 알림'),
                    value: settings.communityNotification,
                    onChanged: profile.isSaving
                        ? null
                        : (value) => profile.updateSettings(
                              settings.copyWith(communityNotification: value),
                            ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('이벤트 알림'),
                    subtitle: const Text('새 소식 및 이벤트 알림'),
                    value: settings.marketingNotification,
                    onChanged: profile.isSaving
                        ? null
                        : (value) => profile.updateSettings(
                              settings.copyWith(marketingNotification: value),
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SettingsSectionTitle('언어'),
            _SettingsCard(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('한국어'),
                    trailing: settings.language == 'ko'
                        ? const Icon(Icons.check, color: _orange)
                        : null,
                    onTap: () => _setLanguage(context, 'ko'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('English'),
                    trailing: settings.language == 'en'
                        ? const Icon(Icons.check, color: _orange)
                        : null,
                    onTap: () => _setLanguage(context, 'en'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SettingsSectionTitle('기기'),
            _SettingsCard(
              child: Column(
                children: [
                  if (profile.devices.isEmpty)
                    const ListTile(
                      title: Text('등록된 기기 없음'),
                      subtitle: Text('쿠커 화면에서 연결하면 등록됩니다.'),
                    )
                  else
                    for (final device in profile.devices) ...[
                      ListTile(
                        title: Text(
                          device.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${device.macAddress}\n최근 연결: ${_settingsFormatDate(device.lastConnectedAt)}',
                        ),
                        isThreeLine: true,
                        trailing: Switch(
                          value: device.autoReconnect,
                          onChanged: (value) => profile
                              .toggleDeviceAutoReconnect(device, value),
                        ),
                        onTap: () => _editDeviceAlias(context, device),
                      ),
                      const Divider(height: 1),
                    ],
                  ListTile(
                    leading: const Icon(Icons.bluetooth_searching),
                    title: const Text('쿠커 검색 및 연결'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/device'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SettingsSectionTitle('계정'),
            _SettingsCard(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('닉네임 변경'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editNickname(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('비밀번호 재설정'),
                    subtitle: const Text('회사 계정 이메일 인증 후 변경합니다.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/reset'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text(
                      '앱 데이터 탈퇴',
                      style: TextStyle(color: Color(0xFFDC2626)),
                    ),
                    subtitle: const Text('로컬 커뮤니티·마이페이지 데이터를 비활성화합니다.'),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFFDC2626),
                    ),
                    onTap: () => _deleteLocalAccount(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _setLanguage(BuildContext context, String language) async {
    final profile = context.read<ProfileProvider>();
    final ok = await profile.updateSettings(
      profile.settings.copyWith(language: language),
    );
    if (!context.mounted || !ok) return;
    context.read<LanguageProvider>().setEnglish(language == 'en');
  }

  Future<void> _editNickname(BuildContext context) async {
    final profile = context.read<ProfileProvider>();
    final auth = context.read<AuthProvider>();
    final controller = TextEditingController(
      text: profile.summary?.nickname ?? auth.currentNickname ?? 'GrapheneUser',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('닉네임 변경'),
        content: TextField(
          controller: controller,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '닉네임 입력'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              final ok = await profile.updateNickname(value);
              if (ok) auth.setLocalNickname(value);
              if (dialogContext.mounted && ok) Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _editDeviceAlias(
    BuildContext context,
    RegisteredDeviceItem device,
  ) async {
    final controller = TextEditingController(text: device.alias);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('기기 별칭 변경'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: device.deviceName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await context
                  .read<ProfileProvider>()
                  .updateDeviceAlias(device.id, controller.text.trim());
              if (dialogContext.mounted && ok) Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _deleteLocalAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('앱 데이터 탈퇴'),
        content: const Text(
          '로컬 커뮤니티와 마이페이지 데이터가 비활성화됩니다. 회사 로그인 계정 자체는 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await context.read<ProfileProvider>().deleteAccount();
    if (!ok || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/login');
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _gray900,
          ),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gray100),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
        ),
      );
}

String _settingsFormatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return iso;
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
