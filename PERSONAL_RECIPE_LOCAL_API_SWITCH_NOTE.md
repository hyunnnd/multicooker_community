# 개인 레시피 로컬 API 전환

## 변경 목적

`내가 올린 레시피` 목록과 상세 화면이 서로 다른 회사 API 조회 결과를 사용하면서,
목록에는 보이지만 상세 화면에서 `레시피를 찾을 수 없습니다.`가 표시되는 문제를 제거했습니다.

## 현재 데이터 흐름

- 레시피 등록: `POST {API_BASE_URL}/recipe/upload`
- 내가 올린 레시피 목록: `GET {API_BASE_URL}/users/me/recipes`
- 레시피 삭제: `DELETE {API_BASE_URL}/users/me/recipes/{recipe_id}`
- 저장한 레시피: `{API_BASE_URL}/users/me/saved-recipes...`
- 조리 이력에서 레시피 저장: 개인 FastAPI의 `/recipe/upload`

`AUTH_API_BASE_URL`은 로그인, 구글 로그인, 토큰 발급 등 회사 인증 기능에만 사용합니다.

## 목록과 상세 화면

마이페이지의 `내가 올린 레시피` 화면은 `RecipeProvider`가 가진 동일한 레시피 객체를 사용합니다.
따라서 항목을 누를 때 회사 API나 별도 상세 API를 다시 호출하지 않고, 이미 불러온 객체로 상세 화면을 엽니다.

## 기존 회사 DB 레시피

회사 API에만 저장되어 있던 기존 개인 레시피는 개인 SQLite DB로 자동 복사되지 않습니다.
개인 API로 다시 등록하거나 별도 마이그레이션을 해야 개인 API 목록에 표시됩니다.
