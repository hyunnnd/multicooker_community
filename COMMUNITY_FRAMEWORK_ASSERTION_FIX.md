# 커뮤니티 framework assertion 수정

## 수정 대상 오류

- 공지 등록 후 `framework.dart`의 `_dependents.isEmpty` assertion
- 게시글 좋아요 후 `framework.dart`/`view.dart` assertion

## 원인 구조

커뮤니티 화면 여러 곳에서 `context.watch<CommunityProvider>()`를 사용한 상태로 공지 모달 종료, 목록 교체, 좋아요 상태 갱신이 같은 프레임에 발생했습니다. 이 과정에서 제거 중인 InheritedProvider 의존 요소와 `notifyListeners()`가 겹칠 수 있었습니다.

## 적용 내용

1. `CommunityProvider`를 UI 자동 구독용 `ChangeNotifierProvider`가 아닌 일반 `Provider`로 제공하도록 변경했습니다.
2. 커뮤니티, 홈, 레시피 상세 화면에서 `CommunityProvider`를 직접 구독하고 다음 프레임에 안전하게 화면을 갱신하도록 변경했습니다.
3. 커뮤니티의 모든 `context.watch<CommunityProvider>()` 의존성을 제거했습니다.
4. `CommunityProvider.notifyListeners()`를 다음 프레임에 한 번만 전달하도록 합쳤습니다.
5. 공지 작성 모달을 독립 StatefulWidget으로 분리하고, 데이터 갱신 프레임이 끝난 뒤 모달을 닫도록 변경했습니다.
6. 게시글, 댓글, 답글, 공지 카드에 ID 기반 `ValueKey`를 추가해 목록 갱신 시 Element 재사용이 꼬이지 않도록 했습니다.

## 수정 파일

- `lib/main.dart`
- `lib/features/community/provider/community_provider.dart`
- `lib/features/community/presentation/community_screen.dart`
- `lib/features/community/presentation/pages/community_admin_pages.dart`
- `lib/features/community/presentation/pages/community_list_page.dart`
- `lib/features/community/presentation/pages/community_post_detail_page.dart`
- `lib/features/community/presentation/pages/community_notice_pages.dart`
- `lib/features/community/presentation/widgets/community_notification_panel.dart`
- `lib/features/community/presentation/widgets/community_review_widgets.dart`
- `lib/features/home/presentation/home_screen.dart`
- `lib/features/recipe/presentation/recipe_detail_screen.dart`
