from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import secrets
import sqlite3
import time
from collections import deque
from datetime import datetime, timedelta, timezone
from html import escape
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Request, UploadFile, File
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse
from dotenv import load_dotenv
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import or_
from sqlmodel import Field, SQLModel, Session, create_engine, select

app = FastAPI(title="MultiCooker Local Community API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def no_cache_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    return response

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(Path(BASE_DIR) / ".env")
UPLOAD_DIR = os.path.join(BASE_DIR, "local_uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# -----------------------------------------------------------------------------
# API access log for collaboration
# -----------------------------------------------------------------------------
LOG_DIR = Path(BASE_DIR) / "logs"
LOG_DIR.mkdir(exist_ok=True)
API_LOG_PATH = LOG_DIR / "api.log"

api_logger = logging.getLogger("multicooker-api-access")
api_logger.setLevel(logging.INFO)
api_logger.propagate = False

if not api_logger.handlers:
    _formatter = logging.Formatter("%(asctime)s | %(levelname)s | %(message)s")

    _file_handler = RotatingFileHandler(
        API_LOG_PATH,
        maxBytes=2 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8",
    )
    _file_handler.setFormatter(_formatter)

    _console_handler = logging.StreamHandler()
    _console_handler.setFormatter(_formatter)

    api_logger.addHandler(_file_handler)
    api_logger.addHandler(_console_handler)


def _tail_log_lines(lines: int = 200) -> list[str]:
    lines = max(1, min(lines, 1000))
    if not API_LOG_PATH.exists():
        return []
    with API_LOG_PATH.open("r", encoding="utf-8", errors="replace") as f:
        # 최근 N개 로그만 가져온 뒤 뒤집어서 최신 로그가 가장 위에 오도록 반환합니다.
        return [line.rstrip("\n") for line in deque(f, maxlen=lines)][::-1]


def _admin_log_allowed(request: Request) -> bool:
    """
    ADMIN_LOG_KEY가 설정되어 있으면 key 쿼리 또는 x-admin-key 헤더가 맞아야 로그 화면을 보여줍니다.
    설정하지 않으면 같은 와이파이 개발 테스트용으로 바로 열립니다.
    """
    admin_key = os.getenv("ADMIN_LOG_KEY", "").strip()
    if not admin_key:
        return True
    supplied_key = request.query_params.get("key") or request.headers.get("x-admin-key") or ""
    return supplied_key == admin_key


@app.middleware("http")
async def api_access_logger(request: Request, call_next):
    start_time = time.time()
    client_ip = request.client.host if request.client else "unknown"
    method = request.method
    path = request.url.path
    query = request.url.query
    display_path = f"{path}?{query}" if query else path

    # 로그 화면 자체가 3초마다 새로고침되므로 로그가 도배되지 않도록 제외합니다.
    skip_log = path.startswith("/admin/log-viewer") or path.startswith("/admin/api-logs")

    try:
        response = await call_next(request)
        duration_ms = (time.time() - start_time) * 1000
        if not skip_log:
            api_logger.info(
                f'{client_ip} | {method} {display_path} -> {response.status_code} ({duration_ms:.1f}ms)'
            )
        return response
    except Exception as exc:
        duration_ms = (time.time() - start_time) * 1000
        if not skip_log:
            api_logger.exception(
                f'{client_ip} | {method} {display_path} -> 500 ERROR ({duration_ms:.1f}ms) | {exc}'
            )
        raise


@app.get("/admin/api-logs")
def get_api_logs(request: Request, lines: int = 200):
    if not _admin_log_allowed(request):
        raise HTTPException(status_code=403, detail="관리자 로그 키가 올바르지 않습니다.")
    return {"logs": _tail_log_lines(lines)}


@app.get("/admin/log-viewer", response_class=HTMLResponse)
def log_viewer(request: Request, lines: int = 200):
    if not _admin_log_allowed(request):
        return HTMLResponse(
            """
            <!doctype html>
            <html lang=\"ko\">
            <head><meta charset=\"utf-8\"><title>API Log Viewer</title></head>
            <body style=\"font-family: sans-serif; padding: 24px;\">
              <h2>관리자 로그 키가 필요합니다.</h2>
              <p>주소 뒤에 <code>?key=관리자키</code>를 붙이거나 <code>x-admin-key</code> 헤더를 사용하세요.</p>
            </body>
            </html>
            """,
            status_code=403,
        )

    log_lines = _tail_log_lines(lines)
    keyword = (request.query_params.get("q") or "").strip()
    if keyword:
        lowered = keyword.lower()
        log_lines = [line for line in log_lines if lowered in line.lower()]

    def _status_class(line: str) -> str:
        if " -> 2" in line or " -> 3" in line:
            return "ok"
        if " -> 4" in line:
            return "warn"
        if " -> 5" in line or "ERROR" in line:
            return "error"
        return "normal"

    rows = "\n".join(
        f'<div class="log-line {_status_class(line)}">{escape(line)}</div>'
        for line in log_lines
    ) or '<div class="empty">아직 표시할 API 로그가 없습니다.</div>'

    safe_keyword = escape(keyword, quote=True)
    safe_lines = max(1, min(lines, 1000))

    return f"""
    <!doctype html>
    <html lang="ko">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta http-equiv="refresh" content="3">
      <title>MultiCooker API Log Viewer</title>
      <style>
        * {{ box-sizing: border-box; }}
        body {{
          margin: 0;
          background: #111827;
          color: #F9FAFB;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }}
        .wrap {{
          max-width: 1180px;
          margin: 0 auto;
          padding: 24px;
        }}
        .top {{
          display: flex;
          align-items: flex-end;
          justify-content: space-between;
          gap: 16px;
          margin-bottom: 16px;
        }}
        h1 {{
          margin: 0 0 6px;
          font-size: 24px;
          letter-spacing: -0.02em;
        }}
        .sub {{
          color: #9CA3AF;
          font-size: 13px;
        }}
        .toolbar {{
          display: flex;
          gap: 8px;
          flex-wrap: wrap;
          justify-content: flex-end;
        }}
        input {{
          height: 36px;
          padding: 0 12px;
          border-radius: 10px;
          border: 1px solid #374151;
          background: #1F2937;
          color: #F9FAFB;
          outline: none;
        }}
        button, a.btn {{
          height: 36px;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 0 12px;
          border: 0;
          border-radius: 10px;
          background: #F97316;
          color: white;
          text-decoration: none;
          font-weight: 700;
          cursor: pointer;
        }}
        .panel {{
          background: #1F2937;
          border: 1px solid #374151;
          border-radius: 16px;
          overflow: hidden;
          box-shadow: 0 18px 45px rgba(0,0,0,.25);
        }}
        .legend {{
          display: flex;
          gap: 12px;
          flex-wrap: wrap;
          padding: 12px 16px;
          border-bottom: 1px solid #374151;
          color: #D1D5DB;
          font-size: 12px;
        }}
        .dot {{
          width: 8px;
          height: 8px;
          display: inline-block;
          border-radius: 999px;
          margin-right: 5px;
        }}
        .ok-dot {{ background: #22C55E; }}
        .warn-dot {{ background: #FACC15; }}
        .error-dot {{ background: #EF4444; }}
        .logs {{
          padding: 12px 0;
          max-height: calc(100vh - 180px);
          overflow: auto;
          font-family: Consolas, "SFMono-Regular", Menlo, monospace;
          font-size: 13px;
          line-height: 1.55;
        }}
        .log-line {{
          white-space: pre-wrap;
          padding: 4px 16px;
          border-left: 4px solid transparent;
        }}
        .log-line.ok {{ border-left-color: #22C55E; color: #DCFCE7; }}
        .log-line.warn {{ border-left-color: #FACC15; color: #FEF9C3; }}
        .log-line.error {{ border-left-color: #EF4444; color: #FEE2E2; }}
        .log-line.normal {{ color: #E5E7EB; }}
        .empty {{ padding: 24px 16px; color: #9CA3AF; }}
        @media (max-width: 720px) {{
          .top {{ align-items: stretch; flex-direction: column; }}
          .toolbar {{ justify-content: flex-start; }}
          input {{ width: 100%; }}
        }}
      </style>
    </head>
    <body>
      <div class="wrap">
        <div class="top">
          <div>
            <h1>MultiCooker API Log Viewer <span class="latest-badge">최신순</span></h1>
            <div class="sub">최근 {safe_lines}줄 · 최신순 · 3초마다 자동 새로고침 · logs/api.log 기준</div>
          </div>
          <form class="toolbar" method="get" action="/admin/log-viewer">
            <input name="q" placeholder="예: reviews, 200, 401" value="{safe_keyword}">
            <input name="lines" type="number" min="1" max="1000" value="{safe_lines}" style="width: 92px;">
            <button type="submit">검색</button>
            <a class="btn" href="/admin/log-viewer?lines={safe_lines}">전체</a>
          </form>
        </div>
        <div class="panel">
          <div class="legend">
            <span><i class="dot ok-dot"></i>2xx/3xx 성공</span>
            <span><i class="dot warn-dot"></i>4xx 요청/권한 문제</span>
            <span><i class="dot error-dot"></i>5xx 서버 오류</span>
          </div>
          <div class="logs">{rows}</div>
        </div>
      </div>
    </body>
    </html>
    """

DATABASE_URL = f"sqlite:///{os.path.join(BASE_DIR, 'multicooker.db')}"
engine = create_engine(DATABASE_URL, echo=False, connect_args={"check_same_thread": False})
DEFAULT_USER = "나"
DEFAULT_AVATAR = 0xFFFF8C42

# -----------------------------------------------------------------------------
# DB models
# -----------------------------------------------------------------------------
class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(index=True)
    password_hash: str
    nickname: str = DEFAULT_USER
    mobile: str = ""
    sex: str = "MALE"
    age: int = 0
    marketing_opt_in: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)

class EmailCode(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(index=True)
    code: str
    purpose: str
    verified: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)

class SessionToken(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int
    access_token: str = Field(index=True)
    refresh_token: str = Field(index=True)
    revoked: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)

class CommunityPost(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    owner_user_id: Optional[int] = Field(default=None, index=True)
    category: str = "자유"
    username: str = DEFAULT_USER
    avatar_color: int = DEFAULT_AVATAR
    time_ago: str = "방금 전"
    title: str
    content: str
    image_url: Optional[str] = None
    tags: str = ""
    likes: int = 0
    # Legacy SQLite compatibility only. Bookmark endpoints and response fields are removed,
    # but older DB files may still have a NOT NULL bookmarks column.
    bookmarks: int = 0
    reports: int = 0
    deleted: bool = False
    activity_d3_likes: int = 0
    activity_d3_comments: int = 0
    activity_d6_likes: int = 0
    activity_d6_comments: int = 0
    activity_d9_likes: int = 0
    activity_d9_comments: int = 0
    activity_d12_likes: int = 0
    activity_d12_comments: int = 0
    # 관리자 테스트/운영용 보정값입니다. 실제 최근 활동량과 별도로 더해집니다.
    admin_popularity_boost: int = 0
    force_popular: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class CommunityComment(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    post_id: int = Field(index=True)
    owner_user_id: Optional[int] = Field(default=None, index=True)
    username: str = DEFAULT_USER
    avatar_color: int = DEFAULT_AVATAR
    content: str
    time_ago: str = "방금 전"
    likes: int = 0
    reports: int = 0
    deleted: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class CommunityReply(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    comment_id: int = Field(index=True)
    owner_user_id: Optional[int] = Field(default=None, index=True)
    username: str = DEFAULT_USER
    avatar_color: int = DEFAULT_AVATAR
    content: str
    time_ago: str = "방금 전"
    likes: int = 0
    reports: int = 0
    deleted: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class PostLike(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    post_id: int = Field(index=True)
    username: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)

class CommentLike(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    comment_id: int = Field(index=True)
    username: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)

class ReplyLike(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    reply_id: int = Field(index=True)
    username: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)

class CommunityNotice(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    owner_user_id: Optional[int] = Field(default=None, index=True)
    title: str
    date: str
    summary: str
    content: str
    important: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class CommunityNotification(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    target_user_id: Optional[int] = Field(default=None, index=True)
    type: str = "comment"
    from_user: str
    avatar_color: int
    # post_title은 기존 DB 호환 및 게시글 이동에 사용합니다.
    post_title: str
    post_id: int
    # 알림 두 번째 줄에 표시할 실제로 새로 작성된 내용의 스냅샷입니다.
    # 댓글 알림: 새 댓글 내용
    # 답글 알림: 새 답글 내용
    context_text: str = ""
    target_comment_id: Optional[int] = Field(default=None, index=True)
    target_reply_id: Optional[int] = Field(default=None, index=True)
    time_ago: str = "방금 전"
    read: bool = False
    username: str = DEFAULT_USER
    created_at: datetime = Field(default_factory=datetime.utcnow)

class CommunityReport(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    target_type: str = Field(index=True)
    target_id: int = Field(index=True)
    reporter_user_id: Optional[int] = Field(default=None, index=True)
    reporter_key: str = Field(default="", index=True)
    reason: str = "부적절한 내용"
    status: str = Field(default="pending", index=True)
    admin_note: str = ""
    processed_by_user_id: Optional[int] = Field(default=None, index=True)
    processed_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

class CommunityBlock(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    blocker_user_id: int = Field(index=True)
    blocked_user_id: Optional[int] = Field(default=None, index=True)
    blocked_username: str = Field(default="", index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)

class RecipeReview(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    owner_user_id: Optional[int] = Field(default=None, index=True)
    username: str
    avatar_color: int
    recipe_title: str
    recipe_image: str
    rating: int
    content: str
    date: str
    likes: int = 0
    comment_count: int = 0
    recipe_id: str = "1"
    deleted: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class ReviewLike(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    review_id: int = Field(index=True)
    username: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)

class RecipeComment(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    recipe_id: str = Field(index=True)
    recipe_title: str = ""
    owner_user_id: Optional[int] = Field(default=None, index=True)
    username: str = DEFAULT_USER
    avatar_color: int = DEFAULT_AVATAR
    content: str
    deleted: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class RegisteredDevice(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    mac_address: str = Field(index=True)
    device_name: str = "Graphene Multi-Cooker"
    serial_number: str = "LOCAL-COOKER-001"
    alias: str = ""
    firmware_version: str = ""
    auto_reconnect: bool = True
    verified: bool = True
    last_connected_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class SavedRecipe(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    # 기존 로컬 레시피는 recipe_id를 사용하고, 회사/앱 레시피는 client_id와
    # 아래 스냅샷 필드로 저장합니다. 기존 SQLite의 NOT NULL 제약과 호환되도록
    # recipe_id 기본값은 0으로 유지합니다.
    recipe_id: int = Field(default=0, index=True)
    client_id: str = Field(default="", index=True)
    title: str = ""
    description: str = ""
    thumbnail_url: Optional[str] = None
    author: str = "Graphene Square"
    is_official: bool = False
    is_personal: bool = False
    total_time_min: int = 10
    max_temperature: int = 180
    steps_json: str = "[]"
    created_at: datetime = Field(default_factory=datetime.utcnow)

class CookingHistory(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    recipe_id: Optional[int] = Field(default=None, index=True)
    client_recipe_id: str = Field(default="", index=True)
    recipe_title: str = "직접 조리"
    device_name: str = "Graphene Multi-Cooker"
    status: str = "completed"
    started_at: datetime = Field(default_factory=datetime.utcnow)
    finished_at: Optional[datetime] = None
    total_time_min: int = 0
    max_temperature: int = 0
    steps_json: str = "[]"
    memo: str = ""
    created_at: datetime = Field(default_factory=datetime.utcnow)

class UserSettings(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    cooking_notification: bool = True
    community_notification: bool = True
    marketing_notification: bool = False
    language: str = "ko"
    tutorial_completed: bool = False
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class RecipeRecord(SQLModel, table=True):
    __tablename__ = "recipes"
    id: Optional[int] = Field(default=None, primary_key=True)
    owner_user_id: Optional[int] = Field(default=None, index=True)
    # 앱에서 사용하는 안정적인 레시피 ID입니다. 기본/공용 레시피는
    # rice, egg 같은 값을 사용하고, 개인 레시피는 기존 숫자 PK를 사용합니다.
    client_id: str = Field(default="", index=True)
    title: str = Field(index=True)
    description: Optional[str] = None
    thumbnail_url: Optional[str] = None
    author: str = "Graphene Square"
    is_personal: bool = False
    is_gsq_suggested: bool = False
    is_official: bool = False
    total_time_min: int = 10
    difficulty: str = "쉬움"
    servings: int = 1
    compatibility_type: str = "fullAuto"
    catalog_order: int = 0
    ingredients_json: str = "[]"
    instruction_steps_json: str = "[]"
    cooker_steps_json: str = "[]"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class RecipeStepRecord(SQLModel, table=True):
    __tablename__ = "recipe_steps"
    id: Optional[int] = Field(default=None, primary_key=True)
    recipe_id: int = Field(index=True)
    temperature: float
    time_offset: float
    label: str = "조리"
    sort_order: int = 1

class IngredientImageRecord(SQLModel, table=True):
    __tablename__ = "ingredient_images"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    s3_key: str = Field(index=True)
    image_url: Optional[str] = None
    original_filename: Optional[str] = None
    content_type: Optional[str] = None
    detected_ingredients: str = ""
    created_at: datetime = Field(default_factory=datetime.utcnow)

# -----------------------------------------------------------------------------
# Request models
# -----------------------------------------------------------------------------
class SendEmailRequest(BaseModel):
    email: str = ""

class VerifyCodeRequest(BaseModel):
    email: str = ""
    code: str = ""

class CompleteRegisterRequest(BaseModel):
    email: str = ""
    password: str = ""
    mobile: str = ""
    sex: str = "MALE"
    age: int = 0
    marketing_opt_in: bool = False

class CompleteResetPasswordRequest(BaseModel):
    email: str = ""
    new_password: str = ""

class LoginIn(BaseModel):
    email: str = ""
    password: str = ""

class RefreshRequest(BaseModel):
    refresh_token: str = ""

class LocalAuthSyncRequest(BaseModel):
    email: str = ""
    nickname: Optional[str] = None
    external_user_id: Optional[str] = None

class PostCreate(BaseModel):
    category: str = "자유"
    title: str
    content: str
    image_url: Optional[str] = None
    tags: list[str] = []

class PostPatch(BaseModel):
    category: Optional[str] = None
    title: Optional[str] = None
    content: Optional[str] = None
    image_url: Optional[str] = None
    tags: Optional[list[str]] = None

class ContentIn(BaseModel):
    content: str

class ReportIn(BaseModel):
    reason: str = "부적절한 내용"

class BlockFromContentRequest(BaseModel):
    target_type: str
    target_id: int

class AdminPostLikesRequest(BaseModel):
    like_count: int
    apply_to_popular_test: bool = True

class AdminPostPopularityRequest(BaseModel):
    like_count: Optional[int] = None
    admin_popularity_boost: int = 0
    force_popular: bool = False

class AdminNoticeRequest(BaseModel):
    title: str
    summary: str = ""
    content: str
    important: bool = False

class AdminReportPatchRequest(BaseModel):
    status: str
    admin_note: str = ""
    delete_content: bool = False

class DeviceVerifyRequest(BaseModel):
    mac_address: str = ""

class RecipeStepIn(BaseModel):
    temperature: float
    time_offset: float

class UploadRecipeRequest(BaseModel):
    title: str
    description: Optional[str] = None
    steps: list[RecipeStepIn]

class UploadUrlRequest(BaseModel):
    filename: str
    content_type: str = "image/png"

class UploadCompleteRequest(BaseModel):
    s3_key: str
    image_url: Optional[str] = None
    original_filename: Optional[str] = None
    content_type: Optional[str] = None

class UserPatchRequest(BaseModel):
    nickname: Optional[str] = None

class PasswordPatchRequest(BaseModel):
    current_password: str = ""
    new_password: str = ""

class SettingsPatchRequest(BaseModel):
    cooking_notification: Optional[bool] = None
    community_notification: Optional[bool] = None
    marketing_notification: Optional[bool] = None
    language: Optional[str] = None
    tutorial_completed: Optional[bool] = None

class SaveRecipeRequest(BaseModel):
    recipe_id: int

class SaveClientRecipeRequest(BaseModel):
    client_id: str = ""
    title: str = ""
    description: str = ""
    thumbnail_url: Optional[str] = None
    author: str = "Graphene Square"
    is_official: bool = False
    is_personal: bool = False
    total_time_min: int = 10
    max_temperature: int = 180
    steps: list[dict] = []

class ReviewPatchRequest(BaseModel):
    rating: Optional[int] = None
    content: Optional[str] = None

class DeviceRegisterRequest(BaseModel):
    mac_address: str = ""
    device_name: str = "Graphene Multi-Cooker"
    serial_number: str = "LOCAL-COOKER-001"
    alias: str = ""
    firmware_version: str = ""
    auto_reconnect: bool = True

class DevicePatchRequest(BaseModel):
    alias: Optional[str] = None
    device_name: Optional[str] = None
    firmware_version: Optional[str] = None
    auto_reconnect: Optional[bool] = None

class CookingHistoryCreateRequest(BaseModel):
    recipe_id: Optional[int] = None
    client_recipe_id: str = ""
    recipe_title: str = "직접 조리"
    device_name: str = "Graphene Multi-Cooker"
    status: str = "completed"
    started_at: Optional[datetime] = None
    finished_at: Optional[datetime] = None
    total_time_min: int = 0
    max_temperature: int = 0
    steps: list[dict] = []
    memo: str = ""

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
def get_session():
    with Session(engine) as session:
        yield session

def _hash(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

def _token() -> str:
    return secrets.token_urlsafe(32)

def _display_name_for_email(email: str) -> str:
    raw = (email or "").strip()
    if not raw:
        return DEFAULT_USER
    return raw.split("@", 1)[0] or raw

def _avatar_for_user(user: User | None) -> int:
    palette = [
        0xFFFF8C42, 0xFF4A90D9, 0xFF4CAF50, 0xFFE91E63,
        0xFF2196F3, 0xFF9C27B0, 0xFFFF5722, 0xFF00BCD4,
        0xFF795548, 0xFF607D8B, 0xFF7C3AED, 0xFF16A34A,
    ]
    if user is None or user.id is None:
        return DEFAULT_AVATAR
    return palette[user.id % len(palette)]

def _user_key(user: User | None) -> str:
    if user is None or user.id is None:
        return "guest"
    return f"user:{user.id}"

def _current_user(authorization: Optional[str] = Header(default=None), session: Session = Depends(get_session)) -> User:
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ", 1)[1]
        row = session.exec(select(SessionToken).where(SessionToken.access_token == token).where(SessionToken.revoked == False)).first()
        if row:
            user = session.get(User, row.user_id)
            if user:
                return user
    raise HTTPException(status_code=401, detail="로그인이 필요합니다.")

def _current_username(user: User = Depends(_current_user)) -> str:
    return user.nickname or _display_name_for_email(user.email)


def _admin_email_set() -> set[str]:
    raw = os.getenv("ADMIN_EMAILS", "")
    return {item.strip().lower() for item in raw.split(",") if item.strip()}


def _is_admin(user: User | None) -> bool:
    if user is None:
        return False
    return (user.email or "").strip().lower() in _admin_email_set()


def _require_admin(user: User = Depends(_current_user)) -> User:
    if not _is_admin(user):
        raise HTTPException(status_code=403, detail="관리자 계정만 사용할 수 있습니다.")
    return user


def _blocked_author_sets(session: Session, user: User) -> tuple[set[int], set[str]]:
    rows = session.exec(
        select(CommunityBlock).where(CommunityBlock.blocker_user_id == user.id)
    ).all()
    blocked_ids = {row.blocked_user_id for row in rows if row.blocked_user_id is not None}
    blocked_names = {
        (row.blocked_username or "").strip().lower()
        for row in rows
        if (row.blocked_username or "").strip()
    }
    return blocked_ids, blocked_names


def _author_is_blocked(
    row,
    blocked: tuple[set[int], set[str]],
) -> bool:
    blocked_ids, blocked_names = blocked
    owner_user_id = getattr(row, "owner_user_id", None)
    username = (getattr(row, "username", "") or "").strip().lower()
    return (owner_user_id is not None and owner_user_id in blocked_ids) or (
        bool(username) and username in blocked_names
    )

def _is_owner(row, user: User) -> bool:
    owner_user_id = getattr(row, "owner_user_id", None)
    if owner_user_id is not None:
        return owner_user_id == user.id
    # 기존 로컬 DB에 owner_user_id가 없는 데이터가 남아 있는 경우에만 표시명 기준으로 보정합니다.
    return getattr(row, "username", None) == (user.nickname or _display_name_for_email(user.email))

def _first_or_404(session: Session, model, row_id: int, message: str):
    row = session.get(model, row_id)
    if row is None or getattr(row, "deleted", False):
        raise HTTPException(status_code=404, detail=message)
    return row

def _tags_list(tags: str | None) -> list[str]:
    if not tags:
        return []
    return [item.strip() for item in tags.split(",") if item.strip()]

def _activity_window(session: Session, post: CommunityPost, days: int) -> dict:
    """Count actual likes/comments/replies created inside a rolling time window."""
    cutoff = datetime.utcnow() - timedelta(days=days)
    likes = len(
        session.exec(
            select(PostLike)
            .where(PostLike.post_id == post.id)
            .where(PostLike.created_at >= cutoff)
        ).all()
    )
    comments = session.exec(
        select(CommunityComment)
        .where(CommunityComment.post_id == post.id)
        .where(CommunityComment.deleted == False)
        .where(CommunityComment.created_at >= cutoff)
    ).all()
    all_comments = session.exec(
        select(CommunityComment)
        .where(CommunityComment.post_id == post.id)
        .where(CommunityComment.deleted == False)
    ).all()
    comment_ids = {row.id for row in all_comments if row.id is not None}
    replies = 0
    if comment_ids:
        replies = len(
            [
                row
                for row in session.exec(
                    select(CommunityReply)
                    .where(CommunityReply.deleted == False)
                    .where(CommunityReply.created_at >= cutoff)
                ).all()
                if row.comment_id in comment_ids
            ]
        )
    return {"likes": likes, "comments": len(comments) + replies}


def _activity(session: Session, post: CommunityPost) -> dict:
    return {f"d{days}": _activity_window(session, post, days) for days in (3, 6, 9, 12)}


def _popularity_threshold() -> int:
    try:
        return max(1, int(os.getenv("POPULAR_SCORE_THRESHOLD", "3")))
    except ValueError:
        return 3


def _popularity_score(session: Session, post: CommunityPost, days: int = 3) -> int:
    window = _activity_window(session, post, days)
    return window["likes"] + window["comments"] * 2 + max(0, post.admin_popularity_boost)


def _is_popular(session: Session, post: CommunityPost, days: int = 3) -> bool:
    return bool(post.force_popular or _popularity_score(session, post, days) >= _popularity_threshold())

def _safe_filename(filename: str) -> str:
    name = Path(filename).name or "ingredient.png"
    name = re.sub(r"[^0-9A-Za-z가-힣._-]+", "_", name)
    return name[:120]

def _local_file_path(s3_key: str) -> str:
    safe_parts = [_safe_filename(part) for part in s3_key.split("/") if part]
    path = os.path.join(UPLOAD_DIR, *safe_parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path

def _recipe_steps(session: Session, recipe_id: int) -> list[RecipeStepRecord]:
    rows = session.exec(select(RecipeStepRecord).where(RecipeStepRecord.recipe_id == recipe_id)).all()
    return sorted(rows, key=lambda s: (s.sort_order, s.id or 0))

def _json_list(value: Optional[str]) -> list:
    try:
        parsed = json.loads(value or "[]")
    except Exception:
        return []
    return parsed if isinstance(parsed, list) else []


def _recipe_public_id(recipe: RecipeRecord) -> str:
    if not recipe.is_personal and (recipe.client_id or "").strip():
        return recipe.client_id.strip()
    return str(recipe.id)


def _derived_cooker_steps(session: Session, recipe: RecipeRecord) -> list[dict]:
    rich_steps = _json_list(recipe.cooker_steps_json)
    if rich_steps:
        return rich_steps

    rows = _recipe_steps(session, recipe.id or 0)
    result: list[dict] = []
    previous_offset = 0.0
    public_id = _recipe_public_id(recipe)
    for index, step in enumerate(rows, start=1):
        offset = max(0.0, float(step.time_offset or 0))
        duration_seconds = offset - previous_offset
        if duration_seconds <= 0:
            duration_seconds = 300
        previous_offset = max(previous_offset, offset)
        result.append({
            "id": f"{public_id}-c{index}",
            "step_no": index,
            "label": step.label or f"{index}단계 조리",
            "temperature": int(round(float(step.temperature or 0))),
            "time_min": max(1, int((duration_seconds + 59) // 60)),
            "requires_user_confirmation_before_start": False,
        })
    return result


def _recipe_payload(session: Session, recipe: RecipeRecord, include_similarity: bool = False, similarity: float = 0.88) -> dict:
    cooker_steps = _derived_cooker_steps(session, recipe)
    total_time = int(recipe.total_time_min or 0)
    if total_time <= 0:
        total_time = sum(max(0, int(step.get("time_min") or 0)) for step in cooker_steps)
    payload = {
        "id": _recipe_public_id(recipe),
        "db_id": recipe.id,
        "client_id": (recipe.client_id or "").strip() or str(recipe.id),
        "title": recipe.title,
        "description": recipe.description or "",
        "thumbnail_url": recipe.thumbnail_url,
        "author": recipe.author,
        "is_personal": recipe.is_personal,
        "is_gsq_suggested": recipe.is_gsq_suggested,
        "is_official": recipe.is_official,
        "total_time_min": max(1, total_time or 10),
        "difficulty": recipe.difficulty or "쉬움",
        "servings": max(1, int(recipe.servings or 1)),
        "compatibility_type": recipe.compatibility_type or "fullAuto",
        "ingredients": _json_list(recipe.ingredients_json),
        "instruction_steps": _json_list(recipe.instruction_steps_json),
        "cooker_steps": cooker_steps,
        "steps": [
            {"temperature": step.temperature, "time_offset": step.time_offset, "label": step.label}
            for step in _recipe_steps(session, recipe.id or 0)
        ],
    }
    if include_similarity:
        payload["similarity"] = similarity
    return payload

def _liked_post(session: Session, post_id: int, username: str) -> bool:
    return session.exec(select(PostLike).where(PostLike.post_id == post_id).where(PostLike.username == username)).first() is not None

def _liked_comment(session: Session, comment_id: int, username: str) -> bool:
    return session.exec(select(CommentLike).where(CommentLike.comment_id == comment_id).where(CommentLike.username == username)).first() is not None

def _liked_reply(session: Session, reply_id: int, username: str) -> bool:
    return session.exec(select(ReplyLike).where(ReplyLike.reply_id == reply_id).where(ReplyLike.username == username)).first() is not None

def _utc_iso(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')


def _reply_payload(
    session: Session,
    reply: CommunityReply,
    user: User,
    blocked: tuple[set[int], set[str]] | None = None,
) -> dict:
    viewer_key = _user_key(user)
    return {
        "id": reply.id,
        "author_user_id": reply.owner_user_id,
        "username": reply.username,
        "avatar_color": reply.avatar_color,
        "content": reply.content,
        "time_ago": reply.time_ago,
        "created_at": _utc_iso(reply.created_at),
        "likes": reply.likes,
        "report_count": reply.reports if _is_admin(user) else None,
        "is_liked": _liked_reply(session, reply.id, viewer_key),
        "is_mine": _is_owner(reply, user),
    }


def _comment_payload(
    session: Session,
    comment: CommunityComment,
    user: User,
    blocked: tuple[set[int], set[str]] | None = None,
) -> dict:
    viewer_key = _user_key(user)
    blocked = blocked or _blocked_author_sets(session, user)
    replies = session.exec(
        select(CommunityReply)
        .where(CommunityReply.comment_id == comment.id)
        .where(CommunityReply.deleted == False)
    ).all()
    replies = sorted(
        [reply for reply in replies if not _author_is_blocked(reply, blocked)],
        key=lambda r: r.id or 0,
    )
    return {
        "id": comment.id,
        "author_user_id": comment.owner_user_id,
        "username": comment.username,
        "avatar_color": comment.avatar_color,
        "content": comment.content,
        "time_ago": comment.time_ago,
        "created_at": _utc_iso(comment.created_at),
        "likes": comment.likes,
        "report_count": comment.reports if _is_admin(user) else None,
        "is_liked": _liked_comment(session, comment.id, viewer_key),
        "is_mine": _is_owner(comment, user),
        "replies": [_reply_payload(session, r, user, blocked) for r in replies],
    }


def _post_payload(
    session: Session,
    post: CommunityPost,
    user: User,
    blocked: tuple[set[int], set[str]] | None = None,
) -> dict:
    viewer_key = _user_key(user)
    blocked = blocked or _blocked_author_sets(session, user)
    comments = session.exec(
        select(CommunityComment)
        .where(CommunityComment.post_id == post.id)
        .where(CommunityComment.deleted == False)
    ).all()
    comments = sorted(
        [comment for comment in comments if not _author_is_blocked(comment, blocked)],
        key=lambda c: c.id or 0,
    )
    return {
        "id": post.id,
        "author_user_id": post.owner_user_id,
        "category": post.category,
        "username": post.username,
        "avatar_color": post.avatar_color,
        "time_ago": post.time_ago,
        "created_at": _utc_iso(post.created_at),
        "title": post.title,
        "content": post.content,
        "likes": post.likes,
        "report_count": post.reports if _is_admin(user) else None,
        "can_administer": _is_admin(user),
        "comments": [_comment_payload(session, c, user, blocked) for c in comments],
        "image_url": post.image_url,
        "tags": _tags_list(post.tags),
        "activity": _activity(session, post),
        "popularity_score": _popularity_score(session, post, 3),
        "admin_popularity_boost": post.admin_popularity_boost if _is_admin(user) else 0,
        "force_popular": post.force_popular if _is_admin(user) else False,
        "is_popular": _is_popular(session, post, 3),
        "is_liked": _liked_post(session, post.id, viewer_key),
        "is_mine": _is_owner(post, user),
    }

def _review_payload(session: Session, review: RecipeReview, user: User) -> dict:
    viewer_key = _user_key(user)
    liked = session.exec(select(ReviewLike).where(ReviewLike.review_id == review.id).where(ReviewLike.username == viewer_key)).first() is not None
    return {
        "id": review.id,
        "author_user_id": review.owner_user_id,
        "username": review.username,
        "avatar_color": review.avatar_color,
        "recipe_title": review.recipe_title,
        "recipe_image": review.recipe_image,
        "rating": review.rating,
        "content": review.content,
        "date": review.date,
        "created_at": _utc_iso(review.created_at),
        "likes": review.likes,
        "comment_count": review.comment_count,
        "recipe_id": review.recipe_id,
        "is_liked": liked,
        "is_mine": _is_owner(review, user),
    }


def _recipe_comment_payload(comment: RecipeComment, user: User) -> dict:
    return {
        "id": comment.id,
        "recipe_id": comment.recipe_id,
        "recipe_title": comment.recipe_title,
        "author_user_id": comment.owner_user_id,
        "username": comment.username,
        "avatar_color": comment.avatar_color,
        "content": comment.content,
        "created_at": _utc_iso(comment.created_at),
        "is_mine": _is_owner(comment, user),
    }

def _sort_posts(session: Session, posts: list[CommunityPost], sort: str) -> list[CommunityPost]:
    if sort == "popular":
        return sorted(
            posts,
            key=lambda p: (1 if p.force_popular else 0, _popularity_score(session, p, 3), p.likes, p.id or 0),
            reverse=True,
        )
    if sort == "likes":
        return sorted(posts, key=lambda p: (p.likes, p.id or 0), reverse=True)
    if sort == "oldest":
        return sorted(posts, key=lambda p: p.id or 0)
    return sorted(posts, key=lambda p: (p.created_at, p.id or 0), reverse=True)

def _inc_activity_comment(post: CommunityPost) -> None:
    post.activity_d3_comments += 1
    post.activity_d6_comments += 1
    post.activity_d9_comments += 1
    post.activity_d12_comments += 1
    post.updated_at = datetime.utcnow()

def _inc_activity_like(post: CommunityPost, delta: int) -> None:
    post.activity_d3_likes = max(0, post.activity_d3_likes + delta)
    post.activity_d6_likes = max(0, post.activity_d6_likes + delta)
    post.activity_d9_likes = max(0, post.activity_d9_likes + delta)
    post.activity_d12_likes = max(0, post.activity_d12_likes + delta)
    post.updated_at = datetime.utcnow()

def _add_notification(
    session: Session,
    *,
    target_user_id: Optional[int] = None,
    target_username: str = "",
    notification_type: str,
    from_user: User,
    post_title: str,
    post_id: int,
    context_text: str = "",
    target_comment_id: Optional[int] = None,
    target_reply_id: Optional[int] = None,
) -> None:
    """Create an in-app community notification for another user."""
    from_name = from_user.nickname or _display_name_for_email(from_user.email)
    if target_user_id is not None and target_user_id == from_user.id:
        return
    if target_user_id is None and target_username == from_name:
        return
    session.add(
        CommunityNotification(
            target_user_id=target_user_id,
            type=notification_type,
            from_user=from_name,
            avatar_color=_avatar_for_user(from_user),
            post_title=post_title,
            post_id=post_id,
            context_text=context_text,
            target_comment_id=target_comment_id,
            target_reply_id=target_reply_id,
            time_ago="방금 전",
            read=False,
            username=target_username,
        )
    )

def _record_report(session: Session, *, target_type: str, target_id: int, user: User, reason: str) -> bool:
    """Return True only when this user reports the target for the first time."""
    reporter_key = _user_key(user)
    exists = session.exec(
        select(CommunityReport)
        .where(CommunityReport.target_type == target_type)
        .where(CommunityReport.target_id == target_id)
        .where(CommunityReport.reporter_key == reporter_key)
    ).first()
    if exists:
        return False
    session.add(
        CommunityReport(
            target_type=target_type,
            target_id=target_id,
            reporter_user_id=user.id,
            reporter_key=reporter_key,
            reason=reason or "부적절한 내용",
        )
    )
    return True


def _community_target_row(session: Session, target_type: str, target_id: int):
    model = {
        "post": CommunityPost,
        "comment": CommunityComment,
        "reply": CommunityReply,
    }.get((target_type or "").strip().lower())
    if model is None:
        raise HTTPException(status_code=400, detail="지원하지 않는 차단 대상입니다.")
    return _first_or_404(session, model, target_id, "차단 대상을 찾을 수 없습니다.")


def _block_payload(row: CommunityBlock) -> dict:
    return {
        "id": row.id,
        "blocked_user_id": row.blocked_user_id,
        "blocked_username": row.blocked_username,
        "created_at": _utc_iso(row.created_at),
    }



def _settings_for_user(session: Session, user: User) -> UserSettings:
    row = session.exec(select(UserSettings).where(UserSettings.user_id == user.id)).first()
    if row is None:
        row = UserSettings(user_id=user.id)
        session.add(row)
        session.commit()
        session.refresh(row)
    return row

def _settings_payload(row: UserSettings) -> dict:
    return {
        "cooking_notification": row.cooking_notification,
        "community_notification": row.community_notification,
        "marketing_notification": row.marketing_notification,
        "language": row.language,
        "tutorial_completed": row.tutorial_completed,
    }

def _registered_device_payload(row: RegisteredDevice) -> dict:
    return {
        "id": row.id,
        "mac_address": row.mac_address,
        "device_name": row.device_name,
        "serial_number": row.serial_number,
        "alias": row.alias,
        "display_name": row.alias or row.device_name,
        "firmware_version": row.firmware_version,
        "auto_reconnect": row.auto_reconnect,
        "verified": row.verified,
        "last_connected_at": row.last_connected_at.isoformat() if row.last_connected_at else None,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }

def _recipe_card_payload(session: Session, recipe: RecipeRecord, saved_at: Optional[datetime] = None) -> dict:
    payload = _recipe_payload(session, recipe)
    cooker_steps = payload.get("cooker_steps") or []
    max_temp = max(
        [int(step.get("temperature") or 0) for step in cooker_steps if isinstance(step, dict)] or [180]
    )
    payload.update({
        "max_temperature": max_temp,
        "saved_at": saved_at.isoformat() if saved_at else None,
        "created_at": recipe.created_at.isoformat() if recipe.created_at else None,
    })
    return payload


def _recipe_for_client_id(session: Session, client_id: str) -> Optional[RecipeRecord]:
    value = (client_id or "").strip()
    if not value:
        return None

    by_client_id = session.exec(
        select(RecipeRecord).where(RecipeRecord.client_id == value)
    ).first()
    if by_client_id is not None:
        return by_client_id

    lowered = value.lower()
    if lowered.startswith("r") and lowered[1:].isdigit():
        index = int(lowered[1:]) - 1
        if 0 <= index < len(APP_RECIPE_CATALOG):
            stable_id = APP_RECIPE_CATALOG[index]["client_id"]
            return session.exec(
                select(RecipeRecord).where(RecipeRecord.client_id == stable_id)
            ).first()
    if value.isdigit():
        return session.get(RecipeRecord, int(value))
    return session.exec(select(RecipeRecord).where(RecipeRecord.title == value)).first()


def _saved_recipe_payload(session: Session, saved: SavedRecipe) -> Optional[dict]:
    """Return a stable recipe card even when the recipe lives on the company server."""
    recipe = session.get(RecipeRecord, saved.recipe_id) if saved.recipe_id else None
    if recipe is not None and not saved.title:
        payload = _recipe_card_payload(session, recipe, saved.created_at)
        payload["client_id"] = saved.client_id or payload["id"]
        return payload

    client_id = (saved.client_id or "").strip()
    title = (saved.title or "").strip()
    if not client_id and recipe is not None:
        client_id = str(recipe.id)
    if not title and recipe is not None:
        title = recipe.title
    if not client_id or not title:
        return None
    try:
        steps = json.loads(saved.steps_json or "[]")
    except Exception:
        steps = []
    return {
        "id": client_id,
        "client_id": client_id,
        "title": title,
        "description": saved.description or "",
        "thumbnail_url": saved.thumbnail_url,
        "author": saved.author or "Graphene Square",
        "is_personal": bool(saved.is_personal),
        "is_official": bool(saved.is_official),
        "total_time_min": max(1, int(saved.total_time_min or 10)),
        "max_temperature": max(0, int(saved.max_temperature or 180)),
        "saved_at": saved.created_at.isoformat() if saved.created_at else None,
        "created_at": None,
        "steps": steps if isinstance(steps, list) else [],
    }


def _fill_saved_recipe_snapshot(
    saved: SavedRecipe,
    *,
    client_id: str,
    title: str,
    description: str = "",
    thumbnail_url: Optional[str] = None,
    author: str = "Graphene Square",
    is_official: bool = False,
    is_personal: bool = False,
    total_time_min: int = 10,
    max_temperature: int = 180,
    steps: Optional[list[dict]] = None,
) -> None:
    saved.client_id = client_id.strip()
    saved.title = title.strip()
    saved.description = description or ""
    saved.thumbnail_url = thumbnail_url
    saved.author = author.strip() or "Graphene Square"
    saved.is_official = bool(is_official)
    saved.is_personal = bool(is_personal)
    saved.total_time_min = max(1, int(total_time_min or 10))
    saved.max_temperature = max(0, int(max_temperature or 0))
    saved.steps_json = json.dumps(steps or [], ensure_ascii=False)


def _history_payload(row: CookingHistory) -> dict:
    try:
        steps = json.loads(row.steps_json or "[]")
    except Exception:
        steps = []
    return {
        "id": row.id,
        "recipe_id": str(row.recipe_id) if row.recipe_id is not None else None,
        "client_recipe_id": row.client_recipe_id or None,
        "recipe_title": row.recipe_title,
        "device_name": row.device_name,
        "status": row.status,
        "started_at": row.started_at.isoformat() if row.started_at else None,
        "finished_at": row.finished_at.isoformat() if row.finished_at else None,
        "total_time_min": row.total_time_min,
        "max_temperature": row.max_temperature,
        "steps": steps,
        "memo": row.memo,
    }

def _my_comment_payload(comment: CommunityComment, post: CommunityPost) -> dict:
    return {
        "id": comment.id,
        "type": "comment",
        "post_id": post.id,
        "post_title": post.title if not post.deleted else "삭제된 게시글입니다.",
        "post_category": post.category or "커뮤니티",
        "content": comment.content,
        "time_ago": comment.time_ago,
        "created_at": comment.created_at.isoformat() if comment.created_at else None,
    }

def _my_reply_payload(reply: CommunityReply, comment: CommunityComment, post: CommunityPost) -> dict:
    return {
        "id": reply.id,
        "type": "reply",
        "post_id": post.id,
        "comment_id": comment.id,
        "post_title": post.title if not post.deleted else "삭제된 게시글입니다.",
        "post_category": post.category or "커뮤니티",
        "content": reply.content,
        "time_ago": reply.time_ago,
        "created_at": reply.created_at.isoformat() if reply.created_at else None,
    }

# -----------------------------------------------------------------------------
# Auth APIs - local DB only
# -----------------------------------------------------------------------------

@app.post("/auth/local_sync")
def local_auth_sync(data: LocalAuthSyncRequest, session: Session = Depends(get_session)):
    """
    Map a user authenticated by the company auth server to this local DB.

    The Flutter app calls this after company login so community/recipe/device APIs
    can still use local SQLite ownership, edit/delete permissions, notifications,
    likes with a local bearer token.

    Prototype note: this endpoint trusts the app-provided profile. In production,
    the local server should verify the company access token server-to-server before
    issuing a local API token.
    """
    email = (data.email or "").strip()
    if not email:
        raise HTTPException(status_code=400, detail="이메일 정보가 필요합니다.")
    nickname = (data.nickname or "").strip() or _display_name_for_email(email)
    user = session.exec(select(User).where(User.email == email)).first()
    if not user:
        user = User(
            email=email,
            password_hash="EXTERNAL_COMPANY_AUTH",
            nickname=nickname,
        )
        session.add(user)
        session.commit()
        session.refresh(user)
    else:
        if nickname and user.nickname != nickname:
            user.nickname = nickname
            session.add(user)
            session.commit()
            session.refresh(user)
    access = _token()
    refresh = _token()
    session.add(SessionToken(user_id=user.id, access_token=access, refresh_token=refresh))
    session.commit()
    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "email": user.email,
            "nickname": user.nickname or _display_name_for_email(user.email),
            "avatar_color": _avatar_for_user(user),
            "is_admin": _is_admin(user),
        },
    }

@app.post("/auth/register/send_email_code")
def send_register_email_code(data: SendEmailRequest, session: Session = Depends(get_session)):
    session.add(EmailCode(email=data.email, code="123456", purpose="REGISTER", verified=False))
    session.commit()
    return {"message": "local code saved", "test_code": "123456"}

@app.post("/auth/register/verify_email_code")
def verify_register_email_code(data: VerifyCodeRequest, session: Session = Depends(get_session)):
    code = session.exec(select(EmailCode).where(EmailCode.email == data.email).where(EmailCode.purpose == "REGISTER")).all()
    if not code or code[-1].code != data.code:
        raise HTTPException(status_code=400, detail="Invalid code. 로컬 테스트 코드는 123456입니다.")
    code[-1].verified = True
    session.add(code[-1])
    session.commit()
    return {"message": "verified"}

@app.post("/auth/register/complete", status_code=201)
def complete_register(data: CompleteRegisterRequest, session: Session = Depends(get_session)):
    exists = session.exec(select(User).where(User.email == data.email)).first()
    if exists:
        raise HTTPException(status_code=400, detail="이미 가입된 이메일입니다.")
    user = User(
        email=data.email,
        password_hash=_hash(data.password),
        nickname=(data.email.split("@", 1)[0] or DEFAULT_USER),
        mobile=data.mobile,
        sex=data.sex,
        age=data.age,
        marketing_opt_in=data.marketing_opt_in,
    )
    session.add(user)
    session.commit()
    return {"message": "registered"}

@app.post("/auth/reset_password/send_email_code")
def send_reset_password_email_code(data: SendEmailRequest, session: Session = Depends(get_session)):
    session.add(EmailCode(email=data.email, code="123456", purpose="RESET_PASSWORD", verified=False))
    session.commit()
    return {"message": "local code saved", "test_code": "123456"}

@app.post("/auth/reset_password/verify_email_code")
def verify_reset_password_email_code(data: VerifyCodeRequest, session: Session = Depends(get_session)):
    codes = session.exec(select(EmailCode).where(EmailCode.email == data.email).where(EmailCode.purpose == "RESET_PASSWORD")).all()
    if not codes or codes[-1].code != data.code:
        raise HTTPException(status_code=400, detail="Invalid code. 로컬 테스트 코드는 123456입니다.")
    codes[-1].verified = True
    session.add(codes[-1])
    session.commit()
    return {"message": "verified"}

@app.post("/auth/reset_password/complete")
def complete_reset_password(data: CompleteResetPasswordRequest, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.email == data.email)).first()
    if not user:
        raise HTTPException(status_code=404, detail="가입되지 않은 이메일입니다.")
    user.password_hash = _hash(data.new_password)
    session.add(user)
    session.commit()
    return {"message": "password reset"}

@app.post("/auth/login")
def login(data: LoginIn, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.email == data.email)).first()
    if not user or user.password_hash != _hash(data.password):
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 다릅니다.")
    access = _token()
    refresh = _token()
    session.add(SessionToken(user_id=user.id, access_token=access, refresh_token=refresh))
    session.commit()
    return {"access_token": access, "refresh_token": refresh, "token_type": "bearer"}

@app.post("/auth/refresh")
def refresh(data: RefreshRequest, session: Session = Depends(get_session)):
    row = session.exec(select(SessionToken).where(SessionToken.refresh_token == data.refresh_token).where(SessionToken.revoked == False)).first()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    row.access_token = _token()
    row.refresh_token = _token()
    session.add(row)
    session.commit()
    return {"access_token": row.access_token, "refresh_token": row.refresh_token, "token_type": "bearer"}

@app.post("/auth/logout")
def logout(data: RefreshRequest, session: Session = Depends(get_session)):
    row = session.exec(select(SessionToken).where(SessionToken.refresh_token == data.refresh_token)).first()
    if row:
        row.revoked = True
        session.add(row)
        session.commit()
    return {"message": "logged out"}

@app.get("/auth/me")
def me(user: User = Depends(_current_user)):
    return {
        "id": user.id,
        "email": user.email,
        "nickname": user.nickname or _display_name_for_email(user.email),
        "avatar_color": _avatar_for_user(user),
        "is_admin": _is_admin(user),
    }


# -----------------------------------------------------------------------------
# My Page APIs
# -----------------------------------------------------------------------------
@app.get("/users/me")
def get_my_profile(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    my_name = user.nickname or _display_name_for_email(user.email)
    recipe_count = len(session.exec(select(RecipeRecord).where(RecipeRecord.owner_user_id == user.id)).all())
    review_count = len(session.exec(
        select(RecipeReview).where(RecipeReview.deleted == False).where(
            or_(RecipeReview.owner_user_id == user.id, RecipeReview.username == my_name)
        )
    ).all())
    comment_count = len(session.exec(select(CommunityComment).where(CommunityComment.deleted == False).where(or_(CommunityComment.owner_user_id == user.id, CommunityComment.username == my_name))).all())
    reply_count = len(session.exec(select(CommunityReply).where(CommunityReply.deleted == False).where(or_(CommunityReply.owner_user_id == user.id, CommunityReply.username == my_name))).all())
    history_count = len(session.exec(select(CookingHistory).where(CookingHistory.user_id == user.id)).all())
    saved_count = len(session.exec(select(SavedRecipe).where(SavedRecipe.user_id == user.id)).all())
    device_count = len(session.exec(select(RegisteredDevice).where(RegisteredDevice.user_id == user.id)).all())
    return {
        "id": user.id,
        "email": user.email,
        "nickname": my_name,
        "avatar_color": _avatar_for_user(user),
        "recipe_count": recipe_count,
        "review_count": review_count,
        "comment_count": comment_count + reply_count,
        "cooking_history_count": history_count,
        "saved_recipe_count": saved_count,
        "device_count": device_count,
        "is_admin": _is_admin(user),
        "settings": _settings_payload(_settings_for_user(session, user)),
    }

@app.patch("/users/me")
def patch_my_profile(data: UserPatchRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    if data.nickname is not None:
        nickname = data.nickname.strip()
        if not nickname:
            raise HTTPException(status_code=400, detail="닉네임을 입력해 주세요.")
        if len(nickname) > 20:
            raise HTTPException(status_code=400, detail="닉네임은 20자 이하로 입력해 주세요.")
        old_name = user.nickname or _display_name_for_email(user.email)
        user.nickname = nickname
        session.add(user)
        # 기존 표시명 기반 데이터도 같이 갱신하여 내 글/후기 목록이 끊기지 않도록 합니다.
        for post in session.exec(select(CommunityPost).where(CommunityPost.owner_user_id == user.id)).all():
            post.username = nickname
            session.add(post)
        for comment in session.exec(select(CommunityComment).where(CommunityComment.owner_user_id == user.id)).all():
            comment.username = nickname
            session.add(comment)
        for reply in session.exec(select(CommunityReply).where(CommunityReply.owner_user_id == user.id)).all():
            reply.username = nickname
            session.add(reply)
        for review in session.exec(select(RecipeReview).where(or_(RecipeReview.owner_user_id == user.id, RecipeReview.username == old_name))).all():
            review.owner_user_id = user.id
            review.username = nickname
            session.add(review)
    session.commit()
    session.refresh(user)
    return get_my_profile(session=session, user=user)

@app.patch("/users/me/password")
def patch_my_password(data: PasswordPatchRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    if user.password_hash != "EXTERNAL_COMPANY_AUTH" and user.password_hash != _hash(data.current_password):
        raise HTTPException(status_code=400, detail="현재 비밀번호가 일치하지 않습니다.")
    if len(data.new_password) < 4:
        raise HTTPException(status_code=400, detail="새 비밀번호는 4자 이상이어야 합니다.")
    user.password_hash = _hash(data.new_password)
    session.add(user)
    session.commit()
    return {"message": "password updated"}

@app.delete("/users/me")
def delete_my_account(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    for token in session.exec(select(SessionToken).where(SessionToken.user_id == user.id)).all():
        token.revoked = True
        session.add(token)
    user.email = f"deleted_user_{user.id}@deleted.local"
    user.nickname = "탈퇴한 사용자"
    user.password_hash = "DELETED"
    session.add(user)
    session.commit()
    return {"message": "account deleted"}

@app.get("/users/me/settings")
def get_my_settings(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    return {"settings": _settings_payload(_settings_for_user(session, user))}

@app.patch("/users/me/settings")
def patch_my_settings(data: SettingsPatchRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    settings = _settings_for_user(session, user)
    if data.cooking_notification is not None:
        settings.cooking_notification = data.cooking_notification
    if data.community_notification is not None:
        settings.community_notification = data.community_notification
    if data.marketing_notification is not None:
        settings.marketing_notification = data.marketing_notification
    if data.language is not None:
        language = data.language.strip().lower()
        if language not in {"ko", "en"}:
            raise HTTPException(status_code=400, detail="지원하지 않는 언어입니다.")
        settings.language = language
    if data.tutorial_completed is not None:
        settings.tutorial_completed = data.tutorial_completed
    settings.updated_at = datetime.utcnow()
    session.add(settings)
    session.commit()
    session.refresh(settings)
    return {"settings": _settings_payload(settings)}

@app.get("/users/me/recipes")
def get_my_recipes(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    rows = session.exec(select(RecipeRecord).where(RecipeRecord.owner_user_id == user.id)).all()
    rows = sorted(rows, key=lambda r: r.id or 0, reverse=True)
    return {"recipes": [_recipe_card_payload(session, row) for row in rows]}

@app.patch("/users/me/recipes/{recipe_id}")
def patch_my_recipe(
    recipe_id: int,
    data: UploadRecipeRequest,
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    row = session.get(RecipeRecord, recipe_id)
    if not row:
        raise HTTPException(status_code=404, detail="Recipe not found")
    if row.owner_user_id != user.id:
        raise HTTPException(status_code=403, detail="내 레시피만 수정할 수 있습니다.")

    title = data.title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="title required")
    if not data.steps:
        raise HTTPException(status_code=400, detail="steps required")

    row.title = title
    row.description = data.description
    row.author = user.nickname or _display_name_for_email(user.email)
    row.updated_at = datetime.utcnow()
    session.add(row)

    for step in session.exec(
        select(RecipeStepRecord).where(RecipeStepRecord.recipe_id == recipe_id)
    ).all():
        session.delete(step)

    for index, step in enumerate(data.steps, start=1):
        session.add(
            RecipeStepRecord(
                recipe_id=recipe_id,
                temperature=step.temperature,
                time_offset=step.time_offset,
                label=f"Step {index}",
                sort_order=index,
            )
        )
    session.commit()
    session.refresh(row)
    payload = _recipe_card_payload(session, row)

    # Saved-recipe rows contain a snapshot for external recipes. Keep snapshots
    # in sync when this local personal recipe is edited as well.
    saved_rows = session.exec(
        select(SavedRecipe).where(
            or_(SavedRecipe.recipe_id == recipe_id, SavedRecipe.client_id == str(recipe_id))
        )
    ).all()
    for saved in saved_rows:
        _fill_saved_recipe_snapshot(
            saved,
            client_id=str(recipe_id),
            title=payload["title"],
            description=payload["description"],
            thumbnail_url=payload["thumbnail_url"],
            author=payload["author"],
            is_official=payload["is_official"],
            is_personal=True,
            total_time_min=payload["total_time_min"],
            max_temperature=payload["max_temperature"],
            steps=payload["steps"],
        )
        session.add(saved)
    if saved_rows:
        session.commit()

    return {"message": "recipe updated", "recipe": payload}


@app.delete("/users/me/recipes/{recipe_id}")
def delete_my_recipe(recipe_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    row = session.get(RecipeRecord, recipe_id)
    if not row:
        raise HTTPException(status_code=404, detail="Recipe not found")
    if row.owner_user_id != user.id:
        raise HTTPException(status_code=403, detail="내 레시피만 삭제할 수 있습니다.")
    for step in session.exec(select(RecipeStepRecord).where(RecipeStepRecord.recipe_id == recipe_id)).all():
        session.delete(step)
    for saved in session.exec(select(SavedRecipe).where(SavedRecipe.recipe_id == recipe_id)).all():
        session.delete(saved)
    session.delete(row)
    session.commit()
    return {"message": "recipe deleted", "recipe_id": recipe_id}

@app.get("/users/me/saved-recipes")
def get_my_saved_recipes(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    rows = session.exec(select(SavedRecipe).where(SavedRecipe.user_id == user.id)).all()
    rows = sorted(rows, key=lambda r: r.id or 0, reverse=True)
    recipes = []
    for saved in rows:
        payload = _saved_recipe_payload(session, saved)
        if payload is not None:
            recipes.append(payload)
    return {"recipes": recipes}

@app.post("/users/me/saved-recipes")
def save_my_recipe(data: SaveRecipeRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    recipe = session.get(RecipeRecord, data.recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    exists = session.exec(
        select(SavedRecipe)
        .where(SavedRecipe.user_id == user.id)
        .where(SavedRecipe.recipe_id == data.recipe_id)
    ).first()
    if not exists:
        exists = SavedRecipe(user_id=user.id, recipe_id=data.recipe_id)
    payload = _recipe_card_payload(session, recipe)
    _fill_saved_recipe_snapshot(
        exists,
        client_id=str(payload["id"]),
        title=payload["title"],
        description=payload["description"],
        thumbnail_url=payload["thumbnail_url"],
        author=payload["author"],
        is_official=payload["is_official"],
        is_personal=payload["is_personal"],
        total_time_min=payload["total_time_min"],
        max_temperature=payload["max_temperature"],
        steps=payload["steps"],
    )
    session.add(exists)
    session.commit()
    session.refresh(exists)
    return {"message": "saved", "recipe": _saved_recipe_payload(session, exists)}

@app.post("/users/me/saved-recipes/by-client-id")
def save_my_recipe_by_client_id(data: SaveClientRecipeRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    client_id = data.client_id.strip()
    if not client_id:
        raise HTTPException(status_code=400, detail="client_id is required")

    exists = session.exec(
        select(SavedRecipe)
        .where(SavedRecipe.user_id == user.id)
        .where(SavedRecipe.client_id == client_id)
    ).first()
    recipe = _recipe_for_client_id(session, client_id)
    if exists is None and recipe is not None and recipe.id is not None:
        # 이전 버전에서 recipe_id만 저장한 행을 동일한 행으로 승격합니다.
        exists = session.exec(
            select(SavedRecipe)
            .where(SavedRecipe.user_id == user.id)
            .where(SavedRecipe.recipe_id == recipe.id)
        ).first()
    if exists is None:
        exists = SavedRecipe(
            user_id=user.id,
            recipe_id=recipe.id if recipe is not None and recipe.id is not None else 0,
        )

    if recipe is not None:
        local_payload = _recipe_card_payload(session, recipe)
        if not data.title.strip():
            title = local_payload["title"]
            description = local_payload["description"]
            thumbnail_url = local_payload["thumbnail_url"]
            author = local_payload["author"]
            total_time_min = local_payload["total_time_min"]
            max_temperature = local_payload["max_temperature"]
            steps = local_payload["steps"]
        else:
            title = data.title.strip()
            description = data.description
            thumbnail_url = data.thumbnail_url
            author = data.author
            total_time_min = data.total_time_min
            max_temperature = data.max_temperature
            steps = data.steps
        # Recipe ownership/type comes from the DB row, not from app-side
        # inference such as "not official means mine".
        is_official = local_payload["is_official"]
        is_personal = local_payload["is_personal"]
    else:
        title = data.title.strip() or client_id
        description = data.description
        thumbnail_url = data.thumbnail_url
        author = data.author
        is_official = data.is_official
        is_personal = data.is_personal
        total_time_min = data.total_time_min
        max_temperature = data.max_temperature
        steps = data.steps

    _fill_saved_recipe_snapshot(
        exists,
        client_id=client_id,
        title=title,
        description=description,
        thumbnail_url=thumbnail_url,
        author=author,
        is_official=is_official,
        is_personal=is_personal,
        total_time_min=total_time_min,
        max_temperature=max_temperature,
        steps=steps,
    )
    session.add(exists)
    session.commit()
    session.refresh(exists)
    return {"message": "saved", "recipe": _saved_recipe_payload(session, exists)}

@app.delete("/users/me/saved-recipes/by-client-id/{client_id}")
def unsave_my_recipe_by_client_id(client_id: str, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    rows = session.exec(
        select(SavedRecipe)
        .where(SavedRecipe.user_id == user.id)
        .where(SavedRecipe.client_id == client_id)
    ).all()
    if not rows:
        recipe = _recipe_for_client_id(session, client_id)
        if recipe is not None and recipe.id is not None:
            rows = session.exec(
                select(SavedRecipe)
                .where(SavedRecipe.user_id == user.id)
                .where(SavedRecipe.recipe_id == recipe.id)
            ).all()
    for row in rows:
        session.delete(row)
    session.commit()
    return {"message": "unsaved", "recipe_id": client_id}

@app.delete("/users/me/saved-recipes/{recipe_id}")
def unsave_my_recipe(recipe_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    rows = session.exec(
        select(SavedRecipe)
        .where(SavedRecipe.user_id == user.id)
        .where(SavedRecipe.recipe_id == recipe_id)
    ).all()
    for row in rows:
        session.delete(row)
    session.commit()
    return {"message": "unsaved", "recipe_id": recipe_id}

@app.get("/users/me/reviews")
def get_my_reviews(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    my_name = user.nickname or _display_name_for_email(user.email)
    rows = session.exec(select(RecipeReview).where(RecipeReview.deleted == False).where(or_(RecipeReview.owner_user_id == user.id, RecipeReview.username == my_name))).all()
    rows = sorted(rows, key=lambda r: r.id or 0, reverse=True)
    return {"reviews": [_review_payload(session, row, user) for row in rows]}

@app.patch("/reviews/{review_id}")
def patch_review(review_id: int, data: ReviewPatchRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    review = session.get(RecipeReview, review_id)
    if not review or review.deleted:
        raise HTTPException(status_code=404, detail="Review not found")
    if not _is_owner(review, user):
        raise HTTPException(status_code=403, detail="내 후기만 수정할 수 있습니다.")
    if data.rating is not None:
        review.rating = max(1, min(5, int(data.rating)))
    if data.content is not None:
        content = data.content.strip()
        if not content:
            raise HTTPException(status_code=400, detail="후기 내용을 입력해 주세요.")
        review.content = content
    review.updated_at = datetime.utcnow()
    session.add(review)
    session.commit()
    session.refresh(review)
    return {"review": _review_payload(session, review, user)}

@app.delete("/reviews/{review_id}")
def delete_review(review_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    review = session.get(RecipeReview, review_id)
    if not review or review.deleted:
        raise HTTPException(status_code=404, detail="Review not found")
    if not _is_owner(review, user):
        raise HTTPException(status_code=403, detail="내 후기만 삭제할 수 있습니다.")
    review.deleted = True
    session.add(review)
    session.commit()
    return {"message": "review deleted", "review_id": review_id}

@app.patch("/community/reviews/{review_id}")
def patch_community_review(review_id: int, data: ReviewPatchRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    return patch_review(review_id=review_id, data=data, session=session, user=user)

@app.delete("/community/reviews/{review_id}")
def delete_community_review(review_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    return delete_review(review_id=review_id, session=session, user=user)

@app.get("/users/me/comments")
def get_my_comments(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    items = []
    my_name = user.nickname or _display_name_for_email(user.email)
    comments = session.exec(select(CommunityComment).where(CommunityComment.deleted == False).where(or_(CommunityComment.owner_user_id == user.id, CommunityComment.username == my_name))).all()
    for comment in comments:
        post = session.get(CommunityPost, comment.post_id)
        if post:
            items.append(_my_comment_payload(comment, post))
    replies = session.exec(select(CommunityReply).where(CommunityReply.deleted == False).where(or_(CommunityReply.owner_user_id == user.id, CommunityReply.username == my_name))).all()
    for reply in replies:
        comment = session.get(CommunityComment, reply.comment_id)
        if comment:
            post = session.get(CommunityPost, comment.post_id)
            if post:
                items.append(_my_reply_payload(reply, comment, post))
    items.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return {"comments": items}

@app.get("/users/me/cooking-histories")
def get_my_cooking_histories(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    rows = session.exec(select(CookingHistory).where(CookingHistory.user_id == user.id)).all()
    rows = sorted(rows, key=lambda h: h.started_at or h.created_at, reverse=True)
    return {"histories": [_history_payload(row) for row in rows]}

@app.post("/users/me/cooking-histories")
def create_my_cooking_history(data: CookingHistoryCreateRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    recipe_title = data.recipe_title.strip() or "직접 조리"
    if data.recipe_id:
        recipe = session.get(RecipeRecord, data.recipe_id)
        if recipe:
            recipe_title = recipe.title
    steps_json = json.dumps(data.steps, ensure_ascii=False)
    row = CookingHistory(
        user_id=user.id,
        recipe_id=data.recipe_id,
        client_recipe_id=data.client_recipe_id.strip(),
        recipe_title=recipe_title,
        device_name=data.device_name.strip() or "Graphene Multi-Cooker",
        status=data.status.strip() or "completed",
        started_at=data.started_at or datetime.utcnow(),
        finished_at=data.finished_at,
        total_time_min=max(0, data.total_time_min),
        max_temperature=max(0, data.max_temperature),
        steps_json=steps_json,
        memo=data.memo.strip(),
    )
    session.add(row)
    session.commit()
    session.refresh(row)
    return {"history": _history_payload(row)}

@app.get("/users/me/cooking-histories/{history_id}")
def get_my_cooking_history(history_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    row = session.get(CookingHistory, history_id)
    if not row or row.user_id != user.id:
        raise HTTPException(status_code=404, detail="Cooking history not found")
    return {"history": _history_payload(row)}

@app.delete("/users/me/cooking-histories/{history_id}")
def delete_my_cooking_history(history_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    row = session.get(CookingHistory, history_id)
    if not row or row.user_id != user.id:
        raise HTTPException(status_code=404, detail="Cooking history not found")
    session.delete(row)
    session.commit()
    return {"message": "history deleted", "history_id": history_id}

@app.post("/users/me/cooking-histories/{history_id}/save-as-recipe")
def save_history_as_recipe(history_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    history = session.get(CookingHistory, history_id)
    if not history or history.user_id != user.id:
        raise HTTPException(status_code=404, detail="Cooking history not found")
    recipe = RecipeRecord(
        owner_user_id=user.id,
        title=f"{history.recipe_title} 복사본",
        description="조리 이력에서 저장한 레시피입니다.",
        author=user.nickname or _display_name_for_email(user.email),
        is_personal=True,
    )
    session.add(recipe)
    session.commit()
    session.refresh(recipe)
    try:
        steps = json.loads(history.steps_json or "[]")
    except Exception:
        steps = []
    if not steps:
        steps = [{"temperature": history.max_temperature or 180, "time_offset": 0}]
    for index, step in enumerate(steps, start=1):
        session.add(RecipeStepRecord(
            recipe_id=recipe.id,
            temperature=float(step.get("temperature") or history.max_temperature or 180),
            time_offset=float(step.get("time_offset") or step.get("timeOffset") or 0),
            label=str(step.get("label") or f"Step {index}"),
            sort_order=index,
        ))
    session.commit()
    return {"recipe": _recipe_card_payload(session, recipe)}

@app.get("/users/me/devices")
def get_my_devices(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    rows = session.exec(select(RegisteredDevice).where(RegisteredDevice.user_id == user.id)).all()
    rows = sorted(rows, key=lambda d: d.last_connected_at or d.created_at, reverse=True)
    return {"devices": [_registered_device_payload(row) for row in rows]}

@app.post("/users/me/devices")
def register_my_device(data: DeviceRegisterRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    mac = data.mac_address.strip() or data.device_name.strip() or "LOCAL-MAC-0000"
    row = session.exec(select(RegisteredDevice).where(RegisteredDevice.user_id == user.id).where(RegisteredDevice.mac_address == mac)).first()
    if not row:
        row = RegisteredDevice(user_id=user.id, mac_address=mac)
    row.device_name = data.device_name.strip() or row.device_name
    row.serial_number = data.serial_number.strip() or row.serial_number
    row.alias = data.alias.strip()
    row.firmware_version = data.firmware_version.strip()
    row.auto_reconnect = data.auto_reconnect
    row.last_connected_at = datetime.utcnow()
    row.updated_at = datetime.utcnow()
    session.add(row)
    session.commit()
    session.refresh(row)
    return {"device": _registered_device_payload(row)}

@app.patch("/users/me/devices/{device_id}")
def patch_my_device(device_id: int, data: DevicePatchRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    row = session.get(RegisteredDevice, device_id)
    if not row or row.user_id != user.id:
        raise HTTPException(status_code=404, detail="Device not found")
    if data.alias is not None:
        row.alias = data.alias.strip()
    if data.device_name is not None:
        row.device_name = data.device_name.strip() or row.device_name
    if data.firmware_version is not None:
        row.firmware_version = data.firmware_version.strip()
    if data.auto_reconnect is not None:
        row.auto_reconnect = data.auto_reconnect
    row.updated_at = datetime.utcnow()
    session.add(row)
    session.commit()
    session.refresh(row)
    return {"device": _registered_device_payload(row)}

@app.delete("/users/me/devices/{device_id}")
def delete_my_device(device_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    row = session.get(RegisteredDevice, device_id)
    if not row or row.user_id != user.id:
        raise HTTPException(status_code=404, detail="Device not found")
    session.delete(row)
    session.commit()
    return {"message": "device deleted", "device_id": device_id}

# -----------------------------------------------------------------------------
# Company OpenAPI compatible local APIs
# -----------------------------------------------------------------------------
@app.get("/auth/google/login")
def google_login():
    return {
        "message": "로컬 테스트 서버에서는 실제 Google OAuth를 수행하지 않습니다.",
        "callback_url": "/auth/google/callback",
        "hint": "배포 서버에서는 이 엔드포인트가 Google 로그인 페이지로 redirect됩니다.",
    }

@app.get("/auth/google/callback")
def google_callback(code: Optional[str] = None, state: Optional[str] = None):
    return {
        "message": "local google callback received",
        "code_received": code is not None,
        "state": state,
    }

@app.post("/device/verify")
def verify_device(data: DeviceVerifyRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    mac = data.mac_address.strip() or "LOCAL-MAC-0000"
    row = session.exec(
        select(RegisteredDevice)
        .where(RegisteredDevice.user_id == user.id)
        .where(RegisteredDevice.mac_address == mac)
    ).first()
    if not row:
        row = RegisteredDevice(user_id=user.id, mac_address=mac)
    row.last_connected_at = datetime.utcnow()
    row.updated_at = datetime.utcnow()
    session.add(row)
    session.commit()
    session.refresh(row)
    return {"verified": row.verified, "device_name": row.device_name, "serial_number": row.serial_number}

@app.post("/device/unregister")
def unregister_device(data: DeviceVerifyRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    mac = data.mac_address.strip()
    rows = session.exec(
        select(RegisteredDevice)
        .where(RegisteredDevice.user_id == user.id)
        .where(RegisteredDevice.mac_address == mac)
    ).all()
    for row in rows:
        session.delete(row)
    session.commit()
    return {"message": "unregistered", "mac_address": mac}

@app.get("/recipes")
def get_recipe_catalog(session: Session = Depends(get_session)):
    allowed_ids = {str(row["client_id"]) for row in APP_RECIPE_CATALOG}
    rows = session.exec(
        select(RecipeRecord).where(RecipeRecord.is_personal == False)
    ).all()
    rows = [row for row in rows if (row.client_id or "") in allowed_ids]
    rows = sorted(rows, key=lambda row: (row.catalog_order, row.id or 0))
    return {"recipes": [_recipe_payload(session, row) for row in rows]}


@app.get("/recipes/{client_id}")
def get_recipe_catalog_detail(client_id: str, session: Session = Depends(get_session)):
    row = _recipe_for_client_id(session, client_id)
    if row is None or row.is_personal:
        raise HTTPException(status_code=404, detail="Recipe not found")
    allowed_ids = {str(item["client_id"]) for item in APP_RECIPE_CATALOG}
    if (row.client_id or "") not in allowed_ids:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return {"recipe": _recipe_payload(session, row)}


@app.post("/recipe/upload")
def upload_recipe(data: UploadRecipeRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    if not data.steps:
        raise HTTPException(status_code=400, detail="steps required")
    recipe = RecipeRecord(
        owner_user_id=user.id,
        title=data.title.strip(),
        description=data.description,
        author=user.nickname or _display_name_for_email(user.email),
        is_personal=True,
        is_gsq_suggested=False,
        is_official=False,
    )
    if not recipe.title:
        raise HTTPException(status_code=400, detail="title required")
    session.add(recipe)
    session.commit()
    session.refresh(recipe)
    for index, step in enumerate(data.steps, start=1):
        session.add(
            RecipeStepRecord(
                recipe_id=recipe.id,
                temperature=step.temperature,
                time_offset=step.time_offset,
                label=f"Step {index}",
                sort_order=index,
            )
        )
    session.commit()
    return {"message": "uploaded", "recipe": _recipe_card_payload(session, recipe)}

@app.get("/recipe/personal_recipes/{amount}")
def get_personal_recipes(amount: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    rows = session.exec(
        select(RecipeRecord)
        .where(RecipeRecord.is_personal == True)
        .where(RecipeRecord.owner_user_id == user.id)
    ).all()
    rows = sorted(rows, key=lambda r: r.id or 0, reverse=True)[:amount]
    return {"recipes": [_recipe_payload(session, row) for row in rows]}

@app.get("/recipe/gsq_suggest_recipes/{amount}")
def get_gsq_suggest_recipes(amount: int, session: Session = Depends(get_session)):
    allowed_ids = {str(item["client_id"]) for item in APP_RECIPE_CATALOG}
    rows = session.exec(select(RecipeRecord).where(RecipeRecord.is_gsq_suggested == True)).all()
    rows = [row for row in rows if (row.client_id or "") in allowed_ids]
    rows = sorted(rows, key=lambda row: (row.catalog_order, row.id or 0))[:max(0, amount)]
    return {"recipes": [_recipe_payload(session, row) for row in rows]}

@app.get("/recipe/recipe_titles")
def get_recipe_titles(session: Session = Depends(get_session)):
    allowed_ids = {str(item["client_id"]) for item in APP_RECIPE_CATALOG}
    rows = session.exec(select(RecipeRecord).where(RecipeRecord.is_personal == False)).all()
    rows = [row for row in rows if (row.client_id or "") in allowed_ids]
    rows = sorted(rows, key=lambda row: (row.catalog_order, row.id or 0))
    return {"recipe_titles": [row.title for row in rows]}

@app.get("/recipe/search_recipes/{title}")
def search_recipes(title: str, session: Session = Depends(get_session)):
    allowed_ids = {str(item["client_id"]) for item in APP_RECIPE_CATALOG}
    rows = session.exec(select(RecipeRecord).where(RecipeRecord.is_personal == False)).all()
    query = title.lower().strip()
    for row in sorted(rows, key=lambda item: (item.catalog_order, item.id or 0)):
        if (row.client_id or "") not in allowed_ids:
            continue
        if row.title.lower() == query or query in row.title.lower():
            return _recipe_payload(session, row)
    raise HTTPException(status_code=404, detail="Recipe not found")

@app.post("/dashboard/upload_gsq_recipe")
async def upload_gsq_recipe(file: UploadFile = File(...), session: Session = Depends(get_session)):
    # 로컬 테스트용: 파일 내용 파싱 대신 샘플 GSQ 레시피 등록 여부만 확인합니다.
    content = await file.read()
    return {"message": "received", "filename": file.filename, "size": len(content)}

@app.post("/dashboard/upload_ingredients_photo")
async def dashboard_upload_ingredients_photo(request: Request, file: UploadFile = File(...), session: Session = Depends(get_session), user: User = Depends(_current_user)):
    filename = _safe_filename(file.filename or "ingredient.png")
    s3_key = f"ingredients/{secrets.token_hex(8)}_{filename}"
    path = _local_file_path(s3_key)
    content = await file.read()
    with open(path, "wb") as f:
        f.write(content)
    image_url = str(request.url_for("local_s3_get", s3_key=s3_key))
    return _ai_response(session, user, s3_key=s3_key, image_url=image_url, original_filename=filename, content_type=file.content_type)

@app.post("/ai_recommend/upload_ingredients_photo")
def get_upload_url(data: UploadUrlRequest, request: Request):
    filename = _safe_filename(data.filename)
    s3_key = f"ingredients/{datetime.utcnow().strftime('%Y%m%d')}/{secrets.token_hex(12)}_{filename}"
    upload_url = str(request.url_for("local_s3_put", s3_key=s3_key))
    image_url = str(request.url_for("local_s3_get", s3_key=s3_key))
    return {
        "upload_url": upload_url,
        "s3_key": s3_key,
        "image_url": image_url,
        "headers": {"Content-Type": data.content_type},
    }

@app.put("/_local_s3/{s3_key:path}")
async def local_s3_put(s3_key: str, request: Request):
    body = await request.body()
    path = _local_file_path(s3_key)
    with open(path, "wb") as f:
        f.write(body)
    return {"message": "uploaded", "s3_key": s3_key, "size": len(body)}

@app.get("/_local_s3/{s3_key:path}")
def local_s3_get(s3_key: str):
    path = _local_file_path(s3_key)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="local object not found")
    return FileResponse(path)

def _ai_response(
    session: Session,
    user: User,
    s3_key: str,
    image_url: Optional[str],
    original_filename: Optional[str],
    content_type: Optional[str],
) -> dict:
    ingredients = [
        {"name": "닭고기", "confidence": 0.92, "bbox": {"x1": 0.12, "y1": 0.18, "x2": 0.62, "y2": 0.72}},
        {"name": "대파", "confidence": 0.84, "bbox": {"x1": 0.55, "y1": 0.12, "x2": 0.88, "y2": 0.45}},
    ]
    record = IngredientImageRecord(
        user_id=user.id,
        s3_key=s3_key,
        image_url=image_url,
        original_filename=original_filename,
        content_type=content_type,
        detected_ingredients=",".join(item["name"] for item in ingredients),
    )
    session.add(record)
    session.commit()

    rows = session.exec(select(RecipeRecord).where(RecipeRecord.is_gsq_suggested == True)).all()
    if not rows:
        rows = session.exec(select(RecipeRecord)).all()
    recipes = [_recipe_payload(session, row, include_similarity=True, similarity=max(0.7, 0.94 - i * 0.07)) for i, row in enumerate(rows[:3])]
    return {"photo_url": image_url, "ingredients": ingredients, "recipes": recipes}

@app.post("/ai_recommend/upload_ingredients_photo_complete")
def upload_complete(data: UploadCompleteRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    # 로컬에서는 실제 S3 대신 local_uploads 폴더에 파일이 있으면 확인합니다. 없더라도 테스트를 위해 추천 응답은 반환합니다.
    image_url = data.image_url
    return _ai_response(
        session,
        user,
        s3_key=data.s3_key,
        image_url=image_url,
        original_filename=data.original_filename,
        content_type=data.content_type,
    )

# -----------------------------------------------------------------------------
# Community APIs
# -----------------------------------------------------------------------------
@app.get("/")
def root():
    return {"message": "MultiCooker Local Community API is running", "db": os.path.join(BASE_DIR, "multicooker.db")}

@app.get("/health")
def health():
    return {"ok": True, "db": os.path.join(BASE_DIR, "multicooker.db")}


@app.post("/community/uploads/image")
async def upload_community_image(
    request: Request,
    file: UploadFile = File(...),
    user: User = Depends(_current_user),
):
    del user  # 인증된 사용자만 업로드할 수 있도록 의존성만 사용합니다.
    original_name = _safe_filename(file.filename or "community.jpg")
    extension = Path(original_name).suffix.lower()
    allowed_extensions = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
    allowed_content_types = {
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/gif",
        "application/octet-stream",
    }
    if extension not in allowed_extensions or (file.content_type or "") not in allowed_content_types:
        raise HTTPException(status_code=400, detail="JPG, PNG, WEBP, GIF 이미지만 업로드할 수 있습니다.")

    max_size = 8 * 1024 * 1024
    content = await file.read(max_size + 1)
    if len(content) > max_size:
        raise HTTPException(status_code=413, detail="이미지는 8MB 이하만 업로드할 수 있습니다.")
    if not content:
        raise HTTPException(status_code=400, detail="빈 이미지 파일입니다.")

    key = (
        f"community/{datetime.utcnow().strftime('%Y/%m/%d')}/"
        f"{secrets.token_hex(12)}{extension}"
    )
    path = _local_file_path(key)
    with open(path, "wb") as output:
        output.write(content)

    image_url = str(request.url_for("local_s3_get", s3_key=key))
    return {
        "image_url": image_url,
        "size": len(content),
        "filename": original_name,
    }


@app.post("/community/blocks/from-content")
def block_community_author(
    data: BlockFromContentRequest,
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    target = _community_target_row(session, data.target_type, data.target_id)
    blocked_user_id = getattr(target, "owner_user_id", None)
    blocked_username = (getattr(target, "username", "") or "").strip()

    if blocked_user_id == user.id or _is_owner(target, user):
        raise HTTPException(status_code=400, detail="자기 자신은 차단할 수 없습니다.")
    if blocked_user_id is None and not blocked_username:
        raise HTTPException(status_code=400, detail="차단할 사용자 정보가 없습니다.")

    rows = session.exec(
        select(CommunityBlock).where(CommunityBlock.blocker_user_id == user.id)
    ).all()
    normalized_name = blocked_username.lower()
    existing = next(
        (
            row
            for row in rows
            if (blocked_user_id is not None and row.blocked_user_id == blocked_user_id)
            or (
                blocked_user_id is None
                and (row.blocked_username or "").strip().lower() == normalized_name
            )
        ),
        None,
    )
    if existing is None:
        existing = CommunityBlock(
            blocker_user_id=user.id,
            blocked_user_id=blocked_user_id,
            blocked_username=blocked_username,
        )
        session.add(existing)
        session.commit()
        session.refresh(existing)

    return {"blocked": True, "block": _block_payload(existing)}


@app.get("/community/blocks")
def get_community_blocks(
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    rows = session.exec(
        select(CommunityBlock).where(CommunityBlock.blocker_user_id == user.id)
    ).all()
    rows = sorted(rows, key=lambda row: row.id or 0, reverse=True)
    return {"blocks": [_block_payload(row) for row in rows]}


@app.delete("/community/blocks/{block_id}")
def delete_community_block(
    block_id: int,
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    row = session.get(CommunityBlock, block_id)
    if row is None or row.blocker_user_id != user.id:
        raise HTTPException(status_code=404, detail="차단 정보를 찾을 수 없습니다.")
    session.delete(row)
    session.commit()
    return {"blocked": False, "block_id": block_id}


@app.patch("/admin/community/posts/{post_id}/likes")
def admin_set_post_likes(
    post_id: int,
    data: AdminPostLikesRequest,
    session: Session = Depends(get_session),
    admin: User = Depends(_require_admin),
):
    if data.like_count < 0 or data.like_count > 1_000_000:
        raise HTTPException(status_code=400, detail="좋아요 수는 0~1,000,000 범위로 입력해 주세요.")
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    post.likes = data.like_count
    if data.apply_to_popular_test:
        # 기존 UI의 옵션과 호환합니다. 실제 기간 집계는 이벤트 생성 시각으로 계산되며,
        # 테스트용 인기도는 관리자 보정값으로 분리합니다.
        post.admin_popularity_boost = data.like_count
    post.updated_at = datetime.utcnow()
    session.add(post)
    session.commit()
    session.refresh(post)
    return {"post": _post_payload(session, post, admin)}


@app.patch("/admin/community/posts/{post_id}/popularity")
def admin_set_post_popularity(
    post_id: int,
    data: AdminPostPopularityRequest,
    session: Session = Depends(get_session),
    admin: User = Depends(_require_admin),
):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    if data.like_count is not None:
        if data.like_count < 0 or data.like_count > 1_000_000:
            raise HTTPException(status_code=400, detail="좋아요 수는 0~1,000,000 범위로 입력해 주세요.")
        post.likes = data.like_count
    if data.admin_popularity_boost < 0 or data.admin_popularity_boost > 1_000_000:
        raise HTTPException(status_code=400, detail="인기도 보정값은 0~1,000,000 범위로 입력해 주세요.")
    post.admin_popularity_boost = data.admin_popularity_boost
    post.force_popular = data.force_popular
    post.updated_at = datetime.utcnow()
    session.add(post)
    session.commit()
    session.refresh(post)
    return {"post": _post_payload(session, post, admin)}


@app.get("/community/posts")
def get_posts(
    category: Optional[str] = None,
    keyword: Optional[str] = None,
    sort: str = "latest",
    limit: int = 100,
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    posts = session.exec(select(CommunityPost).where(CommunityPost.deleted == False)).all()
    blocked = _blocked_author_sets(session, user)
    posts = [post for post in posts if not _author_is_blocked(post, blocked)]
    if category and category not in {"전체", "인기"}:
        posts = [p for p in posts if p.category == category]
    if keyword:
        q = keyword.lower().strip()
        posts = [p for p in posts if q in " ".join([p.title, p.content, p.username, p.category, p.tags or ""]).lower()]
    posts = _sort_posts(session, posts, sort)[:limit]
    payload = [_post_payload(session, post, user, blocked) for post in posts]
    return {"posts": payload, "total_count": len(payload)}

@app.get("/community/posts/popular")
def get_popular_posts(days: int = 3, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    posts = session.exec(select(CommunityPost).where(CommunityPost.deleted == False)).all()
    blocked = _blocked_author_sets(session, user)
    posts = [post for post in posts if not _author_is_blocked(post, blocked)]
    windows = [days] if days in {3, 6, 9, 12} else [3, 6, 9, 12]
    if days == 3:
        windows = [3, 6, 9, 12]
    for d in windows:
        scored = [
            post
            for post in posts
            if post.force_popular or _popularity_score(session, post, d) > 0
        ]
        scored.sort(
            key=lambda post: (
                1 if post.force_popular else 0,
                _popularity_score(session, post, d),
                post.likes,
                post.id or 0,
            ),
            reverse=True,
        )
        if scored:
            return {"days": d, "posts": [_post_payload(session, p, user, blocked) for p in scored]}
    return {"days": 0, "posts": []}

@app.get("/community/posts/{post_id}")
def get_post(post_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    blocked = _blocked_author_sets(session, user)
    if _author_is_blocked(post, blocked):
        raise HTTPException(status_code=404, detail="차단한 사용자의 게시글입니다.")
    return {"post": _post_payload(session, post, user, blocked)}

@app.post("/community/posts")
def create_post(data: PostCreate, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    display_name = user.nickname or _display_name_for_email(user.email)
    post = CommunityPost(
        owner_user_id=user.id,
        category=data.category if data.category in {"자유", "Q&A"} else "자유",
        username=display_name,
        avatar_color=_avatar_for_user(user),
        title=data.title.strip(),
        content=data.content.strip(),
        image_url=data.image_url,
        tags=",".join(data.tags),
        time_ago="방금 전",
    )
    if not post.title or not post.content:
        raise HTTPException(status_code=400, detail="title/content required")
    session.add(post)
    session.commit()
    session.refresh(post)
    return {"message": "created", "post": _post_payload(session, post, user)}

@app.patch("/community/posts/{post_id}")
def update_post(post_id: int, data: PostPatch, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    if not _is_owner(post, user):
        raise HTTPException(status_code=403, detail="내 글만 수정할 수 있습니다.")
    if data.category is not None:
        post.category = data.category if data.category in {"자유", "Q&A"} else post.category
    if data.title is not None:
        post.title = data.title.strip()
    if data.content is not None:
        post.content = data.content.strip()
    if data.image_url is not None:
        post.image_url = data.image_url
    if data.tags is not None:
        post.tags = ",".join(data.tags)
    post.updated_at = datetime.utcnow()
    session.add(post)
    session.commit()
    session.refresh(post)
    return {"message": "updated", "post": _post_payload(session, post, user)}

@app.delete("/community/posts/{post_id}")
def delete_post(post_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    if not _is_owner(post, user):
        raise HTTPException(status_code=403, detail="내 글만 삭제할 수 있습니다.")
    post.deleted = True
    post.updated_at = datetime.utcnow()
    session.add(post)
    session.commit()
    return {"message": "deleted", "post_id": post_id}

@app.post("/community/posts/{post_id}/like")
def like_post(post_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(PostLike).where(PostLike.post_id == post_id).where(PostLike.username == viewer_key)).first()
    if not exists:
        session.add(PostLike(post_id=post_id, username=viewer_key))
        post.likes += 1
        _inc_activity_like(post, 1)
        session.add(post)
        session.commit()
        session.refresh(post)
    return {"is_liked": True, "like_count": post.likes, "post": _post_payload(session, post, user)}

@app.delete("/community/posts/{post_id}/like")
def unlike_post(post_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(PostLike).where(PostLike.post_id == post_id).where(PostLike.username == viewer_key)).first()
    if exists:
        session.delete(exists)
        post.likes = max(0, post.likes - 1)
        _inc_activity_like(post, -1)
        session.add(post)
        session.commit()
        session.refresh(post)
    return {"is_liked": False, "like_count": post.likes, "post": _post_payload(session, post, user)}

@app.post("/community/posts/{post_id}/report")
def report_post(post_id: int, data: ReportIn | None = None, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    created = _record_report(session, target_type="post", target_id=post_id, user=user, reason=(data.reason if data else "부적절한 내용"))
    if created:
        post.reports += 1
        session.add(post)
    session.commit()
    return {"reported": True, "duplicated": not created, "report_count": post.reports if _is_admin(user) else None}

@app.post("/community/posts/{post_id}/comments")
def add_comment(post_id: int, data: ContentIn, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    display_name = user.nickname or _display_name_for_email(user.email)
    comment = CommunityComment(
        post_id=post_id,
        owner_user_id=user.id,
        username=display_name,
        avatar_color=_avatar_for_user(user),
        content=data.content.strip(),
    )
    if not comment.content:
        raise HTTPException(status_code=400, detail="content required")
    _inc_activity_comment(post)
    session.add(post)
    session.add(comment)
    # 새 댓글의 PK를 알림에 정확히 연결하기 위해 commit 전에 flush합니다.
    session.flush()
    _add_notification(
        session,
        target_user_id=post.owner_user_id,
        target_username=post.username,
        notification_type="comment",
        from_user=user,
        post_title=post.title,
        post_id=post_id,
        context_text=comment.content,
        target_comment_id=comment.id,
    )
    session.commit()
    session.refresh(comment)
    session.refresh(post)
    return {"message": "comment created", "comment": _comment_payload(session, comment, user), "post": _post_payload(session, post, user)}

@app.patch("/community/comments/{comment_id}")
def edit_comment(comment_id: int, data: ContentIn, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    comment = _first_or_404(session, CommunityComment, comment_id, "Comment not found")
    if not _is_owner(comment, user):
        raise HTTPException(status_code=403, detail="내 댓글만 수정할 수 있습니다.")
    comment.content = data.content.strip()
    comment.updated_at = datetime.utcnow()
    session.add(comment)
    session.commit()
    session.refresh(comment)
    return {"message": "comment updated", "comment": _comment_payload(session, comment, user)}

@app.delete("/community/comments/{comment_id}")
def delete_comment(comment_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    comment = _first_or_404(session, CommunityComment, comment_id, "Comment not found")
    if not _is_owner(comment, user):
        raise HTTPException(status_code=403, detail="내 댓글만 삭제할 수 있습니다.")
    comment.deleted = True
    session.add(comment)
    session.commit()
    return {"message": "comment deleted", "comment_id": comment_id}

@app.post("/community/comments/{comment_id}/like")
def like_comment(comment_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    comment = _first_or_404(session, CommunityComment, comment_id, "Comment not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(CommentLike).where(CommentLike.comment_id == comment_id).where(CommentLike.username == viewer_key)).first()
    if not exists:
        session.add(CommentLike(comment_id=comment_id, username=viewer_key))
        comment.likes += 1
        session.add(comment)
        session.commit()
        session.refresh(comment)
    return {"is_liked": True, "like_count": comment.likes, "comment": _comment_payload(session, comment, user)}

@app.delete("/community/comments/{comment_id}/like")
def unlike_comment(comment_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    comment = _first_or_404(session, CommunityComment, comment_id, "Comment not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(CommentLike).where(CommentLike.comment_id == comment_id).where(CommentLike.username == viewer_key)).first()
    if exists:
        session.delete(exists)
        comment.likes = max(0, comment.likes - 1)
        session.add(comment)
        session.commit()
        session.refresh(comment)
    return {"is_liked": False, "like_count": comment.likes, "comment": _comment_payload(session, comment, user)}

@app.post("/community/comments/{comment_id}/report")
def report_comment(comment_id: int, data: ReportIn | None = None, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    comment = _first_or_404(session, CommunityComment, comment_id, "Comment not found")
    created = _record_report(session, target_type="comment", target_id=comment_id, user=user, reason=(data.reason if data else "부적절한 내용"))
    if created:
        comment.reports += 1
        session.add(comment)
    session.commit()
    return {"reported": True, "duplicated": not created, "report_count": comment.reports if _is_admin(user) else None}

@app.post("/community/comments/{comment_id}/replies")
def add_reply(comment_id: int, data: ContentIn, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    comment = _first_or_404(session, CommunityComment, comment_id, "Comment not found")
    display_name = user.nickname or _display_name_for_email(user.email)
    reply = CommunityReply(
        comment_id=comment_id,
        owner_user_id=user.id,
        username=display_name,
        avatar_color=_avatar_for_user(user),
        content=data.content.strip(),
    )
    if not reply.content:
        raise HTTPException(status_code=400, detail="content required")
    session.add(reply)
    # 새 답글의 PK를 알림에 정확히 연결하기 위해 commit 전에 flush합니다.
    session.flush()
    post = session.get(CommunityPost, comment.post_id)
    if post:
        _inc_activity_comment(post)
        session.add(post)
        _add_notification(
            session,
            target_user_id=comment.owner_user_id,
            target_username=comment.username,
            notification_type="reply",
            from_user=user,
            post_title=post.title,
            post_id=post.id or 0,
            context_text=reply.content,
            target_comment_id=comment.id,
            target_reply_id=reply.id,
        )
    session.commit()
    session.refresh(reply)
    return {"message": "reply created", "reply": _reply_payload(session, reply, user)}

@app.patch("/community/replies/{reply_id}")
def edit_reply(reply_id: int, data: ContentIn, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    reply = _first_or_404(session, CommunityReply, reply_id, "Reply not found")
    if not _is_owner(reply, user):
        raise HTTPException(status_code=403, detail="내 답글만 수정할 수 있습니다.")
    reply.content = data.content.strip()
    reply.updated_at = datetime.utcnow()
    session.add(reply)
    session.commit()
    session.refresh(reply)
    return {"message": "reply updated", "reply": _reply_payload(session, reply, user)}

@app.delete("/community/replies/{reply_id}")
def delete_reply(reply_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    reply = _first_or_404(session, CommunityReply, reply_id, "Reply not found")
    if not _is_owner(reply, user):
        raise HTTPException(status_code=403, detail="내 답글만 삭제할 수 있습니다.")
    reply.deleted = True
    session.add(reply)
    session.commit()
    return {"message": "reply deleted", "reply_id": reply_id}

@app.post("/community/replies/{reply_id}/like")
def like_reply(reply_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    reply = _first_or_404(session, CommunityReply, reply_id, "Reply not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(ReplyLike).where(ReplyLike.reply_id == reply_id).where(ReplyLike.username == viewer_key)).first()
    if not exists:
        session.add(ReplyLike(reply_id=reply_id, username=viewer_key))
        reply.likes += 1
        session.add(reply)
        session.commit()
        session.refresh(reply)
    return {"is_liked": True, "like_count": reply.likes, "reply": _reply_payload(session, reply, user)}

@app.delete("/community/replies/{reply_id}/like")
def unlike_reply(reply_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    reply = _first_or_404(session, CommunityReply, reply_id, "Reply not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(ReplyLike).where(ReplyLike.reply_id == reply_id).where(ReplyLike.username == viewer_key)).first()
    if exists:
        session.delete(exists)
        reply.likes = max(0, reply.likes - 1)
        session.add(reply)
        session.commit()
        session.refresh(reply)
    return {"is_liked": False, "like_count": reply.likes, "reply": _reply_payload(session, reply, user)}

@app.post("/community/replies/{reply_id}/report")
def report_reply(reply_id: int, data: ReportIn | None = None, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    reply = _first_or_404(session, CommunityReply, reply_id, "Reply not found")
    created = _record_report(session, target_type="reply", target_id=reply_id, user=user, reason=(data.reason if data else "부적절한 내용"))
    if created:
        reply.reports += 1
        session.add(reply)
    session.commit()
    return {"reported": True, "duplicated": not created, "report_count": reply.reports if _is_admin(user) else None}

def _report_target_payload(session: Session, report: CommunityReport) -> dict:
    model = {
        "post": CommunityPost,
        "comment": CommunityComment,
        "reply": CommunityReply,
    }.get(report.target_type)
    row = session.get(model, report.target_id) if model else None
    if row is None:
        return {"exists": False, "title": "삭제된 콘텐츠", "content": "", "author": "", "report_count": 0}
    title = getattr(row, "title", "") or f"{report.target_type} #{report.target_id}"
    return {
        "exists": not getattr(row, "deleted", False),
        "title": title,
        "content": getattr(row, "content", "") or "",
        "author": getattr(row, "username", "") or "",
        "report_count": getattr(row, "reports", 0) or 0,
    }


def _report_payload(session: Session, report: CommunityReport) -> dict:
    reporter = session.get(User, report.reporter_user_id) if report.reporter_user_id else None
    processor = session.get(User, report.processed_by_user_id) if report.processed_by_user_id else None
    return {
        "id": report.id,
        "target_type": report.target_type,
        "target_id": report.target_id,
        "reason": report.reason,
        "status": report.status,
        "admin_note": report.admin_note,
        "reporter": (reporter.nickname or reporter.email) if reporter else report.reporter_key,
        "processed_by": (processor.nickname or processor.email) if processor else "",
        "created_at": _utc_iso(report.created_at),
        "processed_at": _utc_iso(report.processed_at) if report.processed_at else None,
        "target": _report_target_payload(session, report),
    }


@app.get("/admin/community/reports")
def admin_get_reports(
    status: Optional[str] = None,
    session: Session = Depends(get_session),
    admin: User = Depends(_require_admin),
):
    reports = session.exec(select(CommunityReport)).all()
    if status and status != "all":
        reports = [row for row in reports if row.status == status]
    reports.sort(key=lambda row: (0 if row.status == "pending" else 1, -(row.id or 0)))
    all_rows = session.exec(select(CommunityReport)).all()
    summary = {
        "total": len(all_rows),
        "pending": len([row for row in all_rows if row.status == "pending"]),
        "resolved": len([row for row in all_rows if row.status == "resolved"]),
        "rejected": len([row for row in all_rows if row.status == "rejected"]),
    }
    return {"reports": [_report_payload(session, row) for row in reports], "summary": summary}


@app.patch("/admin/community/reports/{report_id}")
def admin_update_report(
    report_id: int,
    data: AdminReportPatchRequest,
    session: Session = Depends(get_session),
    admin: User = Depends(_require_admin),
):
    report = session.get(CommunityReport, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="신고 내역을 찾을 수 없습니다.")
    if data.status not in {"pending", "resolved", "rejected"}:
        raise HTTPException(status_code=400, detail="지원하지 않는 신고 상태입니다.")
    report.status = data.status
    report.admin_note = data.admin_note.strip()
    report.processed_by_user_id = admin.id if data.status != "pending" else None
    report.processed_at = datetime.utcnow() if data.status != "pending" else None
    if data.delete_content:
        model = {"post": CommunityPost, "comment": CommunityComment, "reply": CommunityReply}.get(report.target_type)
        row = session.get(model, report.target_id) if model else None
        if row is not None and hasattr(row, "deleted"):
            row.deleted = True
            session.add(row)
    session.add(report)
    session.commit()
    session.refresh(report)
    return {"report": _report_payload(session, report)}


def _notice_payload(notice: CommunityNotice) -> dict:
    return {
        "id": notice.id,
        "title": notice.title,
        "date": notice.date,
        "summary": notice.summary,
        "content": notice.content,
        "important": notice.important,
        "created_at": _utc_iso(notice.created_at),
        "updated_at": _utc_iso(notice.updated_at or notice.created_at or datetime.utcnow()),
    }


@app.get("/community/notices")
def get_notices(session: Session = Depends(get_session)):
    notices = session.exec(select(CommunityNotice)).all()
    notices = sorted(
        notices,
        key=lambda n: (1 if n.important else 0, n.updated_at or n.created_at or datetime.min, n.id or 0),
        reverse=True,
    )
    return {"notices": [_notice_payload(n) for n in notices]}


@app.get("/community/notices/pinned")
def get_pinned_notice(session: Session = Depends(get_session)):
    notices = session.exec(select(CommunityNotice)).all()
    notices = sorted(
        notices,
        key=lambda n: (1 if n.important else 0, n.updated_at or n.created_at or datetime.min, n.id or 0),
        reverse=True,
    )
    notice = notices[0] if notices else None
    return {"notice": _notice_payload(notice) if notice else None}


@app.get("/community/notices/{notice_id}")
def get_notice(notice_id: int, session: Session = Depends(get_session)):
    notice = session.get(CommunityNotice, notice_id)
    if not notice:
        raise HTTPException(status_code=404, detail="Notice not found")
    return {"notice": _notice_payload(notice)}


@app.post("/admin/community/notices", status_code=201)
def admin_create_notice(
    data: AdminNoticeRequest,
    session: Session = Depends(get_session),
    admin: User = Depends(_require_admin),
):
    title = data.title.strip()
    content = data.content.strip()
    if not title or not content:
        raise HTTPException(status_code=400, detail="공지 제목과 내용을 입력해 주세요.")
    now = datetime.utcnow()
    notice = CommunityNotice(
        owner_user_id=admin.id,
        title=title,
        date=now.strftime("%Y.%m.%d"),
        summary=data.summary.strip(),
        content=content,
        important=data.important,
        created_at=now,
        updated_at=now,
    )
    session.add(notice)
    session.commit()
    session.refresh(notice)
    return {"notice": _notice_payload(notice)}


@app.patch("/admin/community/notices/{notice_id}")
def admin_update_notice(
    notice_id: int,
    data: AdminNoticeRequest,
    session: Session = Depends(get_session),
    admin: User = Depends(_require_admin),
):
    notice = session.get(CommunityNotice, notice_id)
    if not notice:
        raise HTTPException(status_code=404, detail="Notice not found")
    title = data.title.strip()
    content = data.content.strip()
    if not title or not content:
        raise HTTPException(status_code=400, detail="공지 제목과 내용을 입력해 주세요.")
    notice.title = title
    notice.summary = data.summary.strip()
    notice.content = content
    notice.important = data.important
    notice.owner_user_id = admin.id
    notice.date = datetime.utcnow().strftime("%Y.%m.%d")
    notice.updated_at = datetime.utcnow()
    session.add(notice)
    session.commit()
    session.refresh(notice)
    return {"notice": _notice_payload(notice)}


@app.delete("/admin/community/notices/{notice_id}")
def admin_delete_notice(
    notice_id: int,
    session: Session = Depends(get_session),
    admin: User = Depends(_require_admin),
):
    notice = session.get(CommunityNotice, notice_id)
    if not notice:
        raise HTTPException(status_code=404, detail="Notice not found")
    session.delete(notice)
    session.commit()
    return {"deleted": True, "notice_id": notice_id}


def _clean_notification_post_text(value: Optional[str]) -> str:
    """Remove legacy separator-only values such as `|`, `ㅣ`, or `｜`."""
    text = " ".join((value or "").split()).strip()
    if not text:
        return ""
    if all(ch in "|ㅣ｜-·:;_ " for ch in text):
        return ""
    return text.strip("|ㅣ｜ ")


def _short_notification_context(value: Optional[str], limit: int = 60) -> str:
    text = _clean_notification_post_text(value)
    if not text:
        return ""
    return text if len(text) <= limit else f"{text[:limit]}…"


def _notification_post_title(session: Session, notification: CommunityNotification) -> str:
    """Return the current post title, falling back to a short content preview."""
    post = session.get(CommunityPost, notification.post_id)
    if post and not post.deleted:
        title = _clean_notification_post_text(post.title)
        if title:
            return title
        content = _short_notification_context(post.content, 42)
        if content:
            return content

    stored = _clean_notification_post_text(notification.post_title)
    return stored or "게시글"


def _legacy_notification_interaction_text(
    session: Session, notification: CommunityNotification
) -> str:
    """Best-effort recovery for notifications created before interaction IDs existed."""
    candidates: list[CommunityComment | CommunityReply] = []

    if notification.type == "comment":
        candidates = list(
            session.exec(
                select(CommunityComment)
                .where(CommunityComment.post_id == notification.post_id)
                .where(CommunityComment.username == notification.from_user)
                .where(CommunityComment.deleted == False)
            ).all()
        )
    elif notification.type == "reply" and notification.target_comment_id:
        candidates = list(
            session.exec(
                select(CommunityReply)
                .where(CommunityReply.comment_id == notification.target_comment_id)
                .where(CommunityReply.username == notification.from_user)
                .where(CommunityReply.deleted == False)
            ).all()
        )

    if not candidates or not notification.created_at:
        return ""

    closest = min(
        candidates,
        key=lambda row: abs((row.created_at - notification.created_at).total_seconds()),
    )
    # 너무 멀리 떨어진 작성물은 잘못 매칭될 수 있으므로 5분 이내만 사용합니다.
    distance = abs((closest.created_at - notification.created_at).total_seconds())
    if distance > 300:
        return ""
    return _short_notification_context(closest.content)


def _notification_context_text(session: Session, notification: CommunityNotification) -> str:
    """Return the content newly written by the actor who caused the notification.

    * comment notification: the newly added comment text
    * reply notification: the newly added reply text

    New rows keep both an immutable snapshot in ``context_text`` and the target
    row ID so edits can be reflected. Older rows are recovered by matching the
    actor and creation time when possible.
    """
    if notification.type == "comment" and notification.target_comment_id:
        comment = session.get(CommunityComment, notification.target_comment_id)
        if comment and not comment.deleted:
            current_comment = _short_notification_context(comment.content)
            if current_comment:
                return current_comment

    if notification.type == "reply" and notification.target_reply_id:
        reply = session.get(CommunityReply, notification.target_reply_id)
        if reply and not reply.deleted:
            current_reply = _short_notification_context(reply.content)
            if current_reply:
                return current_reply

    legacy_interaction = _legacy_notification_interaction_text(session, notification)
    if legacy_interaction:
        return legacy_interaction

    stored_context = _short_notification_context(notification.context_text)
    if stored_context:
        return stored_context

    return _notification_post_title(session, notification)


def _notification_payload(session: Session, notification: CommunityNotification) -> dict:
    return {
        "id": notification.id,
        "target_user_id": notification.target_user_id,
        "type": notification.type,
        "from_user": notification.from_user,
        "avatar_color": notification.avatar_color,
        "post_title": _notification_post_title(session, notification),
        "context_text": _notification_context_text(session, notification),
        "post_id": notification.post_id,
        "time_ago": notification.time_ago,
        "created_at": _utc_iso(notification.created_at),
        "read": notification.read,
        "username": notification.username,
    }


@app.get("/community/notifications")
def get_notifications(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    rows = session.exec(
        select(CommunityNotification).where(
            or_(
                CommunityNotification.target_user_id == user.id,
                CommunityNotification.username == (user.nickname or _display_name_for_email(user.email)),
            )
        )
    ).all()
    _, blocked_names = _blocked_author_sets(session, user)
    rows = [
        row
        for row in rows
        if (row.from_user or "").strip().lower() not in blocked_names
    ]
    rows = sorted(rows, key=lambda n: n.id or 0, reverse=True)
    return {"notifications": [_notification_payload(session, n) for n in rows]}

@app.patch("/community/notifications/read_all")
def read_all_notifications(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    rows = session.exec(
        select(CommunityNotification).where(
            or_(
                CommunityNotification.target_user_id == user.id,
                CommunityNotification.username == (user.nickname or _display_name_for_email(user.email)),
            )
        )
    ).all()
    for row in rows:
        row.read = True
        session.add(row)
    session.commit()
    return {"message": "all read"}

@app.patch("/community/notifications/{notification_id}/read")
def read_notification(notification_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    row = session.get(CommunityNotification, notification_id)
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    my_name = user.nickname or _display_name_for_email(user.email)
    if row.target_user_id is not None and row.target_user_id != user.id:
        raise HTTPException(status_code=403, detail="내 알림만 읽음 처리할 수 있습니다.")
    if row.target_user_id is None and row.username != my_name:
        raise HTTPException(status_code=403, detail="내 알림만 읽음 처리할 수 있습니다.")
    row.read = True
    session.add(row)
    session.commit()
    return {"message": "read"}

@app.post("/community/reviews")
def create_review(payload: dict, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    recipe_title = str(payload.get("recipe_title") or "").strip()
    content = str(payload.get("content") or "").strip()
    if not recipe_title or not content:
        raise HTTPException(status_code=400, detail="레시피 제목과 후기 내용을 입력해 주세요.")
    try:
        rating = int(payload.get("rating") or 5)
    except (TypeError, ValueError):
        rating = 5
    rating = max(1, min(5, rating))
    recipe_id = str(payload.get("recipe_id") or "").strip() or recipe_title
    recipe_image = str(payload.get("recipe_image") or "").strip() or IMG_STEAK
    username = user.nickname or _display_name_for_email(user.email)
    review = RecipeReview(
        owner_user_id=user.id,
        username=username,
        avatar_color=_avatar_for_user(user),
        recipe_title=recipe_title,
        recipe_image=recipe_image,
        rating=rating,
        content=content,
        date=datetime.utcnow().strftime("%Y.%m.%d"),
        likes=0,
        comment_count=0,
        recipe_id=recipe_id,
    )
    session.add(review)
    session.commit()
    session.refresh(review)
    return {"review": _review_payload(session, review, user)}

@app.get("/community/reviews")
def get_reviews(
    recipe_id: Optional[str] = None,
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    statement = select(RecipeReview).where(RecipeReview.deleted == False)
    if recipe_id is not None and recipe_id.strip():
        statement = statement.where(RecipeReview.recipe_id == recipe_id.strip())
    reviews = session.exec(statement).all()
    reviews = sorted(reviews, key=lambda r: (r.created_at, r.id or 0), reverse=True)
    return {"reviews": [_review_payload(session, r, user) for r in reviews]}


@app.get("/community/recipes/{recipe_id}/comments")
def get_recipe_comments(
    recipe_id: str,
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    rows = session.exec(
        select(RecipeComment)
        .where(RecipeComment.recipe_id == recipe_id)
        .where(RecipeComment.deleted == False)
    ).all()
    rows = sorted(rows, key=lambda row: (row.created_at, row.id or 0), reverse=True)
    return {"comments": [_recipe_comment_payload(row, user) for row in rows]}


@app.post("/community/recipes/{recipe_id}/comments")
def create_recipe_comment(
    recipe_id: str,
    payload: dict,
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    content = str(payload.get("content") or "").strip()
    if not content:
        raise HTTPException(status_code=400, detail="댓글 내용을 입력해 주세요.")
    if len(content) > 500:
        raise HTTPException(status_code=400, detail="댓글은 500자 이하로 입력해 주세요.")
    row = RecipeComment(
        recipe_id=recipe_id,
        recipe_title=str(payload.get("recipe_title") or "").strip(),
        owner_user_id=user.id,
        username=user.nickname or _display_name_for_email(user.email),
        avatar_color=_avatar_for_user(user),
        content=content,
    )
    session.add(row)
    session.commit()
    session.refresh(row)
    return {"comment": _recipe_comment_payload(row, user)}


@app.patch("/community/recipe-comments/{comment_id}")
def update_recipe_comment(
    comment_id: int,
    payload: dict,
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    row = session.get(RecipeComment, comment_id)
    if not row or row.deleted:
        raise HTTPException(status_code=404, detail="Recipe comment not found")
    if not _is_owner(row, user):
        raise HTTPException(status_code=403, detail="내 댓글만 수정할 수 있습니다.")
    content = str(payload.get("content") or "").strip()
    if not content:
        raise HTTPException(status_code=400, detail="댓글 내용을 입력해 주세요.")
    if len(content) > 500:
        raise HTTPException(status_code=400, detail="댓글은 500자 이하로 입력해 주세요.")
    row.content = content
    row.updated_at = datetime.utcnow()
    session.add(row)
    session.commit()
    session.refresh(row)
    return {"comment": _recipe_comment_payload(row, user)}


@app.delete("/community/recipe-comments/{comment_id}")
def delete_recipe_comment(
    comment_id: int,
    session: Session = Depends(get_session),
    user: User = Depends(_current_user),
):
    row = session.get(RecipeComment, comment_id)
    if not row or row.deleted:
        raise HTTPException(status_code=404, detail="Recipe comment not found")
    if not _is_owner(row, user):
        raise HTTPException(status_code=403, detail="내 댓글만 삭제할 수 있습니다.")
    row.deleted = True
    row.updated_at = datetime.utcnow()
    session.add(row)
    session.commit()
    return {"message": "recipe comment deleted", "comment_id": comment_id}


@app.post("/community/reviews/{review_id}/like")
def like_review(review_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    review = session.get(RecipeReview, review_id)
    if not review or getattr(review, "deleted", False):
        raise HTTPException(status_code=404, detail="Review not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(ReviewLike).where(ReviewLike.review_id == review_id).where(ReviewLike.username == viewer_key)).first()
    if not exists:
        session.add(ReviewLike(review_id=review_id, username=viewer_key))
        review.likes += 1
        session.add(review)
        session.commit()
    return {"is_liked": True, "like_count": review.likes}

@app.delete("/community/reviews/{review_id}/like")
def unlike_review(review_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    review = session.get(RecipeReview, review_id)
    if not review or getattr(review, "deleted", False):
        raise HTTPException(status_code=404, detail="Review not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(ReviewLike).where(ReviewLike.review_id == review_id).where(ReviewLike.username == viewer_key)).first()
    if exists:
        session.delete(exists)
        review.likes = max(0, review.likes - 1)
        session.add(review)
        session.commit()
    return {"is_liked": False, "like_count": review.likes}


UNSPLASH_BASE = "https://images.unsplash.com/photo-"
UNSPLASH_QUERY = "?w=800&h=520&fit=crop&auto=format"

def _u(photo_id: str) -> str:
    return f"{UNSPLASH_BASE}{photo_id}{UNSPLASH_QUERY}"

# 사용자가 제공한 Figma/React zip의 App.tsx IMGS 상수와 같은 원본 이미지 경로입니다.
IMG_PORK = _u("1548150914-c9f19106dbf6")
IMG_PORK2 = _u("1550388342-b3fd986e4e67")
IMG_EGG = _u("1590301157890-4810ed352733")
IMG_RICE = _u("1706513043845-afb903a8c4c5")
IMG_SHRIMP = _u("1625943553852-781c6dd46faa")
IMG_SHRIMP2 = _u("1633504581786-316c8002b1b9")
IMG_CHICKEN = _u("1683225757624-86943fb48966")
IMG_STEAK = _u("1565299715199-866c917206bb")
IMG_RISOTTO = _u("1595579547936-c3a0e6c171fc")
IMG_CHOP = _u("1677751632736-f0e9800186d2")
IMG_PREP = _u("1690983323544-026a23725551")
IMG_KITCHEN = _u("1484154218962-a197022b5858")
IMG_TOAST = _u("1533089860892-a7c6f0a88666")

# Flutter의 기존 RecipeMockData와 동일한 7개 레시피입니다.
# 서버 시작 시 SQLite recipes/recipe_steps 테이블에 동기화되며,
# 앱은 더 이상 Dart 목데이터가 아니라 GET /recipes 응답을 사용합니다.
APP_RECIPE_CATALOG = [
    {
        "client_id": "rice",
        "title": "밥",
        "description": "백미 300g과 물 360g으로 완성하는 Graphene Square 공식 레시피",
        "thumbnail_url": "https://images.unsplash.com/photo-1580442151529-343f2f6e0e27?w=900&auto=format&fit=crop",
        "total_time_min": 40,
        "difficulty": "쉬움",
        "servings": 2,
        "compatibility_type": "fullAuto",
        "is_official": True,
        "author": "Graphene Square",
        "ingredients": [
            {"name": "백미", "amount": "300g", "is_required": True},
            {"name": "물", "amount": "360g", "is_required": True},
        ],
        "instruction_steps": [
            {"id": "rice-i1", "step_no": 1, "title": "밥 짓기", "description": "씻은 백미 300g과 물 360g을 용기에 넣고 가열합니다.", "linked_cooker_step_id": "rice-c1", "requires_user_action": False},
            {"id": "rice-i2", "step_no": 2, "title": "뜸 들이기", "description": "가열 완료 후 뚜껑을 열지 않고 그대로 5분간 뜸을 들입니다.", "estimated_time_min": 5, "requires_user_action": False},
        ],
        "cooker_steps": [
            {"id": "rice-c1", "step_no": 1, "label": "밥 가열", "temperature": 250, "time_min": 35, "requires_user_confirmation_before_start": False},
        ],
        "aliases": ["밥", "그래핀 솥밥"],
    },
    {
        "client_id": "egg",
        "title": "계란찜",
        "description": "계란 6알과 정량 양념으로 완성하는 Graphene Square 공식 레시피",
        "thumbnail_url": "https://images.unsplash.com/photo-1729992354928-61ac0843c797?w=900&auto=format&fit=crop",
        "total_time_min": 20,
        "difficulty": "쉬움",
        "servings": 3,
        "compatibility_type": "fullAuto",
        "is_official": True,
        "author": "Graphene Square",
        "ingredients": [
            {"name": "계란", "amount": "6알", "is_required": True},
            {"name": "물", "amount": "150g", "is_required": True},
            {"name": "참치액", "amount": "4g", "is_required": True},
            {"name": "설탕", "amount": "2g", "is_required": True},
        ],
        "instruction_steps": [
            {"id": "egg-i1", "step_no": 1, "title": "계란찜 조리", "description": "계란, 물, 참치액, 설탕을 충분히 섞어 용기에 넣고 뚜껑을 닫아 조리합니다.", "linked_cooker_step_id": "egg-c1", "requires_user_action": False},
        ],
        "cooker_steps": [
            {"id": "egg-c1", "step_no": 1, "label": "계란찜 가열", "temperature": 105, "time_min": 20, "requires_user_confirmation_before_start": False},
        ],
        "aliases": ["계란찜", "부드러운 계란찜"],
    },
    {
        "client_id": "pork",
        "title": "삼겹살 & 닭고기",
        "description": "예열한 쿠커에서 삼겹살 또는 닭고기를 굽는 Graphene Square 공식 레시피",
        "thumbnail_url": "https://images.unsplash.com/photo-1548150914-c9f19106dbf6?w=900&auto=format&fit=crop",
        "total_time_min": 18,
        "difficulty": "쉬움",
        "servings": 2,
        "compatibility_type": "fullAuto",
        "is_official": True,
        "author": "Graphene Square",
        "ingredients": [
            {"name": "삼겹살 또는 닭고기", "amount": "먹을 만큼", "is_required": True},
        ],
        "instruction_steps": [
            {"id": "pork-i1", "step_no": 1, "title": "고기 굽기", "description": "예열을 마친 쿠커에 삼겹살 또는 닭고기를 넣고 상태를 확인하며 굽습니다.", "linked_cooker_step_id": "pork-c1", "requires_user_action": False},
        ],
        "cooker_steps": [
            {"id": "pork-c1", "step_no": 1, "label": "고기 조리", "temperature": 105, "time_min": 18, "requires_user_confirmation_before_start": False},
        ],
        "aliases": ["삼겹살 & 닭고기", "갈바속 삼겹살 구이"],
    },
    {
        "client_id": "vegetables",
        "title": "채소찜",
        "description": "다채로운 채소를 용기 가득 담아 익히는 Graphene Square 공식 레시피",
        "thumbnail_url": "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=900&auto=format&fit=crop",
        "total_time_min": 25,
        "difficulty": "쉬움",
        "servings": 3,
        "compatibility_type": "fullAuto",
        "is_official": True,
        "author": "Graphene Square",
        "ingredients": [
            {"name": "파프리카", "amount": "노란색 위주", "is_required": True},
            {"name": "양파", "amount": "1개", "is_required": True},
            {"name": "아스파라거스", "amount": "적당량", "is_required": True},
            {"name": "방울토마토", "amount": "적당량", "is_required": True},
        ],
        "instruction_steps": [
            {"id": "vegetables-i1", "step_no": 1, "title": "채소 찌기", "description": "양파와 파프리카는 깍둑썰기하고 아스파라거스는 3등분한 뒤 방울토마토와 함께 용기 가득 담아 가열합니다. 상태에 따라 조리를 일찍 종료할 수 있습니다.", "linked_cooker_step_id": "vegetables-c1", "requires_user_action": False},
        ],
        "cooker_steps": [
            {"id": "vegetables-c1", "step_no": 1, "label": "채소 가열", "temperature": 250, "time_min": 25, "requires_user_confirmation_before_start": False},
        ],
        "aliases": ["채소찜", "허브 스테이크"],
    },
    {
        "client_id": "shrimp",
        "title": "마늘 버터 새우",
        "description": "마늘 향과 버터 풍미를 살린 빠른 팬 조리",
        "thumbnail_url": "https://images.unsplash.com/photo-1625943553852-781c6dd46faa?w=900&auto=format&fit=crop",
        "total_time_min": 12,
        "difficulty": "쉬움",
        "servings": 1,
        "compatibility_type": "guidedCook",
        "is_official": False,
        "author": "Graphene Square",
        "ingredients": [
            {"name": "새우", "amount": "200g", "is_required": True},
            {"name": "마늘", "amount": "4쪽", "is_required": True},
            {"name": "버터", "amount": "1큰술", "is_required": True},
            {"name": "소금", "amount": "약간", "is_required": True},
            {"name": "후추", "amount": "약간", "is_required": True},
        ],
        "instruction_steps": [
            {"id": "shrimp-i1", "step_no": 1, "title": "새우 손질", "description": "새우를 손질하고 물기를 제거합니다.", "requires_user_action": True, "action_label": "손질 완료"},
            {"id": "shrimp-i2", "step_no": 2, "title": "새우와 마늘 올리기", "description": "쿠커에 새우와 마늘을 올립니다.", "requires_user_action": True, "action_label": "올렸어요"},
            {"id": "shrimp-i3", "step_no": 3, "title": "새우 익히기", "description": "170℃에서 새우를 익힙니다.", "linked_cooker_step_id": "shrimp-c1", "requires_user_action": False},
            {"id": "shrimp-i4", "step_no": 4, "title": "버터 넣고 섞기", "description": "버터를 넣고 새우를 골고루 섞어주세요.", "requires_user_action": True, "action_label": "섞었어요"},
            {"id": "shrimp-i5", "step_no": 5, "title": "마무리 굽기", "description": "190℃에서 짧게 마무리합니다.", "linked_cooker_step_id": "shrimp-c2", "requires_user_action": False},
        ],
        "cooker_steps": [
            {"id": "shrimp-c1", "step_no": 1, "label": "새우 익히기", "temperature": 170, "time_min": 5, "requires_user_confirmation_before_start": False, "user_action_after_finish": "버터를 넣고 새우를 섞어주세요"},
            {"id": "shrimp-c2", "step_no": 2, "label": "마무리 굽기", "temperature": 190, "time_min": 4, "requires_user_confirmation_before_start": True, "user_action_before_start": "버터를 넣고 새우를 섞어주세요"},
        ],
        "aliases": ["마늘 버터 새우"],
    },
    {
        "client_id": "dakgalbi",
        "title": "멀티쿠커 닭갈비",
        "description": "재료를 단계별로 넣고 섞으며 완성하는 매콤한 닭갈비",
        "thumbnail_url": "https://images.unsplash.com/photo-1683225757624-86943fb48966?w=900&auto=format&fit=crop",
        "total_time_min": 25,
        "difficulty": "보통",
        "servings": 2,
        "compatibility_type": "complexGuidedCook",
        "is_official": False,
        "author": "Graphene Square",
        "ingredients": [
            {"name": "닭고기", "amount": "400g", "is_required": True},
            {"name": "양배추", "amount": "1/4통", "is_required": True},
            {"name": "고구마", "amount": "1개", "is_required": True},
            {"name": "떡", "amount": "한 줌", "is_required": True},
            {"name": "양념장", "amount": "150g", "is_required": True},
        ],
        "instruction_steps": [
            {"id": "dak-i1", "step_no": 1, "title": "닭고기 버무리기", "description": "닭고기를 양념장에 골고루 버무립니다.", "requires_user_action": True, "action_label": "버무렸어요"},
            {"id": "dak-i2", "step_no": 2, "title": "예열", "description": "쿠커를 예열합니다.", "linked_cooker_step_id": "dak-c1", "requires_user_action": False},
            {"id": "dak-i3", "step_no": 3, "title": "닭고기 1차 조리", "description": "닭고기를 먼저 넣고 조리합니다.", "linked_cooker_step_id": "dak-c2", "requires_user_action": False},
            {"id": "dak-i4", "step_no": 4, "title": "야채와 떡 추가", "description": "양배추, 고구마와 떡을 추가해 주세요.", "requires_user_action": True, "action_label": "추가했어요"},
            {"id": "dak-i5", "step_no": 5, "title": "재료 익히기", "description": "중간에 재료를 2~3회 섞어주세요.", "requires_user_action": True, "action_label": "섞었어요", "linked_cooker_step_id": "dak-c3"},
            {"id": "dak-i6", "step_no": 6, "title": "농도 확인", "description": "양념 농도를 확인한 뒤 마무리합니다.", "requires_user_action": True, "action_label": "확인했어요", "linked_cooker_step_id": "dak-c4"},
        ],
        "cooker_steps": [
            {"id": "dak-c1", "step_no": 1, "label": "예열", "temperature": 180, "time_min": 3, "requires_user_confirmation_before_start": False},
            {"id": "dak-c2", "step_no": 2, "label": "닭고기 1차 조리", "temperature": 180, "time_min": 8, "requires_user_confirmation_before_start": False, "user_action_after_finish": "야채와 떡을 추가해 주세요"},
            {"id": "dak-c3", "step_no": 3, "label": "재료 익히기", "temperature": 170, "time_min": 8, "requires_user_confirmation_before_start": False, "user_action_after_finish": "재료를 섞어주세요"},
            {"id": "dak-c4", "step_no": 4, "label": "양념 졸이기", "temperature": 200, "time_min": 3, "requires_user_confirmation_before_start": False, "user_action_before_start": "양념 농도를 확인해 주세요"},
        ],
        "aliases": ["멀티쿠커 닭갈비"],
    },
    {
        "client_id": "risotto",
        "title": "해산물 토마토 리조또",
        "description": "쿠커 조리와 직접 젓기를 함께 하는 토마토 리조또",
        "thumbnail_url": "https://images.unsplash.com/photo-1609770424775-39ec362f2d94?w=900&auto=format&fit=crop",
        "total_time_min": 20,
        "difficulty": "보통",
        "servings": 2,
        "compatibility_type": "partialCook",
        "is_official": False,
        "author": "Graphene Square",
        "ingredients": [
            {"name": "밥 또는 쌀", "amount": "2인분", "is_required": True},
            {"name": "해산물", "amount": "200g", "is_required": True},
            {"name": "토마토소스", "amount": "200ml", "is_required": True},
            {"name": "양파", "amount": "1/2개", "is_required": True},
            {"name": "육수", "amount": "300ml", "is_required": True},
        ],
        "instruction_steps": [
            {"id": "risotto-i1", "step_no": 1, "title": "재료 준비", "description": "양파와 해산물을 먹기 좋게 준비합니다.", "requires_user_action": True, "action_label": "준비 완료"},
            {"id": "risotto-i2", "step_no": 2, "title": "해산물 볶기", "description": "양파와 해산물을 먼저 볶습니다.", "linked_cooker_step_id": "risotto-c1", "requires_user_action": False},
            {"id": "risotto-i3", "step_no": 3, "title": "밥과 소스 추가", "description": "밥, 토마토소스와 육수를 넣습니다.", "requires_user_action": True, "action_label": "넣었어요"},
            {"id": "risotto-i4", "step_no": 4, "title": "중간 저어주기", "description": "바닥에 눌어붙지 않도록 중간중간 저어주세요.", "requires_user_action": True, "action_label": "저었어요", "linked_cooker_step_id": "risotto-c2"},
            {"id": "risotto-i5", "step_no": 5, "title": "농도 확인", "description": "농도를 확인하고 필요하면 육수를 추가합니다.", "requires_user_action": True, "action_label": "확인 완료"},
            {"id": "risotto-i6", "step_no": 6, "title": "마무리 가열", "description": "180℃에서 짧게 마무리합니다.", "linked_cooker_step_id": "risotto-c3", "requires_user_action": False},
        ],
        "cooker_steps": [
            {"id": "risotto-c1", "step_no": 1, "label": "해산물과 양파 볶기", "temperature": 170, "time_min": 4, "requires_user_confirmation_before_start": False},
            {"id": "risotto-c2", "step_no": 2, "label": "리조또 끓이기", "temperature": 150, "time_min": 10, "requires_user_confirmation_before_start": False, "user_action_after_finish": "농도를 확인해 주세요"},
            {"id": "risotto-c3", "step_no": 3, "label": "마무리 가열", "temperature": 180, "time_min": 3, "requires_user_confirmation_before_start": False},
        ],
        "aliases": ["해산물 토마토 리조또"],
    },
]


DEFAULT_RECIPE_THUMBNAILS = {
    "갈바속 삼겹살 구이": IMG_PORK,
    "부드러운 계란찜": IMG_EGG,
    "그래핀 솥밥": IMG_RICE,
    "마늘 버터 새우": IMG_SHRIMP,
    "허브 스테이크": IMG_STEAK,
    "10분 새우구이": IMG_SHRIMP2,
    "멀티쿠커 닭갈비": IMG_CHICKEN,
    "해산물 토마토 리조또": IMG_RISOTTO,
    "마늘 듬뿍 삼겹살 구이": IMG_PORK2,
    "밥": IMG_RICE,
    "계란찜": IMG_EGG,
    "삼겹살 & 닭고기": IMG_PORK,
    "채소찜": IMG_CHOP,
}

DEFAULT_RECIPE_CATALOG = [
    ("갈바속 삼겹살 구이", "멀티쿠커로 간편하게 굽는 바삭한 삼겹살. 허브솔트와 후추로 간단하게 완성.", "Graphene Square", True, [(180, 0), (180, 120), (200, 540)], IMG_PORK),
    ("부드러운 계란찜", "멀티쿠커로 완성하는 부드럽고 고소한 계란찜.", "Graphene Square", True, [(160, 0), (100, 300)], IMG_EGG),
    ("그래핀 솥밥", "센불→중불→약불 자동 조리로 완성하는 고슬고슬 솥밥.", "Graphene Square", True, [(220, 0), (160, 180), (120, 480), (80, 900)], IMG_RICE),
    ("마늘 버터 새우", "마늘 향 가득한 버터 새우. 15분 이내 완성.", "Graphene Square", True, [(170, 0), (190, 180)], IMG_SHRIMP),
    ("허브 스테이크", "로즈마리·버터 향 가득한 프리미엄 스테이크.", "Graphene Square", True, [(220, 0), (60, 240)], IMG_STEAK),
    ("10분 새우구이", "재료만 넣으면 10분 만에 완성되는 간편 새우구이.", "quick_cook99", False, [(190, 0)], IMG_SHRIMP2),
    ("멀티쿠커 닭갈비", "고추장 양념 닭갈비. 단계별 안내로 완성하는 정통 맛.", "cooking_joy", False, [(170, 0), (190, 480), (160, 1080)], IMG_CHICKEN),
    ("해산물 토마토 리조또", "크리미한 토마토 소스와 해산물의 만남.", "min_cook", False, [(160, 0), (140, 480)], IMG_RISOTTO),
    ("마늘 듬뿍 삼겹살 구이", "마늘을 넉넉히 넣어 풍미를 높인 삼겹살 구이.", "min_cook", False, [(180, 0), (200, 600)], IMG_PORK2),
]

LEGACY_RECIPE_TITLE_MAP = {
    "삼겹살 & 닭고기": ("갈바속 삼겹살 구이", IMG_PORK),
    "계란찜": ("부드러운 계란찜", IMG_EGG),
    "밥": ("그래핀 솥밥", IMG_RICE),
    "채소찜": ("허브 스테이크", IMG_STEAK),
}

def _asset_thumbnail_for_title(title: Optional[str]) -> str:
    normalized = (title or "").replace(" ", "").lower()
    if "밥" in normalized or "솥밥" in normalized or "rice" in normalized:
        return IMG_RICE
    if "계란" in normalized or "달걀" in normalized or "egg" in normalized:
        return IMG_EGG
    if "삼겹" in normalized or "고기" in normalized or "수육" in normalized or "갈비" in normalized or "pork" in normalized:
        return IMG_PORK
    if "채소" in normalized or "야채" in normalized or "vegetable" in normalized:
        return IMG_CHOP
    if "새우" in normalized or "shrimp" in normalized:
        return IMG_SHRIMP
    if "닭갈비" in normalized or "닭" in normalized or "chicken" in normalized:
        return IMG_CHICKEN
    if "리조또" in normalized or "risotto" in normalized:
        return IMG_RISOTTO
    if "볶음밥" in normalized:
        return IMG_KITCHEN
    if "스테이크" in normalized:
        return IMG_STEAK
    return IMG_KITCHEN

def _should_repair_image_url(url: Optional[str]) -> bool:
    if not url:
        return True
    value = url.strip()
    return value.startswith("assets/images/")

def _sync_app_recipe_catalog(session: Session) -> None:
    """Persist the Flutter starter catalog in SQLite and keep it in sync.

    Existing personal recipes are never changed. Older default-catalog rows are
    reused by title aliases when possible so saved-recipe foreign keys keep
    working. The public GET /recipes endpoint only exposes rows with one of the
    stable client ids below.
    """
    for order, data in enumerate(APP_RECIPE_CATALOG, start=1):
        client_id = str(data["client_id"])
        recipe = session.exec(
            select(RecipeRecord).where(RecipeRecord.client_id == client_id)
        ).first()

        if recipe is None:
            aliases = [str(value) for value in data.get("aliases", [])]
            aliases.append(str(data["title"]))
            for alias in aliases:
                candidate = session.exec(
                    select(RecipeRecord)
                    .where(RecipeRecord.is_personal == False)
                    .where(RecipeRecord.title == alias)
                ).first()
                if candidate is not None:
                    recipe = candidate
                    break

        if recipe is None:
            recipe = RecipeRecord(title=str(data["title"]))
            session.add(recipe)
            session.commit()
            session.refresh(recipe)

        recipe.owner_user_id = None
        recipe.client_id = client_id
        recipe.title = str(data["title"])
        recipe.description = str(data.get("description") or "")
        recipe.thumbnail_url = data.get("thumbnail_url")
        recipe.author = str(data.get("author") or "Graphene Square")
        recipe.is_personal = False
        recipe.is_gsq_suggested = True
        recipe.is_official = bool(data.get("is_official", False))
        recipe.total_time_min = max(1, int(data.get("total_time_min") or 10))
        recipe.difficulty = str(data.get("difficulty") or "쉬움")
        recipe.servings = max(1, int(data.get("servings") or 1))
        recipe.compatibility_type = str(data.get("compatibility_type") or "fullAuto")
        recipe.catalog_order = order
        recipe.ingredients_json = json.dumps(data.get("ingredients") or [], ensure_ascii=False)
        recipe.instruction_steps_json = json.dumps(
            data.get("instruction_steps") or [], ensure_ascii=False
        )
        recipe.cooker_steps_json = json.dumps(
            data.get("cooker_steps") or [], ensure_ascii=False
        )
        recipe.updated_at = datetime.utcnow()
        session.add(recipe)
        session.commit()
        session.refresh(recipe)

        # Keep the legacy temperature/time table populated for AI/search and
        # older app code. time_offset is cumulative seconds.
        for old_step in session.exec(
            select(RecipeStepRecord).where(RecipeStepRecord.recipe_id == recipe.id)
        ).all():
            session.delete(old_step)
        elapsed_seconds = 0
        for step_order, step in enumerate(data.get("cooker_steps") or [], start=1):
            elapsed_seconds += max(1, int(step.get("time_min") or 1)) * 60
            session.add(
                RecipeStepRecord(
                    recipe_id=recipe.id or 0,
                    temperature=float(step.get("temperature") or 0),
                    time_offset=float(elapsed_seconds),
                    label=str(step.get("label") or f"{step_order}단계 조리"),
                    sort_order=step_order,
                )
            )
        session.commit()


def _sync_default_recipe_catalog(session: Session):
    changed = False
    for recipe in session.exec(select(RecipeRecord)).all():
        mapped = LEGACY_RECIPE_TITLE_MAP.get(recipe.title)
        if mapped:
            recipe.title = mapped[0]
            recipe.thumbnail_url = mapped[1]
            recipe.description = next((row[1] for row in DEFAULT_RECIPE_CATALOG if row[0] == mapped[0]), recipe.description)
            recipe.author = "Graphene Square"
            recipe.is_gsq_suggested = True
            recipe.is_official = True
            session.add(recipe)
            changed = True
    if changed:
        session.commit()

    existing_titles = {row.title for row in session.exec(select(RecipeRecord)).all()}
    for title, desc, author, official, steps, thumbnail_url in DEFAULT_RECIPE_CATALOG:
        if title in existing_titles:
            recipe = session.exec(select(RecipeRecord).where(RecipeRecord.title == title)).first()
            if recipe:
                recipe.description = desc
                recipe.author = author
                recipe.is_personal = False
                recipe.is_gsq_suggested = True
                recipe.is_official = official
                recipe.thumbnail_url = thumbnail_url
                session.add(recipe)
            continue
        recipe = RecipeRecord(
            title=title,
            description=desc,
            author=author,
            is_personal=False,
            is_gsq_suggested=True,
            is_official=official,
            thumbnail_url=thumbnail_url,
        )
        session.add(recipe)
        session.commit()
        session.refresh(recipe)
        for index, (temp, offset) in enumerate(steps, start=1):
            session.add(RecipeStepRecord(recipe_id=recipe.id, temperature=temp, time_offset=offset, label=f"Step {index}", sort_order=index))
        session.commit()

def _repair_default_images(session: Session):
    changed = False
    for recipe in session.exec(select(RecipeRecord)).all():
        if _should_repair_image_url(recipe.thumbnail_url):
            recipe.thumbnail_url = DEFAULT_RECIPE_THUMBNAILS.get(recipe.title, _asset_thumbnail_for_title(recipe.title))
            session.add(recipe)
            changed = True
    for post in session.exec(select(CommunityPost)).all():
        if _should_repair_image_url(post.image_url):
            # 기본 시드 글 중 사진 카드가 비어 보이지 않도록 제목 기준 로컬 이미지를 부여합니다.
            if any(word in post.title for word in ["감자", "수육", "갈비"]):
                post.image_url = IMG_PORK
            elif any(word in post.title for word in ["점심", "된장", "고구마"]):
                post.image_url = IMG_CHOP
            else:
                continue
            session.add(post)
            changed = True
    for review in session.exec(select(RecipeReview)).all():
        if _should_repair_image_url(review.recipe_image):
            review.recipe_image = _asset_thumbnail_for_title(review.recipe_title)
            session.add(review)
            changed = True
    if changed:
        session.commit()

# -----------------------------------------------------------------------------
# Seed data
# -----------------------------------------------------------------------------
_seed_order_counter = 0


def _time_from_relative_label(label: str, *, now: Optional[datetime] = None) -> Optional[datetime]:
    value = (label or "").strip()
    current = now or datetime.utcnow()
    if not value:
        return None
    if value == "방금 전":
        return current
    if value == "어제":
        return current - timedelta(days=1)

    match = re.fullmatch(r"(\d+)분 전", value)
    if match:
        return current - timedelta(minutes=int(match.group(1)))
    match = re.fullmatch(r"(\d+)시간 전", value)
    if match:
        return current - timedelta(hours=int(match.group(1)))
    match = re.fullmatch(r"(\d+)일 전", value)
    if match:
        return current - timedelta(days=int(match.group(1)))
    return None


def _post(session: Session, **kwargs) -> CommunityPost:
    global _seed_order_counter
    if "created_at" not in kwargs:
        seed_time = _time_from_relative_label(str(kwargs.get("time_ago", "")))
        if seed_time is None:
            seed_time = datetime.utcnow() - timedelta(minutes=_seed_order_counter)
            _seed_order_counter += 1
        kwargs["created_at"] = seed_time
        kwargs["updated_at"] = seed_time
    post = CommunityPost(**kwargs)
    session.add(post)
    session.commit()
    session.refresh(post)
    return post

def _comment(session: Session, post_id: int, **kwargs) -> CommunityComment:
    if "created_at" not in kwargs:
        seed_time = _time_from_relative_label(str(kwargs.get("time_ago", ""))) or datetime.utcnow()
        kwargs["created_at"] = seed_time
        kwargs["updated_at"] = seed_time
    c = CommunityComment(post_id=post_id, **kwargs)
    session.add(c)
    session.commit()
    session.refresh(c)
    return c

def _reply(session: Session, comment_id: int, **kwargs) -> CommunityReply:
    if "created_at" not in kwargs:
        seed_time = _time_from_relative_label(str(kwargs.get("time_ago", ""))) or datetime.utcnow()
        kwargs["created_at"] = seed_time
        kwargs["updated_at"] = seed_time
    r = CommunityReply(comment_id=comment_id, **kwargs)
    session.add(r)
    session.commit()
    return r

def _ensure_user(session: Session, email: str, password: str, nickname: str) -> User:
    user = session.exec(select(User).where(User.email == email)).first()
    if user is None:
        user = User(email=email, password_hash=_hash(password), nickname=nickname, mobile="01000000000")
        session.add(user)
        session.commit()
        session.refresh(user)
    return user

def _seed_if_empty():
    with Session(engine) as session:
        default_user = _ensure_user(session, "user@graphene.com", "1234", DEFAULT_USER)
        _ensure_user(session, "11", "11", "11")
        _ensure_user(session, "student@graphene.com", "1234", "student")
        _sync_app_recipe_catalog(session)
        _repair_default_images(session)

        if session.exec(select(CommunityPost)).first() is not None:
            return

        p1 = _post(session, category="Q&A", username="쿠커초보", avatar_color=0xFF4A90D9, time_ago="10분 전", title="압력 조리 후 밥이 너무 무른 것 같아요", content="멀티쿠커로 처음 밥을 지었는데 너무 질어요. 물 비율을 어떻게 해야 할까요? 쌀 2컵에 물 몇 컵 넣으셨나요? 설명서엔 1:1이라고 나와 있는데 먹어보니까 너무 질어서요. 혹시 쌀 종류에 따라 다른가요?", likes=8, tags="밥짓기,압력조리", activity_d3_likes=4, activity_d3_comments=3, activity_d6_likes=6, activity_d6_comments=4, activity_d9_likes=8, activity_d9_comments=5, activity_d12_likes=8, activity_d12_comments=5)
        c = _comment(session, p1.id, username="요리고수", avatar_color=0xFF4CAF50, content="쌀 1컵에 물 0.8컵으로 맞춰보세요! 처음엔 살짝 적게 넣는 게 나아요.", time_ago="5분 전", likes=4)
        _reply(session, c.id, username="쿠커초보", avatar_color=0xFF4A90D9, content="감사해요! 내일 다시 해볼게요 ㅎㅎ", time_ago="2분 전", likes=1)
        _comment(session, p1.id, username="주부9단", avatar_color=0xFFE91E63, content="저도 처음에 그랬어요. 물을 평소보다 20% 줄이면 딱 좋더라고요!", time_ago="3분 전", likes=2)

        p2 = _post(session, owner_user_id=default_user.id, category="자유", username=DEFAULT_USER, avatar_color=DEFAULT_AVATAR, time_ago="32분 전", title="감자 수육할 때 이 팁 쓰면 완전 부드러워요!", content="감자를 먼저 30분 찌고 나서 수육을 같이 넣으면 훨씬 부드럽고 맛이 배요. 마늘이랑 된장 조금 추가하면 국물이 진해져요. 오늘 두 번째로 만들어봤는데 역시 맛있네요. 여러분도 꼭 해보세요! 멀티쿠커 없인 못 살겠어요 이제.", likes=147, image_url=IMG_PORK, tags="감자수육,꿀팁", activity_d6_likes=20, activity_d6_comments=8, activity_d9_likes=30, activity_d9_comments=12, activity_d12_likes=35, activity_d12_comments=13)
        c = _comment(session, p2.id, username="홈쿡러버", avatar_color=0xFF2196F3, content="오 이거 진짜 꿀팁이네요! 내일 해볼게요 ㅎㅎ", time_ago="20분 전", likes=7)
        _reply(session, c.id, owner_user_id=default_user.id, username=DEFAULT_USER, avatar_color=DEFAULT_AVATAR, content="꼭 해보세요! 맛있을 거예요 ㅎㅎ", time_ago="18분 전", likes=3)
        c = _comment(session, p2.id, username="쿠커초보", avatar_color=0xFF4A90D9, content="감자 크기는 어떻게 자르셨어요?", time_ago="15분 전", likes=1)
        _reply(session, c.id, owner_user_id=default_user.id, username=DEFAULT_USER, avatar_color=DEFAULT_AVATAR, content="4등분 정도로 큼직하게 자르시면 돼요~", time_ago="13분 전", likes=5)
        _comment(session, p2.id, username="맛집탐방", avatar_color=0xFF9C27B0, content="저도 같은 방법으로 성공했어요! 진짜 부드럽더라고요.", time_ago="10분 전", likes=8)

        p3 = _post(session, category="자유", username="홈쿡러버", avatar_color=0xFF2196F3, time_ago="2시간 전", title="오늘 멀티쿠커로 만든 점심 인증~", content="고구마 찜이랑 된장찌개 동시에 완성! 멀티쿠커 진짜 신세계예요. 시간도 절약되고 맛도 훨씬 좋네요. 혼자 살면서 이렇게 간단하게 해 먹을 수 있다는 게 너무 좋아요. 앞으로 자주 올릴게요!", likes=234, image_url=IMG_CHOP, tags="오늘점심,인증", activity_d3_likes=52, activity_d3_comments=14, activity_d6_likes=55, activity_d6_comments=15, activity_d9_likes=55, activity_d9_comments=15, activity_d12_likes=55, activity_d12_comments=15)
        _comment(session, p3.id, username="주부9단", avatar_color=0xFFE91E63, content="와 예쁘게 차려놓으셨네요! 부럽다~", time_ago="1시간 전", likes=9)
        c = _comment(session, p3.id, username="맛집탐방", avatar_color=0xFF9C27B0, content="된장찌개 레시피도 올려주세요!", time_ago="1시간 전", likes=6)
        _reply(session, c.id, username="홈쿡러버", avatar_color=0xFF2196F3, content="다음에 올릴게요 ㅎㅎ 된장은 진짜 간단해요!", time_ago="50분 전", likes=4)

        _post(session, category="Q&A", username="새내기쿠커", avatar_color=0xFFFF5722, time_ago="3시간 전", title="찜 기능이랑 압력 기능 차이가 뭔가요?", content="설명서를 읽었는데 잘 이해가 안 가요. 고기 요리할 때 어떤 기능을 써야 더 맛있게 나오나요? 닭이랑 돼지고기 요리를 주로 하는데 추천 기능 알려주세요! 초보라서 잘 모르겠어요.", likes=15, tags="찜,압력", activity_d3_likes=8, activity_d3_comments=5, activity_d6_likes=10, activity_d6_comments=6, activity_d9_likes=12, activity_d9_comments=7, activity_d12_likes=12, activity_d12_comments=7)
        _post(session, category="자유", username="요리연구가", avatar_color=0xFF00BCD4, time_ago="어제", title="멀티쿠커 세척할 때 베이킹소다 쓰면 좋아요", content="냄새가 배었을 때 물+베이킹소다를 넣고 살짝 가열한 뒤 헹구면 훨씬 깔끔해집니다. 고기요리 후 냄새 제거할 때 특히 좋아요.", likes=92, tags="세척,관리", activity_d9_likes=18, activity_d9_comments=4, activity_d12_likes=22, activity_d12_comments=5)
        _post(session, category="Q&A", username="밥잘하고싶다", avatar_color=0xFF795548, time_ago="2일 전", title="죽 만들 때 바닥 눌어붙음 해결법 있을까요?", content="죽 기능을 써도 바닥에 살짝 눌어붙어요. 물을 더 넣어야 하는지, 중간에 저어줘야 하는지 궁금합니다.", likes=24, tags="죽,눌어붙음", activity_d6_likes=5, activity_d6_comments=2, activity_d9_likes=8, activity_d9_comments=3, activity_d12_likes=10, activity_d12_comments=4)
        _post(session, category="자유", username="쿠킹마스터", avatar_color=0xFF607D8B, time_ago="3일 전", title="냉동만두 찔 때 물 조금만 넣어도 되네요", content="찜망 쓰고 물을 바닥에 조금만 넣었는데도 촉촉하게 잘 쪄졌습니다. 시간은 12분 정도가 적당했어요.", likes=67, tags="만두,찜", activity_d9_likes=3, activity_d9_comments=1, activity_d12_likes=5, activity_d12_comments=2)
        _post(session, category="자유", username="주부9단", avatar_color=0xFFE91E63, time_ago="5일 전", title="갈비찜 자동 조리 성공했습니다", content="양념 재우고 자동 조리로 돌렸는데 고기가 부드럽게 잘 익었습니다. 중간에 감자만 추가해주면 완성도가 좋네요.", likes=168, image_url=IMG_PORK, tags="갈비찜,성공", activity_d3_likes=25, activity_d3_comments=9, activity_d6_likes=28, activity_d6_comments=10, activity_d9_likes=30, activity_d9_comments=11, activity_d12_likes=30, activity_d12_comments=11)

        notices = [
            CommunityNotice(title="커뮤니티 이용 안내", date="2026.07.02", summary="서로 존중하는 댓글 문화를 지켜주세요.", content="멀티쿠커 커뮤니티는 레시피와 사용 팁을 나누는 공간입니다. 욕설, 광고, 개인정보 노출 게시글은 숨김 처리될 수 있습니다.", important=True),
            CommunityNotice(title="레시피 후기 작성 기능 안내", date="2026.07.01", summary="레시피 상세 화면에서 후기를 작성할 수 있습니다.", content="후기 탭은 레시피 상세에서 작성된 후기들을 모아 보여줍니다. 별점과 사진을 함께 등록할 수 있도록 확장 예정입니다.", important=False),
        ]
        session.add_all(notices)
        session.add_all([
            CommunityNotification(type="comment", from_user="홈쿡러버", avatar_color=0xFF2196F3, post_title="감자 수육할 때 이 팁 쓰면 완전 부드러워요!", post_id=p2.id, time_ago="20분 전", created_at=_time_from_relative_label("20분 전") or datetime.utcnow(), read=False),
            CommunityNotification(type="comment", from_user="쿠커초보", avatar_color=0xFF4A90D9, post_title="감자 수육할 때 이 팁 쓰면 완전 부드러워요!", post_id=p2.id, time_ago="15분 전", created_at=_time_from_relative_label("15분 전") or datetime.utcnow(), read=False),
            CommunityNotification(type="reply", from_user="홈쿡러버", avatar_color=0xFF2196F3, post_title="감자수육 삼겹살 구이 레시피 진짜 대박이에요", post_id=p3.id, time_ago="45분 전", created_at=_time_from_relative_label("45분 전") or datetime.utcnow(), read=True),
        ])
        session.add_all([
            RecipeReview(username="맛집탐방", avatar_color=0xFF9C27B0, recipe_title="간장찜닭", recipe_image=IMG_CHICKEN, rating=5, content="양념이 잘 배고 닭고기가 부드러웠어요. 자동 조리라 편했습니다.", date="2026.07.02", likes=12, comment_count=3, recipe_id="1"),
            RecipeReview(username="홈쿡러버", avatar_color=0xFF2196F3, recipe_title="계란찜", recipe_image=IMG_EGG, rating=4, content="부드럽게 잘 됐어요. 물 양만 조금 줄이면 더 좋을 것 같습니다.", date="2026.07.01", likes=8, comment_count=1, recipe_id="2"),
        ])
        session.commit()



def _sync_design_notices():
    """Seed design notices once. Administrator edits must survive server restarts."""
    with Session(engine) as session:
        if session.exec(select(CommunityNotice)).first() is not None:
            return
        session.add_all([
            CommunityNotice(
                title="멀티쿠커 커뮤니티 이용 안내",
                date="2026.07.01",
                summary="커뮤니티를 더욱 즐겁게 이용하기 위한 기본 안내입니다.",
                content="""안녕하세요, 멀티쿠커 커뮤니티입니다 :)

모든 회원분들이 즐겁게 이용하실 수 있도록 아래 이용 안내를 꼭 읽어주세요.

■ 게시글 작성 시
• 요리와 관련된 내용을 자유롭게 작성해주세요.
• 타인을 비방하거나 불쾌감을 주는 게시글은 삭제될 수 있습니다.
• 광고성 게시글은 금지됩니다.

■ 댓글 작성 시
• 서로 존중하는 댓글 문화를 만들어주세요.
• 질문에는 친절하게 답변해주세요.

■ 후기 작성 시
• 레시피 페이지에서 직접 작성하신 후기는 커뮤니티 후기 탭에서도 확인할 수 있습니다.
• 솔직한 후기 작성을 권장드립니다.

커뮤니티를 사랑해주셔서 감사합니다 ♥""",
                important=True,
            ),
            CommunityNotice(
                title="레시피 등록 가이드라인 업데이트",
                date="2026.06.20",
                summary="더 좋은 레시피 등록을 위한 가이드라인이 업데이트되었습니다.",
                content="""레시피 등록 가이드라인이 업데이트되었습니다.

■ 주요 변경사항
• 사진 첨부 시 음식이 잘 보이는 밝은 사진을 권장합니다.
• 재료는 분량을 정확하게 기입해주세요.
• 조리 순서는 단계별로 명확하게 작성해주세요.
• 멀티쿠커 기능(압력, 찜, 구이 등)을 명시해주시면 더 좋아요.

자세한 내용은 레시피 작성 화면에서 확인하실 수 있습니다.""",
                important=True,
            ),
            CommunityNotice(
                title="6월 우수 레시피 이벤트 결과 발표",
                date="2026.06.10",
                summary="6월 이벤트에 참여해주신 모든 분들께 감사드립니다.",
                content="""6월 우수 레시피 이벤트에 많은 참여 감사드립니다!

■ 최우수 레시피
• 감자수육 삼겹살 구이 - 요리고수님

■ 우수 레시피
• 압력 닭볶음탕 - 주부9단님
• 멀티쿠커 요거트 - 쿠커매니아님

당첨자 분들께는 개별 연락 드리겠습니다. 감사합니다!""",
                important=False,
            ),
            CommunityNotice(
                title="서비스 점검 안내 (완료)",
                date="2026.05.25",
                summary="서비스 점검이 완료되었습니다. 이용에 불편을 드려 죄송합니다.",
                content="""안녕하세요.

5월 25일 오전 2시부터 4시까지 서비스 정기 점검이 진행되었습니다.

점검이 정상적으로 완료되어 서비스를 이용하실 수 있습니다.

이용에 불편을 드려 죄송합니다. 감사합니다.""",
                important=False,
            ),
            CommunityNotice(
                title="커뮤니티 기능 업데이트 안내",
                date="2026.05.10",
                summary="커뮤니티에 새로운 기능이 추가되었습니다.",
                content="""커뮤니티에 새로운 기능이 추가되었습니다!

■ 추가된 기능
• 댓글 답글 기능
• 인기 게시글 자동 분류 (최근 좋아요·댓글·답글 활동량 기준)
• 후기 탭에서 레시피 연동 후기 확인

앞으로도 더 편리한 커뮤니티를 만들어가겠습니다. 감사합니다!""",
                important=False,
            ),
        ])
        session.commit()

def _repair_legacy_community_times():
    """Convert old fixed Korean time labels into timestamps once, then clear the labels."""
    with Session(engine) as session:
        changed = False
        for model in (CommunityPost, CommunityComment, CommunityReply, CommunityNotification):
            for row in session.exec(select(model)).all():
                label = (getattr(row, "time_ago", "") or "").strip()
                if not label or label == "방금 전":
                    continue
                parsed = _time_from_relative_label(label)
                if parsed is None:
                    continue
                row.created_at = parsed
                if hasattr(row, "updated_at"):
                    row.updated_at = parsed
                row.time_ago = ""
                session.add(row)
                changed = True
        if changed:
            session.commit()


def _ensure_schema_columns():
    """Upgrade old local SQLite DB files created before per-account ownership was added."""
    db_path = os.path.join(BASE_DIR, "multicooker.db")
    if not os.path.exists(db_path):
        return
    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.cursor()
        upgrades = {
            "communitypost": [("owner_user_id", "INTEGER"), ("bookmarks", "INTEGER DEFAULT 0"), ("admin_popularity_boost", "INTEGER DEFAULT 0"), ("force_popular", "BOOLEAN DEFAULT 0")],
            "communitycomment": [("owner_user_id", "INTEGER")],
            "communityreply": [("owner_user_id", "INTEGER")],
            "communitynotice": [("owner_user_id", "INTEGER"), ("updated_at", "TIMESTAMP")],
            "communityreport": [("status", "TEXT DEFAULT 'pending'"), ("admin_note", "TEXT DEFAULT ''"), ("processed_by_user_id", "INTEGER"), ("processed_at", "TIMESTAMP")],
            "communitynotification": [
                ("target_user_id", "INTEGER"),
                ("context_text", "TEXT DEFAULT ''"),
                ("target_comment_id", "INTEGER"),
                ("target_reply_id", "INTEGER"),
            ],
            "recipereview": [
                ("owner_user_id", "INTEGER"),
                ("deleted", "BOOLEAN DEFAULT 0"),
                ("updated_at", "TIMESTAMP"),
            ],
            "registereddevice": [
                ("alias", "TEXT DEFAULT ''"),
                ("firmware_version", "TEXT DEFAULT ''"),
                ("auto_reconnect", "BOOLEAN DEFAULT 1"),
                ("last_connected_at", "TIMESTAMP"),
                ("updated_at", "TIMESTAMP"),
            ],
            "savedrecipe": [
                ("client_id", "TEXT DEFAULT ''"),
                ("title", "TEXT DEFAULT ''"),
                ("description", "TEXT DEFAULT ''"),
                ("thumbnail_url", "TEXT"),
                ("author", "TEXT DEFAULT 'Graphene Square'"),
                ("is_official", "BOOLEAN DEFAULT 0"),
                ("is_personal", "BOOLEAN DEFAULT 0"),
                ("total_time_min", "INTEGER DEFAULT 10"),
                ("max_temperature", "INTEGER DEFAULT 180"),
                ("steps_json", "TEXT DEFAULT '[]'"),
            ],
            "cookinghistory": [
                ("client_recipe_id", "TEXT DEFAULT ''"),
            ],
            "recipes": [
                ("client_id", "TEXT DEFAULT ''"),
                ("total_time_min", "INTEGER DEFAULT 10"),
                ("difficulty", "TEXT DEFAULT '쉬움'"),
                ("servings", "INTEGER DEFAULT 1"),
                ("compatibility_type", "TEXT DEFAULT 'fullAuto'"),
                ("catalog_order", "INTEGER DEFAULT 0"),
                ("ingredients_json", "TEXT DEFAULT '[]'"),
                ("instruction_steps_json", "TEXT DEFAULT '[]'"),
                ("cooker_steps_json", "TEXT DEFAULT '[]'"),
            ],
        }
        for table, columns in upgrades.items():
            existing_tables = {row[0] for row in cursor.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
            if table not in existing_tables:
                continue
            existing_columns = {row[1] for row in cursor.execute(f"PRAGMA table_info({table})").fetchall()}
            for name, type_name in columns:
                if name not in existing_columns:
                    cursor.execute(f"ALTER TABLE {table} ADD COLUMN {name} {type_name}")
        conn.commit()
    finally:
        conn.close()

@app.on_event("startup")
def on_startup():
    SQLModel.metadata.create_all(engine)
    _ensure_schema_columns()
    _seed_if_empty()
    _repair_legacy_community_times()
    _sync_design_notices()
