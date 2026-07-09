import 'cooker_state.dart';


// 조리 모드
enum CookerMode {
    cooking(0x00), // 조리
    music(0x01), // 효과음
    led(0x02); // LED

    final int value;
    const CookerMode(this.value);
}

// 효과음 미리듣기 액션 (Byte 26)
enum MusicPreviewAction {
  none(0x00),
  preview(0x01),
  apply(0x02);

  final int value;
  const MusicPreviewAction(this.value);
}

// 효과음 적용 액션 (Byte 27)
enum MusicApplyAction {
  none(0x00),
  apply(0x01);

  final int value;
  const MusicApplyAction(this.value);
}

// LED 미리보기 액션 (Byte 29)
enum LedPreviewAction {
  none(0x00),
  preview(0x01),
  apply(0x02);

  final int value;
  const LedPreviewAction(this.value);
}

// LED 적용 액션 (Byte 30)
enum LedApplyAction {
  none(0x00),
  apply(0x01);

  final int value;
  const LedApplyAction(this.value);
}

// 조리 구간 모델
class CookingSection {
    final int temperature; // 온도 (40~200)
    final int duration; // 시간 (1~90분)

    const CookingSection({
        required this.temperature,
        required this.duration,
    });
}

// 송신 패킷 구조
// Byte 2:     모드          → CookerMode mode
// Byte 3~22:  온도/시간 구간 → List<CookingSection> sections
// Byte 23:    조리상태       → CookingStatus status
// Byte 24:    ON Music      → MusicOption onMusic
// Byte 25:    OFF Music     → MusicOption offMusic
// Byte 26:    효과음 액션    → MusicPreviewAction musicPreviewAction
// Byte 27:    효과음 적용    → MusicApplyAction musicApplyAction
// Byte 28:    RGB           → LedColor ledColor
// Byte 29:    LED 미리보기   → LedPreviewAction ledPreviewAction
// Byte 30:    LED 적용      → LedApplyAction ledApplyAction

class CookerCommand { 
    final CookerMode mode;
    final List<CookingSection> sections; // 최대 10구간
    final CookingStatus status;
    final MusicOption onMusic;
    final MusicOption offMusic;
    final MusicPreviewAction musicPreviewAction;
    final MusicApplyAction musicApplyAction;
    final LedColor ledColor;
    final LedPreviewAction ledPreviewAction;
    final LedApplyAction ledApplyAction;  

    const CookerCommand({
        required this.mode,
        required this.sections,
        required this.status,
        this.onMusic = MusicOption.option1,
        this.offMusic = MusicOption.option1,
        this.musicPreviewAction = MusicPreviewAction.none,
        this.musicApplyAction = MusicApplyAction.none,
        this.ledColor = LedColor.aurora,
        this.ledPreviewAction = LedPreviewAction.none,
        this.ledApplyAction = LedApplyAction.none,
    });
}

