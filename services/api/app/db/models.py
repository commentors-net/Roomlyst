"""
SQLAlchemy 2.0 Declarative Models for Roomlyst.
Adheres to Blueprint Section 21 & ADR-004.
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import uuid
from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: f"usr_{uuid.uuid4().hex[:12]}")
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(50), default="homeowner")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    projects: Mapped[List["Project"]] = relationship("Project", back_populates="user", cascade="all, delete-orphan")
    audit_logs: Mapped[List["AdminAuditLog"]] = relationship("AdminAuditLog", back_populates="admin_user", cascade="all, delete-orphan")


class Project(Base):
    __tablename__ = "projects"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: f"proj_{uuid.uuid4().hex[:12]}")
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="MYR")
    status: Mapped[str] = mapped_column(String(50), default="ACTIVE")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user: Mapped["User"] = relationship("User", back_populates="projects")
    rooms: Mapped[List["Room"]] = relationship("Room", back_populates="project", cascade="all, delete-orphan")


class Room(Base):
    __tablename__ = "rooms"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: f"room_{uuid.uuid4().hex[:12]}")
    project_id: Mapped[str] = mapped_column(String(36), ForeignKey("projects.id", ondelete="CASCADE"), index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    room_type: Mapped[str] = mapped_column(String(100), default="living_room")
    status: Mapped[str] = mapped_column(String(50), default="CREATED")
    original_image_key: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    depth_map_key: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    room_model_data: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    project: Mapped["Project"] = relationship("Project", back_populates="rooms")
    media_assets: Mapped[List["MediaAsset"]] = relationship("MediaAsset", back_populates="room", cascade="all, delete-orphan")
    processing_jobs: Mapped[List["ProcessingJob"]] = relationship("ProcessingJob", back_populates="room", cascade="all, delete-orphan")
    measurements: Mapped[List["MeasurementRecord"]] = relationship("MeasurementRecord", back_populates="room", cascade="all, delete-orphan")
    corrections: Mapped[List["UserCorrectionRecord"]] = relationship("UserCorrectionRecord", back_populates="room", cascade="all, delete-orphan")


class MediaAsset(Base):
    __tablename__ = "media_assets"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: f"med_{uuid.uuid4().hex[:12]}")
    room_id: Mapped[str] = mapped_column(String(36), ForeignKey("rooms.id", ondelete="CASCADE"), index=True, nullable=False)
    storage_key: Mapped[str] = mapped_column(String(500), nullable=False)
    asset_type: Mapped[str] = mapped_column(String(50), nullable=False)  # e.g., original_photo, depth_map, mask, variant_redesign
    mime_type: Mapped[str] = mapped_column(String(100), default="image/jpeg")
    size_bytes: Mapped[int] = mapped_column(Integer, default=0)
    is_private: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    room: Mapped["Room"] = relationship("Room", back_populates="media_assets")


class ProcessingJob(Base):
    """
    Asynchronous task tracking entity fulfilling Blueprint Section 19.
    Tracks state machine from CREATED -> VALIDATING -> ANALYZING -> COMPLETED/FAILED.
    """
    __tablename__ = "processing_jobs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: f"job_{uuid.uuid4().hex[:12]}")
    room_id: Mapped[str] = mapped_column(String(36), ForeignKey("rooms.id", ondelete="CASCADE"), index=True, nullable=False)
    job_type: Mapped[str] = mapped_column(String(50), nullable=False)  # room_analysis, redesign_generation
    status: Mapped[str] = mapped_column(String(50), default="CREATED", index=True)
    progress_percent: Mapped[int] = mapped_column(Integer, default=0)
    current_step: Mapped[str] = mapped_column(String(100), default="Job initialized")
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    latency_ms: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    cost_usd: Mapped[Optional[float]] = mapped_column(Float, default=0.0)
    result_data: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    room: Mapped["Room"] = relationship("Room", back_populates="processing_jobs")
    cost_records: Mapped[List["JobCostRecord"]] = relationship("JobCostRecord", back_populates="job", cascade="all, delete-orphan")


class MeasurementRecord(Base):
    __tablename__ = "measurements"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: f"meas_{uuid.uuid4().hex[:12]}")
    room_id: Mapped[str] = mapped_column(String(36), ForeignKey("rooms.id", ondelete="CASCADE"), index=True, nullable=False)
    entity_type: Mapped[str] = mapped_column(String(50), nullable=False)  # wall, floor, room
    measurement_type: Mapped[str] = mapped_column(String(50), nullable=False)  # width, height, area
    value: Mapped[float] = mapped_column(Float, nullable=False)
    unit: Mapped[str] = mapped_column(String(20), default="m")
    confidence: Mapped[float] = mapped_column(Float, default=0.75)
    source: Mapped[str] = mapped_column(String(50), default="MONOCULAR_DEPTH")
    verified_by_user: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    room: Mapped["Room"] = relationship("Room", back_populates="measurements")


class UserCorrectionRecord(Base):
    """
    Records human corrections to AI detections for telemetry and model tuning.
    Blueprint Section 15 & 21.
    """
    __tablename__ = "user_corrections"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: f"cor_{uuid.uuid4().hex[:12]}")
    room_id: Mapped[str] = mapped_column(String(36), ForeignKey("rooms.id", ondelete="CASCADE"), index=True, nullable=False)
    element_id: Mapped[str] = mapped_column(String(50), nullable=False)
    correction_type: Mapped[str] = mapped_column(String(50), nullable=False)  # label_override, category_change, deleted, measurement_verified
    original_value: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    corrected_value: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    room: Mapped["Room"] = relationship("Room", back_populates="corrections")


class JobCostRecord(Base):
    """
    Blueprint Section 30: Cost Control.
    Granularly tracks compute & external API generation costs per job and project.
    """
    __tablename__ = "job_cost_records"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: f"cst_{uuid.uuid4().hex[:12]}")
    job_id: Mapped[str] = mapped_column(String(36), ForeignKey("processing_jobs.id", ondelete="CASCADE"), index=True, nullable=False)
    project_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True, index=True)
    provider: Mapped[str] = mapped_column(String(50), default="local_generator")  # replicate, fal, local_generator
    model: Mapped[str] = mapped_column(String(100), default="sdxl-controlnet-depth")
    input_size: Mapped[str] = mapped_column(String(50), default="1024x1024")
    processing_seconds: Mapped[float] = mapped_column(Float, default=0.0)
    gpu_type: Mapped[str] = mapped_column(String(50), default="NVIDIA-A10G")
    estimated_compute_cost: Mapped[float] = mapped_column(Float, default=0.005)
    generation_api_cost: Mapped[float] = mapped_column(Float, default=0.01)
    total_cost_usd: Mapped[float] = mapped_column(Float, default=0.015)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    job: Mapped["ProcessingJob"] = relationship("ProcessingJob", back_populates="cost_records")


class AdminAuditLog(Base):
    """
    Blueprint Section 23 (Item 11) & Section 29.
    Records privileged administrative and support operations.
    """
    __tablename__ = "admin_audit_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: f"aud_{uuid.uuid4().hex[:12]}")
    admin_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    action: Mapped[str] = mapped_column(String(100), nullable=False)  # retry_job, view_failed_jobs, elevated_media_access
    target_resource: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    ip_address: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    admin_user: Mapped["User"] = relationship("User", back_populates="audit_logs")

