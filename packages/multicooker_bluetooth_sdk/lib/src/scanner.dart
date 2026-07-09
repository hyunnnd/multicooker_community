import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class CookerScanner{
    //쿠커를 식별하는 기준값
    static const String _serviceUuid = 'fff0';
    static const String _cookerKeyword = 'graphenecooker';


    // 스캔 중에 기기가 발견될 때마다 새로운 목록이 뜸
    static Stream<List<BluetoothDevice>> get scanResults {
        return FlutterBluePlus.scanResults.map( // 발견되는 모든 BLE 기기를 스트림으로 제공
            (results) => results
                .where((result) => _isLikelyCooker(result))
                .map((result) => result.device)
                .toList(),
        );
    }

    static Future<void> startScan({
        Duration timeout = const Duration(seconds: 8),
    }) async{
        await FlutterBluePlus.stopScan();
        await FlutterBluePlus.startScan(timeout: timeout);
    }

    static Future<void> stopScan() async{
        await FlutterBluePlus.stopScan();
    }

    // 세 가지 조건 중 하나라도 만족하면 쿠커로 판단
    // 1. 기기 이름에 'graphenecooker' 포함
    // 2. 기기 이름에 'fb300' 포함
    // 3. 서비스 UUID에 'fff0' 포함
    static bool _isLikelyCooker(ScanResult result){
        final name = _deviceName(result).toLowerCase();
        final serviceUuids = result.advertisementData.serviceUuids
            .map((uuid) => uuid.toString().toLowerCase())
            .toList();

        return name.contains(_cookerKeyword) ||
            name.contains('fb300') ||
            serviceUuids.any((uuid) => uuid.contains(_serviceUuid));
    }

    // 기기 이름을 가져오는 함수
    // platformName: OS가 저장한 이름
    // advName: Advertising 패킷에 포함된 이름
    static String _deviceName(ScanResult result){
        final platformName = result.device.platformName;
        final advName = result.advertisementData.advName;
        if(platformName.trim().isNotEmpty) return platformName;
        if(advName.trim().isNotEmpty) return advName;
        return '';
    }
}