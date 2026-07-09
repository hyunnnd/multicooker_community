# Community presentation split

커뮤니티 화면은 `community_screen.dart`에 몰려 있던 위젯들을 기능별 파일로 분리했습니다.

## 기준 파일
- `community_screen.dart`  
  커뮤니티 화면 진입점, 화면 상태 전환, 라우팅 콜백만 관리합니다.

## 분리된 파일
- `pages/community_list_page.dart`  
  커뮤니티 목록, 헤더, 공지 고정 영역, 게시글 카드

- `pages/community_post_detail_page.dart`  
  게시글 상세, 댓글, 답글

- `pages/community_notice_pages.dart`  
  공지 상세, 공지 전체 목록

- `pages/community_write_post_page.dart`  
  게시글 작성/수정 화면

- `pages/community_write_review_page.dart`  
  예전 커뮤니티 후기 작성 화면 호환용

- `widgets/community_notification_panel.dart`  
  알림 패널

- `widgets/community_review_widgets.dart`  
  예전 커뮤니티 후기 목록/필터 호환용

- `widgets/community_shared_widgets.dart`  
  공통 UI 조각: 헤더, 아바타, 이미지 박스, 메뉴, 빈 화면, 확인 팝업 등

## 참고
Dart `part` 구조로 분리했기 때문에 기존 `_orange`, `_text`, `_PostCard`처럼 private 이름을 크게 바꾸지 않고도 파일을 나눴습니다.
나중에 더 깔끔하게 하려면 `_` private 클래스를 public 클래스로 바꾸고 일반 import 구조로 다시 정리하면 됩니다.
