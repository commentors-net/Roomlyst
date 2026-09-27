"""
Canonical Room Model Schema definitions for Roomlyst.
Compliant with Blueprint Section 10, 10.1, 11, 14, 15, and 16.
"""

from datetime import datetime, timezone
from enum import Enum
from typing import Any, Dict, List, Optional
import uuid
from pydantic import BaseModel, Field, field_validator, computed_field


class MeasurementSource(str, Enum):
    """
    Measurement provenance types as defined in Section 10.1.
    Never treat all measurements equally.
    """
    LIDAR_NATIVE = "LIDAR_NATIVE"
    HARDWARE_DEPTH = "HARDWARE_DEPTH"
    AR_DEPTH_FROM_MOTION = "AR_DEPTH_FROM_MOTION"
    MULTIVIEW_RECONSTRUCTION = "MULTIVIEW_RECONSTRUCTION"
    MONOCULAR_DEPTH = "MONOCULAR_DEPTH"
    REFERENCE_SCALED = "REFERENCE_SCALED"
    USER_ENTERED = "USER_ENTERED"
    USER_VERIFIED = "USER_VERIFIED"
    UNKNOWN = "UNKNOWN"


class ObjectAction(str, Enum):
    """Actions the user or system can assign to surfaces and objects."""
    KEEP = "KEEP"
    REPLACE = "REPLACE"
    REMOVE = "REMOVE"
    RESTYLE = "RESTYLE"


class ObjectType(str, Enum):
    """Semantic category of detected indoor room elements."""
    FURNITURE = "FURNITURE"
    APPLIANCE = "APPLIANCE"
    FIXTURE = "FIXTURE"
    DECOR = "DECOR"
    ARCHITECTURAL = "ARCHITECTURAL"


class SurfaceType(str, Enum):
    """Types of primary room boundary surfaces."""
    WALL = "WALL"
    FLOOR = "FLOOR"
    CEILING = "CEILING"


class OpeningType(str, Enum):
    """Types of structural wall openings that must be preserved."""
    WINDOW = "WINDOW"
    DOOR = "DOOR"
    ARCHWAY = "ARCHWAY"


class ReferenceScaleType(str, Enum):
    """
    Standard scale calibration reference types as defined in Blueprint Section 12.
    """
    KNOWN_WALL_DIMENSION = "KNOWN_WALL_DIMENSION"
    STANDARD_DOOR_HEIGHT = "STANDARD_DOOR_HEIGHT"
    A4_PAPER = "A4_PAPER"
    FLOOR_TILE = "FLOOR_TILE"
    CREDIT_CARD = "CREDIT_CARD"
    CUSTOM_OBJECT = "CUSTOM_OBJECT"


class RoomShapeType(str, Enum):
    """Architectural classification of room floor plan shape."""
    RECTANGULAR = "RECTANGULAR"
    L_SHAPED = "L_SHAPED"
    T_SHAPED = "T_SHAPED"
    ALCOVE = "ALCOVE"
    POLYGONAL = "POLYGONAL"


class LoopClosureStatus(str, Enum):
    """Status of wall perimeter connectivity and geometric loop closure."""
    CLOSED = "CLOSED"
    SNAPPED = "SNAPPED"
    OPEN = "OPEN"
    SELF_INTERSECTING = "SELF_INTERSECTING"


class FeasibilitySeverity(str, Enum):
    """Severity tier for physical room layout and clearance issues."""
    INFO = "INFO"
    WARNING = "WARNING"
    CRITICAL = "CRITICAL"


class FeasibilityIssueType(str, Enum):
    """Categorization of space feasibility violations."""
    DOOR_SWING_OBSTRUCTED = "DOOR_SWING_OBSTRUCTED"
    WALKWAY_TOO_NARROW = "WALKWAY_TOO_NARROW"
    FURNITURE_OVERLAP = "FURNITURE_OVERLAP"
    WINDOW_ACCESS_BLOCKED = "WINDOW_ACCESS_BLOCKED"
    WALL_LOOP_NOT_CLOSED = "WALL_LOOP_NOT_CLOSED"


class Point2D(BaseModel):
    """2D coordinate in metric room space (meters)."""
    x: float
    y: float


class WallSegment(BaseModel):
    """A single straight wall segment between two floor plan corners."""
    id: str = Field(default_factory=lambda: f"wall_{uuid.uuid4().hex[:8]}")
    name: Optional[str] = None
    start_point: Point2D
    end_point: Point2D
    length_m: float
    height_m: Optional[float] = None
    wall_type: str = "straight"
    opening_ids: List[str] = Field(default_factory=list)


class FurnitureFootprint(BaseModel):
    """2D rectangular footprint bounding box on the floor plane in meters."""
    center_x: float
    center_y: float
    width_m: float
    length_m: float
    rotation_deg: float = 0.0
    min_x: float
    max_x: float
    min_y: float
    max_y: float


class FeasibilityCheck(BaseModel):
    """Individual clearance, loop closure, or layout feasibility assessment."""
    check_id: str = Field(default_factory=lambda: f"chk_{uuid.uuid4().hex[:8]}")
    check_name: str
    passed: bool
    severity: FeasibilitySeverity = FeasibilitySeverity.INFO
    issue_type: Optional[FeasibilityIssueType] = None
    entity_ids: List[str] = Field(default_factory=list)
    entity_names: List[str] = Field(default_factory=list)
    measured_clearance_m: Optional[float] = None
    required_clearance_m: Optional[float] = None
    message: str
    suggested_action: Optional[str] = None


class FeasibilityReport(BaseModel):
    """Aggregated spatial feasibility report for room layout and renovation."""
    overall_feasible: bool = True
    critical_issues_count: int = 0
    warning_issues_count: int = 0
    checks: List[FeasibilityCheck] = Field(default_factory=list)
    min_walkway_clearance_m: Optional[float] = None
    summary: str = "All furniture clearances and wall closures pass feasibility checks."
    evaluated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class BoundingBox2D(BaseModel):
    """Normalized 2D bounding coordinates (0.0 to 1.0)."""
    x_min: float = Field(..., ge=0.0, le=1.0)
    y_min: float = Field(..., ge=0.0, le=1.0)
    x_max: float = Field(..., ge=0.0, le=1.0)
    y_max: float = Field(..., ge=0.0, le=1.0)

    @field_validator("x_max")
    @classmethod
    def validate_x(cls, v: float, info: Any) -> float:
        x_min = info.data.get("x_min", 0.0)
        if v < x_min:
            raise ValueError(f"x_max ({v}) must be greater than or equal to x_min ({x_min})")
        return v

    @field_validator("y_max")
    @classmethod
    def validate_y(cls, v: float, info: Any) -> float:
        y_min = info.data.get("y_min", 0.0)
        if v < y_min:
            raise ValueError(f"y_max ({v}) must be greater than or equal to y_min ({y_min})")
        return v


class Measurement(BaseModel):
    """
    Represents an explicitly tracked measurement with provenance and confidence.
    Section 11: Low-confidence values must be presented as approximate.
    """
    id: str = Field(default_factory=lambda: f"meas_{uuid.uuid4().hex[:8]}")
    entity_type: str = Field(..., description="e.g., room, wall, opening, object")
    entity_id: Optional[str] = Field(None, description="ID of the measured entity")
    measurement_type: str = Field(..., description="e.g., width, height, length, area")
    value: float = Field(..., description="Numerical value")
    unit: str = Field(default="m", description="m, cm, m2, sqft")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence score between 0.0 and 1.0")
    source: MeasurementSource = Field(..., description="Provenance source")
    verified_by_user: bool = Field(default=False)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def is_approximate(self) -> bool:
        """Determines if the measurement is unverified or inferred from low-confidence sources."""
        if self.verified_by_user:
            return False
        if self.source in {MeasurementSource.LIDAR_NATIVE, MeasurementSource.USER_ENTERED, MeasurementSource.USER_VERIFIED, MeasurementSource.REFERENCE_SCALED}:
            return self.confidence < 0.90
        return True

    @computed_field
    @property
    def accuracy_tier(self) -> str:
        """
        Accuracy tier per Add-on Section 6:
        - 'EXACT': Hardware LiDAR (>= 0.90) or verified by user
        - 'APPROXIMATE': Moderate confidence (0.75 - 0.89, e.g. AR depth, multi-view)
        - 'REQUIRES_CONFIRMATION': Lower confidence (< 0.75 or monocular estimate < 0.80)
        """
        if self.verified_by_user or (self.source in (MeasurementSource.LIDAR_NATIVE, MeasurementSource.USER_VERIFIED) and self.confidence >= 0.90):
            return "EXACT"
        elif self.source == MeasurementSource.REFERENCE_SCALED and self.confidence >= 0.92:
            return "EXACT"
        elif self.source == MeasurementSource.MONOCULAR_DEPTH:
            return "REQUIRES_CONFIRMATION" if self.confidence < 0.80 else "APPROXIMATE"
        elif self.confidence >= 0.75:
            return "APPROXIMATE"
        else:
            return "REQUIRES_CONFIRMATION"

    @computed_field
    @property
    def accuracy_label(self) -> str:
        """User-facing accuracy description per Add-on Section 6."""
        tier = self.accuracy_tier
        if tier == "EXACT":
            return "Exact"
        elif tier == "APPROXIMATE":
            return "Approximate"
        else:
            return "Estimated - Confirmation Needed"

    @property
    def display_string(self) -> str:
        """Formats the value appropriately with approx label when required."""
        if self.is_approximate:
            return f"Approx. {self.value:.1f} {self.unit}"
        return f"{self.value:.2f} {self.unit}"


class RoomObject(BaseModel):
    """A detected or user-specified object inside the room."""
    id: str = Field(default_factory=lambda: f"obj_{uuid.uuid4().hex[:8]}")
    name: str = Field(..., description="Human-readable name, e.g. 'Fabric 3-Seater Sofa'")
    category: str = Field(..., description="sofa, coffee_table, tv_unit, dining_chair, plant, etc.")
    object_type: ObjectType = Field(default=ObjectType.FURNITURE)
    confidence: float = Field(default=0.85, ge=0.0, le=1.0)
    bounding_box: Optional[BoundingBox2D] = None
    mask_key: Optional[str] = Field(None, description="Storage key or reference for binary mask")
    action: ObjectAction = Field(default=ObjectAction.KEEP)
    user_label_override: Optional[str] = None
    notes: Optional[str] = None
    views_observed: int = Field(default=1, ge=1, description="Number of viewpoints observing this object")
    footprint_2d: Optional[FurnitureFootprint] = Field(None, description="2D floor plane boundary footprint in meters")


class RoomSurface(BaseModel):
    """A room boundary surface (wall, floor, ceiling)."""
    id: str = Field(default_factory=lambda: f"surf_{uuid.uuid4().hex[:8]}")
    surface_type: SurfaceType
    name: str = Field(..., description="e.g. 'Main Living Room Wall', 'Oak Hardwood Floor'")
    material_detected: Optional[str] = Field(None, description="e.g. 'hardwood', 'ceramic_tile', 'painted_drywall'")
    target_material: Optional[str] = Field(None, description="User requested finish, e.g. 'chevron_light_oak'")
    action: ObjectAction = Field(default=ObjectAction.KEEP)
    estimated_area_sqm: Optional[float] = None
    confidence: float = Field(default=0.90, ge=0.0, le=1.0)
    mask_key: Optional[str] = None
    views_observed: int = Field(default=1, ge=1, description="Number of viewpoints observing this surface")


class RoomOpening(BaseModel):
    """Structural opening (window, door, archway) that must remain preserved."""
    id: str = Field(default_factory=lambda: f"opn_{uuid.uuid4().hex[:8]}")
    opening_type: OpeningType
    name: str = Field(..., description="e.g. 'Double Bay Window', 'Balcony Sliding Door'")
    wall_id: Optional[str] = None
    bounding_box: Optional[BoundingBox2D] = None
    confidence: float = Field(default=0.92, ge=0.0, le=1.0)
    action: ObjectAction = Field(default=ObjectAction.KEEP)
    views_observed: int = Field(default=1, ge=1, description="Number of viewpoints observing this opening")


class Geometry(BaseModel):
    """Room geometry and structural properties."""
    floor_area_sqm: Optional[float] = None
    ceiling_height_m: Optional[float] = None
    estimated_width_m: Optional[float] = None
    estimated_length_m: Optional[float] = None
    confidence: float = Field(default=0.75, ge=0.0, le=1.0)
    reconstruction_method: str = Field(default="monocular_depth_estimate")
    wall_segments: List[WallSegment] = Field(default_factory=list)
    polygon_vertices: List[Point2D] = Field(default_factory=list)
    room_shape: RoomShapeType = Field(default=RoomShapeType.RECTANGULAR)
    loop_closure_status: LoopClosureStatus = Field(default=LoopClosureStatus.CLOSED)
    loop_closure_gap_m: float = 0.0
    perimeter_m: Optional[float] = None


class CaptureMetadata(BaseModel):
    """
    Hardware capability and session profile recorded at capture time.
    Fulfills Add-on Section 2, 3, & 8.
    """
    platform: str = Field(default="unknown", description="ios, android, web")
    device_model: Optional[str] = None
    os_version: Optional[str] = None
    has_lidar: bool = False
    has_hardware_depth: bool = False
    has_ar: bool = False
    has_arkit: bool = False
    has_roomplan: bool = False
    has_arcore: bool = False
    has_arcore_depth: bool = False
    has_motion_sensors: bool = False
    available_memory_mb: Optional[int] = None
    capability_tier: str = Field(default="Tier C", description="Tier A, Tier B, Tier C")
    scan_mode: str = Field(default="rgb_photo_scan", description="lidar_scan, ar_depth_scan, ar_rgb_scan, rgb_video_scan, rgb_photo_scan")
    capability_confidence: float = Field(default=0.70, ge=0.0, le=1.0)
    user_guidance_prompt: Optional[str] = None
    accuracy_assurance: Optional[str] = None
    unsupported_reason: Optional[str] = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class QualityReport(BaseModel):
    """Automated quality control results for uploaded capture media."""
    passed: bool = True
    blur_score: float = Field(..., description="Laplacian variance score")
    is_blurry: bool = False
    exposure_mean: float = Field(..., description="Mean luminance value (0-255)")
    is_under_exposed: bool = False
    is_over_exposed: bool = False
    width_px: int
    height_px: int
    feedback_messages: List[str] = Field(default_factory=list)


class CaptureFrame(BaseModel):
    """
    Represents an individual viewpoint / corner photo in a multi-image capture session.
    Fulfills Milestone 2.1 & Blueprint Section 8.2.
    """
    id: str = Field(default_factory=lambda: f"frm_{uuid.uuid4().hex[:8]}")
    image_url: str
    viewpoint_label: str = Field(default="Corner 1", description="e.g. Corner 1, Corner 2, Detail View")
    corner_index: int = Field(default=1, ge=1)
    quality_score: float = Field(default=0.90, ge=0.0, le=1.0)
    is_duplicate: bool = False
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class CoverageReport(BaseModel):
    """
    Multi-view visual coverage and overlap validation report.
    Fulfills Milestone 2.1 & Blueprint Section 8.2 and 9.
    """
    total_frames: int = 1
    valid_frames: int = 1
    rejected_frames: int = 0
    estimated_coverage_pct: float = Field(default=40.0, ge=0.0, le=100.0)
    corners_covered: List[int] = Field(default_factory=lambda: [1])
    walls_covered_count: int = Field(default=2, ge=0)
    total_walls_expected: int = Field(default=4, ge=1)
    has_sufficient_overlap: bool = True
    missing_viewpoints: List[str] = Field(default_factory=list)
    actionable_guidance: List[str] = Field(default_factory=list)


class ScaleCalibration(BaseModel):
    """
    Scale calibration record per Blueprint Section 12 & Milestone 2.2.
    Records ground-truth reference, scale factor, and calibration metadata.
    """
    calibration_id: str = Field(default_factory=lambda: f"cal_{uuid.uuid4().hex[:8]}")
    reference_type: ReferenceScaleType = Field(default=ReferenceScaleType.KNOWN_WALL_DIMENSION)
    reference_entity_id: Optional[str] = None
    reference_dimension_type: str = Field(default="width", description="width, height, length, area")
    target_real_value: float = Field(..., gt=0.0, description="Real-world reference value in meters")
    original_estimated_value: float = Field(..., gt=0.0, description="Pre-calibration estimated value in meters")
    scale_factor: float = Field(..., gt=0.0, description="Scale multiplier = target_real_value / original_estimated_value")
    calibrated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    calibration_notes: Optional[str] = None


class DesignConstraint(BaseModel):
    """
    Structured design request sent to the generation pipeline.
    Section 14: Never pass unconstrained free-text prompts directly to models.
    """
    room_type: str = Field(default="living_room")
    styles: List[str] = Field(default_factory=lambda: ["warm", "modern", "minimalist"])
    budget_currency: str = Field(default="MYR")
    budget_amount: Optional[float] = None
    preserve_ids: List[str] = Field(default_factory=list, description="IDs of objects/surfaces to keep unchanged")
    replace_ids: List[str] = Field(default_factory=list, description="IDs of objects/surfaces to replace")
    remove_ids: List[str] = Field(default_factory=list, description="IDs of objects to completely remove")
    restyle_ids: List[str] = Field(default_factory=list, description="IDs of surfaces/objects to refinish/restyle")
    goals: List[str] = Field(default_factory=list, description="e.g. increase_storage, brighter_lighting")
    free_text_prompt: Optional[str] = None


class DesignVariant(BaseModel):
    """One of the 3 candidate designs generated per request."""
    variant_id: str = Field(default_factory=lambda: f"var_{uuid.uuid4().hex[:6]}")
    title: str = Field(..., description="e.g., 'Warm Japandi Minimalist'")
    style: str
    image_url: str
    description: str
    structural_preservation_score: float = Field(default=0.92, ge=0.0, le=1.0)
    changes_made: List[str] = Field(default_factory=list)
    estimated_cost: Optional[float] = None


class DesignVersion(BaseModel):
    """
    Immutable design version node supporting branching (Section 16).
    """
    id: str = Field(default_factory=lambda: f"ver_{uuid.uuid4().hex[:8]}")
    room_id: str
    parent_version_id: Optional[str] = None
    version_number: int = 1
    constraints: DesignConstraint
    variants: List[DesignVariant] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    model_provider: str = Field(default="local-pipeline")
    model_version: str = Field(default="1.0.0")
    generation_latency_ms: Optional[float] = None
    estimated_cost_usd: Optional[float] = None


class CanonicalRoomModel(BaseModel):
    """
    The Single Canonical Room Model (Section 10).
    All capture modes and AI pipelines produce this structured state.
    """
    id: str = Field(default_factory=lambda: f"room_{uuid.uuid4().hex[:8]}")
    project_id: str = Field(default_factory=lambda: f"proj_{uuid.uuid4().hex[:8]}")
    name: str = Field(default="Living Room")
    room_type: str = Field(default="living_room")
    status: str = Field(default="READY_FOR_REVIEW")
    original_image_url: Optional[str] = None
    depth_map_url: Optional[str] = None
    geometry: Geometry = Field(default_factory=Geometry)
    surfaces: List[RoomSurface] = Field(default_factory=list)
    openings: List[RoomOpening] = Field(default_factory=list)
    objects: List[RoomObject] = Field(default_factory=list)
    measurements: List[Measurement] = Field(default_factory=list)
    versions: List[DesignVersion] = Field(default_factory=list)
    capture_metadata: Optional[CaptureMetadata] = None
    quality_report: Optional[QualityReport] = None
    frames: List[CaptureFrame] = Field(default_factory=list)
    coverage_report: Optional[CoverageReport] = None
    scale_calibration: Optional[ScaleCalibration] = None
    feasibility_report: Optional[FeasibilityReport] = None
    overall_confidence: float = Field(default=0.88, ge=0.0, le=1.0)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    def get_element_by_id(self, element_id: str) -> Optional[Any]:
        """Finds a surface, opening, or object by its unique ID."""
        for s in self.surfaces:
            if s.id == element_id:
                return s
        for opn in self.openings:
            if opn.id == element_id:
                return opn
        for obj in self.objects:
            if obj.id == element_id:
                return obj
        return None

    def set_action_for_element(self, element_id: str, action: ObjectAction) -> bool:
        """Updates the action status (KEEP, REPLACE, REMOVE, RESTYLE) for an element."""
        element = self.get_element_by_id(element_id)
        if element:
            element.action = action
            self.updated_at = datetime.now(timezone.utc)
            return True
        return False

    def apply_correction(
        self,
        element_id: str,
        label_override: Optional[str] = None,
        category_override: Optional[str] = None,
        is_deleted: bool = False,
    ) -> bool:
        """
        Fulfills Blueprint Section 15: Users must be able to correct AI mistakes.
        Updates name/label, changes category, or deletes false positive detections.
        """
        if is_deleted:
            self.objects = [o for o in self.objects if o.id != element_id]
            self.openings = [op for op in self.openings if op.id != element_id]
            self.surfaces = [s for s in self.surfaces if s.id != element_id]
            self.updated_at = datetime.now(timezone.utc)
            return True

        elem = self.get_element_by_id(element_id)
        if elem:
            if label_override:
                elem.name = label_override
                if hasattr(elem, "user_label_override"):
                    elem.user_label_override = label_override
            if category_override and hasattr(elem, "category"):
                elem.category = category_override
            self.updated_at = datetime.now(timezone.utc)
            return True
        return False

    def verify_measurement(self, measurement_id: str, verified_value: Optional[float] = None) -> bool:
        """
        Confirms a measurement, switching provenance to USER_VERIFIED and removing approximation.
        """
        for m in self.measurements:
            if m.id == measurement_id:
                if verified_value is not None:
                    m.value = verified_value
                m.verified_by_user = True
                m.source = MeasurementSource.USER_VERIFIED
                m.confidence = 1.0
                self.updated_at = datetime.now(timezone.utc)
                return True
        return False

    def calibrate_scale(
        self,
        target_real_value: float,
        reference_type: ReferenceScaleType = ReferenceScaleType.KNOWN_WALL_DIMENSION,
        reference_dimension_type: str = "width",
        reference_entity_id: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> ScaleCalibration:
        """
        Rescales all room dimensions, surface areas, and measurements using a known real-world reference.
        Fulfills Blueprint Section 12 & Milestone 2.2.
        """
        estimated_val = None
        for m in self.measurements:
            if reference_entity_id and m.entity_id == reference_entity_id and m.measurement_type == reference_dimension_type:
                estimated_val = m.value
                break
            elif not reference_entity_id and m.measurement_type == reference_dimension_type:
                estimated_val = m.value
                break

        if not estimated_val or estimated_val <= 0:
            if reference_dimension_type == "width" and self.geometry.estimated_width_m:
                estimated_val = self.geometry.estimated_width_m
            elif reference_dimension_type == "height" and self.geometry.ceiling_height_m:
                estimated_val = self.geometry.ceiling_height_m
            elif reference_dimension_type == "length" and self.geometry.estimated_length_m:
                estimated_val = self.geometry.estimated_length_m
            else:
                estimated_val = 4.2

        scale_factor = target_real_value / estimated_val

        for m in self.measurements:
            if m.unit in ("m", "cm"):
                m.value = round(m.value * scale_factor, 2)
            elif m.unit in ("m2", "sqm"):
                m.value = round(m.value * (scale_factor ** 2), 2)

            if reference_entity_id and m.entity_id == reference_entity_id and m.measurement_type == reference_dimension_type:
                m.value = round(target_real_value, 2)
                m.source = MeasurementSource.USER_VERIFIED
                m.verified_by_user = True
                m.confidence = 0.99
            else:
                m.source = MeasurementSource.REFERENCE_SCALED
                m.confidence = min(0.96, round(max(m.confidence, 0.88) + 0.05, 2))

        for s in self.surfaces:
            if s.estimated_area_sqm:
                s.estimated_area_sqm = round(s.estimated_area_sqm * (scale_factor ** 2), 2)
                s.confidence = min(0.98, round(s.confidence + 0.04, 2))

        if self.geometry.floor_area_sqm:
            self.geometry.floor_area_sqm = round(self.geometry.floor_area_sqm * (scale_factor ** 2), 2)
        if self.geometry.estimated_width_m:
            self.geometry.estimated_width_m = round(self.geometry.estimated_width_m * scale_factor, 2)
        if self.geometry.estimated_length_m:
            self.geometry.estimated_length_m = round(self.geometry.estimated_length_m * scale_factor, 2)
        if self.geometry.ceiling_height_m:
            self.geometry.ceiling_height_m = round(self.geometry.ceiling_height_m * scale_factor, 2)
        if self.geometry.perimeter_m:
            self.geometry.perimeter_m = round(self.geometry.perimeter_m * scale_factor, 2)
        if self.geometry.loop_closure_gap_m:
            self.geometry.loop_closure_gap_m = round(self.geometry.loop_closure_gap_m * scale_factor, 3)

        for p in self.geometry.polygon_vertices:
            p.x = round(p.x * scale_factor, 3)
            p.y = round(p.y * scale_factor, 3)

        for w in self.geometry.wall_segments:
            w.start_point.x = round(w.start_point.x * scale_factor, 3)
            w.start_point.y = round(w.start_point.y * scale_factor, 3)
            w.end_point.x = round(w.end_point.x * scale_factor, 3)
            w.end_point.y = round(w.end_point.y * scale_factor, 3)
            w.length_m = round(w.length_m * scale_factor, 3)
            if w.height_m:
                w.height_m = round(w.height_m * scale_factor, 3)

        for obj in self.objects:
            if obj.footprint_2d:
                obj.footprint_2d.center_x = round(obj.footprint_2d.center_x * scale_factor, 3)
                obj.footprint_2d.center_y = round(obj.footprint_2d.center_y * scale_factor, 3)
                obj.footprint_2d.width_m = round(obj.footprint_2d.width_m * scale_factor, 3)
                obj.footprint_2d.length_m = round(obj.footprint_2d.length_m * scale_factor, 3)
                obj.footprint_2d.min_x = round(obj.footprint_2d.min_x * scale_factor, 3)
                obj.footprint_2d.max_x = round(obj.footprint_2d.max_x * scale_factor, 3)
                obj.footprint_2d.min_y = round(obj.footprint_2d.min_y * scale_factor, 3)
                obj.footprint_2d.max_y = round(obj.footprint_2d.max_y * scale_factor, 3)

        self.geometry.confidence = min(0.95, round(self.geometry.confidence + 0.12, 2))
        self.geometry.reconstruction_method = "scale_calibrated_reference_model"

        cal = ScaleCalibration(
            reference_type=reference_type,
            reference_entity_id=reference_entity_id,
            reference_dimension_type=reference_dimension_type,
            target_real_value=round(target_real_value, 3),
            original_estimated_value=round(estimated_val, 3),
            scale_factor=round(scale_factor, 4),
            calibration_notes=notes or f"Calibrated using {reference_type.value}",
        )
        self.scale_calibration = cal
        self.overall_confidence = min(0.95, round(self.overall_confidence + 0.08, 2))
        self.updated_at = datetime.now(timezone.utc)
        return cal

    def build_design_constraint(
        self,
        styles: List[str],
        goals: Optional[List[str]] = None,
        budget_amount: Optional[float] = None,
        budget_currency: str = "MYR",
        free_text: Optional[str] = None,
    ) -> DesignConstraint:
        """
        Compiles the current room element states into a strict DesignConstraint
        for the AI redesign generator.
        """
        preserve_ids: List[str] = []
        replace_ids: List[str] = []
        remove_ids: List[str] = []
        restyle_ids: List[str] = []

        # Openings are architectural: default to preserve unless explicitly altered
        for opn in self.openings:
            if opn.action == ObjectAction.KEEP:
                preserve_ids.append(opn.id)
            elif opn.action == ObjectAction.REPLACE:
                replace_ids.append(opn.id)

        # Surfaces
        for surf in self.surfaces:
            if surf.action == ObjectAction.KEEP:
                preserve_ids.append(surf.id)
            elif surf.action == ObjectAction.REPLACE:
                replace_ids.append(surf.id)
            elif surf.action == ObjectAction.RESTYLE:
                restyle_ids.append(surf.id)

        # Furniture & Objects
        for obj in self.objects:
            if obj.action == ObjectAction.KEEP:
                preserve_ids.append(obj.id)
            elif obj.action == ObjectAction.REPLACE:
                replace_ids.append(obj.id)
            elif obj.action == ObjectAction.REMOVE:
                remove_ids.append(obj.id)
            elif obj.action == ObjectAction.RESTYLE:
                restyle_ids.append(obj.id)

        return DesignConstraint(
            room_type=self.room_type,
            styles=styles,
            budget_currency=budget_currency,
            budget_amount=budget_amount,
            preserve_ids=preserve_ids,
            replace_ids=replace_ids,
            remove_ids=remove_ids,
            restyle_ids=restyle_ids,
            goals=goals or [],
            free_text_prompt=free_text,
        )
