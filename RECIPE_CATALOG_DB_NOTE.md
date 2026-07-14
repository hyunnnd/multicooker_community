# 기본 레시피 SQLite 전환

기존 Flutter `RecipeMockData`에 있던 7개 레시피를 개인 FastAPI 서버의 SQLite DB로 이전했습니다.

## 데이터 흐름

```text
Flutter 레시피 화면
→ GET /recipes
→ FastAPI
→ multicooker.db의 recipes / recipe_steps 조회
→ 레시피 목록·상세 표시
```

## DB에 동기화되는 기본 레시피

- 밥 (`rice`)
- 계란찜 (`egg`)
- 삼겹살 & 닭고기 (`pork`)
- 채소찜 (`vegetables`)
- 마늘 버터 새우 (`shrimp`)
- 멀티쿠커 닭갈비 (`dakgalbi`)
- 해산물 토마토 리조또 (`risotto`)

서버 시작 시 기존 `multicooker.db`에 필요한 열을 자동 추가하고 위 레시피를 등록 또는 갱신합니다. 기존 사용자의 게시글, 댓글, 개인 레시피, 저장 레시피와 조리 이력은 삭제하지 않습니다.

레시피 제목, 설명, 난이도, 인분, 호환 조리 유형, 재료, 안내 단계, 쿠커 온도·시간 단계 및 이미지 URL이 SQLite에 저장됩니다. 이미지 파일 자체는 SQLite BLOB으로 넣지 않고 기존 이미지 URL을 저장합니다.

## 적용 방법

기존 데이터를 유지하려면 다음 항목은 새 압축 파일의 것으로 덮어쓰거나 삭제하지 않습니다.

```text
multicooker.db
local_uploads/
.env
```

새 `main.py`를 적용한 뒤 개인 서버를 재시작합니다.

```powershell
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

확인 주소:

```text
GET http://127.0.0.1:8001/recipes
GET http://127.0.0.1:8001/recipes/rice
```
