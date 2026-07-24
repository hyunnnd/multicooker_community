# ProfileSettings 호환 필드 빌드 수정

`app.dart`와 `global_cooker_overlay.dart`에서 사용하는 설정 필드를
`ProfileSettings`에 다시 추가했습니다.

추가/복구 필드:
- autoReconnect
- commentNotification
- replyNotification
- likeNotification
- noticeNotification
- slimeEnabled

기존 설정 필드와 JSON 저장/복원 및 copyWith 호환을 유지합니다.
