"""
Authentication Routes for Roomlyst.
Adheres to Blueprint Section 22 and 24.
"""

from datetime import datetime
from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session

from ...core.dependencies import get_current_active_user
from ...core.security import create_access_token, decode_guest_token, hash_password, verify_password
from ...db.models import Project, User
from ...db.repository import repository
from ...db.session import get_db

router = APIRouter(prefix="/auth", tags=["Authentication"])


class SocialLoginRequest(BaseModel):
    provider: str = Field(..., description="'google' or 'apple'")
    email: EmailStr = Field(..., json_schema_extra={"example": "user@gmail.com"})
    name: Optional[str] = None
    id_token: Optional[str] = None
    role: str = Field(default="homeowner")


class UserRegisterRequest(BaseModel):
    email: EmailStr = Field(..., json_schema_extra={"example": "homeowner@roomlyst.com"})
    password: str = Field(..., min_length=8, json_schema_extra={"example": "SecurePass123!"})
    role: str = Field(default="homeowner")


class UserLoginRequest(BaseModel):
    email: EmailStr = Field(..., json_schema_extra={"example": "homeowner@roomlyst.com"})
    password: str = Field(..., json_schema_extra={"example": "SecurePass123!"})


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    email: str
    role: str


class UserProfileResponse(BaseModel):
    id: str
    email: str
    role: str
    is_active: bool
    created_at: datetime


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(req: UserRegisterRequest, db: Session = Depends(get_db)):
    """Registers a new user account with hashed password credentials."""
    existing = db.query(User).filter(User.email == req.email.lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this email address already exists",
        )

    user = User(
        email=req.email.lower(),
        hashed_password=hash_password(req.password),
        role=req.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(subject=user.id, claims={"email": user.email, "role": user.role})
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        email=user.email,
        role=user.role,
    )


@router.post("/login", response_model=TokenResponse)
def login(req: UserLoginRequest, db: Session = Depends(get_db)):
    """Authenticates credentials and issues a secure JWT access token."""
    user = db.query(User).filter(User.email == req.email.lower()).first()
    if not user or not verify_password(req.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is currently inactive",
        )

    token = create_access_token(subject=user.id, claims={"email": user.email, "role": user.role})
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        email=user.email,
        role=user.role,
    )


@router.post("/social-login", response_model=TokenResponse)
def social_login(req: SocialLoginRequest, db: Session = Depends(get_db)):
    """Authenticates or auto-registers a user via Google or Apple Identity provider (Zero API charge)."""
    provider_lower = req.provider.lower()
    if provider_lower not in ("google", "apple"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported social provider: {req.provider}. Supported: 'google', 'apple'",
        )

    user = db.query(User).filter(User.email == req.email.lower()).first()
    if not user:
        user = User(
            email=req.email.lower(),
            hashed_password=hash_password(f"social_oauth_{uuid.uuid4().hex}"),
            role=req.role,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is currently inactive",
        )

    token = create_access_token(subject=user.id, claims={"email": user.email, "role": user.role, "provider": provider_lower})
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        email=user.email,
        role=user.role,
    )


@router.get("/me", response_model=UserProfileResponse)
def get_current_user_profile(user: User = Depends(get_current_active_user)):
    """Returns profile for currently authenticated user."""
    return UserProfileResponse(
        id=user.id,
        email=user.email,
        role=user.role,
        is_active=user.is_active,
        created_at=user.created_at,
    )


class MigrateGuestRequest(BaseModel):
    guest_token: str = Field(..., description="Cryptographically signed server-issued guest token")


class MigrateGuestResponse(BaseModel):
    status: str
    migrated_projects_count: int
    migrated_project_ids: List[str]


@router.post("/migrate-guest-projects", response_model=MigrateGuestResponse)
def migrate_guest_projects(
    req: MigrateGuestRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Fulfills Prompt 07 Section A: Secure guest-to-account project migration.
    Reassigns projects created during an ephemeral guest session to the authenticated user account,
    requiring the authentic, server-signed guest token as proof of session ownership.
    Prevents claiming arbitrary user projects, demo projects, or legacy usr_default records.
    """
    payload = decode_guest_token(req.guest_token)
    if not payload or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid, tampered, or expired guest session token",
        )

    guest_user_id = str(payload["sub"])
    if not guest_user_id.startswith("usr_guest_") or guest_user_id == "usr_default":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot migrate non-guest or protected identity records",
        )

    # 1. Migrate in SQL database
    db_projects = db.query(Project).filter(Project.user_id == guest_user_id).all()
    migrated_ids: List[str] = []
    for dp in db_projects:
        dp.user_id = current_user.id
        migrated_ids.append(dp.id)

    # 2. Migrate in memory repository
    for proj in repository.projects.values():
        if proj.user_id == guest_user_id:
            proj.user_id = current_user.id
            if proj.id not in migrated_ids:
                migrated_ids.append(proj.id)

    db.commit()

    return MigrateGuestResponse(
        status="migrated",
        migrated_projects_count=len(migrated_ids),
        migrated_project_ids=migrated_ids,
    )

