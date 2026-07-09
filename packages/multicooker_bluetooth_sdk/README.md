# multicooker_bluetooth_sdk

멀티쿠커와 Flutter 앱 간 BLE 통신을 담당하는 SDK입니다. 앱 개발팀은 이 SDK의 내부 통신 로직(패킷 구조, 체크섬, 청크 분할 등)을 몰라도 아래 가이드만으로 개발을 진행할 수 있습니다.

## 설치

### 1. pubspec.yaml에 의존성 추가

GitHub 저장소를 직접 참조하는 방식입니다. 프로젝트의 `pubspec.yaml`에서 `dependencies` 항목에 추가하세요.

```yaml
dependencies:
  flutter:
    sdk: flutter

  multicooker_bluetooth_sdk:
    git:
      url: https://github.com/Dongun614/multicooker_bluetooth_sdk
      ref: main 

  # 기존 의존성들...
```

### 2. 패키지 설치

터미널에서 프로젝트 루트 경로에서 실행합니다.

```bash
flutter pub get
```

### 3. import

```dart
import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';
```

이 한 줄로 SDK의 모든 공개 기능을 사용할 수 있습니다.

---

## 1. 쿠커 검색 (Scan)

### 검색 시작 / 중지

```dart
await CookerScanner.startScan(); // 기본 8초간 검색
await CookerScanner.stopScan();
```

### 검색 결과 받기

```dart
CookerScanner.scanResults.listen((devices) {
    // devices: List<BluetoothDevice>
    // 주변에서 발견된 쿠커 기기 목록 (자동 필터링됨)
    for (final device in devices) {
        print(device.platformName);
    }
});
```

쿠커가 아닌 기기는 SDK 내부에서 자동으로 걸러지므로, 받은 목록은 모두 쿠커로 간주해도 됩니다.

---

## 2. 쿠커 연결 (Connection)

`CookerConnection`은 싱글톤입니다. 앱 어디서 호출하든 항상 동일한 객체를 사용하게 되며, 한 번에 하나의 쿠커에만 연결됩니다.

```dart
final connection = CookerConnection();
```

### 연결 / 해제

```dart
await connection.connect(device); // device: scanResults에서 받은 BluetoothDevice
await connection.disconnect();
```

다른 쿠커에 연결하고 싶다면 `connect()`를 다시 호출하기만 하면 됩니다. 기존 연결은 SDK가 자동으로 끊고 새로 연결합니다.

### 연결 상태 확인

`onConnectionChanged`는 `bool`이 아니라 `ConnectionEvent` 열거형을 전달합니다. 단순히 "연결됐다/끊겼다"뿐 아니라 끊김의 **원인**까지 구분할 수 있습니다.

```dart
enum ConnectionEvent {
  connected,                 // 연결 성공
  disconnectedByUser,        // 사용자가 직접 disconnect()를 호출해서 끊김
  disconnectedByAdapterOff,  // 휴대폰 블루투스 자체가 꺼져서 끊김
  disconnectedByLoss,        // 거리 멀어짐 등 신호 문제로 끊김 (그 외의 의도치 않은 끊김)
}
```

```dart
// 실시간 변화 감지 (연결/끊김 발생 시마다 호출됨)
connection.onConnectionChanged.listen((event) {
    switch (event) {
        case ConnectionEvent.connected:
            // 연결됨 UI
            break;
        case ConnectionEvent.disconnectedByUser:
            // 사용자가 직접 끊음: 재연결 UI를 보여줄 필요 없음
            break;
        case ConnectionEvent.disconnectedByAdapterOff:
            // 블루투스 자체가 꺼짐: 사용자가 블루투스를 켜야만 재연결이 재개됨
            break;
        case ConnectionEvent.disconnectedByLoss:
            // 거리 멀어짐 등 신호 문제로 끊김: SDK가 자동 재연결을 시도하는 동안 안내 UI 표시
            break;
    }
});

// 현재 상태를 즉시 확인 (버튼 클릭 시 등)
if (connection.isConnected) {
    // ...
}
```

### 자동 재연결

연결 중 기기와의 연결이 예기치 않게 끊기면(`ConnectionEvent.disconnectedByAdapterOff` 또는 `disconnectedByLoss`, 사용자가 직접 `disconnect()`를 호출한 경우 제외) SDK가 내부적으로 자동 재연결을 시도합니다. 앱에서 별도로 재연결 로직을 구현할 필요는 없으며, `onConnectionChanged`로 결과만 지켜보면 됩니다.

- 연결이 끊긴 후 2초 뒤 첫 재연결을 시도하고, 실패하면 3초 간격으로 계속 재시도합니다.
- 재연결에 성공하면 `onConnectionChanged`로 `ConnectionEvent.connected` 이벤트가 다시 전달됩니다.
- 블루투스 어댑터(휴대폰 블루투스 자체)가 꺼져 있는 동안에는 재연결을 시도하지 않고 대기하며, 어댑터가 다시 켜지면 자동으로 재개합니다.

### 블루투스 어댑터 상태 확인

기기 연결 상태(`onConnectionChanged`)와 별개로, 휴대폰의 블루투스 On/Off 상태는 `onAdapterStateChanged`로 확인할 수 있습니다. 예를 들어 연결이 끊겼을 때 원인이 "기기와 멀어짐"인지 "휴대폰 블루투스가 꺼짐"인지 구분하고 싶을 때 사용하세요.

```dart
connection.onAdapterStateChanged.listen((state) {
    if (state == BluetoothAdapterState.off) {
        // 사용자에게 블루투스를 켜달라고 안내
    }
});
```

`BluetoothAdapterState`는 `flutter_blue_plus` 패키지에서 제공하는 타입입니다.

### 끊김 원인 정확히 구분하기

`onConnectionChanged` 하나만 구독해도 끊김의 원인을 구분할 수 있습니다. 사용자가 `disconnect()`를 호출하지 않은 의도치 않은 끊김이 발생하면, SDK가 내부적으로 추적하고 있던 어댑터 상태를 그 시점에 확인해서 "어댑터가 꺼져서 끊겼는지" "거리 멀어짐 등 신호 문제로 끊겼는지"를 분류한 뒤 이벤트로 전달합니다. 앱에서 `onAdapterStateChanged`와 직접 상관관계를 맞추는 워크어라운드는 필요하지 않습니다.

| 상황 | 이벤트 |
|---|---|
| 어댑터(블루투스) 꺼짐 | `ConnectionEvent.disconnectedByAdapterOff` |
| 거리 멀어짐 등 신호 문제 | `ConnectionEvent.disconnectedByLoss` |
| 사용자가 직접 끊음 | `ConnectionEvent.disconnectedByUser` |
| 재연결 성공 | `ConnectionEvent.connected` |

`onAdapterStateChanged`는 이 분류와 별개로, 연결 여부와 무관하게 휴대폰 블루투스 자체의 On/Off 상태를 실시간으로 보여주고 싶을 때(예: 설정 화면에 상태 표시) 계속 사용할 수 있습니다.

---

## 3. 쿠커 상태 받기 (조리 진행 상황)

쿠커가 보내는 조리 상태(온도, 시간, LED 색상 등)는 `CookerState` 객체로 자동 변환되어 Stream으로 전달됩니다.

```dart
connection.onStateChanged.listen((state) {
    print(state.status);             // CookingStatus (standby, cooking, stopped, completed, error)
    print(state.section);            // 현재 구간 (1~10)
    print(state.currentTemperature); // 현재 온도
    print(state.currentMinute);      // 현재 시간 (분)
    print(state.currentSecond);      // 현재 시간 (초)
    print(state.ledColor);           // LedColor
    print(state.onMusic);            // MusicOption
    print(state.offMusic);           // MusicOption
});
```

패킷 파싱, 체크섬 검증 등은 모두 SDK 내부에서 처리되므로 신경 쓸 필요가 없습니다.

---

## 4. 쿠커에 명령 보내기

### 명령 객체 만들기

```dart
final command = CookerCommand(
    mode: CookerMode.cooking, // cooking, music, led 중 하나
    sections: [
        CookingSection(temperature: 100, duration: 10), // 1구간: 100도, 10분
        CookingSection(temperature: 120, duration: 5),  // 2구간: 120도, 5분
        // 최대 10구간까지 가능. 입력 안 한 구간은 자동으로 빈 값 처리됨
    ],
    status: CookingStatus.cooking,
    onMusic: MusicOption.option1,
    offMusic: MusicOption.option2,
    musicPreviewAction: MusicPreviewAction.none,
    musicApplyAction: MusicApplyAction.none,
    ledColor: LedColor.grapheneBlue,
    ledPreviewAction: LedPreviewAction.none,
    ledApplyAction: LedApplyAction.none,
);
```

### 전송하기

```dart
final packet = PacketEncoder.encode(command);
await connection.sendPacket(packet);
```

패킷 분할(20바이트 청크), 전송 딜레이, 체크섬 계산은 모두 SDK 내부에서 자동으로 처리됩니다.

---

## 5. 전체 사용 흐름 예시

```dart
// 1. 검색
await CookerScanner.startScan();
CookerScanner.scanResults.listen((devices) {
    // 사용자가 목록에서 기기 선택
});

// 2. 연결
final connection = CookerConnection();
await connection.connect(selectedDevice);

// 3. 상태 구독
connection.onStateChanged.listen((state) {
    // UI 업데이트
});

// 4. 조리 시작 명령 전송
final command = CookerCommand(
    mode: CookerMode.cooking,
    sections: [CookingSection(temperature: 100, duration: 10)],
    status: CookingStatus.cooking,
    onMusic: MusicOption.option1,
    offMusic: MusicOption.option1,
    musicPreviewAction: MusicPreviewAction.none,
    musicApplyAction: MusicApplyAction.none,
    ledColor: LedColor.grapheneBlue,
    ledPreviewAction: LedPreviewAction.none,
    ledApplyAction: LedApplyAction.none,
);
await connection.sendPacket(PacketEncoder.encode(command));

// 5. 연결 종료 (화면 벗어날 때 등)
await connection.disconnect();
```

---

## 주의사항

- **권장 흐름**: 검색 → 연결 → 상태 구독 → 명령 전송 순서를 지켜주세요. 연결 전에 `sendPacket()`을 호출하면 예외가 발생합니다.
- **동시 전송 불가**: 한 번에 하나의 패킷만 전송할 수 있습니다. 이전 전송이 끝나기 전에 다시 `sendPacket()`을 호출하면 예외가 발생합니다.
- **앱 종료 시**: 화면이나 앱이 완전히 종료될 때는 `connection.dispose()`를 호출해 리소스를 정리해주세요. 단순 연결 해제는 `disconnect()`로 충분합니다.
- **단일 연결**: `CookerConnection`은 싱글톤이라 앱 전체에서 한 번에 하나의 쿠커에만 연결됩니다. 두 개의 쿠커를 동시에 다룰 수 없습니다.
- **자동 재연결**: 연결이 예기치 않게 끊기면 SDK가 자동으로 재연결을 시도합니다([자동 재연결](#자동-재연결) 참고). `dispose()`를 호출하면 재연결 시도도 함께 종료됩니다.
- **전송 실패 처리 필수**: `sendPacket()`은 전송 도중 연결이 끊기면 예외를 던집니다. `try-catch`로 감싸서 처리해주세요.

```dart
try {
    await connection.sendPacket(packet);
} catch (e) {
    // 전송 실패 처리, 재시도 또는 사용자 안내
}
```