"""
Authentication Routes for Roomlyst.
Adheres to Blueprint Section 22 and 24.
"""

from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session

from ...core.dependencies import get_current_active_user
from ...core.security import create_access_token, hash_password, verify_password
from ...db.models import User
from ...db.session import get_db

router = APIRouter(prefix="/auth", tags=["Authentication"])


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
