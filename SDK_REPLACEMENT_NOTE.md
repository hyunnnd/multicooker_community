# SDK 교체 내용

- 업로드된 `multicooker_bluetooth_sdk-main (1).zip` 내용을 `packages/multicooker_bluetooth_sdk/`에 포함했습니다.
- `pubspec.yaml`의 `multicooker_bluetooth_sdk` 의존성을 GitHub가 아니라 로컬 path 의존성으로 변경했습니다.
- 새 SDK의 `onConnectionChanged`가 `ConnectionEvent` 스트림이므로, 기존 앱의 `CookerService.connections` 인터페이스에 맞게 `connected` 이벤트만 `true`, 나머지는 `false`로 변환했습니다.
