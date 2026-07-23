# 신규 계정 튜토리얼 진입 수정

- 이메일 로그인 성공 후 무조건 `/home`으로 이동하던 로직을 제거했습니다.
- 로컬 API의 `/users/me/settings`에서 `tutorial_completed` 값을 확인합니다.
- 값이 `false`인 신규 계정은 `/my/tutorial`로 이동합니다.
- Google 콜백의 `status=register`가 없더라도 서버 설정이 미완료 상태이면 튜토리얼을 표시합니다.
- 회원가입 자동 로그인 실패 후 수동 로그인한 경우에도 튜토리얼이 표시됩니다.
- 튜토리얼 완료 시 기존 로직대로 `tutorial_completed=true`가 저장됩니다.
