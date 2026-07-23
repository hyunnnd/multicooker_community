# CommunityProvider 시작 오류 수정

## 원인
`CommunityProvider`는 `ChangeNotifier`를 상속하지만 `main.dart`에서 일반 `Provider<CommunityProvider>`로 등록되어 있었습니다.
provider 6.x는 `Listenable`/`ChangeNotifier` 객체를 일반 `Provider`에 등록하면 앱 시작 시 잘못된 등록으로 판단하고 assertion을 발생시킵니다.

## 수정
- `Provider<CommunityProvider>`를 `ChangeNotifierProvider<CommunityProvider>`로 변경
- 일반 Provider 검사 비활성화(`Provider.debugCheckInvalidValueType = null`) 같은 우회 코드는 사용하지 않음
- `ChangeNotifierProvider`가 `CommunityProvider.dispose()`를 자동 호출하므로 중복 `dispose` 콜백 제거

## 적용 방법
Hot Reload가 아니라 앱을 완전히 종료한 뒤 다시 실행해야 합니다.

```bash
flutter clean
flutter pub get
flutter run
```
