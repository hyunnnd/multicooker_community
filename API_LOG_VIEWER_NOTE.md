# API 로그 웹 화면 추가 안내

이번 수정본에는 FastAPI 서버 로그를 다른 작업자도 브라우저에서 확인할 수 있는 웹 화면을 추가했습니다.

## 서버 실행

```powershell
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload --access-log --log-level info
```

## 로그 화면 접속

같은 와이파이에 있는 작업자는 브라우저에서 아래 주소로 확인할 수 있습니다.

```text
http://<서버_PC_IP>:8001/admin/log-viewer
```

예시:

```text
http://192.1.0.28:8001/admin/log-viewer
```

## API 문서

```text
http://<서버_PC_IP>:8001/docs
```

## 로그 저장 위치

```text
logs/api.log
```

## 검색 기능

로그 화면에서 `reviews`, `200`, `401`, `500` 같은 키워드로 검색할 수 있습니다.

## 관리자 키 설정 선택 사항

팀 내부 테스트에서는 키 없이 바로 접속됩니다. 외부망에 노출할 경우 서버 실행 전에 관리자 키를 설정하십시오.

```powershell
$env:ADMIN_LOG_KEY="1234"
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload --access-log --log-level info
```

이 경우 접속 주소는 다음처럼 됩니다.

```text
http://<서버_PC_IP>:8001/admin/log-viewer?key=1234
```


## 최신순 표시 수정

`/admin/log-viewer`와 `/admin/api-logs`는 최근 로그를 읽은 뒤 역순으로 반환하므로, 가장 최신 요청 로그가 화면/JSON의 맨 위에 표시됩니다.
