"""
Authentication and Authorization Dependencies for FastAPI Routes.
Adheres to Blueprint Section 24 (Security Requirements).
"""

from dataclasses import dataclass
from typing import Optional
from fastapi import Depends, HTTPException, Request, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from ..db.models import Project, Room, User
from ..db.repository import repository
from ..db.session import get_db
from .security import decode_access_token, decode_guest_token

security_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Extracts and validates JWT bearer token from request header."""
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(credentials.credentials)
    if not payload or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload["sub"]
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Authenticated user no longer exists",
        )
    return user


def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is deactivated",
        )
    return current_user


def get_current_admin_user(current_user: User = Depends(get_current_active_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required for this action",
        )
    return current_user


@dataclass
class AuthContext:
    user_id: str
    role: str
    is_authenticated: bool
    is_guest: bool
    guest_session_id: Optional[str] = None


def get_auth_context(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security_scheme),
    db: Session = Depends(get_db),
) -> AuthContext:
    """
    Extracts authenticated user, cryptographically verified guest session, or anonymous context.
    Adheres strictly to Prompt 07: Prevents guest-session impersonation by validating server-issued
    guest tokens. Raw UUIDs, arbitrary client headers, or tampered credentials fail closed.
    
    Precedence:
    1. Valid Bearer Token (Authorization: Bearer <jwt>)
       - Authenticated user: is_authenticated=True, is_guest=False
       - Signed guest token via Bearer: is_authenticated=False, is_guest=True
       - Invalid/expired token: fails closed to anonymous.
    2. Server-Signed Guest Token
       - Via header: X-Guest-Token, X-Guest-Session-ID, X-Session-ID
       - Via cookie: guest_session_id, guest_session_token
       - Verified via decode_guest_token(); unverified client IDs fail closed.
    3. Anonymous
       - user_id="", role="anonymous", is_authenticated=False, is_guest=False
    """
    # 1. Check Bearer token in Authorization header
    if credentials and credentials.credentials:
        token_str = credentials.credentials.strip()
        payload = decode_access_token(token_str)
        if payload and "sub" in payload:
            sub = str(payload["sub"])
            return AuthContext(
                user_id=sub,
                role=payload.get("role", "homeowner"),
                is_authenticated=True,
                is_guest=False,
                guest_session_id=None,
            )
        
        # Check if caller mistakenly sent a guest token as Bearer token
        guest_payload = decode_guest_token(token_str)
        if guest_payload:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Guest tokens cannot be used as Bearer access tokens. Transmit via X-Guest-Token header.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Bearer token was provided but failed decoding: fail closed with 401 (never silently downgrade)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Bearer access token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 2. Check for server-signed guest token in headers or cookies
    guest_token_header = (
        request.headers.get("X-Guest-Token")
        or request.headers.get("X-Guest-Session-ID")
        or request.headers.get("X-Session-ID")
        or request.headers.get("x-guest-token")
        or request.headers.get("x-guest-session-id")
    )
    guest_token_cookie = (
        request.cookies.get("guest_session_id")
        or request.cookies.get("guest_session_token")
    )

    if not guest_token_header and guest_token_cookie:
        # Cookie-only authentication on state-changing requests: CSRF defense
        if request.method in ("POST", "PUT", "DELETE", "PATCH"):
            sec_fetch = request.headers.get("sec-fetch-site")
            if sec_fetch == "cross-site":
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Cross-site state-changing request blocked by CSRF guard",
                )
            csrf_header = request.headers.get("X-CSRF-Token")
            if csrf_header and csrf_header.strip() != guest_token_cookie.strip():
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Mismatched CSRF token for cookie session",
                )

    guest_token = guest_token_header or guest_token_cookie
    if guest_token:
        payload = decode_guest_token(guest_token.strip())
        if payload and "sub" in payload:
            guest_id = str(payload["sub"])
            return AuthContext(
                user_id=guest_id,
                role="guest",
                is_authenticated=False,
                is_guest=True,
                guest_session_id=guest_token.strip(),
            )
        # Untrusted, tampered, expired, or raw client-provided ID: fail closed
        # Do NOT forge or accept arbitrary user IDs

    return AuthContext(
        user_id="",
        role="anonymous",
        is_authenticated=False,
        is_guest=False,
        guest_session_id=None,
    )


def verify_project_ownership(
    project_id: str,
    auth: AuthContext,
    db: Session,
    require_write: bool = False,
):
    """
    Verifies caller has authorization to access or mutate the given project.
    Fails closed with HTTP 401 (if unauthenticated) or HTTP 403 (if mismatched tenant).
    Admin users and authorized collaborators are permitted.
    Demo projects ('proj_demo_*') are permitted read-only.
    """
    if project_id.startswith("proj_demo_"):
        if require_write and auth.role != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Demo projects are read-only and cannot be modified",
            )
        proj = repository.get_project(project_id)
        if proj:
            return proj
        dp = db.query(Project).filter(Project.id == project_id).first()
        if dp:
            return dp
        raise HTTPException(status_code=404, detail="Project not found")

    dp = db.query(Project).filter(Project.id == project_id).first()
    proj = repository.get_project(project_id)
    if not dp and not proj:
        raise HTTPException(status_code=404, detail="Project not found")

    owner_id = dp.user_id if dp else (proj.user_id if proj else None)

    if auth.role == "admin":
        return proj or dp

    if owner_id in ("usr_demo", None):
        if require_write and not auth.is_authenticated and not auth.is_guest:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required to modify this project",
            )
        return proj or dp

    # Standard user / guest ownership verification
    if not auth.is_authenticated and not auth.is_guest:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required to access this project",
        )

    is_collab = proj and any(c.user_id == auth.user_id for c in proj.collaborators)
    if owner_id != auth.user_id and not is_collab:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access another user's project",
        )

    return proj or dp


def verify_room_ownership(
    room_id: str,
    auth: AuthContext,
    db: Session,
    require_write: bool = False,
):
    """
    Verifies caller has authorization to access or mutate the given room.
    Locates room in SQL DB or memory repository and checks parent project ownership.
    """
    db_room = db.query(Room).filter(Room.id == room_id).first()
    room = repository.get_room(room_id)
    if not db_room and not room:
        raise HTTPException(status_code=404, detail="Room not found")

    project_id = db_room.project_id if db_room else room.project_id
    verify_project_ownership(project_id=project_id, auth=auth, db=db, require_write=require_write)
    return room, db_room


