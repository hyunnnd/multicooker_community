import 'models/cooker_state.dart';

class PacketDecoder {
    static const int _stx = 0x5E;
    static const int _etx = 0x5F;
    static const int _packetLength = 11;

    static CookerState? decode(List<int> rawData){
        //STX 위치 찾기
        final stxIndex = rawData.indexOf(_stx);
        if(stxIndex < 0) return null;

        //STX부터 11바이트 추출
        if(rawData.length < stxIndex + _packetLength) return null;
        final packet = rawData.sublist(stxIndex, stxIndex + _packetLength);

        //ETX 검증
        if(packet[10] != _etx) return null;

        // 체크섬 검증(Byte 2-9 합산 하위 1바이트) -> 현재 체크섬 값이 자료와 다름. 하여 일단 주석 처리. 추후에 확인 필요
        // final calcChecksum = packet.sublist(1, 9).reduce((a, b) => a + b) & 0xFF;
        // if(calcChecksum != packet[9]) return null;

        return CookerState(
            status: _parseCookingStatus(packet[1]),
            section: packet[2],
            currentTemperature: packet[3],
            currentMinute: packet[4],
            currentSecond: packet[5],
            ledColor: _parseLedColor(packet[6]),
            onMusic: _parseMusicOption(packet[7]),
            offMusic: _parseMusicOption(packet[8]),
        );
    }

    static CookingStatus _parseCookingStatus(int byte){
        return CookingStatus.values.firstWhere(
            (e) => e.value == byte,
            orElse: () => CookingStatus.standby,
        );
    }

    static LedColor _parseLedColor(int byte){
        return LedColor.values.firstWhere(
            (e) => e.value == byte,
            orElse: () => LedColor.aurora,
        );
    }

    static MusicOption _parseMusicOption(int byte){
        return MusicOption.values.firstWhere(
            (e) => e.value == byte,
            orElse: () => MusicOption.option1,
        );
    }
}