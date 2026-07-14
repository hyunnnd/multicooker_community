# 레시피 후기·댓글 연동

## 적용 내용

- 레시피 상세 화면의 기존 목업 `후기 · 댓글` 영역을 개인 FastAPI API와 연결
- 레시피 ID별 후기 조회 및 좋아요
- 레시피 ID별 댓글 작성·조회
- 본인이 작성한 레시피 댓글 수정·삭제
- 레시피 상세 화면에서 해당 레시피가 자동 입력된 후기 작성 화면으로 이동
- 조리 완료 화면의 `후기 작성` 버튼을 실제 후기 작성 화면과 연결
- 조리 완료 화면에서 선택한 별점을 후기 작성 화면의 초기값으로 전달

## 개인 API

```text
GET    /community/reviews?recipe_id={recipe_id}
POST   /community/reviews
GET    /community/recipes/{recipe_id}/comments
POST   /community/recipes/{recipe_id}/comments
PATCH  /community/recipe-comments/{comment_id}
DELETE /community/recipe-comments/{comment_id}
```

레시피 댓글은 SQLite의 `recipecomment` 테이블에 저장됩니다. 기존 `multicooker.db`는 삭제할 필요가 없으며, 서버 시작 시 새 테이블이 자동 생성됩니다.

## 적용 시 주의

`main.py`가 변경되었으므로 파일 교체 후 개인 FastAPI 서버를 재시작해야 합니다.

```powershell
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

기존 데이터 보존을 위해 다음 항목은 덮어쓰거나 삭제하지 않습니다.

```text
.env
multicooker.db
local_uploads/
```
