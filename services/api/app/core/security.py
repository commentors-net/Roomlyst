"""
Security and Authentication Utilities for Roomlyst.
Handles password hashing via bcrypt and JWT token generation via python-jose.
"""

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional
import bcrypt
from jose import JWTError, jwt
from .config import settings


def hash_password(password: str) -> str:
    """Hashes a plaintext password using bcrypt with salt."""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plaintext password against a stored bcrypt hash."""
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8"),
        )
    except Exception:
        return False


import secrets

GUEST_TOKEN_TYPE = "guest_session"
DEFAULT_GUEST_EXPIRE_DAYS = 30


def create_access_token(
    subject: str,
    claims: Optional[Dict[str, Any]] = None,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Generates an encoded JWT access token with expiration."""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode: Dict[str, Any] = {
        "sub": str(subject),
        "type": "access_token",
        "iss": "roomlyst-api",
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    if claims:
        to_encode.update(claims)

    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """Decodes and validates a JWT access token for registered users."""
    if not token or not isinstance(token, str):
        return None
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        # Reject tokens explicitly marked as guest_session or with guest role
        if payload.get("type") == GUEST_TOKEN_TYPE or payload.get("role") == "guest" or payload.get("is_guest"):
            return None
        return payload
    except JWTError:
        return None


def create_guest_token(
    guest_id: Optional[str] = None,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Generates an unpredictable, cryptographically signed token for an ephemeral guest user.
    Fulfills Prompt 07: Prevents guest-session impersonation by requiring a server-validated
    cryptographic signature rather than trusting arbitrary client headers or raw IDs.
    """
    if not guest_id:
        # High entropy 128-bit random token
        entropy = secrets.token_hex(16)
        guest_id = f"usr_guest_{entropy}"

    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(days=DEFAULT_GUEST_EXPIRE_DAYS)

    to_encode: Dict[str, Any] = {
        "sub": str(guest_id),
        "type": GUEST_TOKEN_TYPE,
        "role": "guest",
        "is_guest": True,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_guest_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Decodes and validates a guest session token.
    Fails closed: returns payload only if the signature is authentic, unexpired,
    and bound to a guest session ('usr_guest_*'). Raw IDs, legacy usr_default,
    or tampered tokens return None.
    """
    if not token or not isinstance(token, str):
        return None
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        if not payload or "sub" not in payload:
            return None
        sub = str(payload["sub"])
        # Strict validation: must be a guest user ID and cannot be usr_default
        if not sub.startswith("usr_guest_") or sub == "usr_default":
            return None
        if payload.get("type") != GUEST_TOKEN_TYPE or not payload.get("is_guest"):
            return None
        return payload
    except JWTError:
        return None

