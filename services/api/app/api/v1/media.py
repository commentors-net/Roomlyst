"""
Signed Media Access and Direct Upload Endpoints.
Fulfills Blueprint Section 20 & Section 23 (Privacy Requirements).
"""

import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ...core.dependencies import get_current_active_user
from ...db.models import MediaAsset, Room, User
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
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Issues a secure, short-lived signed URL for direct upload to object storage.
    Section 20: Direct-to-object-storage signed uploads without passing through API payload.
    """
    room = db.query(Room).filter(Room.id == req.room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

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
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Returns time-limited signed URL for viewing sensitive room media.
    Section 23: Raw room media is never public.
    """
    asset = db.query(MediaAsset).filter(MediaAsset.id == asset_id).first()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")

    signed_url = storage.get_signed_url(asset.storage_key, expires_in=3600)
    return SignedDownloadResponse(
        asset_id=asset.id,
        signed_url=signed_url,
        expires_in_seconds=3600,
    )


@router.delete("/{asset_id}")
def delete_media_asset(
    asset_id: str,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Blueprint Section 23 (Privacy Requirements):
    Deletes sensitive media asset both from database and underlying object storage.
    """
    asset = db.query(MediaAsset).filter(MediaAsset.id == asset_id).first()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")

    # Authorize deletion: check project owner or admin
    room = db.query(Room).filter(Room.id == asset.room_id).first()
    if room and room.project:
        if room.project.user_id != current_user.id and current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Not authorized to delete this media asset")

    # Delete physical object from storage
    try:
        storage.delete_file(asset.storage_key)
    except Exception:
        pass  # Proceed even if already gone from storage

    db.delete(asset)
    db.commit()

    return {"status": "deleted", "asset_id": asset_id}
