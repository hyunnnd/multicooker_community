# 마이페이지·레시피·저장·조리 이력 수정 사항

## 설정 화면 위치

- 메인 마이페이지 및 설정 메뉴: `lib/features/settings/presentation/settings_screen.dart`
- 설정 상세 라우트: `/settings/app`
- 알림·언어·기기 별칭·자동 재연결 설정은 로컬 FastAPI의 사용자별 설정/기기 API에 저장됩니다.
- 비밀번호 재설정은 회사 인증 서버의 기존 `/reset` 흐름으로 이동합니다.

## 서버 구분

- `AUTH_API_BASE_URL`: 회사 서버
  - `POST /recipe/upload`
  - `GET /recipe/personal_recipes/100`
  - 로그인·회원가입·비밀번호 재설정
- `API_BASE_URL`: 앱용 로컬 FastAPI
  - 저장한 레시피
  - 조리 이력
  - 커뮤니티·후기·댓글·기기·설정

회사 서버에 저장/조리 이력 API가 없으므로 해당 데이터는 로컬 FastAPI에서 사용자별로 관리합니다. 회사 레시피를 저장할 때에는 레시피 스냅샷과 회사 레시피 식별자를 함께 보관합니다.

## 실행 예시

```powershell
flutter run `
  --dart-define=AUTH_API_BASE_URL=http://3.36.14.110:8000 `
  --dart-define=API_BASE_URL=http://<로컬 FastAPI 서버 IP>:8001
```

`main.py`가 변경되었으므로 로컬 FastAPI 서버에도 이 프로젝트의 `main.py`를 반영한 뒤 재시작해야 합니다.
