import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';

import 'cooker_service.dart';

class SdkCookerService implements CookerService {
  final CookerConnection _connection = CookerConnection();
  final Map<String, Future<void> Function()> _connectors = {};

  @override
  Stream<CookerState> get states => _connection.onStateChanged;

  @override
  Stream<bool> get connections => _connection.onConnectionChanged.map(
        (event) => event == ConnectionEvent.connected,
      );

  @override
  bool get isConnected => _connection.isConnected;

  @override
  Future<List<String>> scanDevices() async {
    _connectors.clear();
    final seenDeviceIds = <String>{};
    final subscription = CookerScanner.scanResults.listen((devices) {
      for (final device in devices) {
        final id = device.remoteId.str;
        if (!seenDeviceIds.add(id)) continue;
        final name = device.platformName.trim();
        var label = name.isEmpty ? id : name;
        if (_connectors.containsKey(label)) label = '$label ($id)';
        _connectors[label] = () => _connection.connect(device);
      }
    });
    try {
      await CookerScanner.startScan();
      await Future<void>.delayed(const Duration(seconds: 8));
    } finally {
      await CookerScanner.stopScan();
      await subscription.cancel();
    }
    return _connectors.keys.toList(growable: false);
  }

  @override
  Future<void> connect(String deviceId) async {
    final connect = _connectors[deviceId];
    if (connect == null) throw StateError('검색된 쿠커를 선택해 주세요.');
    await connect();
  }

  @override
  Future<void> disconnect() => _connection.disconnect();

  @override
  Future<void> send(CookerCommand command) =>
      _connection.sendPacket(PacketEncoder.encode(command));

  @override
  void dispose() => _connection.dispose();
}
