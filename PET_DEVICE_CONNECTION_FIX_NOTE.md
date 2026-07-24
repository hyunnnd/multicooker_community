# 펫 애니메이션 및 기기 연결 화면 수정

## 적용 기준

- 펫 애니메이션은 `assets/images/pet/tangerine_chef.webp`와 `assets/images/pet/tangerine_idle.png` 두 파일만 사용합니다.
- `idle.png`, `connected.png`, `cooking.png` 등 이전 상태별 에셋은 코드에서 사용하지 않습니다.
- 기존 `tangerine_idle.png`의 일부 프레임이 192px 셀 경계를 넘어가 인접 프레임이 보이던 문제를 동일 이미지 안에서 위치만 정렬해 수정했습니다.
- `tangerine_idle.png`도 첫 프레임 고정이 아니라 상태별 행 애니메이션을 재생하도록 수정했습니다.
- 기기 관리 화면에서 쿠커 연결 성공 시 확인 팝업을 띄우지 않고 `/home`으로 즉시 이동합니다.

## 수정 파일

- `lib/features/pet/presentation/cooking_pet.dart`
- `lib/features/device/presentation/device_screen.dart`
- `assets/images/pet/tangerine_idle.png`
