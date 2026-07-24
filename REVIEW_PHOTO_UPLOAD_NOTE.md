# 후기 사진 등록 기능 추가

- 후기 작성 화면에서 갤러리 사진 1장 선택/미리보기/변경/삭제 지원
- 등록 시 기존 `/community/uploads/image` API로 이미지를 먼저 업로드한 뒤 후기 데이터에 URL 저장
- `RecipeReview.review_image_url` 컬럼 및 기존 SQLite 자동 마이그레이션 추가
- 커뮤니티 후기 목록, 레시피 상세 후기, 마이페이지 내가 쓴 후기에서 첨부 사진 표시
- JPG/PNG/WEBP/GIF, 8MB 제한은 기존 커뮤니티 이미지 업로드 API 정책을 그대로 사용
