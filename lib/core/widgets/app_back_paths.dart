/// 앱의 현재 경로에서 시스템 뒤로가기를 더 이상 pop할 수 없을 때
/// 이동해야 할 하단 탭의 기준 경로를 반환합니다.
String appBackFallbackForPath(String path) {
  if (path == '/home') return '/home';

  // 하단 탭의 최상위 화면은 한 번 더 뒤로가면 홈으로 이동합니다.
  if (path == '/ai-scan' ||
      path == '/recipes' ||
      path == '/community' ||
      path == '/settings') {
    return '/home';
  }

  // 각 탭 안에서 열린 하위 화면은 해당 탭의 최상위 화면으로 돌아갑니다.
  if (path.startsWith('/ai')) return '/ai-scan';
  if (path.startsWith('/recipes')) return '/recipes';
  if (path.startsWith('/my/') || path.startsWith('/settings/')) return '/settings';

  // 쿠커·조리·테스트 화면은 별도 하단 탭이 없으므로 홈으로 돌아갑니다.
  if (path == '/device' ||
      path == '/pet-test' ||
      path.startsWith('/cooking')) {
    return '/home';
  }

  return '/home';
}
