"""
Job Status and Inspection Endpoints.
Adheres to Blueprint Section 19 & 29.
"""

from typing import Any, Dict, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ...db.models import ProcessingJob
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
def get_job_status(job_id: str, db: Session = Depends(get_db)):
    """Retrieves real-time processing job status and progress."""
    job = db.query(ProcessingJob).filter(ProcessingJob.id == job_id).first()
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Processing job not found",
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
