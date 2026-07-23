# 후기·비밀번호 재설정·알림 수정

## 1. 내가 쓴 후기

- 상단의 후기 개수/평균 별점 요약과 설명 카드를 제거했습니다.
- 후기 목록에서는 레시피 썸네일, 제목, 별점, 작성일, 좋아요 수만 표시합니다.
- 후기 본문과 `레시피 보기` 버튼을 제거했습니다.
- 카드 전체를 누르면 해당 레시피 상세 화면으로 이동하여 후기를 확인할 수 있습니다.
- 수정/삭제는 우측 더보기 메뉴에서 실행합니다.

## 2. Google 로그인과 비밀번호 재설정

- 비밀번호 재설정은 이메일/비밀번호로 가입한 계정에만 사용합니다.
- Google 로그인 계정은 Google 계정에서 비밀번호를 관리하므로 재설정 화면에 안내 문구를 표시합니다.
- 로그인 화면의 버튼명을 `이메일 로그인 비밀번호 재설정`으로 변경했습니다.
- 재설정 화면을 `push` 방식으로 열고 `PopScope`에 로그인 화면 fallback을 추가하여 뒤로가기 시 앱이 종료되지 않도록 수정했습니다.
- 이메일, 인증코드, 새 비밀번호(8자 이상) 입력 검사를 추가했습니다.
- 포함된 FastAPI의 테스트 인증 흐름은 `인증 전 재설정 거부 → 코드 검증 → 비밀번호 변경 → 새 비밀번호 로그인` 순서로 검수했습니다.
- 앱 기본값의 회사 인증 서버(`AUTH_API_BASE_URL`)는 검수 시 접속할 수 없어 회사 서버의 실제 메일 발송은 별도로 확인해야 합니다.

## 3. 알림 읽음 처리와 중복 휴대전화 알림

- 게시글 상세 화면에 들어가면 해당 게시글의 댓글/답글 알림을 모두 읽음 처리합니다.
- 레시피 상세 화면에 들어가면 해당 레시피의 댓글/후기 알림을 모두 읽음 처리합니다.
- 기존 폴링 알림은 최신 알림 ID가 증가했을 때만 한 번 표시합니다.
- 읽음 수가 17개에서 16개로 바뀌는 것처럼 개수만 감소한 경우에는 다시 울리지 않습니다.
- 읽음 처리 시 마지막 전달 ID를 삭제하지 않으므로 앱을 다시 실행해도 과거 알림이 재전송되지 않습니다.

## 4. 앱 종료 상태 원격 푸시(FCM)

앱이 완전히 종료된 상태에서 알림을 받으려면 로컬 알림만으로는 불가능하므로 Firebase Cloud Messaging 연동을 추가했습니다.

### Flutter 실행 값

Firebase 프로젝트의 앱 설정값을 다음 `dart-define`으로 전달합니다.

```bash
flutter run \
  --dart-define=API_BASE_URL=http://서버주소:8001 \
  --dart-define=AUTH_API_BASE_URL=http://인증서버주소:8000 \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=...
```

iOS 빌드는 다음 값도 추가합니다.

```bash
--dart-define=FIREBASE_IOS_APP_ID=... \
--dart-define=FIREBASE_IOS_BUNDLE_ID=...
```

값이 없으면 앱은 종료 상태 푸시를 비활성화하고 기존 앱 실행 중 폴링 방식으로 동작합니다.

### FastAPI 서버 설정

```bash
pip install -r requirements.txt
```

`.env`에 Firebase Admin 서비스 계정 JSON 경로를 설정합니다.

```env
FIREBASE_SERVICE_ACCOUNT_JSON=C:/absolute/path/firebase-service-account.json
```

서버 재시작 후 앱이 로그인하면 FCM 토큰이 `/push/devices`로 등록됩니다. 다른 사용자가 댓글·답글·레시피 댓글·후기를 작성하면 DB 저장이 완료된 뒤 서버가 푸시를 한 번 전송합니다. Android에서는 같은 태그를 사용해 최신 알림 카드 하나를 갱신하고 읽지 않은 개수를 표시합니다.

### iOS 추가 설정

Xcode의 Runner Target에서 `Push Notifications` capability와 `Background Modes > Remote notifications`를 활성화하고, Firebase 프로젝트에 APNs 인증 키를 등록해야 합니다.
