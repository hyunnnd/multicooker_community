# Google 로그인/회원가입 연동

## 앱에서 구현된 흐름

1. 로그인 화면에서 `Google로 로그인 / 회원가입` 선택
2. 회사 서버의 `GET /auth/google/login`을 외부 브라우저로 실행
3. Google 인증 후 회사 서버의 `GET /auth/google/callback`으로 복귀
4. 회사 서버가 `multicooker://auth/google/callback?code=...&status=...`로 앱을 호출
5. 앱이 `POST /auth/google/token`으로 일회용 코드를 교환
6. 회사 access/refresh token을 보안 저장소에 저장
7. 회사 JWT의 `sub` 이메일을 사용해 개인 FastAPI 사용자와 동기화
8. 기존 사용자는 로그인, 최초 사용자는 회사 DB에 자동 가입 후 홈으로 이동

## 회사 서버 설정 필수값

회사 서버의 `app/.env`에서 아래 값이 실제 배포 환경과 일치해야 합니다.

```env
GOOGLE_CALLBACK_URL=https://회사서버도메인/auth/google/callback
GOOGLE_MOBILE_REDIRECT_URL=multicooker://auth/google/callback
```

`GOOGLE_CALLBACK_URL`은 Google Cloud Console의 승인된 리디렉션 URI와 완전히 같아야 합니다.

## 실행

`app_links` 패키지가 추가되었으므로 프로젝트 교체 후 한 번 실행합니다.

```powershell
flutter pub get
flutter run `
  --dart-define=API_BASE_URL=http://개인서버IP:8001 `
  --dart-define=AUTH_API_BASE_URL=http://3.36.14.110:8000
```

회사 인증 서버 주소가 변경되면 `AUTH_API_BASE_URL`만 변경합니다.

## Android 딥링크 테스트

Google 로그인 없이 앱의 딥링크 연결 여부만 확인하려면 다음 형식으로 테스트할 수 있습니다.

```powershell
adb shell am start -a android.intent.action.VIEW -d "multicooker://auth/google/callback?error=google_login_failed"
```
