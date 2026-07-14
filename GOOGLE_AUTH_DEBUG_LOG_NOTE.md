# Google 로그인 디버그 로그 확인

Google 로그인 전체 흐름을 앱 실행 콘솔에서 확인할 수 있도록 디버그 로그를 추가했습니다.

## 확인 위치

- Android Studio에서 실행한 경우: 하단 `Run` 또는 `Debug` 창
- VS Code에서 실행한 경우: `Debug Console` 또는 `Terminal`
- `flutter run`으로 실행한 경우: 명령어를 실행한 터미널
- Android Logcat에서 확인할 경우: `[Google Auth]`로 검색

## 실행 예시

```powershell
flutter run `
  --dart-define=AUTH_API_BASE_URL=http://3.36.14.110:8000 `
  --dart-define=API_BASE_URL=http://192.1.0.28:8001
```

## 정상 로그인 시 예상 로그

```text
[Google Auth] 로그인 페이지 열기: http://3.36.14.110:8000/auth/google/login
[Google Auth] 외부 브라우저 실행 여부: true
[Google Auth] 딥링크 수신: scheme=multicooker, host=auth, path=/google/callback, code 존재=true, status=login, error 존재=false
[Google Auth] 구글 콜백 처리 시작
[Google Auth] 일회성 코드 확인 완료: 길이=..., status=login
[Google Auth] 회사 서버 토큰 교환 요청 시작
[Google Auth] AuthProvider 구글 로그인 처리 시작
[Google Auth] 요청 주소: http://3.36.14.110:8000/auth/google/token
[Google Auth] 전송할 일회성 코드 존재 여부: true
[Google Auth] /auth/google/token 응답 상태: 200
[Google Auth] Access Token 발급 여부: true
[Google Auth] Refresh Token 발급 여부: true
[Google Auth] 회사 토큰 유효성 확인 완료
[Google Auth] 회사 인증 토큰 보안 저장소 저장 완료
[Google Auth] Access Token에서 계정 식별 정보 확인 여부: true
[Google Auth] Provider 토큰 확인: access=true, refresh=true
[Google Auth] 회사 계정 인증 완료: 이메일 정보 존재=true
[Google Auth] AuthProvider 구글 로그인 최종 결과: 성공=true
[Google Auth] 로그인 처리 결과: 성공=true, 회사 인증=true, 개인 API 준비=true
```

회사 서버가 `/auth/me`를 제공하지 않는 현재 구조에서는 다음 로그가 출력될 수 있습니다. 이는 `/auth/google/token`에서 토큰을 정상 발급받은 뒤 JWT의 계정 정보로 로그인 상태를 확인하는 대체 처리입니다.

```text
[Google Auth] 회사 서버에 /auth/me가 없어 발급된 JWT 정보로 로그인 계정을 확인합니다.
```

## 실패 시 예상 로그

```text
[Google Auth] /auth/google/token 요청 실패
[Google Auth] 요청 주소: http://3.36.14.110:8000/auth/google/token
[Google Auth] 응답 상태: 401
[Google Auth] 오류 내용: Invalid authorization code
[Google Auth] AuthProvider 구글 로그인 최종 결과: 성공=false, 오류=...
```

## 보안 처리

다음 민감 정보는 로그에 출력하지 않습니다.

- Google 일회성 코드의 실제 값
- Access Token 실제 값
- Refresh Token 실제 값
- 로그인한 사용자의 실제 이메일 주소

로그는 `kDebugMode` 조건 안에서만 출력되므로 디버그 실행에서 확인할 수 있습니다.
