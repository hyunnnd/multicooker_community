from __future__ import annotations

import hashlib
import os
import re
import secrets
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Request, UploadFile, File
from fastapi.responses import FileResponse, RedirectResponse
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
UPLOAD_DIR = os.path.join(BASE_DIR, "local_uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
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

class PostBookmark(SQLModel, table=True):
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
    title: str
    date: str
    summary: str
    content: str
    important: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)

class CommunityNotification(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    target_user_id: Optional[int] = Field(default=None, index=True)
    type: str = "comment"
    from_user: str
    avatar_color: int
    post_title: str
    post_id: int
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
    created_at: datetime = Field(default_factory=datetime.utcnow)

class RecipeReview(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
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
    created_at: datetime = Field(default_factory=datetime.utcnow)

class ReviewLike(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    review_id: int = Field(index=True)
    username: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)

class RegisteredDevice(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    mac_address: str = Field(index=True)
    device_name: str = "Graphene Multi-Cooker"
    serial_number: str = "LOCAL-COOKER-001"
    verified: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)

class RecipeRecord(SQLModel, table=True):
    __tablename__ = "recipes"
    id: Optional[int] = Field(default=None, primary_key=True)
    owner_user_id: Optional[int] = Field(default=None, index=True)
    title: str = Field(index=True)
    description: Optional[str] = None
    thumbnail_url: Optional[str] = None
    author: str = "Graphene Square"
    is_personal: bool = False
    is_gsq_suggested: bool = False
    is_official: bool = False
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

def _activity(post: CommunityPost) -> dict:
    return {
        "d3": {"likes": post.activity_d3_likes, "comments": post.activity_d3_comments},
        "d6": {"likes": post.activity_d6_likes, "comments": post.activity_d6_comments},
        "d9": {"likes": post.activity_d9_likes, "comments": post.activity_d9_comments},
        "d12": {"likes": post.activity_d12_likes, "comments": post.activity_d12_comments},
    }

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

def _recipe_payload(session: Session, recipe: RecipeRecord, include_similarity: bool = False, similarity: float = 0.88) -> dict:
    payload = {
        "id": str(recipe.id),
        "title": recipe.title,
        "description": recipe.description,
        "thumbnail_url": recipe.thumbnail_url,
        "author": recipe.author,
        "is_personal": recipe.is_personal,
        "is_gsq_suggested": recipe.is_gsq_suggested,
        "is_official": recipe.is_official,
        "steps": [
            {"temperature": step.temperature, "time_offset": step.time_offset}
            for step in _recipe_steps(session, recipe.id or 0)
        ],
    }
    if include_similarity:
        payload["similarity"] = similarity
    return payload

def _liked_post(session: Session, post_id: int, username: str) -> bool:
    return session.exec(select(PostLike).where(PostLike.post_id == post_id).where(PostLike.username == username)).first() is not None

def _bookmarked_post(session: Session, post_id: int, username: str) -> bool:
    return session.exec(select(PostBookmark).where(PostBookmark.post_id == post_id).where(PostBookmark.username == username)).first() is not None

def _liked_comment(session: Session, comment_id: int, username: str) -> bool:
    return session.exec(select(CommentLike).where(CommentLike.comment_id == comment_id).where(CommentLike.username == username)).first() is not None

def _liked_reply(session: Session, reply_id: int, username: str) -> bool:
    return session.exec(select(ReplyLike).where(ReplyLike.reply_id == reply_id).where(ReplyLike.username == username)).first() is not None

def _reply_payload(session: Session, reply: CommunityReply, user: User) -> dict:
    viewer_key = _user_key(user)
    return {
        "id": reply.id,
        "username": reply.username,
        "avatar_color": reply.avatar_color,
        "content": reply.content,
        "time_ago": reply.time_ago,
        "likes": reply.likes,
        "is_liked": _liked_reply(session, reply.id, viewer_key),
        "is_mine": _is_owner(reply, user),
    }

def _comment_payload(session: Session, comment: CommunityComment, user: User) -> dict:
    viewer_key = _user_key(user)
    replies = session.exec(select(CommunityReply).where(CommunityReply.comment_id == comment.id).where(CommunityReply.deleted == False)).all()
    replies = sorted(replies, key=lambda r: r.id or 0)
    return {
        "id": comment.id,
        "username": comment.username,
        "avatar_color": comment.avatar_color,
        "content": comment.content,
        "time_ago": comment.time_ago,
        "likes": comment.likes,
        "is_liked": _liked_comment(session, comment.id, viewer_key),
        "is_mine": _is_owner(comment, user),
        "replies": [_reply_payload(session, r, user) for r in replies],
    }

def _post_payload(session: Session, post: CommunityPost, user: User) -> dict:
    viewer_key = _user_key(user)
    comments = session.exec(select(CommunityComment).where(CommunityComment.post_id == post.id).where(CommunityComment.deleted == False)).all()
    comments = sorted(comments, key=lambda c: c.id or 0)
    return {
        "id": post.id,
        "category": post.category,
        "username": post.username,
        "avatar_color": post.avatar_color,
        "time_ago": post.time_ago,
        "title": post.title,
        "content": post.content,
        "likes": post.likes,
        "bookmarks": post.bookmarks,
        "comments": [_comment_payload(session, c, user) for c in comments],
        "image_url": post.image_url,
        "tags": _tags_list(post.tags),
        "activity": _activity(post),
        "is_liked": _liked_post(session, post.id, viewer_key),
        "is_bookmarked": _bookmarked_post(session, post.id, viewer_key),
        "is_mine": _is_owner(post, user),
        "created_at": post.created_at.isoformat(),
    }

def _review_payload(session: Session, review: RecipeReview, user: User) -> dict:
    viewer_key = _user_key(user)
    liked = session.exec(select(ReviewLike).where(ReviewLike.review_id == review.id).where(ReviewLike.username == viewer_key)).first() is not None
    return {
        "id": review.id,
        "username": review.username,
        "avatar_color": review.avatar_color,
        "recipe_title": review.recipe_title,
        "recipe_image": review.recipe_image,
        "rating": review.rating,
        "content": review.content,
        "date": review.date,
        "likes": review.likes,
        "comment_count": review.comment_count,
        "recipe_id": review.recipe_id,
        "is_liked": liked,
    }

def _sort_posts(posts: list[CommunityPost], sort: str) -> list[CommunityPost]:
    if sort in {"popular", "likes"}:
        return sorted(posts, key=lambda p: (p.likes, p.activity_d3_likes + p.activity_d3_comments * 2, p.id or 0), reverse=True)
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

# -----------------------------------------------------------------------------
# Auth APIs - local DB only
# -----------------------------------------------------------------------------

@app.post("/auth/local_sync")
def local_auth_sync(data: LocalAuthSyncRequest, session: Session = Depends(get_session)):
    """
    Map a user authenticated by the company auth server to this local DB.

    The Flutter app calls this after company login so community/recipe/device APIs
    can still use local SQLite ownership, edit/delete permissions, notifications,
    likes, and bookmarks with a local bearer token.

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
    }


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

@app.post("/recipe/upload")
def upload_recipe(data: UploadRecipeRequest, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    if not data.steps:
        raise HTTPException(status_code=400, detail="steps required")
    recipe = RecipeRecord(
        owner_user_id=user.id,
        title=data.title.strip(),
        description=data.description,
        author=user.nickname or DEFAULT_USER,
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
    return {"message": "uploaded", "recipe": _recipe_payload(session, recipe)}

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
    rows = session.exec(select(RecipeRecord).where(RecipeRecord.is_gsq_suggested == True)).all()
    rows = sorted(rows, key=lambda r: r.id or 0)[:amount]
    return {"recipes": [_recipe_payload(session, row) for row in rows]}

@app.get("/recipe/recipe_titles")
def get_recipe_titles(session: Session = Depends(get_session)):
    rows = session.exec(select(RecipeRecord)).all()
    return {"recipe_titles": [row.title for row in rows]}

@app.get("/recipe/search_recipes/{title}")
def search_recipes(title: str, session: Session = Depends(get_session)):
    rows = session.exec(select(RecipeRecord)).all()
    query = title.lower().strip()
    for row in rows:
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
    if category and category not in {"전체", "인기"}:
        posts = [p for p in posts if p.category == category]
    if keyword:
        q = keyword.lower().strip()
        posts = [p for p in posts if q in " ".join([p.title, p.content, p.username, p.category, p.tags or ""]).lower()]
    posts = _sort_posts(posts, sort)[:limit]
    payload = [_post_payload(session, post, user) for post in posts]
    return {"posts": payload, "total_count": len(payload)}

@app.get("/community/posts/popular")
def get_popular_posts(days: int = 3, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    posts = session.exec(select(CommunityPost).where(CommunityPost.deleted == False)).all()
    windows = [days] if days in {3, 6, 9, 12} else [3, 6, 9, 12]
    if days == 3:
        windows = [3, 6, 9, 12]
    for d in windows:
        def score(post: CommunityPost) -> int:
            return {
                3: post.activity_d3_likes + post.activity_d3_comments * 2,
                6: post.activity_d6_likes + post.activity_d6_comments * 2,
                9: post.activity_d9_likes + post.activity_d9_comments * 2,
                12: post.activity_d12_likes + post.activity_d12_comments * 2,
            }[d]
        scored = sorted([p for p in posts if score(p) > 0], key=score, reverse=True)
        if scored:
            return {"days": d, "posts": [_post_payload(session, p, user) for p in scored]}
    return {"days": 0, "posts": []}

@app.get("/community/posts/{post_id}")
def get_post(post_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    return {"post": _post_payload(session, post, user)}

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

@app.post("/community/posts/{post_id}/bookmark")
def bookmark_post(post_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(PostBookmark).where(PostBookmark.post_id == post_id).where(PostBookmark.username == viewer_key)).first()
    if not exists:
        session.add(PostBookmark(post_id=post_id, username=viewer_key))
        post.bookmarks += 1
        session.add(post)
        session.commit()
        session.refresh(post)
    return {"is_bookmarked": True, "bookmark_count": post.bookmarks, "post": _post_payload(session, post, user)}

@app.delete("/community/posts/{post_id}/bookmark")
def unbookmark_post(post_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    viewer_key = _user_key(user)
    exists = session.exec(select(PostBookmark).where(PostBookmark.post_id == post_id).where(PostBookmark.username == viewer_key)).first()
    if exists:
        session.delete(exists)
        post.bookmarks = max(0, post.bookmarks - 1)
        session.add(post)
        session.commit()
        session.refresh(post)
    return {"is_bookmarked": False, "bookmark_count": post.bookmarks, "post": _post_payload(session, post, user)}

@app.post("/community/posts/{post_id}/report")
def report_post(post_id: int, data: ReportIn | None = None, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    post = _first_or_404(session, CommunityPost, post_id, "Post not found")
    created = _record_report(session, target_type="post", target_id=post_id, user=user, reason=(data.reason if data else "부적절한 내용"))
    if created:
        post.reports += 1
        session.add(post)
    session.commit()
    return {"reported": True, "duplicated": not created, "report_count": post.reports}

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
    _add_notification(
        session,
        target_user_id=post.owner_user_id,
        target_username=post.username,
        notification_type="comment",
        from_user=user,
        post_title=post.title,
        post_id=post_id,
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
    return {"reported": True, "duplicated": not created, "report_count": comment.reports}

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
    return {"reported": True, "duplicated": not created, "report_count": reply.reports}

@app.get("/community/notices")
def get_notices(session: Session = Depends(get_session)):
    notices = session.exec(select(CommunityNotice)).all()
    notices = sorted(notices, key=lambda n: n.id or 0)
    return {"notices": [n.model_dump() for n in notices]}

@app.get("/community/notices/pinned")
def get_pinned_notice(session: Session = Depends(get_session)):
    notice = session.exec(select(CommunityNotice).where(CommunityNotice.important == True).order_by(CommunityNotice.id)).first()
    if not notice:
        notice = session.exec(select(CommunityNotice).order_by(CommunityNotice.id)).first()
    return {"notice": notice.model_dump() if notice else None}

@app.get("/community/notices/{notice_id}")
def get_notice(notice_id: int, session: Session = Depends(get_session)):
    notice = session.get(CommunityNotice, notice_id)
    if not notice:
        raise HTTPException(status_code=404, detail="Notice not found")
    return {"notice": notice.model_dump()}

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
    rows = sorted(rows, key=lambda n: n.id or 0, reverse=True)
    return {"notifications": [n.model_dump() for n in rows]}

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
def get_reviews(session: Session = Depends(get_session), user: User = Depends(_current_user)):
    reviews = session.exec(select(RecipeReview)).all()
    reviews = sorted(reviews, key=lambda r: r.id or 0, reverse=True)
    return {"reviews": [_review_payload(session, r, user) for r in reviews]}

@app.post("/community/reviews/{review_id}/like")
def like_review(review_id: int, session: Session = Depends(get_session), user: User = Depends(_current_user)):
    review = session.get(RecipeReview, review_id)
    if not review:
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
    if not review:
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

def _post(session: Session, **kwargs) -> CommunityPost:
    global _seed_order_counter
    if "created_at" not in kwargs:
        seed_time = datetime.utcnow() - timedelta(minutes=_seed_order_counter)
        kwargs["created_at"] = seed_time
        kwargs["updated_at"] = seed_time
        _seed_order_counter += 1
    post = CommunityPost(**kwargs)
    session.add(post)
    session.commit()
    session.refresh(post)
    return post

def _comment(session: Session, post_id: int, **kwargs) -> CommunityComment:
    c = CommunityComment(post_id=post_id, **kwargs)
    session.add(c)
    session.commit()
    session.refresh(c)
    return c

def _reply(session: Session, comment_id: int, **kwargs) -> CommunityReply:
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
        _sync_default_recipe_catalog(session)
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
            CommunityNotification(type="comment", from_user="홈쿡러버", avatar_color=0xFF2196F3, post_title="감자 수육할 때 이 팁 쓰면 완전 부드러워요!", post_id=p2.id, time_ago="20분 전", read=False),
            CommunityNotification(type="comment", from_user="쿠커초보", avatar_color=0xFF4A90D9, post_title="감자 수육할 때 이 팁 쓰면 완전 부드러워요!", post_id=p2.id, time_ago="15분 전", read=False),
            CommunityNotification(type="reply", from_user="홈쿡러버", avatar_color=0xFF2196F3, post_title="감자수육 삼겹살 구이 레시피 진짜 대박이에요", post_id=p3.id, time_ago="45분 전", read=True),
        ])
        session.add_all([
            RecipeReview(username="맛집탐방", avatar_color=0xFF9C27B0, recipe_title="간장찜닭", recipe_image=IMG_CHICKEN, rating=5, content="양념이 잘 배고 닭고기가 부드러웠어요. 자동 조리라 편했습니다.", date="2026.07.02", likes=12, comment_count=3, recipe_id="1"),
            RecipeReview(username="홈쿡러버", avatar_color=0xFF2196F3, recipe_title="계란찜", recipe_image=IMG_EGG, rating=4, content="부드럽게 잘 됐어요. 물 양만 조금 줄이면 더 좋을 것 같습니다.", date="2026.07.01", likes=8, comment_count=1, recipe_id="2"),
        ])
        session.commit()



def _sync_design_notices():
    """Keep the local notice seed aligned with 앱 제작 요청 (4).zip."""
    with Session(engine) as session:
        for old in session.exec(select(CommunityNotice)).all():
            session.delete(old)
        session.commit()
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
• 게시글 북마크 기능
• 인기 게시글 자동 분류 (좋아요 100개 이상)
• 후기 탭에서 레시피 연동 후기 확인

앞으로도 더 편리한 커뮤니티를 만들어가겠습니다. 감사합니다!""",
                important=False,
            ),
        ])
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
            "communitypost": [("owner_user_id", "INTEGER")],
            "communitycomment": [("owner_user_id", "INTEGER")],
            "communityreply": [("owner_user_id", "INTEGER")],
            "communitynotification": [("target_user_id", "INTEGER")],
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
    _sync_design_notices()
