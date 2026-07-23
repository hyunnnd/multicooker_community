# 선택 통합 기준

- 기준 프로젝트: `GrapheneSquare_cooker_app-master (10).zip`
- 가져온 기능: `GrapheneSquare_cooker_app_popular_category_badge_aligned.zip`의 커뮤니티 및 설정 기능
- 유지한 기능:
  - 기기 관리 화면과 UI: 앱마스터 원본
  - 튜토리얼 다시 보기: 앱마스터의 홈 스포트라이트 튜토리얼
  - 홈, 조리, 레시피, AI, 프로필 하위 화면: 앱마스터 원본
- 설정 하위 화면 상단 바:
  - 앱마스터 기기 관리와 동일한 `#F8FAFC` 배경
  - 왼쪽 회색 둥근 뒤로가기 버튼
  - 오른쪽 작은 회색 제목
- 추가 경로: `/settings/blocked-users`
- 튜토리얼 경로: `/my/tutorial` → `/tutorial/home`

실행 전:

```powershell
flutter clean
flutter pub get
flutter run --dart-define=AUTH_API_BASE_URL=http://3.36.14.110:8000 --dart-define=API_BASE_URL=http://192.1.0.28:8001 -d "SM S926N"
```
