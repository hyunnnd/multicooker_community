part of 'settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _requested = false;
  bool _changingSetting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final profile = context.read<ProfileProvider>();
      await profile.loadPreferences();
      if (!mounted) return;
      final settings = profile.settings;
      context.read<LanguageProvider>().setEnglish(settings.language == 'en');
      context.read<DeviceProvider>().setAutoReconnectEnabled(
            settings.autoReconnect,
          );
    });
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<RemoteNotificationService>().unregister();
    await context.read<LocalNotificationService>()
        .cancelAllAppBehaviorNotifications();
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/login');
  }

  Future<void> _updateSettings(
    ProfileSettings next, {
    bool requestNotificationPermission = false,
  }) async {
    if (_changingSetting) return;
    if (requestNotificationPermission) {
      final granted = await context
          .read<LocalNotificationService>()
          .requestPermission(force: true);
      if (!mounted) return;
      if (!granted) {
        _message('휴대전화 설정에서 알림 권한을 허용해 주세요.');
        return;
      }
    }

    setState(() => _changingSetting = true);
    final ok = await context.read<ProfileProvider>().updateSettings(next);
    if (!mounted) return;
    setState(() => _changingSetting = false);
    if (!ok) {
      _message(
        context.read<ProfileProvider>().errorMessage ??
            '설정을 저장하지 못했습니다.',
      );
      return;
    }

    context.read<DeviceProvider>().setAutoReconnectEnabled(next.autoReconnect);
    final notifications = context.read<LocalNotificationService>();
    if (!next.communityNotification) {
      await notifications.cancelCommunitySummary(
        accountEmail: context.read<AuthProvider>().currentEmail,
        resetState: false,
      );
    }
    if (!next.cookingNotification) {
      await notifications.cancelCookingAlerts();
    }
    if (!next.autoReconnect) {
      await notifications.cancelReconnecting();
    }
  }

  Future<void> _updateNotificationSettings(
    NotificationSettings next, {
    bool requestNotificationPermission = false,
  }) => _updateSettings(
        context.read<ProfileProvider>().settings.copyWith(notifications: next),
        requestNotificationPermission: requestNotificationPermission,
      );

  Future<void> _updateBehaviorSettings(BehaviorSettings next) => _updateSettings(
        context.read<ProfileProvider>().settings.copyWith(behavior: next),
      );

  Future<void> _setLanguage(bool english) async {
    final profile = context.read<ProfileProvider>();
    final next = profile.settings.copyWith(language: english ? 'en' : 'ko');
    context.read<LanguageProvider>().setEnglish(english);
    await _updateSettings(next);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final profile = context.watch<ProfileProvider>();
    final settings = profile.settings;
    final nickname =
        profile.summary?.nickname ?? auth.currentNickname ?? 'GrapheneUser';
    final email = profile.summary?.email ?? auth.currentEmail ?? '';
    final disabled = _changingSetting;

    return Scaffold(
      backgroundColor: _bg,
      appBar: SectionPageAppBar(title: lang.t('설정', 'Settings')),
      bottomNavigationBar: const MainNavigationBar(currentIndex: 4),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsLanguageSection(
            isEnglish: lang.isEnglish,
            disabled: disabled,
            onChanged: _setLanguage,
          ),
          const SizedBox(height: 14),
          _SettingsAccountSection(
            authenticated: auth.isAuthenticated,
            loading: auth.isLoading,
            nickname: nickname,
            email: email,
            onLogin: () => context.go('/login'),
            onChangePassword: () => context.push('/reset'),
            onBlockedUsers: () => context.push('/settings/blocked-users'),
            onLogout: () => _logout(context),
          ),
          const SizedBox(height: 14),
          _SettingsNotificationSection(
            settings: settings.notifications,
            disabled: disabled,
            onChanged: (next, requestPermission) => _updateNotificationSettings(
              next,
              requestNotificationPermission: requestPermission,
            ),
          ),
          const SizedBox(height: 14),
          _SettingsBehaviorSection(
            settings: settings.behavior,
            disabled: disabled,
            onChanged: _updateBehaviorSettings,
          ),
          const SizedBox(height: 14),
          const _SettingsInformationSection(),
        ],
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
