# Settings module structure

- `data/settings_models.dart`: 알림·앱 동작·언어·튜토리얼 설정 모델과 통합 `ProfileSettings`
- `presentation/settings_screen.dart`: 마이페이지 진입 화면과 공통 라이브러리 선언
- `presentation/app_settings_screen.dart`: 설정 화면 상태 로딩·저장·로그아웃 제어
- `presentation/blocked_users_screen.dart`: 차단 사용자 조회 및 차단 해제
- `presentation/sections/settings_language_section.dart`: 언어 설정
- `presentation/sections/settings_account_section.dart`: 계정·암호·차단 사용자·로그아웃
- `presentation/sections/settings_notification_section.dart`: 댓글·답글·좋아요·공지·조리 알림
- `presentation/sections/settings_behavior_section.dart`: 자동 재연결·슬라임 표시
- `presentation/sections/settings_information_section.dart`: 앱 정보·정책
- `presentation/widgets/settings_common_widgets.dart`: 설정 화면 공통 타일과 섹션 UI
