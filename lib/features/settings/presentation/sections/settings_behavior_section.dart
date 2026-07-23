part of '../settings_screen.dart';

class _SettingsBehaviorSection extends StatelessWidget {
  const _SettingsBehaviorSection({
    required this.settings,
    required this.disabled,
    required this.onChanged,
  });

  final BehaviorSettings settings;
  final bool disabled;
  final ValueChanged<BehaviorSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return _SettingsSection(
      title: lang.t('앱 동작', 'App Behavior'),
      children: [
        _SettingsSwitchTile(
          icon: Icons.bluetooth_searching_rounded,
          title: lang.t('쿠커 자동 재연결', 'Auto Reconnect Cooker'),
          subtitle: lang.t(
            '신호가 끊기면 자동으로 다시 연결 시도',
            'Try reconnecting when the signal is lost',
          ),
          value: settings.autoReconnect,
          onChanged: disabled
              ? (_) {}
              : (value) => onChanged(
                    settings.copyWith(autoReconnect: value),
                  ),
        ),
        _SettingsSwitchTile(
          icon: Icons.pets_outlined,
          title: lang.t('슬라임 표시', 'Show Slime'),
          subtitle: lang.t(
            '화면에 조리 도우미 슬라임 캐릭터 표시',
            'Show the slime cooking helper on screen',
          ),
          value: settings.slimeEnabled,
          onChanged: disabled
              ? (_) {}
              : (value) => onChanged(
                    settings.copyWith(slimeEnabled: value),
                  ),
        ),
      ],
    );
  }
}
