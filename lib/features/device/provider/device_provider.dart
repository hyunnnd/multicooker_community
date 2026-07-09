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
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<CookerState>? _stateSubscription;

  bool isConnected = false;
  bool isScanning = false;
  bool isBusy = false;
  String deviceName = '연결된 기기 없음';
  String? errorMessage;
  CookerState? status;
  List<String> devices = const [];

  Future<void> scanDevices() async {
    isScanning = true;
    errorMessage = null;
    devices = const [];
    notifyListeners();
    try {
      devices = await _scanWithInitializationRetry();
      if (devices.isEmpty) errorMessage = '주변에서 Graphene Cooker를 찾지 못했습니다.';
    } catch (error) {
      errorMessage = _message(error);
    } finally {
      isScanning = false;
      notifyListeners();
    }
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

  Future<bool> connect(String name) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.connect(name);
      isConnected = _service.isConnected;
      deviceName = name;
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

  void _onConnection(bool connected) {
    isConnected = connected;
    if (!connected) deviceName = '연결된 기기 없음';
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
    _service.dispose();
    super.dispose();
  }
}
