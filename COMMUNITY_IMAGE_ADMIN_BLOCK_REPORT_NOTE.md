# 커뮤니티 이미지·관리자·차단·신고 수정

## 1. 게시글 이미지

- 앱에서 선택한 사진을 `POST /community/uploads/image`로 업로드합니다.
- 이미지 파일은 `local_uploads/community/YYYY/MM/DD/`에 저장됩니다.
- SQLite `communitypost.image_url`에는 이미지 파일 자체가 아니라 조회 URL만 저장됩니다.
- 허용 형식: JPG, JPEG, PNG, WEBP, GIF
- 최대 크기: 8MB

서버 폴더를 교체할 때 기존 이미지를 유지하려면 `local_uploads/` 폴더를 덮어쓰거나 삭제하지 마세요.

## 2. 관리자 계정

프로젝트 루트 `.env`에 회사 로그인 이메일을 등록합니다.

```env
ADMIN_EMAILS=admin@example.com
```

여러 계정은 쉼표로 구분합니다.

```env
ADMIN_EMAILS=admin1@example.com,admin2@example.com
```

관리자 계정으로 로그인하면 다음 기능이 표시됩니다.

- 게시글·댓글·답글 신고 횟수 확인
- 게시글 메뉴의 `관리자 좋아요 설정`
- 인기글 테스트 점수 반영 여부 선택

관리자 설정은 개인 FastAPI 서버의 로컬 사용자 이메일을 기준으로 판별합니다. 앱이 회사 로그인 후 `/auth/local_sync`를 호출하므로 회사 계정 이메일과 `.env` 값이 정확히 같아야 합니다.

## 3. 사용자 차단

게시글·댓글·답글 메뉴에서 차단하면 해당 콘텐츠 하나가 아니라 작성자 자체가 차단됩니다.

차단한 사용자에 대해 다음 항목이 서버 응답에서 제외됩니다.

- 모든 게시글
- 다른 게시글에 작성한 댓글
- 다른 댓글에 작성한 답글
- 해당 사용자가 보낸 커뮤니티 알림

차단 정보는 `communityblock` 테이블에 계정별로 저장됩니다. 앱을 재실행하거나 서버를 재시작해도 유지됩니다.

## 4. 신고

- 같은 사용자가 같은 대상을 여러 번 신고해도 신고 수는 한 번만 증가합니다.
- 일반 계정에는 신고 수가 응답되지 않습니다.
- `ADMIN_EMAILS`에 등록된 관리자 계정에만 신고 수가 표시됩니다.

## 5. 서버 적용

```powershell
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

기존 데이터 유지가 필요하면 다음 항목을 보관하세요.

- `multicooker.db`
- `local_uploads/`
- `.env`
