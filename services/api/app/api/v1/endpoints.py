"""
V1 REST Endpoints for Roomlyst API.
Compliant with Blueprint Section 7, 21, and 22.
"""

import io
import os
import uuid
from typing import List, Optional
from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile, status
from PIL import Image
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from packages.room_model import (
    CanonicalRoomModel,
    CaptureMetadata,
    DesignConstraint,
    DesignVersion,
    FeasibilityReport,
    ObjectAction,
    ReferenceScaleType,
)
from services.ai_worker.pipelines.generation import LocalRedesignGenerator
from services.ai_worker.pipelines.room_analyzer import RoomAnalyzer
from services.ai_worker.pipelines.multiview_analyzer import MultiViewRoomAnalyzer
from services.ai_worker.pipelines.scale_calibrator import ScaleCalibrator
from services.ai_worker.pipelines.feasibility_analyzer import GeometryAndFeasibilityAnalyzer
from ...core.rate_limit import rate_limit_general, rate_limit_generation
from ...core.sanitizer import sanitize_image
from ...db.models import Project, Room
from ...db.repository import ProjectRecord, repository
from ...db.session import get_db

router = APIRouter()

# Pipeline singletons
room_analyzer = RoomAnalyzer()
multiview_analyzer = MultiViewRoomAnalyzer()
scale_calibrator = ScaleCalibrator()
feasibility_analyzer = GeometryAndFeasibilityAnalyzer()
redesign_generator = LocalRedesignGenerator(output_dir="storage/outputs")
os.makedirs("storage/uploads", exist_ok=True)
os.makedirs("storage/outputs", exist_ok=True)


class DeviceCapabilityRequest(BaseModel):
    platform: str = Field(default="web", description="ios, android, web")
    device_model: Optional[str] = None
    has_lidar: bool = False
    has_ar: bool = False


class ProjectCreateRequest(BaseModel):
    name: str = Field(..., json_schema_extra={"example": "My Penthouse Renovation"})
    currency: str = Field(default="MYR", json_schema_extra={"example": "MYR"})


class ElementUpdateRequest(BaseModel):
    action: ObjectAction
    user_label_override: Optional[str] = None


class GenerateRedesignRequest(BaseModel):
    styles: List[str] = Field(default_factory=lambda: ["Warm Modern Minimalist"])
    goals: List[str] = Field(default_factory=lambda: ["increase_natural_light", "modernize_finishes"])
    budget_amount: Optional[float] = 15000.0
    budget_currency: str = "MYR"
    free_text_prompt: Optional[str] = None


@router.get("/devices/capabilities")
def get_device_capabilities(
    platform: str = "web",
    os_version: str = "1.0.0",
    device_model: Optional[str] = None,
    has_lidar: bool = False,
    has_hardware_depth: bool = False,
    has_ar: bool = False,
    has_arkit: bool = False,
    has_roomplan: bool = False,
    has_arcore: bool = False,
    has_arcore_depth: bool = False,
    has_motion_sensors: bool = True,
    camera_available: bool = True,
):
    """
    Evaluates runtime hardware capability tier and optimal scan mode.
    Fulfills Add-on Section 1, 2, 3, & 4 (Adaptive Device Capability and Scan Strategy).
    Hierarchy:
    1. Hardware LiDAR / dedicated depth sensor -> lidar_scan (Tier A)
    2. Platform depth API (RoomPlan / ARCore Depth) -> ar_depth_scan (Tier B)
    3. AR tracking + RGB camera -> ar_rgb_scan (Tier B)
    4. RGB video + motion -> rgb_video_scan (Tier C)
    5. Standard RGB camera -> rgb_photo_scan (Tier C)
    """
    scan_mode = "rgb_photo_scan"
    tier = "Tier C"
    guidance = "Capture Room: Take photos from room corners with good lighting."
    confidence = 0.70

    accuracy = "AI Vision Estimated (~ 10-15cm - Manual Confirmation Recommended)"
    if has_lidar:
        tier = "Tier A"
        scan_mode = "lidar_scan"
        guidance = "Scan Room: Point camera and walk around room to capture exact 3D geometry."
        accuracy = "Hardware 3D Precision (High Accuracy < 2cm)"
        confidence = 0.96
    elif has_hardware_depth or has_arcore_depth or (has_arkit and has_roomplan):
        tier = "Tier B"
        scan_mode = "ar_depth_scan"
        guidance = "Scan Room: Move smoothly across surfaces to map depth and walls."
        accuracy = "AR Depth Sensor (~ 3-5cm Accuracy)"
        confidence = 0.86
    elif has_ar or has_arkit or has_arcore:
        tier = "Tier B"
        scan_mode = "ar_rgb_scan"
        guidance = "Move slowly around room: Point at floor and walls to track boundaries."
        accuracy = "AR Motion Geometry (~ 5-8cm Approximate)"
        confidence = 0.78
    elif camera_available and has_motion_sensors:
        tier = "Tier C"
        scan_mode = "rgb_video_scan"
        guidance = "Walk around room: Record continuous view with overlapping angles."
        confidence = 0.74
    else:
        tier = "Tier C"
        scan_mode = "rgb_photo_scan"
        guidance = "Capture Room: Take photos from room corners with good lighting."
        confidence = 0.70

    from datetime import datetime, timezone
    return {
        "platform": platform,
        "os_version": os_version,
        "device_model": device_model or "Standard Smartphone",
        "camera_available": camera_available,
        "has_lidar": has_lidar,
        "has_hardware_depth": has_hardware_depth,
        "has_arkit": has_arkit,
        "has_roomplan": has_roomplan,
        "has_arcore": has_arcore,
        "has_arcore_depth": has_arcore_depth,
        "has_motion_sensors": has_motion_sensors,
        "capability_tier": tier,
        "scan_mode": scan_mode,
        "recommended_capture_mode": scan_mode,
        "user_guidance_prompt": guidance,
        "accuracy_assurance": accuracy,
        "capability_confidence": confidence,
        "lidar_supported": has_lidar,
        "ar_supported": has_ar or has_arkit or has_arcore,
        "camera_supported": camera_available,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@router.post("/projects", response_model=ProjectRecord)
def create_project(req: ProjectCreateRequest, db: Session = Depends(get_db)):
    proj_rec = repository.create_project(name=req.name, currency=req.currency)
    db_proj = Project(id=proj_rec.id, name=proj_rec.name, currency=proj_rec.currency, user_id="usr_default")
    db.add(db_proj)
    db.commit()
    return proj_rec


@router.get("/projects", response_model=List[ProjectRecord])
def list_projects():
    return repository.list_projects()


@router.get("/projects/{project_id}", response_model=ProjectRecord)
def get_project(project_id: str):
    proj = repository.get_project(project_id)
    if not proj:
        raise HTTPException(status_code=404, detail="Project not found")
    return proj


@router.delete("/projects/{project_id}")
def delete_project(project_id: str, db: Session = Depends(get_db)):
    """
    Blueprint Section 23 & 49:
    User can delete a project with cascading deletion of child rooms,
    media assets from object storage, measurements, jobs, and corrections.
    """
    deleted_rooms = 0
    deleted_assets = 0

    # Clean up SQL DB and underlying object storage files
    db_proj = db.query(Project).filter(Project.id == project_id).first()
    storage_provider = get_storage_provider()

    if db_proj:
        for room in db_proj.rooms:
            deleted_rooms += 1
            for asset in room.media_assets:
                deleted_assets += 1
                try:
                    storage_provider.delete_file(asset.storage_key)
                except Exception:
                    pass
            if room.original_image_key:
                try:
                    storage_provider.delete_file(room.original_image_key)
                except Exception:
                    pass
            if room.depth_map_key:
                try:
                    storage_provider.delete_file(room.depth_map_key)
                except Exception:
                    pass
        db.delete(db_proj)
        db.commit()

    # Clean in-memory repository
    if project_id in repository.projects:
        proj = repository.projects.pop(project_id, None)
        if proj:
            for rid in proj.room_ids:
                repository.rooms.pop(rid, None)

    return {
        "status": "deleted",
        "project_id": project_id,
        "deleted_rooms_count": deleted_rooms,
        "deleted_assets_count": deleted_assets,
        "message": "Project and all associated room data securely purged",
    }


@router.delete("/rooms/{room_id}")
def delete_room(room_id: str, db: Session = Depends(get_db)):
    """
    Deletes room and associated media assets from database and object storage.
    """
    db_room = db.query(Room).filter(Room.id == room_id).first()
    if not db_room and room_id not in repository.rooms:
        raise HTTPException(status_code=404, detail="Room not found")

    deleted_assets = 0
    storage_provider = get_storage_provider()
    if db_room:
        for asset in db_room.media_assets:
            deleted_assets += 1
            try:
                storage_provider.delete_file(asset.storage_key)
            except Exception:
                pass
        if db_room.original_image_key:
            try:
                storage_provider.delete_file(db_room.original_image_key)
            except Exception:
                pass
        db.delete(db_room)
        db.commit()

    # Clean in-memory repository
    repository.rooms.pop(room_id, None)
    for p in repository.projects.values():
        if room_id in p.room_ids:
            p.room_ids.remove(room_id)

    return {
        "status": "deleted",
        "room_id": room_id,
        "deleted_assets_count": deleted_assets,
    }


@router.post("/rooms/upload-and-analyze", response_model=CanonicalRoomModel, dependencies=[Depends(rate_limit_general)])
async def upload_and_analyze_room(
    file: UploadFile = File(...),
    room_name: str = Form(default="Living Room"),
    room_type: str = Form(default="living_room"),
    project_id: Optional[str] = Form(default=None),
    platform: str = Form(default="web"),
    has_lidar: bool = Form(default=False),
    has_hardware_depth: bool = Form(default=False),
    has_ar: bool = Form(default=False),
    has_arcore_depth: bool = Form(default=False),
    has_roomplan: bool = Form(default=False),
    scan_mode: Optional[str] = Form(default=None),
    db: Session = Depends(get_db),
):
    """
    Fulfills Milestone 0.4 & Section 20/22/23 & Add-on Section 2/8.
    Uploads single room photo, strips EXIF/GPS, runs quality check & CV pipeline, builds CanonicalRoomModel.
    """
    contents = await file.read()
    # Strip sensitive EXIF / GPS metadata prior to processing or persistence (Blueprint Section 23)
    contents = sanitize_image(contents)
    try:
        image = Image.open(io.BytesIO(contents))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid image format: {str(e)}")

    # Save original image to storage
    upload_ext = os.path.splitext(file.filename or "upload.jpg")[1] or ".jpg"
    upload_filename = f"room_{uuid.uuid4().hex[:8]}{upload_ext}"
    upload_path = os.path.join("storage/uploads", upload_filename)
    image.save(upload_path)

    effective_scan_mode = scan_mode or (
        "lidar_scan" if has_lidar
        else "ar_depth_scan" if (has_hardware_depth or has_arcore_depth or has_roomplan)
        else "ar_rgb_scan" if has_ar
        else "rgb_photo_scan"
    )
    effective_tier = "Tier A" if has_lidar else "Tier B" if (has_ar or has_hardware_depth or has_arcore_depth) else "Tier C"

    capture_meta = CaptureMetadata(
        platform=platform,
        has_lidar=has_lidar,
        has_hardware_depth=has_hardware_depth,
        has_ar=has_ar,
        has_arcore_depth=has_arcore_depth,
        has_roomplan=has_roomplan,
        capability_tier=effective_tier,
        scan_mode=effective_scan_mode,
        capability_confidence=0.96 if has_lidar else 0.86 if (has_hardware_depth or has_arcore_depth) else 0.78 if has_ar else 0.74,
    )

    # Execute room analyzer with adaptive capture metadata
    room = room_analyzer.analyze_photo(
        image=image,
        room_name=room_name,
        room_type=room_type,
        project_id=project_id,
        capture_metadata=capture_meta,
    )

    room.original_image_url = f"/storage/uploads/{upload_filename}"

    # Persist in memory repository
    repository.save_room(room)

    # Persist in SQL database
    db_proj = db.query(Project).filter(Project.id == room.project_id).first()
    if not db_proj:
        db_proj = Project(id=room.project_id, name="Default Project", user_id="usr_default")
        db.add(db_proj)
        db.commit()

    db_room = Room(
        id=room.id,
        project_id=db_proj.id,
        name=room.name,
        room_type=room.room_type,
        status=room.status,
        original_image_key=upload_path,
        room_model_data=room.model_dump(mode="json"),
    )
    db.add(db_room)

    from ...db.models import MeasurementRecord
    for m in room.measurements:
        meas_rec = MeasurementRecord(
            id=m.id,
            room_id=room.id,
            entity_type=m.entity_type,
            measurement_type=m.measurement_type,
            value=m.value,
            unit=m.unit,
            confidence=m.confidence,
            source=m.source.value,
            verified_by_user=m.verified_by_user,
        )
        db.add(meas_rec)
    db.commit()

    return room


@router.post("/rooms/multi-capture-and-analyze", response_model=CanonicalRoomModel, dependencies=[Depends(rate_limit_general)])
async def upload_and_analyze_multi_view(
    files: List[UploadFile] = File(...),
    viewpoint_labels: Optional[str] = Form(default=None),
    room_name: str = Form(default="Living Room"),
    room_type: str = Form(default="living_room"),
    project_id: Optional[str] = Form(default=None),
    platform: str = Form(default="ios"),
    has_lidar: bool = Form(default=False),
    has_hardware_depth: bool = Form(default=False),
    has_ar: bool = Form(default=True),
    has_arkit: bool = Form(default=False),
    has_roomplan: bool = Form(default=False),
    has_arcore: bool = Form(default=False),
    has_arcore_depth: bool = Form(default=False),
    scan_mode: Optional[str] = Form(default=None),
    db: Session = Depends(get_db),
):
    """
    Fulfills Milestone 2.1 & Blueprint Section 8.2 (Guided Multi-Photo Capture).
    Ingests multiple corner photos, rejects duplicates, performs cross-image feature
    association, validates coverage, and synthesizes a high-confidence CanonicalRoomModel.
    """
    if not files or len(files) == 0:
        raise HTTPException(status_code=400, detail="At least one room photo must be uploaded.")

    parsed_labels: List[str] = []
    if viewpoint_labels:
        parsed_labels = [l.strip() for l in viewpoint_labels.split(",") if l.strip()]

    images: List[Image.Image] = []
    saved_file_paths: List[str] = []

    for f in files:
        contents = await f.read()
        contents = sanitize_image(contents)
        try:
            img = Image.open(io.BytesIO(contents))
            images.append(img)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid image format: {str(e)}")

        ext = os.path.splitext(f.filename or "frame.jpg")[1] or ".jpg"
        fn = f"frame_{uuid.uuid4().hex[:8]}{ext}"
        fp = os.path.join("storage/uploads", fn)
        img.save(fp)
        saved_file_paths.append(fp)

    effective_scan_mode = scan_mode or (
        "lidar_scan" if has_lidar
        else "ar_depth_scan" if (has_hardware_depth or has_arcore_depth or has_roomplan)
        else "ar_rgb_scan" if has_ar
        else "rgb_video_scan" if len(files) > 1
        else "rgb_photo_scan"
    )
    effective_tier = "Tier A" if has_lidar else "Tier B" if (has_ar or has_hardware_depth or has_arcore_depth) else "Tier C"

    capture_meta = CaptureMetadata(
        platform=platform,
        has_lidar=has_lidar,
        has_hardware_depth=has_hardware_depth,
        has_ar=has_ar,
        has_arcore_depth=has_arcore_depth,
        has_roomplan=has_roomplan,
        capability_tier=effective_tier,
        scan_mode=effective_scan_mode,
        capability_confidence=0.96 if has_lidar else 0.88 if len(files) >= 2 else 0.74,
    )

    room = multiview_analyzer.analyze_multi_view(
        images=images,
        viewpoint_labels=parsed_labels,
        room_name=room_name,
        room_type=room_type,
        project_id=project_id,
        capture_metadata=capture_meta,
    )

    for i, frame in enumerate(room.frames):
        if i < len(saved_file_paths):
            frame.image_url = f"/{saved_file_paths[i].replace(os.sep, '/')}"

    if saved_file_paths:
        room.original_image_url = f"/{saved_file_paths[0].replace(os.sep, '/')}"

    repository.save_room(room)

    db_proj = db.query(Project).filter(Project.id == room.project_id).first()
    if not db_proj:
        db_proj = Project(id=room.project_id, name="Default Project", user_id="usr_default")
        db.add(db_proj)
        db.commit()

    db_room = Room(
        id=room.id,
        project_id=db_proj.id,
        name=room.name,
        room_type=room.room_type,
        status=room.status,
        original_image_key=saved_file_paths[0] if saved_file_paths else "storage/uploads/default.jpg",
        room_model_data=room.model_dump(mode="json"),
    )
    db.add(db_room)

    from ...db.models import MeasurementRecord, MediaAsset
    for fp in saved_file_paths:
        asset = MediaAsset(
            id=f"ast_{uuid.uuid4().hex[:8]}",
            room_id=room.id,
            asset_type="capture_frame",
            storage_key=fp,
            size_bytes=os.path.getsize(fp) if os.path.exists(fp) else 0,
            mime_type="image/jpeg",
        )
        db.add(asset)

    for m in room.measurements:
        meas_rec = MeasurementRecord(
            id=m.id,
            room_id=room.id,
            entity_type=m.entity_type,
            measurement_type=m.measurement_type,
            value=m.value,
            unit=m.unit,
            confidence=m.confidence,
            source=m.source.value,
            verified_by_user=m.verified_by_user,
        )
        db.add(meas_rec)

    db.commit()
    return room


@router.get("/rooms/{room_id}/model", response_model=CanonicalRoomModel)
def get_room_model(room_id: str):
    room = repository.get_room(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


@router.patch("/rooms/{room_id}/elements/{element_id}")
def update_room_element(room_id: str, element_id: str, update: ElementUpdateRequest):
    """
    Updates element action (KEEP, REPLACE, REMOVE, RESTYLE) or label override.
    Blueprint Section 15.
    """
    room = repository.get_room(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    elem = room.get_element_by_id(element_id)
    if not elem:
        raise HTTPException(status_code=404, detail="Room element not found")

    elem.action = update.action
    if update.user_label_override and hasattr(elem, "user_label_override"):
        elem.user_label_override = update.user_label_override

    repository.save_room(room)
    return {"status": "success", "element_id": element_id, "action": elem.action}


@router.post("/rooms/{room_id}/design-requests", response_model=DesignVersion, dependencies=[Depends(rate_limit_generation)])
def generate_room_design(room_id: str, req: GenerateRedesignRequest):
    """
    Fulfills Milestone 0.3 & 0.4.
    Compiles design constraints with keep/replace filters and generates 3 design variants.
    """
    room = repository.get_room(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    # Load original image
    if not room.original_image_url:
        raise HTTPException(status_code=400, detail="Room does not have an original image associated")

    local_img_path = room.original_image_url.lstrip("/")
    if not os.path.exists(local_img_path):
        raise HTTPException(status_code=404, detail="Original image file not found on disk")

    image = Image.open(local_img_path)

    # Compile strict design constraints from current room element statuses
    constraints = room.build_design_constraint(
        styles=req.styles,
        goals=req.goals,
        budget_amount=req.budget_amount,
        budget_currency=req.budget_currency,
        free_text=req.free_text_prompt,
    )

    result = redesign_generator.generate_redesigns(
        image=image,
        room_model=room,
        constraints=constraints,
        count=3,
    )

    repository.save_room(room)
    return result.data


@router.get("/rooms/{room_id}/versions", response_model=List[DesignVersion])
def get_room_versions(room_id: str):
    room = repository.get_room(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    return room.versions


# =====================================================================
# Milestone 1.1: Production Async Worker Pipeline Endpoints
# =====================================================================

from fastapi import BackgroundTasks, Depends
from sqlalchemy.orm import Session
from ...db.session import get_db
from ...db.models import Room, Project
from ...jobs.manager import job_manager
from ...storage import get_storage_provider


@router.post("/rooms/{room_id}/analyze-async", dependencies=[Depends(rate_limit_general)])
async def analyze_room_async(
    room_id: str,
    file: UploadFile = File(...),
    platform: str = Form(default="web"),
    has_lidar: bool = Form(default=False),
    has_hardware_depth: bool = Form(default=False),
    has_ar: bool = Form(default=False),
    has_arcore_depth: bool = Form(default=False),
    scan_mode: Optional[str] = Form(default=None),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db),
):
    """
    Fulfills Blueprint Section 19 & 23 & Add-on Section 2/8.
    Strips EXIF/GPS metadata, uploads to private storage, and asynchronously processes
    room photo through the validation, depth, segmentation, and room model pipeline via JobManager,
    calibrating measurement confidence and provenance from runtime device capabilities.
    """
    contents = await file.read()
    contents = sanitize_image(contents)
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        # Create default project and room if needed
        proj = db.query(Project).first()
        if not proj:
            proj = Project(name="Default Project", currency="MYR", user_id="usr_demo")
            db.add(proj)
            db.commit()
            db.refresh(proj)
        room = Room(id=room_id, project_id=proj.id, name="Living Room Scan")
        db.add(room)
        db.commit()

    storage_key = f"uploads/{room_id}/source.jpg"
    get_storage_provider().upload_file(storage_key, contents)
    room.original_image_key = storage_key
    db.commit()

    effective_scan_mode = scan_mode or (
        "lidar_scan" if has_lidar
        else "ar_depth_scan" if (has_hardware_depth or has_arcore_depth)
        else "ar_rgb_scan" if has_ar
        else "rgb_photo_scan"
    )
    effective_tier = "Tier A" if has_lidar else "Tier B" if (has_ar or has_hardware_depth or has_arcore_depth) else "Tier C"

    capture_meta = CaptureMetadata(
        platform=platform,
        has_lidar=has_lidar,
        has_hardware_depth=has_hardware_depth,
        has_ar=has_ar,
        has_arcore_depth=has_arcore_depth,
        capability_tier=effective_tier,
        scan_mode=effective_scan_mode,
        capability_confidence=0.96 if has_lidar else 0.86 if (has_hardware_depth or has_arcore_depth) else 0.78 if has_ar else 0.74,
    )

    job = job_manager.create_job(db, room_id=room_id, job_type="room_analysis")
    background_tasks.add_task(job_manager.execute_room_analysis, job.id, room_id, contents, capture_meta)

    return {
        "job_id": job.id,
        "room_id": room_id,
        "status": "CREATED",
        "current_step": "Job queued for processing",
    }


@router.post("/rooms/{room_id}/design-requests-async", dependencies=[Depends(rate_limit_generation)])
async def generate_redesign_async(
    room_id: str,
    req: GenerateRedesignRequest,
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: Session = Depends(get_db),
):
    """
    Fulfills Blueprint Section 19.
    Asynchronously synthesizes 3 design variants using compiled constraints.
    """
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room or not room.original_image_key or not room.room_model_data:
        raise HTTPException(status_code=404, detail="Room analysis data or image not found")

    image_bytes = get_storage_provider().download_file(room.original_image_key)
    room_model = CanonicalRoomModel.model_validate(room.room_model_data)

    constraints = room_model.build_design_constraint(
        styles=req.styles,
        goals=req.goals,
        budget_amount=req.budget_amount,
        budget_currency=req.budget_currency,
        free_text=req.free_text_prompt,
    )

    job = job_manager.create_job(db, room_id=room_id, job_type="redesign_generation")
    background_tasks.add_task(job_manager.execute_redesign, job.id, room_id, constraints, image_bytes)

    return {
        "job_id": job.id,
        "room_id": room_id,
        "status": "CREATED",
        "current_step": "Redesign job queued",
    }


# =====================================================================
# Milestone 1.4: User Confirmation, Correction & Verification Endpoints
# =====================================================================

class ElementCorrectionItem(BaseModel):
    element_id: str
    label_override: Optional[str] = None
    category_override: Optional[str] = None
    is_deleted: bool = False


class MeasurementVerifyRequest(BaseModel):
    verified_value: Optional[float] = None


@router.patch("/rooms/{room_id}/model/corrections", response_model=CanonicalRoomModel)
def apply_room_corrections(
    room_id: str,
    corrections: List[ElementCorrectionItem],
    db: Session = Depends(get_db),
):
    """
    Fulfills Blueprint Section 15 & Milestone 1.4:
    Users can correct AI misclassifications (e.g. relabel cabinet to door, delete false positives).
    """
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room or not room.room_model_data:
        raise HTTPException(status_code=404, detail="Room model data not found")

    room_model = CanonicalRoomModel.model_validate(room.room_model_data)

    from ...db.models import UserCorrectionRecord
    for item in corrections:
        elem = room_model.get_element_by_id(item.element_id)
        original_name = getattr(elem, "name", None) if elem else None

        room_model.apply_correction(
            element_id=item.element_id,
            label_override=item.label_override,
            category_override=item.category_override,
            is_deleted=item.is_deleted,
        )

        corr_rec = UserCorrectionRecord(
            room_id=room_id,
            element_id=item.element_id,
            correction_type="deleted" if item.is_deleted else "label_override",
            original_value=original_name,
            corrected_value=item.label_override or item.category_override,
        )
        db.add(corr_rec)

    room.room_model_data = room_model.model_dump(mode="json")
    db.commit()
    db.refresh(room)
    return room_model


@router.post("/rooms/{room_id}/measurements/{measurement_id}/verify")
def verify_measurement(
    room_id: str,
    measurement_id: str,
    req: MeasurementVerifyRequest,
    db: Session = Depends(get_db),
):
    """
    Fulfills Blueprint Section 11 & 12:
    Confirms an approximate measurement, transitioning provenance to USER_VERIFIED.
    """
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room or not room.room_model_data:
        raise HTTPException(status_code=404, detail="Room model data not found")

    room_model = CanonicalRoomModel.model_validate(room.room_model_data)
    success = room_model.verify_measurement(measurement_id, req.verified_value)
    if not success:
        raise HTTPException(status_code=404, detail="Measurement ID not found in room model")

    from ...db.models import MeasurementRecord
    meas_rec = db.query(MeasurementRecord).filter(
        MeasurementRecord.room_id == room_id,
        MeasurementRecord.id == measurement_id,
    ).first()
    if meas_rec:
        if req.verified_value is not None:
            meas_rec.value = req.verified_value
        meas_rec.verified_by_user = True
        meas_rec.source = "USER_VERIFIED"
        meas_rec.confidence = 1.0

    room.room_model_data = room_model.model_dump(mode="json")
    db.commit()

    return {
        "status": "success",
        "measurement_id": measurement_id,
        "verified_by_user": True,
        "source": "USER_VERIFIED",
    }


class ScaleCalibrationRequest(BaseModel):
    reference_type: str = Field(default="KNOWN_WALL_DIMENSION")
    target_real_value: float = Field(..., gt=0.0)
    reference_dimension_type: str = Field(default="width")
    reference_entity_id: Optional[str] = None
    notes: Optional[str] = None


@router.get("/rooms/scale-presets")
def get_scale_presets():
    """
    Fulfills Blueprint Section 12 & Milestone 2.2:
    Lists standard scale reference presets (A4 paper, door height, floor tile, credit card).
    """
    return scale_calibrator.get_presets()


@router.post("/rooms/{room_id}/scale-calibration", response_model=CanonicalRoomModel)
def calibrate_room_scale(
    room_id: str,
    req: ScaleCalibrationRequest,
    db: Session = Depends(get_db),
):
    """
    Fulfills Blueprint Section 12 & Milestone 2.2:
    Rescales all room dimensions and surface areas proportionally using a verified reference.
    Upgrades measurement provenance to REFERENCE_SCALED with high confidence.
    """
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room or not room.room_model_data:
        raise HTTPException(status_code=404, detail="Room model data not found")

    room_model = CanonicalRoomModel.model_validate(room.room_model_data)

    try:
        ref_type = ReferenceScaleType(req.reference_type)
    except ValueError:
        ref_type = ReferenceScaleType.KNOWN_WALL_DIMENSION

    scale_calibrator.calibrate(
        room=room_model,
        target_real_value=req.target_real_value,
        reference_type=ref_type,
        reference_dimension_type=req.reference_dimension_type,
        reference_entity_id=req.reference_entity_id,
        notes=req.notes,
    )
    # Re-evaluate spatial clearances and loop closures on rescaled dimensions
    feasibility_analyzer.analyze(room_model)

    room.room_model_data = room_model.model_dump(mode="json")
    from ...db.models import MeasurementRecord
    for m in room_model.measurements:
        meas_rec = db.query(MeasurementRecord).filter(
            MeasurementRecord.room_id == room_id,
            MeasurementRecord.id == m.id,
        ).first()
        if meas_rec:
            meas_rec.value = m.value
            meas_rec.source = m.source.value
            meas_rec.confidence = m.confidence
            meas_rec.verified_by_user = m.verified_by_user

    db.commit()
    repository.save_room(room_model)
    return room_model


@router.get("/rooms/{room_id}/feasibility", response_model=FeasibilityReport)
def get_room_feasibility(room_id: str, db: Session = Depends(get_db)):
    """
    Fulfills Blueprint Section 14 & Milestone 2.3:
    Evaluates wall loop closure, non-rectangular room geometry, door swing clearances,
    and inter-furniture circulation pathways.
    """
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room or not room.room_model_data:
        raise HTTPException(status_code=404, detail="Room model data not found")

    room_model = CanonicalRoomModel.model_validate(room.room_model_data)
    report = feasibility_analyzer.analyze(room_model)
    room.room_model_data = room_model.model_dump(mode="json")
    db.commit()
    repository.save_room(room_model)
    return report



