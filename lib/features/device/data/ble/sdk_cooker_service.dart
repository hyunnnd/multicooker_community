import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';

import 'cooker_service.dart';

class SdkCookerService implements CookerService {
  final CookerConnection _connection = CookerConnection();
  final Map<String, Future<void> Function()> _connectors = {};
  final Map<String, String> _labelByRemoteId = {};

  @override
  Stream<CookerState> get states => _connection.onStateChanged;

  @override
  Stream<ConnectionEvent> get connections => _connection.onConnectionChanged;

  @override
  Stream<List<String>> get scanResults =>
      CookerScanner.scanResults.map((devices) {
        for (final device in devices) {
          final id = device.remoteId.str;
          if (_labelByRemoteId.containsKey(id)) continue;
          final name = device.platformName.trim();
          var label = name.isEmpty ? id : name;
          if (_connectors.containsKey(label)) label = '$label ($id)';
          _labelByRemoteId[id] = label;
          _connectors[label] = () => _connection.connect(device);
        }
        return _connectors.keys.toList(growable: false);
      });

  @override
  bool get isConnected => _connection.isConnected;

  @override
  Future<List<String>> scanDevices() async {
    await startScan();
    await Future<void>.delayed(const Duration(seconds: 8));
    await stopScan();
    return _connectors.keys.toList(growable: false);
  }

  @override
  Future<void> startScan() async {
    _connectors.clear();
    _labelByRemoteId.clear();
    await CookerScanner.startScan();
  }

  @override
  Future<void> stopScan() => CookerScanner.stopScan();

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
