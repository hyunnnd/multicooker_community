# 사용자 레시피 공개·비공개 기능

## 적용 내용

- 레시피 등록 및 수정 화면에서 `공개` 또는 `비공개`를 선택할 수 있습니다.
- 공개 레시피는 모든 사용자의 레시피 목록과 검색 결과에 표시됩니다.
- 비공개 레시피는 작성자 본인의 `내가 올린 레시피`와 `내 비공개 레시피` 영역에서만 표시됩니다.
- 다른 사용자는 비공개 레시피의 상세 조회와 저장을 할 수 없습니다.
- 공개 레시피를 저장한 뒤 작성자가 비공개로 전환하면 다른 사용자의 저장 목록에서도 더 이상 표시되지 않습니다.
- 레시피 수정과 삭제는 기존과 동일하게 작성자만 가능합니다.
- 기존 DB의 사용자 레시피는 마이그레이션 시 안전하게 `비공개`로 설정되고, 공식 레시피는 `공개`로 유지됩니다.

## 추가·변경 API

```text
GET /recipes                 공식 레시피 목록
GET /recipes/public          모든 사용자의 공개 레시피 목록
GET /recipes/public/{id}     공개 사용자 레시피 상세
GET /users/me/recipes        내가 작성한 공개·비공개 레시피
POST /recipe/upload          visibility 값을 포함하여 레시피 등록
PATCH /users/me/recipes/{id} visibility를 포함하여 본인 레시피 수정
DELETE /users/me/recipes/{id} 본인 레시피 삭제
```

`visibility` 값은 `public` 또는 `private`만 허용됩니다.

## 서버 재시작

```powershell
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

기존 데이터를 유지하려면 `.env`, `multicooker.db`, `local_uploads/`는 삭제하거나 새 파일로 덮어쓰지 마십시오.
