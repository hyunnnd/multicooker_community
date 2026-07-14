# 레시피 단계 사진 저장 구조

- 앱에서 선택한 단계 사진은 레시피 저장 전에 `POST /recipe/uploads/image`로 업로드됩니다.
- 실제 파일은 `local_uploads/recipes/steps/YYYY/MM/DD/`에 저장됩니다.
- SQLite의 `recipes.instruction_steps_json`에는 휴대폰의 로컬 경로가 아니라 서버 이미지 URL이 저장됩니다.
- 레시피 상세 화면은 `instruction_steps[].image_url`을 사용해 사진을 표시합니다.
- 기존 레시피 수정 화면에서는 저장된 이미지 URL을 미리 표시하며, 새 사진을 고르면 새 URL로 교체됩니다.
- 서버 폴더 교체 시 `local_uploads/`를 보존해야 기존 단계 사진이 유지됩니다.
