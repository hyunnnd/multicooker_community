part of '../settings_screen.dart';

class _SettingsLanguageSection extends StatelessWidget {
  const _SettingsLanguageSection({
    required this.isEnglish,
    required this.disabled,
    required this.onChanged,
  });

  final bool isEnglish;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return _SettingsSection(
      title: lang.t('언어', 'Language'),
      children: [
        _LanguageOptionTile(
          label: '한국어',
          selected: !isEnglish,
          onTap: disabled ? () {} : () => onChanged(false),
        ),
        _LanguageOptionTile(
          label: 'English',
          selected: isEnglish,
          onTap: disabled ? () {} : () => onChanged(true),
        ),
      ],
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
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
    return _SettingsBaseTile(
      icon: Icons.language_rounded,
      title: label,
      subtitle: selected
          ? lang.t('선택됨', 'Selected')
          : lang.t('탭하여 변경', 'Tap to change'),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: _orange)
          : const Icon(
              Icons.radio_button_unchecked_rounded,
              color: _gray400,
            ),
      onTap: onTap,
    );
  }
}
