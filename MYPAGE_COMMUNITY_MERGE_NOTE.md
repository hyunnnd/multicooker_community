# 마이페이지/커뮤니티 병합 메모

이 수정본은 기존 앱 프로젝트에 이전 작업본의 커뮤니티 기능과 마이페이지 기능을 반영한 버전입니다.

## 반영 범위

- 커뮤니티 화면 및 상세/댓글/답글/공지/알림 구조 반영
- `/community?postId=...` 진입 시 해당 게시글 상세로 이동
- 마이페이지 상단 사용자 정보 API 연동
- 내가 올린 레시피
- 저장한 레시피
- 내가 쓴 후기
- 내가 쓴 댓글/답글
- 조리 이력
- 기기 관리 연결
- 튜토리얼 다시 보기
- 로그아웃
- 하단바를 `홈 / 레시피 / 쿠커 / 커뮤니티 / 마이` 구조로 변경

## 제외한 부분

- 마이페이지 메뉴에서 설정 항목은 제외했습니다.
- 기존 `/settings/app` 라우트도 제외했습니다.

## 서버 구조

- 인증: `AUTH_API_BASE_URL` 기본값 `http://3.36.14.110:8000`
- 앱 DB 기능: `API_BASE_URL` 기본값 `http://192.1.0.28:8001`

Flutter 실행 예시:

```powershell
flutter run --dart-define=AUTH_API_BASE_URL=http://3.36.14.110:8000 --dart-define=API_BASE_URL=http://192.1.0.28:8001
```

로컬 FastAPI 실행 예시:

```powershell
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```
