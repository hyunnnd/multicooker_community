# 레시피 공개·홈 연동 및 API 정리

## 앱 반영
- 내 레시피 목록의 관리 메뉴에서 공개/비공개를 즉시 변경할 수 있습니다.
- 홈의 인기 레시피는 DB의 `rating_average`, `review_count`, `usage_count`를 표시합니다.
- 인기 레시피 정렬은 사용 횟수 → 평균 별점 → 후기 수 순입니다.
- 홈의 커뮤니티 최신글은 `/community/posts` 응답을 실제 작성 시각 기준으로 정렬하여 최대 2개 표시합니다.

## API 정리
- 레시피 목록은 앱에서 `GET /recipes/feed` 하나만 호출합니다.
  - 공식 레시피와 공개 사용자 레시피를 통합 반환합니다.
- 레시피 생성의 표준 경로는 `POST /users/me/recipes`입니다.
  - 기존 `POST /recipe/upload`는 호환을 위해 deprecated alias로 유지합니다.
- 공개 범위 변경은 `PATCH /users/me/recipes/{recipe_id}/visibility`를 사용합니다.
- 기존 `GET /recipe/personal_recipes/{amount}`는 `GET /users/me/recipes`와 중복되므로 deprecated로 표시했습니다.
- 단계 이미지 업로드 코드에 중복으로 들어간 경로 인수를 제거했습니다.

로그인 API는 변경하지 않았습니다.
