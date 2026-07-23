import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../features/auth/provider/auth_provider.dart';
import '../../features/profile/provider/profile_provider.dart';

/// 로그인 완료 후 신규 사용자 튜토리얼 여부를 결정합니다.
///
/// 로그인 과정에서 이미 조회한 로컬 프로필의 tutorial_completed 값을 우선
/// 사용합니다. 이전처럼 로그인 직후 설정 API 응답을 무기한 기다리지 않으므로
/// 개인 API가 느리더라도 로그인 버튼이 멈춘 것처럼 보이지 않습니다.
Future<String> resolveAuthenticatedLandingRoute(
  BuildContext context, {
  bool forceTutorial = false,
}) async {
  if (forceTutorial) return '/tutorial/home';

  final auth = context.read<AuthProvider>();
  final knownTutorialState = auth.tutorialCompleted;
  if (knownTutorialState != null) {
    return knownTutorialState ? '/home' : '/tutorial/home';
  }

  if (!auth.localApiReady) return '/home';

  // 구버전 개인 API처럼 /auth/me에 tutorial_completed가 없는 경우에만
  // 설정 API를 짧게 확인합니다. 네트워크가 느리거나 응답하지 않아도 로그인은
  // 계속 진행되도록 제한 시간을 둡니다.
  final profile = context.read<ProfileProvider>();
  try {
    final loaded = await profile
        .loadSettings()
        .timeout(const Duration(seconds: 3), onTimeout: () => false);
    if (loaded && !profile.settings.tutorialCompleted) {
      return '/tutorial/home';
    }
  } catch (_) {
    // 튜토리얼 확인 실패가 로그인 자체를 막아서는 안 됩니다.
  }
  return '/home';
}
