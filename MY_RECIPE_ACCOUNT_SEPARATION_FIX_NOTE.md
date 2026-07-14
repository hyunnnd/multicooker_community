# 내가 올린 레시피 계정 분리 수정

## 최종 구조

`내가 올린 레시피` 화면은 현재 로그인 사용자의 개인 API 응답만 사용합니다.

```text
GET /users/me/recipes
Authorization: Bearer 개인_API_토큰
```

서버는 토큰에서 현재 사용자를 확인하고 다음 조건으로 조회합니다.

```text
RecipeRecord.owner_user_id == current_user.id
```

Flutter는 이 응답을 별도의 `_myRecipes` 목록에 그대로 저장합니다. 공식 레시피 여부를 나타내는 `isOfficial` 값이나 별도의 `isMyRecipe` 표시값으로 소유자를 추측하지 않습니다.

## 변경 내용

- `RecipeProvider`에서 공개 레시피 목록과 내 레시피 목록을 분리했습니다.
  - `_catalogRecipes`: 공개/기본 레시피
  - `_myRecipes`: `GET /users/me/recipes` 응답
- `Recipe.isMyRecipe` 필드를 제거했습니다.
- `RecipeProvider.personalRecipes`는 `_myRecipes`를 그대로 반환합니다.
- 마이페이지의 `내가 올린 레시피` 진입 및 새로고침은 `loadMyRecipes()`만 호출합니다.
- 업로드 성공 시 `POST /recipe/upload` 응답으로 받은 새 레시피를 내 목록에 바로 추가합니다.
- 업로드 직후 상세 화면 이동은 제목 검색이 아니라 서버가 반환한 레시피 ID를 사용합니다.
- 내 레시피 삭제는 `DELETE /users/me/recipes/{recipe_id}`를 사용합니다.
- 앱 복원 또는 계정 변경 시 개인 API 토큰을 회사 로그인 계정 기준으로 다시 발급하여 이전 계정 토큰이 재사용되지 않도록 했습니다.
- 마이페이지 레시피 개수는 `/users/me`의 계정별 `recipe_count`를 사용합니다.

## 계정 분리 확인 결과

테스트 계정 A로 레시피를 등록한 뒤 각 토큰으로 조회했습니다.

```text
A 계정 GET /users/me/recipes → A가 등록한 레시피 표시
B 계정 GET /users/me/recipes → 빈 목록
```

따라서 다른 계정에서 동일한 레시피가 보인다면 앱에서 이전 빌드 또는 이전 개인 API 토큰을 사용하고 있는지 확인해야 합니다.
