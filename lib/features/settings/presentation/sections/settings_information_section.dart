part of '../settings_screen.dart';

class _SettingsInformationSection extends StatelessWidget {
  const _SettingsInformationSection();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return _SettingsSection(
      title: lang.t('정보', 'About'),
      children: [
        const _SettingsInfoTile(
          icon: Icons.info_outline,
          title: 'Graphene Multi-Cooker',
          subtitle: 'Prototype · v0.1',
        ),
        _SettingsInfoTile(
          icon: Icons.policy_outlined,
          title: lang.t('개인정보 및 약관', 'Privacy and Terms'),
          subtitle: lang.t(
            '서비스 정책 문서 연결 예정',
            'Service policy documents will be linked later',
          ),
        ),
      ],
    );
  }
}
