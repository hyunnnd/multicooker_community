````md
# MultiCooker Community 기능 설명

## 1. 커뮤니티 기능 개요

멀티쿠커 앱의 커뮤니티 기능은 사용자가 조리 경험, 질문, 팁 등을 공유할 수 있도록 만든 게시판 기능입니다.

현재 커뮤니티는 다음 기능을 제공합니다.

- 자유 게시글 작성
- Q&A 게시글 작성
- 게시글 목록 조회
- 게시글 상세 조회
- 게시글 수정 및 삭제
- 게시글 좋아요
- 게시글 북마크
- 게시글 신고
- 댓글 작성, 수정, 삭제
- 댓글 좋아요
- 댓글 신고
- 답글 작성, 수정, 삭제
- 답글 좋아요
- 답글 신고
- 공지사항 조회
- 알림 조회 및 읽음 처리
- 인기글 조회

기존에 커뮤니티 안에 있던 `후기` 탭은 제거했습니다.  
현재 레시피 후기는 커뮤니티 탭이 아니라 **레시피 상세 화면 하단의 후기 영역**에서 작성하고 확인하는 구조입니다.

단, 서버 API 이름은 기존 구조와의 호환을 위해 아직 `/community/reviews`를 사용합니다.

---

## 2. 커뮤니티 화면 파일 구조

커뮤니티 화면은 유지보수를 쉽게 하기 위해 기능별로 파일을 분리했습니다.

```text
lib/features/community/presentation/community_screen.dart
````

커뮤니티의 메인 진입점입니다.
화면 전환, Provider 연결, 페이지 호출 역할만 담당합니다.

```text
lib/features/community/presentation/pages/community_list_page.dart
```

커뮤니티 목록 화면입니다.
게시글 목록, 탭, 검색, 인기글, 공지 미리보기 등을 표시합니다.

```text
lib/features/community/presentation/pages/community_post_detail_page.dart
```

게시글 상세 화면입니다.
게시글 본문, 댓글, 답글, 좋아요, 수정/삭제/신고 기능을 담당합니다.

```text
lib/features/community/presentation/pages/community_write_post_page.dart
```

게시글 작성 및 수정 화면입니다.
제목, 내용, 이미지, 게시판 카테고리 선택 기능을 담당합니다.

```text
lib/features/community/presentation/pages/community_notice_pages.dart
```

공지사항 목록 및 공지사항 상세 화면입니다.

```text
lib/features/community/presentation/widgets/community_notification_panel.dart
```

알림 패널입니다.
내 글에 댓글이 달리거나 내 댓글에 답글이 달렸을 때 생성된 알림을 표시합니다.

```text
lib/features/community/presentation/widgets/community_shared_widgets.dart
```

커뮤니티에서 공통으로 사용하는 UI 위젯들을 모아둔 파일입니다.

```text
lib/features/community/presentation/widgets/community_review_widgets.dart
```

이전 커뮤니티 후기 구조와의 호환을 위해 남겨둔 후기 관련 위젯입니다.
현재 실제 후기 작성은 레시피 상세 화면에서 사용하는 구조입니다.

---

## 3. 인증 방식

커뮤니티 API는 대부분 로그인이 필요합니다.

앱은 회사 로그인 서버에서 로그인한 뒤, 로컬 FastAPI 서버의 `/auth/local_sync`를 호출하여 로컬 API용 토큰을 발급받습니다.

이후 커뮤니티 API 요청에는 아래 헤더가 포함되어야 합니다.

```http
Authorization: Bearer <local_access_token>
```

로그인 토큰이 없으면 서버는 커뮤니티 API 요청을 거부합니다.

---

## 4. 사용 중인 API 목록

## 4.1 로컬 계정 동기화 API

| Method | Endpoint           | 설명                                             |
| ------ | ------------------ | ---------------------------------------------- |
| POST   | `/auth/local_sync` | 회사 로그인 성공 후 로컬 DB 사용자와 동기화하고 로컬 API 토큰을 발급합니다. |

요청 예시:

```json
{
  "email": "user@example.com",
  "nickname": "사용자",
  "external_user_id": "company_user_id"
}
```

응답 예시:

```json
{
  "access_token": "local_access_token",
  "refresh_token": "local_refresh_token",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "nickname": "사용자"
  }
}
```

---

# 5. 커뮤니티 게시글 API

## 5.1 게시글 목록 조회

```http
GET /community/posts
```

Query Parameter:

| 이름         | 타입     | 설명                        |
| ---------- | ------ | ------------------------- |
| `category` | string | `전체`, `자유`, `Q&A`, `인기` 등 |
| `keyword`  | string | 검색어                       |
| `sort`     | string | 정렬 기준. 기본값 `latest`       |
| `limit`    | int    | 가져올 개수. 기본값 100           |

응답 예시:

```json
{
  "posts": [
    {
      "id": 1,
      "category": "자유",
      "username": "사용자",
      "title": "감자 수육 팁 공유합니다",
      "content": "조리할 때 물을 조금만 넣으면 좋습니다.",
      "image_url": null,
      "tags": [],
      "likes": 3,
      "bookmarks": 1,
      "comment_count": 2,
      "is_liked": false,
      "is_bookmarked": false,
      "is_owner": true
    }
  ],
  "total_count": 1
}
```

---

## 5.2 인기글 조회

```http
GET /community/posts/popular
```

Query Parameter:

| 이름     | 타입  | 설명               |
| ------ | --- | ---------------- |
| `days` | int | 인기글 산정 기간. 기본값 3 |

현재 인기글은 단순 누적 좋아요 수가 아니라, 최근 기간 동안의 활동량을 기준으로 계산합니다.

인기글 점수 기준:

```text
최근 좋아요 증가 수 + 최근 댓글 증가 수 * 2
```

즉 오래된 글이 예전에 좋아요를 많이 받았다는 이유만으로 계속 인기글에 남지 않도록 구성했습니다.

응답 예시:

```json
{
  "days": 3,
  "posts": []
}
```

---

## 5.3 게시글 상세 조회

```http
GET /community/posts/{post_id}
```

설명:

게시글 상세, 댓글, 답글, 좋아요 여부, 북마크 여부, 작성자 권한 정보를 가져옵니다.

응답 예시:

```json
{
  "post": {
    "id": 1,
    "category": "자유",
    "username": "사용자",
    "title": "감자 수육 팁 공유합니다",
    "content": "조리 팁 내용입니다.",
    "likes": 3,
    "bookmarks": 1,
    "comments": [],
    "is_liked": false,
    "is_bookmarked": false,
    "is_owner": true
  }
}
```

---

## 5.4 게시글 작성

```http
POST /community/posts
```

요청 Body:

```json
{
  "category": "자유",
  "title": "게시글 제목",
  "content": "게시글 내용",
  "image_url": null,
  "tags": []
}
```

설명:

로그인한 사용자의 계정 정보로 게시글을 작성합니다.
작성자 정보는 클라이언트에서 직접 보내지 않고 서버의 로그인 토큰 기준으로 저장됩니다.

---

## 5.5 게시글 수정

```http
PATCH /community/posts/{post_id}
```

요청 Body:

```json
{
  "category": "Q&A",
  "title": "수정된 제목",
  "content": "수정된 내용",
  "image_url": null,
  "tags": []
}
```

설명:

본인이 작성한 게시글만 수정할 수 있습니다.
다른 사용자의 게시글 수정 요청은 `403`으로 거부됩니다.

---

## 5.6 게시글 삭제

```http
DELETE /community/posts/{post_id}
```

설명:

본인이 작성한 게시글만 삭제할 수 있습니다.
실제 DB row를 즉시 삭제하지 않고 `deleted = true`로 처리합니다.

---

## 5.7 게시글 좋아요

```http
POST /community/posts/{post_id}/like
```

설명:

게시글 좋아요를 추가합니다.
같은 사용자가 같은 게시글에 중복 좋아요를 누를 수 없습니다.

---

## 5.8 게시글 좋아요 취소

```http
DELETE /community/posts/{post_id}/like
```

설명:

게시글 좋아요를 취소합니다.

---

## 5.9 게시글 북마크

```http
POST /community/posts/{post_id}/bookmark
```

설명:

게시글을 북마크합니다.

---

## 5.10 게시글 북마크 취소

```http
DELETE /community/posts/{post_id}/bookmark
```

설명:

게시글 북마크를 취소합니다.

---

## 5.11 게시글 신고

```http
POST /community/posts/{post_id}/report
```

요청 Body:

```json
{
  "reason": "부적절한 내용"
}
```

설명:

게시글을 신고합니다.
같은 사용자가 같은 게시글을 중복 신고해도 신고는 1회만 반영됩니다.

---

# 6. 댓글 API

## 6.1 댓글 작성

```http
POST /community/posts/{post_id}/comments
```

요청 Body:

```json
{
  "content": "댓글 내용"
}
```

설명:

게시글에 댓글을 작성합니다.
내 글에 다른 사용자가 댓글을 달면 알림이 생성됩니다.

---

## 6.2 댓글 수정

```http
PATCH /community/comments/{comment_id}
```

요청 Body:

```json
{
  "content": "수정된 댓글 내용"
}
```

설명:

본인이 작성한 댓글만 수정할 수 있습니다.

---

## 6.3 댓글 삭제

```http
DELETE /community/comments/{comment_id}
```

설명:

본인이 작성한 댓글만 삭제할 수 있습니다.
실제 DB row를 삭제하지 않고 `deleted = true`로 처리합니다.

---

## 6.4 댓글 좋아요

```http
POST /community/comments/{comment_id}/like
```

설명:

댓글에 좋아요를 추가합니다.
같은 사용자가 같은 댓글에 중복 좋아요를 누를 수 없습니다.

---

## 6.5 댓글 좋아요 취소

```http
DELETE /community/comments/{comment_id}/like
```

설명:

댓글 좋아요를 취소합니다.

---

## 6.6 댓글 신고

```http
POST /community/comments/{comment_id}/report
```

요청 Body:

```json
{
  "reason": "부적절한 댓글"
}
```

설명:

댓글을 신고합니다.
같은 사용자의 중복 신고는 1회만 반영됩니다.

---

# 7. 답글 API

## 7.1 답글 작성

```http
POST /community/comments/{comment_id}/replies
```

요청 Body:

```json
{
  "content": "답글 내용"
}
```

설명:

댓글에 답글을 작성합니다.
내 댓글에 다른 사용자가 답글을 달면 알림이 생성됩니다.

---

## 7.2 답글 수정

```http
PATCH /community/replies/{reply_id}
```

요청 Body:

```json
{
  "content": "수정된 답글 내용"
}
```

설명:

본인이 작성한 답글만 수정할 수 있습니다.

---

## 7.3 답글 삭제

```http
DELETE /community/replies/{reply_id}
```

설명:

본인이 작성한 답글만 삭제할 수 있습니다.

---

## 7.4 답글 좋아요

```http
POST /community/replies/{reply_id}/like
```

설명:

답글 좋아요를 추가합니다.

---

## 7.5 답글 좋아요 취소

```http
DELETE /community/replies/{reply_id}/like
```

설명:

답글 좋아요를 취소합니다.

---

## 7.6 답글 신고

```http
POST /community/replies/{reply_id}/report
```

요청 Body:

```json
{
  "reason": "부적절한 답글"
}
```

설명:

답글을 신고합니다.

---

# 8. 공지사항 API

## 8.1 공지사항 목록 조회

```http
GET /community/notices
```

설명:

전체 공지사항 목록을 조회합니다.

---

## 8.2 고정 공지 조회

```http
GET /community/notices/pinned
```

설명:

중요 공지 또는 가장 우선 표시할 공지를 조회합니다.

---

## 8.3 공지사항 상세 조회

```http
GET /community/notices/{notice_id}
```

설명:

특정 공지사항의 상세 내용을 조회합니다.

---

# 9. 알림 API

## 9.1 내 알림 목록 조회

```http
GET /community/notifications
```

설명:

현재 로그인한 사용자의 알림 목록을 조회합니다.

알림이 생성되는 대표 상황:

```text
내 게시글에 다른 사용자가 댓글 작성
내 댓글에 다른 사용자가 답글 작성
```

본인이 본인 글에 댓글을 쓰거나, 본인 댓글에 답글을 쓰는 경우에는 알림을 만들지 않습니다.

---

## 9.2 전체 알림 읽음 처리

```http
PATCH /community/notifications/read_all
```

설명:

현재 로그인한 사용자의 모든 알림을 읽음 처리합니다.

---

## 9.3 특정 알림 읽음 처리

```http
PATCH /community/notifications/{notification_id}/read
```

설명:

특정 알림 하나를 읽음 처리합니다.
본인의 알림만 읽음 처리할 수 있습니다.

---

# 10. 레시피 후기 API

현재 레시피 후기는 커뮤니티 탭이 아니라 레시피 상세 화면에서 사용합니다.
다만 API 경로는 기존 구조와의 호환을 위해 `/community/reviews`를 사용합니다.

## 10.1 후기 작성

```http
POST /community/reviews
```

요청 Body:

```json
{
  "recipe_id": "recipe_001",
  "recipe_title": "허브 스테이크",
  "recipe_image": "https://example.com/image.jpg",
  "rating": 5,
  "content": "생각보다 맛있고 조리가 편했습니다."
}
```

설명:

레시피 상세 화면에서 후기를 작성합니다.

별점은 1점부터 5점까지 사용합니다.
서버에서는 잘못된 값이 들어와도 1~5 사이로 보정합니다.

```text
0점 요청 → 1점으로 저장
10점 요청 → 5점으로 저장
```

---

## 10.2 후기 목록 조회

```http
GET /community/reviews
```

설명:

서버는 전체 후기를 반환합니다.
앱에서는 현재 레시피의 `recipe_id` 또는 `recipe_title`과 맞는 후기만 필터링해서 레시피 상세 화면에 표시합니다.

현재 구조:

```text
서버: 전체 후기 반환
앱: 현재 레시피에 해당하는 후기만 필터링
```

추후 개선 방향:

```text
GET /recipes/{recipe_id}/reviews
```

처럼 레시피별 후기 조회 API로 분리하는 것이 좋습니다.

---

## 10.3 후기 좋아요

```http
POST /community/reviews/{review_id}/like
```

설명:

후기에 좋아요를 추가합니다.
같은 사용자가 같은 후기에 중복 좋아요를 누를 수 없습니다.

---

## 10.4 후기 좋아요 취소

```http
DELETE /community/reviews/{review_id}/like
```

설명:

후기 좋아요를 취소합니다.

---

# 11. 주요 DB 테이블

커뮤니티 기능에서 사용하는 주요 테이블은 다음과 같습니다.

| 테이블                     | 설명         |
| ----------------------- | ---------- |
| `CommunityPost`         | 커뮤니티 게시글   |
| `CommunityComment`      | 게시글 댓글     |
| `CommunityReply`        | 댓글의 답글     |
| `PostLike`              | 게시글 좋아요    |
| `PostBookmark`          | 게시글 북마크    |
| `CommentLike`           | 댓글 좋아요     |
| `ReplyLike`             | 답글 좋아요     |
| `CommunityNotice`       | 공지사항       |
| `CommunityNotification` | 알림         |
| `CommunityReport`       | 신고 기록      |
| `RecipeReview`          | 레시피 후기     |
| `ReviewLike`            | 레시피 후기 좋아요 |

---

# 12. 권한 처리

커뮤니티는 로그인 사용자 기준으로 권한을 처리합니다.

게시글, 댓글, 답글에는 작성자 ID가 저장됩니다.

```text
owner_user_id
```

수정 및 삭제는 작성자 본인만 가능합니다.

```text
내 게시글 → 수정/삭제 가능
다른 사람 게시글 → 신고 가능
내 댓글 → 수정/삭제 가능
다른 사람 댓글 → 신고 가능
내 답글 → 수정/삭제 가능
다른 사람 답글 → 신고 가능
```

---

# 13. 신고 처리 방식

신고는 `CommunityReport` 테이블에 저장됩니다.

같은 사용자가 같은 대상을 여러 번 신고해도 1회만 반영됩니다.

신고 대상은 다음과 같습니다.

```text
post
comment
reply
```

신고 API는 신고 수만 증가시키며, 자동 삭제나 자동 차단은 하지 않습니다.

---

# 14. 인기글 처리 방식

인기글은 전체 누적 좋아요 기준이 아니라 최근 활동량 기준으로 계산합니다.

기준이 되는 값:

```text
최근 좋아요 증가 수
최근 댓글 증가 수
```

점수 계산:

```text
좋아요 증가 수 + 댓글 증가 수 * 2
```

이 방식은 오래된 게시글이 과거 누적 좋아요 때문에 계속 인기글에 남는 문제를 줄이기 위한 구조입니다.

---

# 15. 현재 한계 및 개선 예정

현재 구현에서 개선할 수 있는 부분은 다음과 같습니다.

* 레시피 후기 API 경로를 `/community/reviews`에서 `/recipes/{recipe_id}/reviews`로 분리
* 후기 수정 기능 추가
* 후기 삭제 기능 추가
* 후기 신고 기능 추가
* 레시피별 평균 별점 API 추가
* 레시피별 후기 개수 API 추가
* 내 게시글만 보기 기능 추가
* 내가 북마크한 게시글만 보기 기능 추가
* 관리자용 신고 목록 조회 기능 추가
* 관리자용 공지 작성/수정/삭제 기능 추가

````

추가로 README에 아주 짧게 넣으려면 이 버전만 쓰셔도 됩니다.

```md
## Community

커뮤니티는 멀티쿠커 사용자들이 조리 팁, 질문, 사용 경험을 공유하는 게시판 기능입니다.

지원 기능:

- 자유 게시판
- Q&A 게시판
- 게시글 작성/수정/삭제
- 댓글/답글 작성
- 좋아요/북마크
- 신고
- 공지사항
- 알림
- 인기글
- 레시피 상세 후기

커뮤니티 API는 로그인 후 발급받은 로컬 API 토큰을 사용합니다.

```http
Authorization: Bearer <local_access_token>
````

주요 API:

| Method | Endpoint                                          | 설명           |
| ------ | ------------------------------------------------- | ------------ |
| GET    | `/community/posts`                                | 게시글 목록 조회    |
| GET    | `/community/posts/popular`                        | 인기글 조회       |
| GET    | `/community/posts/{post_id}`                      | 게시글 상세 조회    |
| POST   | `/community/posts`                                | 게시글 작성       |
| PATCH  | `/community/posts/{post_id}`                      | 게시글 수정       |
| DELETE | `/community/posts/{post_id}`                      | 게시글 삭제       |
| POST   | `/community/posts/{post_id}/like`                 | 게시글 좋아요      |
| DELETE | `/community/posts/{post_id}/like`                 | 게시글 좋아요 취소   |
| POST   | `/community/posts/{post_id}/bookmark`             | 게시글 북마크      |
| DELETE | `/community/posts/{post_id}/bookmark`             | 게시글 북마크 취소   |
| POST   | `/community/posts/{post_id}/report`               | 게시글 신고       |
| POST   | `/community/posts/{post_id}/comments`             | 댓글 작성        |
| PATCH  | `/community/comments/{comment_id}`                | 댓글 수정        |
| DELETE | `/community/comments/{comment_id}`                | 댓글 삭제        |
| POST   | `/community/comments/{comment_id}/like`           | 댓글 좋아요       |
| DELETE | `/community/comments/{comment_id}/like`           | 댓글 좋아요 취소    |
| POST   | `/community/comments/{comment_id}/report`         | 댓글 신고        |
| POST   | `/community/comments/{comment_id}/replies`        | 답글 작성        |
| PATCH  | `/community/replies/{reply_id}`                   | 답글 수정        |
| DELETE | `/community/replies/{reply_id}`                   | 답글 삭제        |
| POST   | `/community/replies/{reply_id}/like`              | 답글 좋아요       |
| DELETE | `/community/replies/{reply_id}/like`              | 답글 좋아요 취소    |
| POST   | `/community/replies/{reply_id}/report`            | 답글 신고        |
| GET    | `/community/notices`                              | 공지 목록 조회     |
| GET    | `/community/notices/pinned`                       | 고정 공지 조회     |
| GET    | `/community/notices/{notice_id}`                  | 공지 상세 조회     |
| GET    | `/community/notifications`                        | 내 알림 조회      |
| PATCH  | `/community/notifications/read_all`               | 전체 알림 읽음 처리  |
| PATCH  | `/community/notifications/{notification_id}/read` | 특정 알림 읽음 처리  |
| POST   | `/community/reviews`                              | 레시피 후기 작성    |
| GET    | `/community/reviews`                              | 레시피 후기 목록 조회 |
| POST   | `/community/reviews/{review_id}/like`             | 후기 좋아요       |
| DELETE | `/community/reviews/{review_id}/like`             | 후기 좋아요 취소    |

```
```
