# MultiCooker 로컬 FastAPI + SQLite 실행 방법

이 프로젝트는 Flutter 앱과 같은 폴더에서 FastAPI 서버를 실행하도록 맞춰져 있습니다.
서버는 `main.py`이고, DB는 같은 폴더의 `multicooker.db`입니다.
DB 파일이 없으면 서버 시작 시 자동으로 생성되고, 샘플 커뮤니티 데이터가 들어갑니다.

## 1. 서버 실행

```cmd
cd C:\Users\user\AndroidStudioProjects\graphene_multicooker_app
python -m venv .venv
.venv\Scripts\activate
python -m pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

확인 주소:

```text
http://127.0.0.1:8001/docs
http://127.0.0.1:8001/health
http://127.0.0.1:8001/community/posts
```

## 2. Flutter 실행

서버를 켠 터미널은 그대로 두고, 새 터미널을 열어서 실행합니다.

### Chrome / Windows

```cmd
cd C:\Users\user\AndroidStudioProjects\graphene_multicooker_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

### Android Emulator

```cmd
flutter run -d emulator --dart-define=API_BASE_URL=http://10.0.2.2:8001
```

### 실제 휴대폰

PC와 휴대폰이 같은 Wi-Fi에 있어야 합니다. `ipconfig`에서 PC의 IPv4 주소를 확인한 뒤 실행합니다.

```cmd
flutter run --dart-define=API_BASE_URL=http://내PC_IP:8001
```

## 3. 로컬 로그인 테스트

서버 시작 시 테스트 계정이 자동 생성됩니다.

```text
Email: user@graphene.com
Password: 1234
```

회원가입/비밀번호 재설정 인증번호는 로컬 테스트용으로 항상 `123456`입니다.

## 4. DB 확인

```cmd
python -c "import sqlite3; con=sqlite3.connect('multicooker.db'); cur=con.cursor(); print(cur.execute('SELECT id,title,likes FROM communitypost ORDER BY id DESC').fetchall()); con.close()"
```

댓글 확인:

```cmd
python -c "import sqlite3; con=sqlite3.connect('multicooker.db'); cur=con.cursor(); print(cur.execute('SELECT id,post_id,content FROM communitycomment ORDER BY id DESC').fetchall()); con.close()"
```

좋아요 확인:

```cmd
python -c "import sqlite3; con=sqlite3.connect('multicooker.db'); cur=con.cursor(); print(cur.execute('SELECT * FROM postlike').fetchall()); con.close()"
```

## 5. DB 초기화

처음 샘플 상태로 다시 돌리고 싶으면 서버를 끈 뒤 `multicooker.db`를 삭제하고 다시 서버를 실행하면 됩니다.

```cmd
del multicooker.db
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

## 6. 이번 수정본 내용

이번 수정본은 `GrapheneMultiCooker_community_db_fixed_v2` 구조를 유지하면서, 회사 배포 서버 OpenAPI 형태에 맞춰 로컬 `main.py`에 필요한 API를 추가한 버전입니다.

추가/정리된 API:

```text
GET  /auth/google/login
GET  /auth/google/callback
POST /device/verify
POST /device/unregister
POST /recipe/upload
GET  /recipe/personal_recipes/{amount}
GET  /recipe/gsq_suggest_recipes/{amount}
GET  /recipe/recipe_titles
GET  /recipe/search_recipes/{title}
POST /ai_recommend/upload_ingredients_photo
PUT  /_local_s3/{s3_key}
GET  /_local_s3/{s3_key}
POST /ai_recommend/upload_ingredients_photo_complete
```

DB에 추가된 로컬 테이블:

```text
registereddevice
recipes
recipe_steps
ingredient_images
```

Flutter 쪽 변경:

```text
RecipeProvider가 mock 전용이 아니라 로컬 API(/recipe/gsq_suggest_recipes/50)를 우선 호출합니다.
서버가 꺼져 있으면 기존 mock recipe로 fallback합니다.
CommunityRepository가 공통 DioClient를 사용하므로 Authorization Bearer 토큰이 같이 전달됩니다.
AI 식재료 이미지 처리는 Image.file()이 아니라 XFile.readAsBytes() + Image.memory() 방식으로 수정되어 Flutter Web에서도 동작합니다.
AI 업로드도 파일 경로 기반이 아니라 bytes 기반으로 S3/local upload URL에 PUT 전송합니다.
```

주의:

```text
기존 multicooker.db가 있으면 새 테이블이 바로 반영되지 않을 수 있습니다.
로컬 테스트 중 스키마 오류가 나면 서버를 끄고 multicooker.db를 삭제한 뒤 다시 실행하세요.
```

## 7. 계정별 커뮤니티 권한 수정 내용

이번 수정본에서는 커뮤니티 작성자/수정/삭제/좋아요/북마크/알림을 로그인 계정 기준으로 분리했습니다.

테스트 계정:

```text
Email: user@graphene.com
Password: 1234

Email: 11
Password: 11

Email: student@graphene.com
Password: 1234
```

회원가입으로 만든 계정도 별도 계정으로 저장됩니다. 게시글, 댓글, 답글은 작성한 계정에만 수정/삭제 메뉴가 표시되고, 다른 계정에서는 신고/차단 메뉴가 표시됩니다.

신고 동작:

```text
신고 버튼을 누르면 communityreport 테이블에 신고 이력이 저장됩니다.
동일 계정이 같은 게시글/댓글/답글을 여러 번 신고해도 신고 수는 한 번만 증가합니다.
앱 화면에서는 신고한 항목을 즉시 숨깁니다.
서버에서는 자동 삭제하지 않고 신고 수만 누적합니다.
```

## 8. 회사 로그인 서버 + 로컬 커뮤니티 서버 분리 실행

이번 구조에서는 서버 주소가 2개로 분리됩니다.

```text
AUTH_API_BASE_URL = 회사 로그인/회원가입/이메일 인증/비밀번호 재설정 서버
API_BASE_URL      = 로컬 FastAPI 커뮤니티/레시피/AI/기기/SQLite DB 서버
```

기본값은 다음과 같이 들어가 있습니다.

```text
AUTH_API_BASE_URL=http://3.36.14.110:8000
API_BASE_URL=http://192.1.0.28:8001
```

로컬 FastAPI 서버는 PC에서 아래처럼 켭니다.

```cmd
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

같은 Wi-Fi의 갤럭시 실기기 또는 Chrome에서 실행할 때는 아래처럼 실행합니다.

```cmd
flutter run --dart-define=AUTH_API_BASE_URL=http://3.36.14.110:8000 --dart-define=API_BASE_URL=http://192.1.0.28:8001
```

회사 로그인 서버 주소나 로컬 서버 포트가 바뀌면 `--dart-define` 값만 바꾸면 됩니다.

동작 방식:

```text
1. 로그인/회원가입/이메일 인증/비밀번호 재설정은 AUTH_API_BASE_URL로 요청합니다.
2. 로그인 성공 후 /auth/me에서 받은 회사 계정 정보를 API_BASE_URL의 /auth/local_sync로 보냅니다.
3. 로컬 서버는 같은 이메일의 로컬 사용자와 연결하고 로컬 API 토큰을 발급합니다.
4. 커뮤니티, 레시피, AI, 기기 인증은 로컬 API 토큰으로 API_BASE_URL에 요청합니다.
```

주의:

```text
/auth/local_sync는 프로토타입용입니다. 앱에서 받은 회사 계정 정보를 신뢰하여 로컬 토큰을 발급합니다.
실제 배포용으로 쓰려면 로컬 서버가 회사 access token을 서버-서버 방식으로 검증한 뒤 로컬 토큰을 발급하도록 바꾸는 것이 안전합니다.
```

서버가 꺼져 있을 때:

```text
앱 자체는 실행됩니다.
로그인 서버가 꺼져 있으면 새 로그인/회원가입/비밀번호 재설정은 실패합니다.
로컬 FastAPI 서버가 꺼져 있으면 커뮤니티 DB 저장/조회, 알림, 좋아요, 댓글, 레시피 API, AI 업로드는 실패하거나 fallback 화면만 보입니다.
이미 앱에 저장된 화면 asset과 일부 mock 레시피는 표시될 수 있습니다.
```
