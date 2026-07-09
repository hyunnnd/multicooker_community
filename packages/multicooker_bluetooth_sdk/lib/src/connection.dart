import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'models/cooker_state.dart';
import 'packet_decoder.dart';

//디버그용
import 'package:flutter/foundation.dart';

// 연결 상태 변경의 '원인'을 구분하기 위한 이벤트.
// bool 하나만으로는 '사용자가 직접 끊었는지', '신호가 끊겨서 끊겼는지'를 구분할 수가 없음.
enum ConnectionEvent{
  connected,            // 연결 성공
  disconnectedByUser,   // 사용자가 직접 연결을 끊음
  disconnectedByAdapterOff, // 블루투스 어댑터가 꺼져서 끊김 -> 사용자가 직접 블루투스를 켜야함
  disconnectedByLoss,   // 신호가 끊겨서 끊김, 기기 이탈 등 의도치 않게 끊김 -> 자동 재연결 시도
}

class CookerConnection{
    // 싱글톤: 객체를 하나만 생성하도록 강제
    static final CookerConnection _instance = CookerConnection._internal();
    factory CookerConnection() => _instance;
    CookerConnection._internal();

    static const String _serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
    static const String _writeUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
    static const String _notifyUuid = '0000fff2-0000-1000-8000-00805f9b34fb';
    static const int _chunkSize = 20;
    static const int _chunkDelay = 15; // milliseconds

    BluetoothDevice? _device;
    BluetoothCharacteristic? _writeCharacteristic;
    BluetoothCharacteristic? _notifyCharacteristic;

    StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
    StreamSubscription<List<int>>? _notifySubscription;
    StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

    final _stateController = StreamController<CookerState>.broadcast();
    final _connectionController = StreamController<ConnectionEvent>.broadcast();
    final _adapterStateController = StreamController<BluetoothAdapterState>.broadcast();

    Stream<CookerState> get onStateChanged => _stateController.stream;
    Stream<ConnectionEvent> get onConnectionChanged => _connectionController.stream;
    Stream<BluetoothAdapterState> get onAdapterStateChanged => _adapterStateController.stream;

    bool _isConnected = false;
    bool _isWriting = false;
    bool _isReconnecting = false;
    bool _adapterListenerStarted = false;
    // 마지막으로 확인된 어댑터 상태 (재연결 루프에서 매번 스트림을 기다리지 않고 참조) 
    BluetoothAdapterState _lastAdapterState = BluetoothAdapterState.unknown;
    final List<int> _rxBuffer = [];

    bool get isConnected => _isConnected;

    // 1. 기존 연결이 있으면 먼저 끊기
    // 2. 연결 상태 모니터링 시작
    // 3. BLE 연결
    // 4. MTU 요청 (185바이트, 실패해도 무시)
    // 5. Service/Characteristic 탐색 (FFF1, FFF2 찾기)
    // 6. Notification Enable 및 수신 구독 시작
    Future<void> connect(BluetoothDevice device) async {
      _ensureAdapterListener();

      // 기존 연결이 있으면 먼저 끊기
      if (_isConnected) {
          await disconnect();
      }

      _device = device;

      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state){
          final connected = state == BluetoothConnectionState.connected;
          _isConnected = connected;

          if(connected){
            _connectionController.add(ConnectionEvent.connected);
          } else{
            // 사용자가 disconnect()으로 끊은 경우, disconnect() 쪽에서
            // 이미 disconnectedByUser 이벤트를 보내고 이 리스터를 취소 했기 때문에
            // 여기 도달했다는 것은 '의도치 않은 끊김'이라는 의미
            // 다만 그 원인이 "어댑터 꺼짐"인지 "신호/거리 문제"인지는 구분해야 함.
            // 앱팀이 onAdapterStateChanged와 직접 상관관계를 맞추는 워크어라운드 없이
            // onConnectionChanged 하나만 구독해도 되므로, 여기서 SDK가 대신 분류
            _connectionController.add(_classifyUnintendedDisconnect());
          }

          //연결이 끊기면 자동 재연결 시도
          if(!connected && _device != null && !_isReconnecting){
            _reconnect();
          }
      });

        await device.connect(
            license: License.nonprofit,
            autoConnect: false,
            timeout: const Duration(seconds: 12),
        );

        try{
            await device.requestMtu(185);
        } catch (_) {}

        final services = await device.discoverServices();

        BluetoothCharacteristic? writeChar;
        BluetoothCharacteristic? notifyChar;

        for(final service in services){
            if(! _sameUuid(service.uuid, _serviceUuid)) continue;
            for(final char in service.characteristics){
                if(_sameUuid(char.uuid, _writeUuid)) writeChar = char;
                if(_sameUuid(char.uuid, _notifyUuid)) notifyChar = char;
            }
        }

        if(writeChar == null || notifyChar == null){
            throw Exception('FFF1/FFF2 Characteristics을 찾지 못했습니다.');
        }

        _writeCharacteristic = writeChar;
        _notifyCharacteristic = notifyChar;

        await notifyChar.setNotifyValue(true);

        _rxBuffer.clear();
        _notifySubscription = notifyChar.onValueReceived.listen(_onNotifyData);
    }

    Future<void> disconnect() async{
      // 실제 연결 해체 동작을 시작하기 전에, "사용자가 직접 끊었다"는 사실을
      // 리스너가 취소되기 전에 먼저 스트림으로 보냄.
      if(_isConnected){
        _connectionController.add(ConnectionEvent.disconnectedByUser);
      }

        await _notifySubscription?.cancel();
        await _connectionSubscription?.cancel();
        await _notifyCharacteristic?.setNotifyValue(false);
        await _device?.disconnect();
        _writeCharacteristic = null;
        _notifyCharacteristic = null;
        _device = null;
        _isConnected = false;
        _rxBuffer.clear();
    }

    Future<void> sendPacket(List<int> packet) async{
        final writeChar = _writeCharacteristic;
        if(writeChar == null) throw Exception("연결되지 않은 상태입니다.");
        if(_isWriting) throw Exception("이전 전송이 아직 완료되지 않았습니다.");

        _isWriting = true;
        try{
            await _writeInChunks(writeChar, packet);
        } finally{
            _isWriting = false;
        }
    }

    Future<void> _writeInChunks(
        BluetoothCharacteristic writeChar,
        List<int> packet,
    ) async{
        final chunks = <List<int>>[];
        for(int offset=0; offset<packet.length; offset+=_chunkSize){
            final end = (offset + _chunkSize < packet.length)
                ? offset + _chunkSize
                : packet.length;
            chunks.add(packet.sublist(offset, end));
        }

        for(final chunk in chunks){
            await writeChar.write(chunk, withoutResponse: false);
            await Future.delayed(const Duration(milliseconds: _chunkDelay));
        }
    }

    void _onNotifyData(List<int> data){
        _rxBuffer.addAll(data);

        while(_rxBuffer.isNotEmpty){
            final stxIndex = _rxBuffer.indexOf(0x5E);
            if(stxIndex < 0){
                _rxBuffer.clear();
                return;
            }

            if(stxIndex > 0){
                _rxBuffer.removeRange(0, stxIndex);
            }

            if(_rxBuffer.length < 11) return;

            final packet = _rxBuffer.take(11).toList();
            if(packet.last != 0x5F){
                _rxBuffer.removeAt(0);
                continue;
            }

            _rxBuffer.removeRange(0, 11);

            final state = PacketDecoder.decode(packet);
            if(state != null){
                debugPrint('수신: status=${state.status}, temp=${state.currentTemperature}');  // 임시 로그
                _stateController.add(state);
            }
        }
    }

    bool _sameUuid(Guid actual, String expected){
        final actualText = actual.toString().toLowerCase();
        final expectedText = expected.toLowerCase();
        final shortExpected = expectedText.substring(4, 8);
        return actualText == expectedText || actualText == shortExpected;
    }

    // 의도치 않은 끊김이 발생했을 때, 그 시점에 캡처해둔 _lastAdapterState를 참조해서
    // '어댑터 꺼짐'과 '신호/거리 문제'를 구분함
    // 스트림(onAdapterStateChanged)이 아니라 이미 캐시된 필드를 동기적으로 읽는 이유:
    // 두 개의 별도 스트림(어댑터 상태 vs 기기 연결 상태) 중 뭐가 먼저 도착하는지에
    // 판단을 맡기면 레이스 컨디션이 생김. 여기서는 "언제 끊겼는지"는 connectionState
    // 스트림이 트리거하고, "왜 끊겼는지"는 그 콜백 안에서 스냅샷으로 확정함.
    // unknown을 disconnectedByAdapterOff로 단정하지 않는 이유:
    // _reconnect()가 이미 채택한 관례와 동일하개, "꺼짐이 확정되지 않은 상태"는
    // 관대하게(=신호 문제 쪽으로) 처리해서 두 로직 간 일관성을 유지함
    ConnectionEvent _classifyUnintendedDisconnect(){
        final adapterConfirmedOff = _lastAdapterState != BluetoothAdapterState.on &&
            _lastAdapterState != BluetoothAdapterState.unknown;
        return adapterConfirmedOff
            ? ConnectionEvent.disconnectedByAdapterOff
            : ConnectionEvent.disconnectedByLoss;
    }

    // 블루투스 어댑터 On/Off 상태를 감지해서, 어댑터가 꺼진 동안에는 불필요한 connect() 재시도(각 시도마다 12초 타임아웃)를 하지 않도록 함.
    // 앱 자체 전원이 아니라 "블루투스 활성화 여부"만을 나타내는 상태임
    void _ensureAdapterListener(){
      if(_adapterListenerStarted) return;
      _adapterListenerStarted = true;

      _adapterSubscription = FlutterBluePlus.adapterState.listen((state){
        _lastAdapterState = state;
        _adapterStateController.add(state);

        //어댑터가 다시 켜졌고, 재연결 대상 기기가 있고, 아직 연결이 안되어 있고, 현재 재연결 루프가 돌고 있지 않다면 재연결을 재개
        if(state == BluetoothAdapterState.on && 
          _device != null && 
          !_isConnected && 
          !_isReconnecting){
          _reconnect();
        }
      });
    }

    Future<void> _reconnect() async{
      _isReconnecting = true;
      await Future.delayed(const Duration(seconds: 2));

      while(_device != null && !_isConnected){
        //어댑터 자체가 꺼져있으면(혹은 전환 중이면) connect()를 시도하지 않고 루프를 빠져나감
        // 이후 어댑터가 다시 켜지면 위 리스너가 _reconnect()를 다시 호출해서 재개함.
        if(_lastAdapterState != BluetoothAdapterState.on &&
        _lastAdapterState != BluetoothAdapterState.unknown){
          break;
        }
  
        try{
          await connect(_device!);
          break;
        } catch(_){
          await Future.delayed(const Duration(seconds: 3));
        }
      }
      _isReconnecting = false;
    }

    void dispose(){
        _notifySubscription?.cancel();
        _connectionSubscription?.cancel();
        _adapterSubscription?.cancel();
        _notifyCharacteristic = null;
        _stateController.close();
        _connectionController.close();
        _adapterStateController.close();
        _device?.disconnect();
    }
}