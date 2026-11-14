"""
Asynchronous Job Manager for Roomlyst.
Coordinates state transitions, background task execution, and database updates.
Fulfills Blueprint Section 19 & ADR-005.
"""

import asyncio
import io
import time
from typing import Any, Dict, Optional
from PIL import Image
from sqlalchemy.orm import Session

from packages.room_model import CanonicalRoomModel, DesignConstraint, ObjectAction
from services.ai_worker.pipelines.generation import LocalRedesignGenerator
from services.ai_worker.pipelines.room_analyzer import RoomAnalyzer
from ..db.models import JobCostRecord, MeasurementRecord, ProcessingJob, Room
from ..db.session import SessionLocal
from ..storage import get_storage_provider
from .state_machine import JobStatus


class JobManager:
    """Manages long-running asynchronous computer vision and generation jobs."""

    def __init__(self):
        self.room_analyzer = RoomAnalyzer()
        self.redesign_generator = LocalRedesignGenerator()
        self.storage = get_storage_provider()

    def create_job(self, db: Session, room_id: str, job_type: str = "room_analysis") -> ProcessingJob:
        """Initializes a new job record in the database."""
        job = ProcessingJob(
            room_id=room_id,
            job_type=job_type,
            status=JobStatus.CREATED.value,
            progress_percent=0,
            current_step="Job registered",
        )
        db.add(job)
        db.commit()
        db.refresh(job)
        return job

    def update_job_status(
        self,
        job_id: str,
        status: JobStatus,
        progress: int,
        step: str,
        error_msg: Optional[str] = None,
        result_data: Optional[Dict[str, Any]] = None,
        latency_ms: Optional[float] = None,
        cost_usd: Optional[float] = None,
    ):
        """Updates job state in an isolated DB transaction."""
        with SessionLocal() as db:
            job = db.query(ProcessingJob).filter(ProcessingJob.id == job_id).first()
            if job:
                job.status = status.value
                job.progress_percent = progress
                job.current_step = step
                if error_msg:
                    job.error_message = error_msg
                if result_data:
                    job.result_data = result_data
                if latency_ms is not None:
                    job.latency_ms = latency_ms
                if cost_usd is not None:
                    job.cost_usd = cost_usd
                db.commit()

    def execute_room_analysis(
        self,
        job_id: str,
        room_id: str,
        image_bytes: bytes,
        capture_metadata: Optional[Any] = None,
    ):
        """
        Background worker task executing room analysis state machine:
        CREATED -> VALIDATING -> ESTIMATING_DEPTH -> SEGMENTING -> BUILDING_ROOM_MODEL -> READY_FOR_REVIEW
        Dynamically adapts depth & measurement confidence based on runtime capture metadata.
        """
        start_time = time.time()
        try:
            # 1. VALIDATING
            self.update_job_status(job_id, JobStatus.VALIDATING, 15, "Validating photo quality (blur, exposure, resolution)")
            image = Image.open(io.BytesIO(image_bytes))

            # 2. ESTIMATING_DEPTH & SEGMENTING
            self.update_job_status(job_id, JobStatus.ESTIMATING_DEPTH, 40, "Estimating monocular depth and perspective vanishing planes")
            self.update_job_status(job_id, JobStatus.SEGMENTING, 65, "Segmenting walls, floor, structural openings, and furniture")

            # Execute room analyzer with capture metadata
            room_model = self.room_analyzer.analyze_photo(
                image,
                room_name="Room",
                project_id="proj",
                capture_metadata=capture_metadata,
            )

            # 3. BUILDING_ROOM_MODEL & DB PERSISTENCE
            self.update_job_status(job_id, JobStatus.BUILDING_ROOM_MODEL, 85, "Normalizing into Canonical Room Model")

            with SessionLocal() as db:
                db_room = db.query(Room).filter(Room.id == room_id).first()
                if db_room:
                    db_room.room_model_data = room_model.model_dump(mode="json")
                    db_room.status = "READY_FOR_REVIEW"

                    # Sync measurements into relational table for querying
                    for m in room_model.measurements:
                        meas_rec = MeasurementRecord(
                            room_id=room_id,
                            entity_type=m.entity_type,
                            measurement_type=m.measurement_type,
                            value=m.value,
                            unit=m.unit,
                            confidence=m.confidence,
                            source=m.source.value,
                            verified_by_user=m.verified_by_user,
                        )
                        db.add(meas_rec)

                    latency_ms = (time.time() - start_time) * 1000.0
                    cost_rec = JobCostRecord(
                        job_id=job_id,
                        project_id=db_room.project_id if db_room else None,
                        provider="local_analyzer",
                        model="monocular-depth-v1+segmenter",
                        input_size=f"{image.width}x{image.height}",
                        processing_seconds=round(latency_ms / 1000.0, 3),
                        gpu_type="CPU/NVIDIA-A10G",
                        estimated_compute_cost=0.005,
                        generation_api_cost=0.0,
                        total_cost_usd=0.005,
                    )
                    db.add(cost_rec)
                    db.commit()

            self.update_job_status(
                job_id=job_id,
                status=JobStatus.READY_FOR_REVIEW,
                progress=100,
                step="Analysis complete. Ready for user element review.",
                result_data={"room_id": room_id, "surfaces_count": len(room_model.surfaces), "objects_count": len(room_model.objects)},
                latency_ms=round(latency_ms, 2),
                cost_usd=0.005,
            )

        except Exception as e:
            self.update_job_status(
                job_id=job_id,
                status=JobStatus.FAILED_RETRYABLE,
                progress=0,
                step="Analysis failed",
                error_msg=str(e),
            )

    def execute_redesign(
        self,
        job_id: str,
        room_id: str,
        constraints: DesignConstraint,
        image_bytes: bytes,
        parent_version_id: Optional[str] = None,
        parent_variant_id: Optional[str] = None,
        branch_label: Optional[str] = None,
        generation_mode: str = "algorithmic_preview",
    ):
        """
        Background worker task executing structure-preserving redesign:
        CREATED -> VALIDATING -> GENERATING -> COMPLETED
        Supports explicit 'algorithmic_preview' and 'ai_inpainting' modes.
        """
        start_time = time.time()
        try:
            self.update_job_status(job_id, JobStatus.VALIDATING, 20, "Compiling architectural preserve masks and constraints")

            image = Image.open(io.BytesIO(image_bytes))

            # Retrieve room model
            with SessionLocal() as db:
                db_room = db.query(Room).filter(Room.id == room_id).first()
                if not db_room or not db_room.room_model_data:
                    raise ValueError("Room model not found for room_id")
                room_model = CanonicalRoomModel.model_validate(db_room.room_model_data)

            if generation_mode == "ai_inpainting":
                from services.ai_worker.pipelines.inpainting import (
                    ReplicateInpaintingAdapter,
                    MockInpaintingProvider,
                    run_inpainting_pipeline,
                    InpaintingProviderException,
                )
                if os.environ.get("TEST_MOCK_DIFFUSION") == "1":
                    inp_provider = MockInpaintingProvider()
                else:
                    inp_provider = ReplicateInpaintingAdapter()

                is_ready, reason = inp_provider.is_available()
                if not is_ready:
                    self.update_job_status(
                        job_id=job_id,
                        status=JobStatus.FAILED_RETRYABLE,
                        progress=0,
                        step="AI Inpainting provider unconfigured or unavailable",
                        error_msg=reason or "Real AI inpainting requires server-side provider credentials. You can retry with Algorithmic Preview.",
                        result_data={
                            "error_code": "PROVIDER_UNCONFIGURED",
                            "recoverable": True,
                            "suggested_mode": "algorithmic_preview",
                        },
                    )
                    return

                self.update_job_status(job_id, JobStatus.GENERATING, 60, "Synthesizing 3 neural diffusion redesign concepts")
                result = run_inpainting_pipeline(
                    image=image,
                    room_model=room_model,
                    constraints=constraints,
                    provider=inp_provider,
                    parent_version_id=parent_version_id,
                    parent_variant_id=parent_variant_id,
                    branch_label=branch_label,
                )
            else:
                self.update_job_status(job_id, JobStatus.GENERATING, 60, "Generating 3 algorithmic redesign concept previews")
                result = self.redesign_generator.generate_redesigns(
                    image=image,
                    room_model=room_model,
                    constraints=constraints,
                    count=3,
                    parent_version_id=parent_version_id,
                    parent_variant_id=parent_variant_id,
                    branch_label=branch_label,
                )

            version = result.data

            # Update DB Room with updated version list
            latency_ms = (time.time() - start_time) * 1000.0
            with SessionLocal() as db:
                db_room = db.query(Room).filter(Room.id == room_id).first()
                if db_room:
                    db_room.room_model_data = room_model.model_dump(mode="json")
                    db_room.status = "COMPLETED"
                    cost_rec = JobCostRecord(
                        job_id=job_id,
                        project_id=db_room.project_id if db_room else None,
                        provider=version.model_provider,
                        model=version.model_version,
                        input_size=f"{image.width}x{image.height}",
                        processing_seconds=round(latency_ms / 1000.0, 3),
                        gpu_type="NVIDIA-A10G" if generation_mode == "ai_inpainting" else "CPU",
                        estimated_compute_cost=0.005 if generation_mode == "ai_inpainting" else 0.0,
                        generation_api_cost=0.010 if generation_mode == "ai_inpainting" else 0.015,
                        total_cost_usd=round(version.estimated_cost_usd, 4),
                    )
                    db.add(cost_rec)
                    db.commit()

            self.update_job_status(
                job_id=job_id,
                status=JobStatus.COMPLETED,
                progress=100,
                step="3 redesign variants generated successfully",
                result_data=version.model_dump(mode="json"),
                latency_ms=round(latency_ms, 2),
                cost_usd=round(version.estimated_cost_usd, 4),
            )


        except Exception as e:
            self.update_job_status(
                job_id=job_id,
                status=JobStatus.FAILED_RETRYABLE,
                progress=0,
                step="Redesign generation failed",
                error_msg=str(e),
            )


# Global job manager singleton
job_manager = JobManager()
