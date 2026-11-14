"""
Signed Media Access and Direct Upload Endpoints.
Fulfills Blueprint Section 20 & Section 23 (Privacy Requirements).
"""

import hashlib
import hmac
import mimetypes
import os
import time
import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import FileResponse
from jose import JWTError, jwt
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.config import settings
from ...core.dependencies import get_auth_context, AuthContext
from ...core.security import decode_guest_token
from ...db.models import MediaAsset, Project, Room, User
from ...db.session import get_db
from ...storage import get_storage_provider

router = APIRouter(prefix="/media", tags=["Media Storage"])
storage = get_storage_provider()


class SignedUploadRequest(BaseModel):
    room_id: str
    file_name: str
    content_type: str = "image/jpeg"
    asset_type: str = "original_photo"


class SignedUploadResponse(BaseModel):
    asset_id: str
    storage_key: str
    signed_upload_url: str
    expires_in_seconds: int = 3600


class SignedDownloadResponse(BaseModel):
    asset_id: str
    signed_url: str
    expires_in_seconds: int = 3600


@router.post("/signed-upload-url", response_model=SignedUploadResponse)
def get_signed_upload_url(
    req: SignedUploadRequest,
    auth: AuthContext = Depends(get_auth_context),
    db: Session = Depends(get_db),
):
    """
    Issues a secure, short-lived signed URL for direct upload to object storage.
    Section 20: Direct-to-object-storage signed uploads without passing through API payload.
    """
    if not auth.is_authenticated and not auth.is_guest:
        raise HTTPException(status_code=401, detail="Authentication required to request signed upload URL")

    room = db.query(Room).filter(Room.id == req.room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    if room.project and room.project.user_id != auth.user_id and auth.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to upload media to another user's room")

    ext = req.file_name.split(".")[-1] if "." in req.file_name else "jpg"
    storage_key = f"uploads/{room.project_id}/{room.id}/{uuid.uuid4().hex[:8]}.{ext}"

    # Record MediaAsset in database
    asset = MediaAsset(
        room_id=room.id,
        storage_key=storage_key,
        asset_type=req.asset_type,
        mime_type=req.content_type,
        is_private=True,
    )
    db.add(asset)
    db.commit()
    db.refresh(asset)

    signed_url = storage.get_signed_url(storage_key, expires_in=3600)
    return SignedUploadResponse(
        asset_id=asset.id,
        storage_key=storage_key,
        signed_upload_url=signed_url,
        expires_in_seconds=3600,
    )


@router.get("/{asset_id}/signed-url", response_model=SignedDownloadResponse)
def get_signed_download_url(
    asset_id: str,
    auth: AuthContext = Depends(get_auth_context),
    db: Session = Depends(get_db),
):
    """
    Returns time-limited signed URL for viewing sensitive room media.
    Section 23: Raw room media is never public.
    """
    if not auth.is_authenticated and not auth.is_guest:
        raise HTTPException(status_code=401, detail="Authentication required to view media asset")

    asset = db.query(MediaAsset).filter(MediaAsset.id == asset_id).first()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")

    # Authorize download: check project owner or admin (Blueprint Section 23)
    room = db.query(Room).filter(Room.id == asset.room_id).first()
    if room and room.project:
        if room.project.user_id != auth.user_id and auth.role != "admin":
            raise HTTPException(status_code=403, detail="Not authorized to access another user's private media asset")

    signed_url = storage.get_signed_url(asset.storage_key, expires_in=3600)
    return SignedDownloadResponse(
        asset_id=asset.id,
        signed_url=signed_url,
        expires_in_seconds=3600,
    )


@router.delete("/{asset_id}")
def delete_media_asset(
    asset_id: str,
    auth: AuthContext = Depends(get_auth_context),
    db: Session = Depends(get_db),
):
    """
    Blueprint Section 23 (Privacy Requirements):
    Deletes sensitive media asset both from database and underlying object storage.
    """
    if not auth.is_authenticated and not auth.is_guest:
        raise HTTPException(status_code=401, detail="Authentication required to delete media asset")

    asset = db.query(MediaAsset).filter(MediaAsset.id == asset_id).first()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")

    # Authorize deletion: check project owner or admin
    room = db.query(Room).filter(Room.id == asset.room_id).first()
    if room and room.project:
        if room.project.user_id != auth.user_id and auth.role != "admin":
            raise HTTPException(status_code=403, detail="Not authorized to delete this media asset")

    # Delete physical object from storage
    try:
        storage.delete_file(asset.storage_key)
    except Exception:
        pass  # Proceed even if already gone from storage

    db.delete(asset)
    db.commit()

    return {"status": "deleted", "asset_id": asset_id}


def serve_media_asset(
    file_path: str,
    request: Request,
    sig: Optional[str] = None,
    exp: Optional[int] = None,
    db: Session = None,
):
    """
    Blueprint Section 20 & 23, ADR-005 & ADR-008:
    Guards private room media assets against unauthenticated, unauthorized, or cross-user access.
    Supports either:
    1. Cryptographically verified time-limited HMAC signature (sig & exp query parameters).
    2. Valid Bearer token with project ownership / admin verification.
    Rejects path traversal, expired grants, unauthorized users, and missing assets.
    """
    # 1. Normalize path & prevent path traversal
    clean_path = os.path.normpath(file_path).replace("\\", "/")
    if ".." in clean_path or clean_path.startswith("/") or clean_path.startswith("./"):
        raise HTTPException(status_code=400, detail="Invalid path traversal detected in media request")

    base_storage_dir = os.path.abspath(settings.LOCAL_STORAGE_PATH)
    full_path = os.path.abspath(os.path.join(base_storage_dir, clean_path))
    if not full_path.startswith(base_storage_dir):
        raise HTTPException(status_code=403, detail="Access denied: path outside storage root")

    if not os.path.exists(full_path) or not os.path.isfile(full_path):
        raise HTTPException(status_code=404, detail="Media asset not found")

    # 2. Check for HMAC signed URL grant first
    is_signed_grant_valid = False
    if sig and exp is not None:
        current_ts = int(time.time())
        if exp < current_ts:
            raise HTTPException(status_code=403, detail="Media access grant has expired")

        sig_payload = f"{clean_path}:{exp}".encode("utf-8")
        expected_sig = hmac.new(settings.SECRET_KEY.encode("utf-8"), sig_payload, hashlib.sha256).hexdigest()[:16]

        if hmac.compare_digest(sig, expected_sig):
            is_signed_grant_valid = True
        else:
            raise HTTPException(status_code=403, detail="Invalid media signature grant")

    # 3. If signed grant is not used or invalid, authenticate via Bearer token or server-signed guest token
    if not is_signed_grant_valid:
        caller_user_id: Optional[str] = None
        caller_role: str = "homeowner"

        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.split(" ", 1)[1].strip()
            # Check if it's a signed guest token
            guest_payload = decode_guest_token(token)
            if guest_payload and "sub" in guest_payload:
                caller_user_id = str(guest_payload["sub"])
                caller_role = "guest"
            else:
                try:
                    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
                    caller_user_id = payload.get("sub")
                    caller_role = payload.get("role", "homeowner")
                except JWTError:
                    raise HTTPException(status_code=401, detail="Invalid or expired token")
        else:
            # Check for server-signed guest token in headers or cookies
            guest_token = (
                request.headers.get("X-Guest-Token")
                or request.headers.get("X-Guest-Session-ID")
                or request.headers.get("X-Session-ID")
                or request.headers.get("x-guest-token")
                or request.headers.get("x-guest-session-id")
                or request.cookies.get("guest_session_id")
                or request.cookies.get("guest_session_token")
            )
            if guest_token:
                guest_payload = decode_guest_token(guest_token.strip())
                if guest_payload and "sub" in guest_payload:
                    caller_user_id = str(guest_payload["sub"])
                    caller_role = "guest"

        if not caller_user_id:
            raise HTTPException(
                status_code=401,
                detail="Authentication required: Provide a valid Authorization Bearer token, signed guest token, or signed media grant",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # 4. Check Ownership / Role Authorization for caller
        if caller_role != "admin" and db:
            filename = os.path.basename(clean_path)
            asset = db.query(MediaAsset).filter(
                (MediaAsset.storage_key == clean_path) |
                (MediaAsset.storage_key == f"storage/{clean_path}") |
                (MediaAsset.storage_key.endswith(filename))
            ).first()

            target_room = None
            if asset:
                target_room = db.query(Room).filter(Room.id == asset.room_id).first()
            if not target_room:
                target_room = db.query(Room).filter(
                    (Room.original_image_key.contains(filename))
                ).first()
            if not target_room:
                rooms = db.query(Room).all()
                for r in rooms:
                    if r.room_model_data:
                        raw_data = str(r.room_model_data)
                        if filename in raw_data:
                            target_room = r
                            break

            if target_room:
                project = db.query(Project).filter(Project.id == target_room.project_id).first()
                if project and project.user_id != caller_user_id:
                    raise HTTPException(
                        status_code=403,
                        detail="Not authorized to access another user's private room media"
                    )

    # 5. Serve file with detected Content-Type
    mime_type, _ = mimetypes.guess_type(full_path)
    return FileResponse(full_path, media_type=mime_type or "application/octet-stream")


@router.get("/secure-file/{file_path:path}")
def get_secure_media_file(
    file_path: str,
    request: Request,
    sig: Optional[str] = None,
    exp: Optional[int] = None,
    db: Session = Depends(get_db),
):
    """Secure media retrieval endpoint requiring valid signature or bearer authentication."""
    return serve_media_asset(file_path=file_path, request=request, sig=sig, exp=exp, db=db)
