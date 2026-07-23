part of '../settings_screen.dart';

class _SettingsAccountSection extends StatelessWidget {
  const _SettingsAccountSection({
    required this.authenticated,
    required this.loading,
    required this.nickname,
    required this.email,
    required this.onLogin,
    required this.onChangePassword,
    required this.onBlockedUsers,
    required this.onLogout,
  });

  final bool authenticated;
  final bool loading;
  final String nickname;
  final String email;
  final VoidCallback onLogin;
  final VoidCallback onChangePassword;
  final VoidCallback onBlockedUsers;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return _SettingsSection(
      title: lang.t('계정 및 커뮤니티', 'Account & Community'),
      children: [
        _SettingsInfoTile(
          icon: Icons.person_outline,
          title: authenticated ? nickname : 'Guest',
          subtitle: authenticated && email.isNotEmpty
              ? email
              : lang.t('로그인이 필요합니다', 'Sign in required'),
        ),
        if (!authenticated)
          _SettingsActionTile(
            icon: Icons.login_rounded,
            title: lang.t('로그인', 'Sign in'),
            subtitle: lang.t(
              '이메일 또는 Google 계정으로 로그인',
              'Sign in with email or Google',
            ),
            onTap: onLogin,
          ),
        if (authenticated)
          _SettingsActionTile(
            icon: Icons.lock_reset_rounded,
            title: lang.t('암호 변경', 'Change Password'),
            subtitle: lang.t(
              '인증코드로 비밀번호를 재설정합니다',
              'Reset your password with a verification code',
            ),
            onTap: onChangePassword,
          ),
        if (authenticated)
          _SettingsActionTile(
            icon: Icons.person_off_outlined,
            title: lang.t('차단 사용자 관리', 'Blocked Users'),
            subtitle: lang.t(
              '차단한 사용자를 확인하고 해제합니다',
              'Review and unblock community users',
            ),
            onTap: onBlockedUsers,
          ),
        if (authenticated)
          _SettingsActionTile(
            icon: Icons.logout_rounded,
            title: lang.t('로그아웃', 'Sign out'),
            subtitle: lang.t(
              '현재 계정에서 나갑니다',
              'Sign out of this account',
            ),
            danger: true,
            onTap: loading ? null : onLogout,
          ),
      ],
    );
  }
}
