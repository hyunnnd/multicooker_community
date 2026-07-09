// 조리 상태
enum CookingStatus {
    standby(0x00), //0x00: 조리 대기
    cooking(0x01), //0x01: 조리 시작
    stopped(0x02), //0x02: 조리 중지
    completed(0x03), //0x03: 조리 완료
    error(0x04); //0x04: 에러 종료

    final int value;
    const CookingStatus(this.value);
}

// LED 색상
enum LedColor {
    aurora(0x01), //0x01
    grapheneBlue(0x02), //0x02
    green(0x03), //0x03
    yellow(0x04), //0x04
    purple(0x05), //0x05
    white(0x06); //0x06

    final int value;
    const LedColor(this.value);
}

// 효과음
enum MusicOption {
    option1(0x01), //0x01
    option2(0x02); //0x02

    final int value;
    const MusicOption(this.value);
}

// 수신 패킷 구조
// Byte 2: 조리상태     → CookingStatus status
// Byte 3: 구간정보     → int section
// Byte 4: 현재온도     → int currentTemperature
// Byte 5: 현재시간(분) → int currentMinutes
// Byte 6: 현재시간(초) → int currentSeconds
// Byte 7: RGB         → LedColor ledColor
// Byte 8: ON Music    → MusicOption onMusic
// Byte 9: OFF Music   → MusicOption offMusic

// 쿠커 -> 앱 수신 데이터 모델
class CookerState {
    final CookingStatus status; // 조리 상태
    final int section; // 현재 구간 (1~10)
    final int currentTemperature; // 현재 온도
    final int currentMinute; // 현재 시간 (분)
    final int currentSecond; // 현재 시간 (초)
    final LedColor ledColor; // LED 색상
    final MusicOption onMusic; // ON 효과음
    final MusicOption offMusic; // OFF 효과음

    const CookerState({
        required this.status,
        required this.section,
        required this.currentTemperature,
        required this.currentMinute,
        required this.currentSecond,
        required this.ledColor,
        required this.onMusic,
        required this.offMusic,
    });
}
