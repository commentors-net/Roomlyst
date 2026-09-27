"""
Admin Support & Telemetry Endpoints for Roomlyst API.
Adheres to Blueprint Section 23 (Audited Access), Section 29 (Admin Panel), & Section 30 (Cost Control).
Protected by get_current_admin_user (RBAC).
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from ...core.dependencies import get_current_admin_user
from ...db.models import AdminAuditLog, JobCostRecord, MediaAsset, ProcessingJob, Project, Room, User
from ...db.session import get_db
from ...jobs.manager import job_manager
from ...jobs.state_machine import JobStatus
from ...storage import get_storage_provider

router = APIRouter(prefix="/admin", tags=["Admin Operations"])
storage = get_storage_provider()


class RetryJobResponse(BaseModel):
    job_id: str
    status: str
    current_step: str
    message: str


class ElevatedMediaAccessRequest(BaseModel):
    reason: str = Field(..., min_length=5, description="Audited business justification (e.g. support ticket #)")


class ElevatedMediaAccessResponse(BaseModel):
    asset_id: str
    signed_url: str
    expires_in_seconds: int = 900
    audited: bool = True


class CostTelemetryResponse(BaseModel):
    total_compute_cost_usd: float
    total_generation_api_cost_usd: float
    total_cost_usd: float
    job_count: int
    breakdown_by_provider: Dict[str, float]
    breakdown_by_project: Dict[str, float]
    recent_records: List[Dict[str, Any]]


class AuditLogEntry(BaseModel):
    id: str
    admin_user_id: str
    action: str
    target_resource: Optional[str]
    reason: Optional[str]
    ip_address: Optional[str]
    created_at: datetime


@router.get("/jobs/failed")
def list_failed_jobs(
    limit: int = 50,
    current_admin: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    """
    Blueprint Section 29: Inspect processing errors & failed jobs.
    """
    failed_jobs = (
        db.query(ProcessingJob)
        .filter(ProcessingJob.status.in_([JobStatus.FAILED_RETRYABLE.value, JobStatus.FAILED_FINAL.value]))
        .order_by(ProcessingJob.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": j.id,
            "room_id": j.room_id,
            "job_type": j.job_type,
            "status": j.status,
            "error_message": j.error_message,
            "current_step": j.current_step,
            "latency_ms": j.latency_ms,
            "created_at": j.created_at.isoformat() if j.created_at else None,
        }
        for j in failed_jobs
    ]


@router.post("/jobs/{job_id}/retry", response_model=RetryJobResponse)
def retry_failed_job(
    job_id: str,
    request: Request,
    background_tasks: BackgroundTasks,
    current_admin: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    """
    Blueprint Section 29: Retry failed jobs with administrative auditing.
    """
    job = db.query(ProcessingJob).filter(ProcessingJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    room = db.query(Room).filter(Room.id == job.room_id).first()
    if not room or not room.original_image_key:
        raise HTTPException(status_code=400, detail="Cannot retry: source image no longer available")

    # Record administrative audit trail (Section 23 Item 11)
    client_ip = request.client.host if request.client else "unknown"
    audit_log = AdminAuditLog(
        admin_user_id=current_admin.id,
        action="retry_job",
        target_resource=f"job:{job.id}",
        reason="Administrative retry triggered from support panel",
        ip_address=client_ip,
    )
    db.add(audit_log)

    # Reset job status
    job.status = JobStatus.CREATED.value
    job.progress_percent = 0
    job.current_step = "Retrying job from admin console"
    job.error_message = None
    db.commit()

    # Re-dispatch background task based on job type
    image_bytes = storage.download_file(room.original_image_key)
    if job.job_type == "room_analysis":
        background_tasks.add_task(job_manager.execute_room_analysis, job.id, room.id, image_bytes)
    elif job.job_type == "redesign_generation":
        from packages.room_model import CanonicalRoomModel
        room_model = CanonicalRoomModel.model_validate(room.room_model_data)
        constraints = room_model.build_design_constraint()
        background_tasks.add_task(job_manager.execute_redesign, job.id, room.id, constraints, image_bytes)

    return RetryJobResponse(
        job_id=job.id,
        status="CREATED",
        current_step="Retrying job from admin console",
        message="Job successfully re-queued for processing",
    )


@router.get("/telemetry/costs", response_model=CostTelemetryResponse)
def get_cost_telemetry(
    current_admin: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    """
    Blueprint Section 30 & Section 49:
    Per-job and per-project processing cost is measurable from day one.
    """
    cost_records = db.query(JobCostRecord).order_by(JobCostRecord.created_at.desc()).all()

    total_compute = sum(r.estimated_compute_cost for r in cost_records)
    total_api = sum(r.generation_api_cost for r in cost_records)
    total_cost = sum(r.total_cost_usd for r in cost_records)

    by_provider: Dict[str, float] = {}
    by_project: Dict[str, float] = {}

    for r in cost_records:
        by_provider[r.provider] = round(by_provider.get(r.provider, 0.0) + r.total_cost_usd, 4)
        proj_key = r.project_id or "unassigned"
        by_project[proj_key] = round(by_project.get(proj_key, 0.0) + r.total_cost_usd, 4)

    recent = [
        {
            "id": r.id,
            "job_id": r.job_id,
            "project_id": r.project_id,
            "provider": r.provider,
            "model": r.model,
            "input_size": r.input_size,
            "processing_seconds": r.processing_seconds,
            "gpu_type": r.gpu_type,
            "compute_cost": r.estimated_compute_cost,
            "api_cost": r.generation_api_cost,
            "total_cost_usd": r.total_cost_usd,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in cost_records[:50]
    ]

    return CostTelemetryResponse(
        total_compute_cost_usd=round(total_compute, 4),
        total_generation_api_cost_usd=round(total_api, 4),
        total_cost_usd=round(total_cost, 4),
        job_count=len(cost_records),
        breakdown_by_provider=by_provider,
        breakdown_by_project=by_project,
        recent_records=recent,
    )


@router.post("/media/{asset_id}/elevated-access", response_model=ElevatedMediaAccessResponse)
def request_elevated_media_access(
    asset_id: str,
    req: ElevatedMediaAccessRequest,
    request: Request,
    current_admin: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    """
    Blueprint Section 23 Item 11 & Section 29 Privacy Principle:
    'Support staff should not automatically see private room media. Elevated access must be explicit and audited.'
    """
    asset = db.query(MediaAsset).filter(MediaAsset.id == asset_id).first()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")

    client_ip = request.client.host if request.client else "unknown"
    audit_entry = AdminAuditLog(
        admin_user_id=current_admin.id,
        action="elevated_media_access",
        target_resource=f"media:{asset.id}",
        reason=req.reason,
        ip_address=client_ip,
    )
    db.add(audit_entry)
    db.commit()

    # Issue short-lived 15-minute signed URL
    signed_url = storage.get_signed_url(asset.storage_key, expires_in=900)
    return ElevatedMediaAccessResponse(
        asset_id=asset.id,
        signed_url=signed_url,
        expires_in_seconds=900,
        audited=True,
    )


@router.get("/audit-logs", response_model=List[AuditLogEntry])
def get_audit_logs(
    limit: int = 50,
    current_admin: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    """
    Blueprint Section 23 Item 11:
    Lists privileged admin audit logs.
    """
    logs = db.query(AdminAuditLog).order_by(AdminAuditLog.created_at.desc()).limit(limit).all()
    return logs


@router.get("/system/info")
def get_system_info(
    current_admin: User = Depends(get_current_admin_user),
):
    """
    Blueprint Section 29: Review model/provider version and service health.
    """
    return {
        "status": "operational",
        "service": "roomlyst-api",
        "version": "0.3.0",
        "phase": "Phase 1 - MVP AI Room Designer",
        "pipeline_models": {
            "depth_estimation": "monocular_gradient_v1",
            "segmentation": "color_spatial_v1",
            "redesign_generator": "local_synthesizer_v1 (SDXL/Flux compatible)",
        },
        "storage_provider": storage.__class__.__name__,
        "rate_limiting_enabled": True,
    }
