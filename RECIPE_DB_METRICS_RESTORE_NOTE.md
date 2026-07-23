# 레시피 별점·사용 횟수 DB 연동 복구

- 앱의 가짜 고정 별점/사용 횟수 값을 제거했습니다.
- `GET /recipes/feed` 응답의 `rating_average`, `review_count`, `usage_count`를 `Recipe` 모델에 저장합니다.
- 서버는 기존 `RecipeReview`와 완료 상태의 `CookingHistory` 행을 집계해 값을 반환합니다.
- 후기를 등록한 직후 레시피 목록을 다시 읽어 평균 별점과 후기 수를 갱신합니다.
- DB 파일은 ZIP에 포함하지 않습니다. 기존 DB를 그대로 유지한 채 코드만 덮어써야 합니다.
