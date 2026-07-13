import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';

import '../data/ble/cooker_service.dart';
import '../data/device_repository.dart';

class DeviceProvider extends ChangeNotifier {
  DeviceProvider(this._repository, this._service) {
    _connectionSubscription = _service.connections.listen(_onConnection);
    _stateSubscription = _service.states.listen(_onState);
  }

  final DeviceRepository _repository;
  final CookerService _service;
  StreamSubscription<ConnectionEvent>? _connectionSubscription;
  StreamSubscription<CookerState>? _stateSubscription;
  StreamSubscription<List<String>>? _scanSubscription;
  Timer? _scanTimeout;
  String? _lastConnectedName;

  bool isConnected = false;
  bool isScanning = false;
  bool isBusy = false;
  String deviceName = '연결된 기기 없음';
  String? errorMessage;
  CookerState? status;
  List<String> devices = const [];
  ConnectionEvent? connectionEvent;

  Future<void> scanDevices() async {
    isScanning = true;
    errorMessage = null;
    devices = const [];
    notifyListeners();
    try {
      await _startLiveScan();
    } catch (error) {
      errorMessage = _message(error);
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> _startLiveScan({bool afterConnectionLoss = false}) async {
    await _scanSubscription?.cancel();
    _scanTimeout?.cancel();
    _scanSubscription = _service.scanResults.listen((next) {
      devices = next;
      notifyListeners();
    });
    await _startScanWithInitializationRetry();
    _scanTimeout = Timer(const Duration(seconds: 8), () async {
      if (isConnected || !isScanning) return;
      await _service.stopScan();
      isScanning = false;
      if (devices.isEmpty) {
        errorMessage = afterConnectionLoss
            ? '쿠커를 다시 찾지 못했습니다. 가까이 두고 다시 검색해 주세요.'
            : '주변에서 Graphene Cooker를 찾지 못했습니다.';
      }
      notifyListeners();
    });
  }

  Future<void> _startScanWithInitializationRetry() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await _service.startScan();
        return;
      } catch (error) {
        if (!error.toString().contains('CBManagerStateUnknown') ||
            attempt == 4) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _stopLiveScan() async {
    _scanTimeout?.cancel();
    _scanTimeout = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _service.stopScan();
    isScanning = false;
  }

  Future<List<String>> _scanWithInitializationRetry() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        return await _service.scanDevices();
      } catch (error) {
        if (!error.toString().contains('CBManagerStateUnknown') ||
            attempt == 4) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return const [];
  }

  Future<void> stopScan() async {
    await _stopLiveScan();
    notifyListeners();
  }

  Future<void> refreshDevicesForTests() async {
    try {
      devices = await _scanWithInitializationRetry();
    } finally {
      notifyListeners();
    }
  }

  Future<bool> connect(String name) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _stopLiveScan();
      await _service.connect(name);
      isConnected = _service.isConnected;
      deviceName = name;
      if (isConnected) _lastConnectedName = name;
      return isConnected;
    } catch (error) {
      await _service.disconnect();
      isConnected = false;
      deviceName = '연결된 기기 없음';
      errorMessage = _message(error);
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _lastConnectedName = null;
    await _service.disconnect();
    isConnected = false;
    deviceName = '연결된 기기 없음';
    notifyListeners();
  }

  Future<void> sendCookingProgram({
    required List<CookingSection> sections,
    required CookingStatus cookingStatus,
    required MusicOption onMusic,
    required MusicOption offMusic,
    required LedColor ledColor,
  }) async {
    if (sections.isEmpty || sections.length > 10) {
      throw ArgumentError('조리 구간은 1~10개여야 합니다.');
    }
    if (sections.any(
      (section) =>
          section.temperature < 40 ||
          section.temperature > 250 ||
          section.duration < 1 ||
          section.duration > 90,
    )) {
      throw ArgumentError('온도는 40~250℃, 시간은 1~90분으로 설정해 주세요.');
    }
    await _service.send(
      CookerCommand(
        mode: CookerMode.cooking,
        sections: sections,
        status: cookingStatus,
        onMusic: onMusic,
        offMusic: offMusic,
        ledColor: ledColor,
      ),
    );
  }

  Future<void> sendMusic({
    required MusicOption onMusic,
    required MusicOption offMusic,
    required bool preview,
  }) => _service.send(
    CookerCommand(
      mode: CookerMode.music,
      sections: const [],
      status: CookingStatus.standby,
      onMusic: onMusic,
      offMusic: offMusic,
      musicPreviewAction: preview
          ? MusicPreviewAction.preview
          : MusicPreviewAction.apply,
      musicApplyAction: preview
          ? MusicApplyAction.none
          : MusicApplyAction.apply,
    ),
  );

  Future<void> sendLed({required LedColor ledColor, required bool preview}) =>
      _service.send(
        CookerCommand(
          mode: CookerMode.led,
          sections: const [],
          status: CookingStatus.standby,
          ledColor: ledColor,
          ledPreviewAction: preview
              ? LedPreviewAction.preview
              : LedPreviewAction.apply,
          ledApplyAction: preview ? LedApplyAction.none : LedApplyAction.apply,
        ),
      );

  Future<void> verifyRegisteredDevice(String macAddress) async {
    final result = await _repository.verifyDevice(macAddress);
    isConnected = result.verified;
    deviceName = result.deviceName ?? deviceName;
    notifyListeners();
  }

  void _onConnection(ConnectionEvent event) {
    connectionEvent = event;
    isConnected = event == ConnectionEvent.connected;
    if (isConnected) {
      errorMessage = null;
      unawaited(_stopLiveScan());
    } else {
      deviceName = '연결된 기기 없음';
      errorMessage = switch (event) {
        ConnectionEvent.disconnectedByUser => null,
        ConnectionEvent.disconnectedByAdapterOff =>
          'Bluetooth가 꺼져 연결이 해제되었습니다. Bluetooth를 켜 주세요.',
        ConnectionEvent.disconnectedByLoss =>
          '쿠커와의 연결이 끊겼습니다. 가까이 두면 자동 재연결을 시도합니다.',
        ConnectionEvent.connected => null,
      };
      if (event == ConnectionEvent.disconnectedByLoss &&
          _lastConnectedName != null &&
          !isScanning) {
        isScanning = true;
        devices = const [];
        unawaited(_startLiveScan(afterConnectionLoss: true));
      }
    }
    notifyListeners();
  }

  void _onState(CookerState next) {
    status = next;
    notifyListeners();
  }

  String _message(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('bluetooth must be turned on') ||
        message.contains('CBManagerStateUnknown')) {
      return 'Bluetooth를 켜고 권한을 허용한 뒤 다시 검색해 주세요.';
    }
    return message;
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _stateSubscription?.cancel();
    _scanTimeout?.cancel();
    _scanSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
