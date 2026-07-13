import 'package:multicooker_bluetooth_sdk/multicooker_bluetooth_sdk.dart';

abstract class CookerService {
  Stream<CookerState> get states;
  Stream<ConnectionEvent> get connections;
  Stream<List<String>> get scanResults;
  bool get isConnected;

  Future<List<String>> scanDevices();
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<void> send(CookerCommand command);
  void dispose();
}
