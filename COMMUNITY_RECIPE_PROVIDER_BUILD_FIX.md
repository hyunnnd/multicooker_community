# Community RecipeProvider build fix

- `community_screen.dart`에서 프로필 수정 후 레시피 목록을 다시 불러오기 위해 `RecipeProvider`를 사용하고 있었으나 import가 누락되어 있었습니다.
- `../../recipe/provider/recipe_provider.dart` import를 추가했습니다.
- `Future.wait`에 전달되는 세 호출이 모두 `Future<void>`로 해석되도록 복구했습니다.
- DB, `.env`, 업로드 파일, 로그, 빌드 산출물은 배포 ZIP에 포함하지 않았습니다.
