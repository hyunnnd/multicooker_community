# 커뮤니티 공지·좋아요·알림·검색 수정 내역

## 1. 공지 등록 후 Flutter assertion 대응

- 커뮤니티 최상위 화면이 `CommunityProvider`의 모든 변경을 감시하지 않도록 수정했습니다.
- 최상위 화면은 로딩 상태만 선택적으로 감시하고, 게시글·공지 목록은 필요한 하위 화면에서만 다시 그립니다.
- 공지 저장 중에는 저장 버튼, 닫기 버튼, 하단 시트 드래그 및 바깥 영역 닫기를 차단합니다.
- Provider 변경 알림이 build/layout 단계와 겹치는 경우에만 다음 프레임으로 합쳐 전달합니다.

## 2. 게시글 좋아요 assertion 및 중복 요청 대응

- 게시글 카드 내부에서 별도의 Provider 감시를 제거했습니다.
- 좋아요 요청 중인 게시글 ID를 추적합니다.
- 요청 완료 전에는 같은 좋아요 버튼을 다시 누를 수 없도록 처리했습니다.
- 목록 화면과 게시글 상세 화면에 동일한 중복 요청 방지 처리를 적용했습니다.

## 3. 알림 작성자 닉네임·프로필 최신화

- 알림 응답에 `from_user_id`를 포함하고 앱 모델에서 보관합니다.
- 알림창을 열기 전에 서버에서 최신 알림을 다시 조회합니다.
- 서버는 알림 생성 당시 저장된 이름만 사용하지 않고 작성자 ID를 기준으로 현재 닉네임, 프로필 색상, 프로필 이미지 URL을 조회하여 반환합니다.
- 기존 알림 데이터도 닉네임 변경 또는 프로필 이미지 변경 시 작성자 ID와 연결되도록 보완했습니다.

## 4. 커뮤니티 검색 입력창 색상

- 검색 상태의 상단 배경을 회색 계열로 변경했습니다.
- 검색 입력창을 `#F3F4F6` 회색 배경과 `#E5E7EB` 테두리로 통일했습니다.

## 주요 수정 파일

- `lib/features/community/provider/community_provider.dart`
- `lib/features/community/data/models/community_models.dart`
- `lib/features/community/data/community_repository.dart`
- `lib/features/community/presentation/community_screen.dart`
- `lib/features/community/presentation/pages/community_list_page.dart`
- `lib/features/community/presentation/pages/community_post_detail_page.dart`
- `lib/features/community/presentation/pages/community_admin_pages.dart`
- `main.py`

## 적용 시 주의사항

백엔드 코드가 수정되었으므로 FastAPI 서버를 재시작해야 합니다. Flutter 프로젝트에서는 패키지 변경은 없으므로 일반적으로 `flutter clean`은 필수가 아니지만, 기존 디버그 세션에 framework assertion 상태가 남아 있다면 앱을 완전히 종료한 후 다시 실행하는 것이 좋습니다.
