import 'models/cooker_command.dart';

class PacketEncoder {
    static const int _stx = 0x5E;
    static const int _etx = 0x5F;
    static const int _packetLength = 32;

    static List<int> encode(CookerCommand command) {
        final packet = List<int>.filled(_packetLength, 0x00);

        // Byte 1: STX
        packet[0] = _stx;

        // Byte 2: 모드
        packet[1] = command.mode.value.clamp(0, 255);

        // Byte 3~22: 조리 구간 (온도/시간 * 10구간)
        for(int i=0; i<10; i++){
            if(i<command.sections.length){
                packet[2 + (i*2)] = command.sections[i].temperature.clamp(0, 255);
                packet[3 + (i*2)] = command.sections[i].duration.clamp(0, 255);
            } else{
                packet[2 + (i*2)] = 0x00;
                packet[3 + (i*2)] = 0x00;
            }
        }

        // Byte 23: 조리 상태
        packet[22] = command.status.value.clamp(0, 255);

        // Byte 24: ON Music
        packet[23] = command.onMusic.value.clamp(0, 255);

        // Byte 25: OFF Music
        packet[24] = command.offMusic.value.clamp(0, 255);

        // Byte 26: 효과음 액션
        packet[25] = command.musicPreviewAction.value.clamp(0, 255);

        // Byte 27: 효과음 적용
        packet[26] = command.musicApplyAction.value.clamp(0, 255);

        // Byte 28: RGB
        packet[27] = command.ledColor.value.clamp(0, 255);

        // Byte 29: LED 액션
        packet[28] = command.ledPreviewAction.value.clamp(0, 255);

        // Byte 30: LED 적용
        packet[29] = command.ledApplyAction.value.clamp(0, 255);

        // Byte 31: 체크섬 (Byte 2~30 합산 하위 1바이트)
        packet[30] = _calculateChecksum(packet);

        // Byte 32: ETX
        packet[31] = _etx;

        return packet;
    }

    static int _calculateChecksum(List<int> packet) {
        return packet.sublist(1, 30).reduce((a, b) => a + b) & 0xFF;
    }
}