"""
Job Status and Inspection Endpoints.
Adheres to Blueprint Section 19 & 29.
"""

from typing import Any, Dict, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ...core.dependencies import AuthContext, get_auth_context
from ...db.models import ProcessingJob, Room
from ...db.session import get_db

router = APIRouter(prefix="/jobs", tags=["Jobs & Workers"])


class JobStatusResponse(BaseModel):
    id: str
    room_id: str
    job_type: str
    status: str
    progress_percent: int
    current_step: str
    error_message: Optional[str] = None
    latency_ms: Optional[float] = None
    cost_usd: Optional[float] = None
    result_data: Optional[Dict[str, Any]] = None


@router.get("/{job_id}", response_model=JobStatusResponse)
def get_job_status(
    job_id: str,
    auth: AuthContext = Depends(get_auth_context),
    db: Session = Depends(get_db),
):
    """
    Retrieves real-time processing job status and progress.
    Fulfills Prompt 07 Section A: Ensures background jobs bind to the authorized owner
    and cannot be queried across tenants.
    """
    job = db.query(ProcessingJob).filter(ProcessingJob.id == job_id).first()
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Processing job not found",
        )

    if auth.role != "admin":
        room = db.query(Room).filter(Room.id == job.room_id).first()
        if room and room.project and room.project.user_id not in ("usr_demo", None):
            if not auth.is_authenticated and not auth.is_guest:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authentication required to inspect processing job",
                )
            if room.project.user_id != auth.user_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Not authorized to inspect another user's processing job",
                )

    return JobStatusResponse(
        id=job.id,
        room_id=job.room_id,
        job_type=job.job_type,
        status=job.status,
        progress_percent=job.progress_percent,
        current_step=job.current_step,
        error_message=job.error_message,
        latency_ms=job.latency_ms,
        cost_usd=job.cost_usd,
        result_data=job.result_data,
    )

