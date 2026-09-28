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
    AR_MOTION_VERIFIED = "AR_MOTION_VERIFIED"
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


class CurrencyCode(str, Enum):
    """Regional currencies supported for renovation budgeting (Blueprint Section 34)."""
    MYR = "MYR"  # Malaysian Ringgit (RM)
    SGD = "SGD"  # Singapore Dollar (S$)
    USD = "USD"  # US Dollar ($)
    EUR = "EUR"  # Euro (€)
    GBP = "GBP"  # British Pound (£)
    AUD = "AUD"  # Australian Dollar (A$)
    CAD = "CAD"  # Canadian Dollar (C$)


class RenovationTier(str, Enum):
    """Renovation finish tier determining benchmark unit rates and scope."""
    ECONOMY = "ECONOMY"      # Budget-friendly refresh / DIY materials
    MODERATE = "MODERATE"    # Quality standard materials / mid-tier finishes
    PREMIUM = "PREMIUM"      # Designer custom finishes / high-end fixtures
    LUXURY = "LUXURY"        # Bespoke architectural millwork / imported materials


class BudgetCategory(str, Enum):
    """Core renovation work and material categories."""
    PAINTING_WALLS = "PAINTING_WALLS"
    FLOORING = "FLOORING"
    MILLWORK_CABINETRY = "MILLWORK_CABINETRY"
    LIGHTING_ELECTRICAL = "LIGHTING_ELECTRICAL"
    FURNITURE_DECOR = "FURNITURE_DECOR"
    LABOR_DEMOLITION = "LABOR_DEMOLITION"
    CONTINGENCY = "CONTINGENCY"


class CategoryCostItem(BaseModel):
    """Detailed cost breakdown item within a renovation budget category."""
    category: BudgetCategory
    category_name: str
    allocated_amount: float
    estimated_cost: float
    unit: str = "sqm"  # e.g., sqm, unit, linear_m, lump_sum
    quantity: float = 1.0
    unit_rate: float = 0.0
    notes: Optional[str] = None
    is_over_budget: bool = False


class KeepReplaceTradeoff(BaseModel):
    """Cost comparison and savings gained by keeping vs replacing an existing room element."""
    element_id: str
    element_label: str
    action: str = "keep"  # keep, replace, remove, restyle
    category: BudgetCategory = BudgetCategory.FURNITURE_DECOR
    replacement_cost_estimate: float = 0.0
    savings_if_kept: float = 0.0
    notes: Optional[str] = None


class BudgetPlan(BaseModel):
    """
    Renovation budget plan and indicative cost estimation.
    Fulfills Blueprint Section 34 & Milestone 2.4.
    """
    plan_id: str = Field(default_factory=lambda: f"bgt_{uuid.uuid4().hex[:8]}")
    total_budget: float
    currency: CurrencyCode = CurrencyCode.MYR
    renovation_tier: RenovationTier = RenovationTier.MODERATE
    allocated_items: List[CategoryCostItem] = Field(default_factory=list)
    tradeoffs: List[KeepReplaceTradeoff] = Field(default_factory=list)
    total_estimated_cost: float = 0.0
    total_allocated: float = 0.0
    savings_from_kept_items: float = 0.0
    remaining_budget: float = 0.0
    is_within_budget: bool = True
    disclaimer: str = (
        "Indicative renovation estimate only based on regional material and work benchmarks. "
        "Does not constitute a formal contractor quote, structural engineering sign-off, or commercial guarantee."
    )
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


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
        if self.source in {
            MeasurementSource.LIDAR_NATIVE,
            MeasurementSource.HARDWARE_DEPTH,
            MeasurementSource.USER_ENTERED,
            MeasurementSource.USER_VERIFIED,
            MeasurementSource.REFERENCE_SCALED,
            MeasurementSource.MULTIVIEW_RECONSTRUCTION,
            MeasurementSource.AR_DEPTH_FROM_MOTION,
            MeasurementSource.AR_MOTION_VERIFIED,
        }:
            return self.confidence < 0.90
        return True

    @computed_field
    @property
    def accuracy_tier(self) -> str:
        """
        Accuracy tier per Add-on Section 6:
        - 'EXACT': Hardware LiDAR (>= 0.90), user verified, or high-confidence reference/AR calibration
        - 'APPROXIMATE': Moderate-to-high confidence (0.75 - 0.94, e.g. AR depth, multi-view)
        - 'REQUIRES_CONFIRMATION': Lower confidence (< 0.75 or monocular estimate < 0.80)
        """
        if self.verified_by_user or (self.source in (MeasurementSource.LIDAR_NATIVE, MeasurementSource.HARDWARE_DEPTH, MeasurementSource.USER_VERIFIED) and self.confidence >= 0.90):
            return "EXACT"
        elif self.source == MeasurementSource.REFERENCE_SCALED and self.confidence >= 0.92:
            return "EXACT"
        elif self.source in (MeasurementSource.AR_DEPTH_FROM_MOTION, MeasurementSource.AR_MOTION_VERIFIED) and self.confidence >= 0.95:
            return "EXACT"
        elif self.source in (MeasurementSource.AR_DEPTH_FROM_MOTION, MeasurementSource.AR_MOTION_VERIFIED, MeasurementSource.MULTIVIEW_RECONSTRUCTION):
            return "APPROXIMATE"
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

    @property
    def is_closed(self) -> bool:
        return self.loop_closure_status in (LoopClosureStatus.CLOSED, LoopClosureStatus.SNAPPED)


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
    renovation_tier: Optional[str] = "MODERATE"
    preserve_ids: List[str] = Field(default_factory=list, description="IDs of objects/surfaces to keep unchanged")
    replace_ids: List[str] = Field(default_factory=list, description="IDs of objects/surfaces to replace")
    remove_ids: List[str] = Field(default_factory=list, description="IDs of objects to completely remove")
    restyle_ids: List[str] = Field(default_factory=list, description="IDs of surfaces/objects to refinish/restyle")
    goals: List[str] = Field(default_factory=list, description="e.g. increase_storage, brighter_lighting")
    free_text_prompt: Optional[str] = None


class DesignVariant(BaseModel):
    """One of the candidate designs generated per request. Fulfills Milestone 1.5 & 2.5."""
    variant_id: str = Field(default_factory=lambda: f"var_{uuid.uuid4().hex[:6]}")
    title: str = Field(..., description="e.g., 'Warm Japandi Minimalist'")
    style: str
    image_url: str
    description: str
    structural_preservation_score: float = Field(default=0.92, ge=0.0, le=1.0)
    changes_made: List[str] = Field(default_factory=list)
    estimated_cost: Optional[float] = None
    parent_variant_id: Optional[str] = None
    is_favorite: bool = False
    favorite_notes: Optional[str] = None
    starred_at: Optional[datetime] = None


class DesignVersion(BaseModel):
    """
    Immutable design version node supporting branching (Section 16 & Milestone 2.5).
    """
    id: str = Field(default_factory=lambda: f"ver_{uuid.uuid4().hex[:8]}")
    room_id: str
    parent_version_id: Optional[str] = None
    parent_variant_id: Optional[str] = None
    branch_label: Optional[str] = Field(default="Main Branch", description="e.g., 'Japandi Alternative', 'Budget Floor Refresh'")
    version_number: int = 1
    constraints: DesignConstraint
    variants: List[DesignVariant] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    model_provider: str = Field(default="local-pipeline")
    model_version: str = Field(default="1.0.0")
    generation_latency_ms: Optional[float] = None
    estimated_cost_usd: Optional[float] = None


class VariantComparison(BaseModel):
    """
    Side-by-side comparison report between two redesign variants (Milestone 2.5).
    """
    variant_a_id: str
    variant_b_id: str
    variant_a_title: str
    variant_b_title: str
    variant_a_style: str
    variant_b_style: str
    variant_a_image_url: str
    variant_b_image_url: str
    cost_a: Optional[float] = None
    cost_b: Optional[float] = None
    cost_delta: Optional[float] = None
    preservation_score_a: float = 0.0
    preservation_score_b: float = 0.0
    preservation_score_delta: float = 0.0
    shared_changes: List[str] = Field(default_factory=list)
    changes_unique_to_a: List[str] = Field(default_factory=list)
    changes_unique_to_b: List[str] = Field(default_factory=list)


class VideoScanMetadata(BaseModel):
    """
    Telemetry and motion characteristics from video scanning (Milestone 3.1 & Blueprint Section 8.3).
    """
    video_duration_seconds: float = Field(default=0.0, description="Length of recorded video scan")
    fps: float = Field(default=30.0, description="Frames per second")
    total_frames_recorded: int = Field(default=0, description="Raw total frames recorded")
    sampled_keyframes_count: int = Field(default=0, description="Selected keyframes for reconstruction")
    average_motion_speed_deg_per_sec: Optional[float] = Field(default=None, description="Average angular panning rate")
    motion_stability_score: float = Field(default=0.90, ge=0.0, le=1.0, description="1.0 = smooth panning, 0.0 = shaky")
    excessive_motion_warnings_count: int = Field(default=0, description="Number of times user panned too fast")
    coverage_score: float = Field(default=0.85, ge=0.0, le=1.0, description="Estimated coverage completeness")
    is_stable_sequence: bool = Field(default=True, description="True if motion meets reconstruction stability baseline")


class VideoKeyframe(BaseModel):
    """
    Smart-sampled keyframe extracted from continuous video sweep (Milestone 3.1).
    """
    keyframe_id: str = Field(default_factory=lambda: f"kf_{uuid.uuid4().hex[:6]}")
    frame_index: int = Field(..., description="Index in original video frame sequence")
    timestamp_seconds: float = Field(..., description="Time offset in video")
    image_url: str = Field(..., description="Path/URL to saved keyframe image")
    sharpness_score: float = Field(default=100.0, description="Laplacian variance sharpness metric")
    camera_motion_speed: Optional[float] = Field(default=None, description="Instantaneous motion speed")
    detected_wall_view: Optional[str] = Field(default=None, description="Semantic wall anchor (e.g., main_wall, corner_1)")
    estimated_coverage_pct: float = Field(default=0.0, description="Cumulative coverage reached with this frame")


class VideoScanReport(BaseModel):
    """
    Comprehensive video scan assessment fulfilling Milestone 3.1 exit criteria.
    Evaluates whether a non-LiDAR phone produced a sequence suitable for reconstruction.
    """
    session_id: str = Field(default_factory=lambda: f"vscan_{uuid.uuid4().hex[:8]}")
    room_id: str
    metadata: VideoScanMetadata = Field(default_factory=VideoScanMetadata)
    keyframes: List[VideoKeyframe] = Field(default_factory=list)
    quality_assessment: str = Field(default="EXCELLENT", description="EXCELLENT, ACCEPTABLE, UNSTABLE, INSUFFICIENT_COVERAGE")
    guidance_notes: List[str] = Field(default_factory=list)
    is_suitable_for_reconstruction: bool = Field(default=True)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class CameraPose(BaseModel):
    """
    Estimated 6-DoF camera pose for an individual viewpoint/keyframe.
    Fulfills Milestone 3.2 & Blueprint Section 9.
    """
    frame_id: str
    position: List[float] = Field(..., description="[x, y, z] camera location in room frame (meters)")
    rotation_quaternion: Optional[List[float]] = Field(default=None, description="[w, x, y, z] rotation quaternion")
    euler_angles_deg: Optional[List[float]] = Field(default=None, description="[yaw, pitch, roll] in degrees")
    viewing_direction: Optional[List[float]] = Field(default=None, description="[dx, dy, dz] unit gaze vector")


class SpatialPlane(BaseModel):
    """
    Architectural 3D surface plane fitted from dense point cloud via RANSAC.
    Fulfills Milestone 3.2 plane extraction.
    """
    plane_id: str = Field(default_factory=lambda: f"plane_{uuid.uuid4().hex[:6]}")
    plane_type: str = Field(..., description="floor, ceiling, wall, slanted")
    coefficients: List[float] = Field(..., description="[a, b, c, d] for ax + by + cz + d = 0")
    normal_vector: List[float] = Field(..., description="[nx, ny, nz] normalized surface normal")
    elevation_m: float = Field(default=0.0, description="Dominant elevation / distance along axis (meters)")
    inliers_count: int = Field(default=0, description="Number of supporting 3D points")
    confidence: float = Field(default=0.90, ge=0.0, le=1.0)
    boundary_polygon_2d: Optional[List[Point2D]] = Field(default=None, description="2D projected boundary polygon")
    associated_wall_id: Optional[str] = None


class PointCloudMetadata(BaseModel):
    """
    Dense 3D point cloud reconstructed from multi-view parallax (SfM/MVS).
    Fulfills Milestone 3.2 point cloud deliverables.
    """
    point_cloud_id: str = Field(default_factory=lambda: f"pcd_{uuid.uuid4().hex[:8]}")
    total_points: int = Field(default=0)
    density_pts_per_sqm: float = Field(default=150.0)
    bounds_min: List[float] = Field(default_factory=lambda: [-2.0, -2.0, 0.0])
    bounds_max: List[float] = Field(default_factory=lambda: [2.0, 2.0, 2.8])
    file_url: Optional[str] = Field(None, description="URL or relative path to .ply point cloud file")
    has_rgb_colors: bool = Field(default=True)


class MultiViewReconstructionReport(BaseModel):
    """
    Complete Multi-View Stereo (SfM/MVS) reconstruction report.
    Fulfills Milestone 3.2 exit criteria.
    """
    reconstruction_id: str = Field(default_factory=lambda: f"recon_{uuid.uuid4().hex[:8]}")
    room_id: str
    method: str = Field(default="SFM_MVS", description="SFM_MVS, COLMAP_COMPATIBLE, GAUSSIAN_SPLAT")
    camera_poses: List[CameraPose] = Field(default_factory=list)
    spatial_planes: List[SpatialPlane] = Field(default_factory=list)
    point_cloud: Optional[PointCloudMetadata] = None
    reconstruction_status: str = Field(default="COMPLETED", description="COMPLETED, DEGRADED, FAILED")
    spatial_consistency_score: float = Field(default=0.92, ge=0.0, le=1.0)
    is_consistently_reconstructed: bool = Field(default=True)
    estimated_volume_cbm: Optional[float] = None
    notes: List[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ARCameraPose(BaseModel):
    """
    Client-side 6-DoF visual-inertial odometry (VIO) pose from ARKit/ARCore without LiDAR.
    Fulfills Milestone 3.3.
    """
    frame_index: int = 0
    timestamp_ms: float = 0.0
    translation: List[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0], description="[x, y, z] in meters")
    rotation_quaternion: List[float] = Field(default_factory=lambda: [1.0, 0.0, 0.0, 0.0], description="[w, x, y, z]")
    tracking_state: str = Field(default="TRACKING", description="TRACKING, PAUSED, STOPPED")
    feature_points_count: int = Field(default=150, ge=0)
    confidence: float = Field(default=0.95, ge=0.0, le=1.0)


class IMUMotionSample(BaseModel):
    """
    Inertial Measurement Unit (IMU) telemetry sample associated with camera keyframes.
    Fulfills Milestone 3.3.
    """
    timestamp_ms: float = 0.0
    acceleration: List[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0], description="[ax, ay, az] in m/s^2")
    rotation_rate: List[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0], description="[gx, gy, gz] in rad/s")
    gravity_vector: List[float] = Field(default_factory=lambda: [0.0, 0.0, -9.81], description="[gx, gy, gz]")
    heading_deg: float = 0.0
    tilt_deg: float = 0.0


class DepthFromMotionPayload(BaseModel):
    """
    Sparse/dense depth points inferred from camera motion (e.g. ARCore Depth API / ARKit without LiDAR).
    Fulfills Milestone 3.3.
    """
    depth_map_url: Optional[str] = None
    sparse_points_count: int = 0
    min_depth_m: float = 0.5
    max_depth_m: float = 6.0
    mean_depth_confidence: float = Field(default=0.88, ge=0.0, le=1.0)
    sparse_point_samples: List[List[float]] = Field(default_factory=list, description="List of [x, y, z, confidence]")


class ARAssistedScanReport(BaseModel):
    """
    Multi-sensor fusion report linking AR VIO poses, IMU motion, depth-from-motion, and 3D reconstruction.
    Fulfills Milestone 3.3 exit criteria.
    """
    session_id: str = Field(default_factory=lambda: f"arsess_{uuid.uuid4().hex[:8]}")
    room_id: str
    tracking_quality: str = Field(default="EXCELLENT", description="EXCELLENT, ACCEPTABLE, DEGRADED, LOST")
    poses_count: int = 0
    imu_samples_count: int = 0
    has_depth_from_motion: bool = False
    scale_factor_estimated: float = Field(default=1.0, gt=0.0)
    motion_trajectory_length_m: float = 0.0
    fused_consistency_score: float = Field(default=0.95, ge=0.0, le=1.0)
    fusion_tier: str = Field(default="TIER_3_AR_RGB", description="TIER_2_AR_DEPTH, TIER_3_AR_RGB")
    notes: List[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class NativeSurfaceScan(BaseModel):
    """
    Architectural boundary surface detected by native spatial hardware (Apple RoomPlan / Android ToF).
    Fulfills Milestone 3.4.
    """
    surface_id: str = Field(default_factory=lambda: f"nsurf_{uuid.uuid4().hex[:6]}")
    category: str = Field(..., description="wall, floor, ceiling")
    dimensions_m: List[float] = Field(default_factory=lambda: [3.0, 2.8, 0.15], description="[width, height, thickness/length]")
    transform_matrix: Optional[List[float]] = Field(default=None, description="4x4 column-major or row-major transform matrix (16 floats)")
    translation: List[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0], description="[x, y, z] center in meters")
    normal_vector: List[float] = Field(default_factory=lambda: [0.0, 1.0, 0.0], description="[nx, ny, nz] surface normal")
    boundary_points_2d: Optional[List[List[float]]] = Field(default=None, description="2D floor plan projection coordinates [[x, y], ...]")
    confidence: float = Field(default=0.98, ge=0.0, le=1.0)


class NativeOpeningScan(BaseModel):
    """
    Architectural opening (door, window, opening) detected by native spatial hardware.
    Fulfills Milestone 3.4.
    """
    opening_id: str = Field(default_factory=lambda: f"nopn_{uuid.uuid4().hex[:6]}")
    category: str = Field(..., description="door, window, opening")
    dimensions_m: List[float] = Field(default_factory=lambda: [0.9, 2.1], description="[width, height]")
    translation: List[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0], description="[x, y, z] center in meters")
    parent_wall_id: Optional[str] = None
    confidence: float = Field(default=0.98, ge=0.0, le=1.0)


class NativeObjectScan(BaseModel):
    """
    3D furniture or fixture detected by native spatial hardware (RoomPlan CapturedRoom.objects).
    Fulfills Milestone 3.4.
    """
    object_id: str = Field(default_factory=lambda: f"nobj_{uuid.uuid4().hex[:6]}")
    category: str = Field(..., description="chair, table, sofa, bed, storage, refrigerator, stove, sink, etc.")
    label: Optional[str] = None
    dimensions_m: List[float] = Field(default_factory=lambda: [1.0, 1.0, 0.8], description="[width, length, height]")
    translation: List[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0], description="[x, y, z] center in meters")
    rotation_deg: float = 0.0
    confidence: float = Field(default=0.95, ge=0.0, le=1.0)


class NativeSpatialScanPayload(BaseModel):
    """
    Client-side native LiDAR / hardware depth capture payload submitted for normalization.
    Fulfills Milestone 3.4.
    """
    room_id: Optional[str] = None
    project_id: Optional[str] = None
    platform: str = Field(default="apple_roomplan", description="apple_roomplan or android_hardware_depth")
    device_tier: str = Field(default="TIER_1_LIDAR", description="TIER_1_LIDAR or TIER_2_AR_DEPTH")
    surfaces: List[NativeSurfaceScan] = Field(default_factory=list)
    openings: List[NativeOpeningScan] = Field(default_factory=list)
    objects: List[NativeObjectScan] = Field(default_factory=list)
    mesh_vertices_count: int = 0
    sensor_notes: List[str] = Field(default_factory=list)


class NativeSpatialScanReport(BaseModel):
    """
    Normalization report certifying native hardware LiDAR / ToF spatial scan integration.
    Fulfills Milestone 3.4 exit criteria.
    """
    scan_id: str = Field(default_factory=lambda: f"spatial_{uuid.uuid4().hex[:8]}")
    room_id: str
    platform: str = "apple_roomplan"
    hardware_type: str = "APPLE_LIDAR_ROOMPLAN"
    surfaces_detected: int = 0
    openings_detected: int = 0
    objects_detected: int = 0
    confidence_score: float = Field(default=0.98, ge=0.0, le=1.0)
    measurement_provenance: str = Field(default="LIDAR_NATIVE", description="LIDAR_NATIVE or HARDWARE_DEPTH")
    raw_scan_retained: bool = True
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class TierBenchmarkMetrics(BaseModel):
    """
    Standardized accuracy, latency, and cost telemetry benchmarks by device capability tier.
    Fulfills Blueprint Section 41 Milestone 3.5.
    """
    tier_id: str
    tier_name: str
    hardware_description: str
    scan_mode: str
    primary_framework: str
    typical_accuracy_cm: float
    accuracy_tier: str = "APPROXIMATE"
    expected_confidence: float = 0.90
    mean_capture_time_sec: float = 25.0
    mean_processing_time_sec: float = 8.0
    relative_compute_cost_usd: float = 0.015
    scale_stability: str = "METRIC_SCALED"
    loop_closure_reliability: str = "RANSAC_OPTIMIZED"
    supported_devices_sample: List[str] = Field(default_factory=list)


def get_standard_tier_benchmarks() -> List[TierBenchmarkMetrics]:
    """Returns static comparative performance & accuracy matrix across all 5 capability tiers."""
    return [
        TierBenchmarkMetrics(
            tier_id="TIER_1_LIDAR",
            tier_name="Hardware LiDAR Mesh",
            hardware_description="Direct time-of-flight laser scanner (iPhone Pro / iPad Pro)",
            scan_mode="lidar_scan",
            primary_framework="Apple RoomPlan / ARKit",
            typical_accuracy_cm=0.8,
            accuracy_tier="EXACT",
            expected_confidence=0.98,
            mean_capture_time_sec=15.0,
            mean_processing_time_sec=3.0,
            relative_compute_cost_usd=0.005,
            scale_stability="ABSOLUTE_SI_METRIC",
            loop_closure_reliability="NATIVE_HARDWARE_CLOSED",
            supported_devices_sample=["iPhone 12-16 Pro / Pro Max", "iPad Pro LiDAR (2020+)"],
        ),
        TierBenchmarkMetrics(
            tier_id="TIER_2_AR_DEPTH",
            tier_name="AR Hardware Depth / ToF",
            hardware_description="Infrared Time-of-Flight / active depth sensor on Android or iOS",
            scan_mode="ar_depth_scan",
            primary_framework="Android ARCore Depth API / ARKit Depth",
            typical_accuracy_cm=2.5,
            accuracy_tier="EXACT",
            expected_confidence=0.96,
            mean_capture_time_sec=20.0,
            mean_processing_time_sec=5.0,
            relative_compute_cost_usd=0.010,
            scale_stability="METRIC_DEPTH_SCALED",
            loop_closure_reliability="NATIVE_DEPTH_FUSED",
            supported_devices_sample=["Samsung Galaxy S20-S24 Ultra", "Pixel 4/8 Pro", "OnePlus 11/12"],
        ),
        TierBenchmarkMetrics(
            tier_id="TIER_3_AR_RGB",
            tier_name="AR Visual-Inertial Odometry",
            hardware_description="6-DoF VIO camera tracking with IMU motion sensors (No LiDAR)",
            scan_mode="ar_rgb_scan",
            primary_framework="ARCore / ARKit VIO Motion Fusion",
            typical_accuracy_cm=4.5,
            accuracy_tier="EXACT",
            expected_confidence=0.94,
            mean_capture_time_sec=25.0,
            mean_processing_time_sec=8.0,
            relative_compute_cost_usd=0.015,
            scale_stability="VIO_ODOMETRY_SCALED",
            loop_closure_reliability="KEYFRAME_LOOP_CLOSED",
            supported_devices_sample=["Standard iPhone 11-16", "Google Pixel 6-8a", "Galaxy S21-S24 Base"],
        ),
        TierBenchmarkMetrics(
            tier_id="TIER_4_VIDEO_SWEEP",
            tier_name="Guided Monocular Video Sweep",
            hardware_description="Standard HD video sweep with keyframe extraction & Structure-from-Motion",
            scan_mode="rgb_video_scan",
            primary_framework="Roomlyst Video Keyframe SfM Pipeline",
            typical_accuracy_cm=7.5,
            accuracy_tier="APPROXIMATE",
            expected_confidence=0.90,
            mean_capture_time_sec=30.0,
            mean_processing_time_sec=12.0,
            relative_compute_cost_usd=0.025,
            scale_stability="SFM_MULTI_VIEW_SCALED",
            loop_closure_reliability="RANSAC_OPTIMIZED",
            supported_devices_sample=["Any smartphone with 1080p camera & accelerometer"],
        ),
        TierBenchmarkMetrics(
            tier_id="TIER_5_BASIC_RGB",
            tier_name="Multi-Corner Photo Capture",
            hardware_description="3-4 corner photos with optional paper/wall scale calibration",
            scan_mode="rgb_photo_scan",
            primary_framework="Multi-View Associator & Monocular Depth",
            typical_accuracy_cm=12.0,
            accuracy_tier="APPROXIMATE",
            expected_confidence=0.85,
            mean_capture_time_sec=45.0,
            mean_processing_time_sec=10.0,
            relative_compute_cost_usd=0.020,
            scale_stability="REFERENCE_CALIBRATION_RECOMMENDED",
            loop_closure_reliability="CORNER_POLYGON_SNAPPED",
            supported_devices_sample=["Entry-level Android/iOS devices", "Legacy smartphones", "Web camera"],
        ),
    ]


class ScanOrchestrationEvaluation(BaseModel):
    """
    Evaluation result and orchestrated fallback routing based on runtime device capability.
    Fulfills Milestone 3.5.
    """
    evaluated_tier: str
    recommended_scan_mode: str
    user_guidance_prompt: str
    accuracy_assurance: str
    fallback_chain: List[str] = Field(default_factory=list)
    fallback_reasons: List[str] = Field(default_factory=list)
    active_benchmark: TierBenchmarkMetrics
    all_tier_benchmarks: List[TierBenchmarkMetrics] = Field(default_factory=list)
    evaluated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


def evaluate_scan_orchestration(profile: Any) -> ScanOrchestrationEvaluation:
    """
    Evaluates runtime device capabilities and resolves the optimal capture mode,
    full graceful degradation fallback chain, and comparative telemetry benchmarks.
    """
    all_benchmarks = get_standard_tier_benchmarks()
    benchmarks_by_tier = {b.tier_id: b for b in all_benchmarks}

    # Extract boolean flags safely from dict or CaptureMetadata
    def get_flag(prop: str) -> bool:
        if isinstance(profile, dict):
            return bool(profile.get(prop, False))
        return bool(getattr(profile, prop, False))

    has_lidar = get_flag("has_lidar") or get_flag("lidar_supported")
    has_hw_depth = get_flag("has_hardware_depth") or get_flag("has_arcore_depth")
    has_ar = get_flag("has_ar") or get_flag("has_arkit") or get_flag("has_arcore") or get_flag("ar_supported")
    has_motion = get_flag("has_motion_sensors")

    if has_lidar:
        tier_id = "TIER_1_LIDAR"
        mode = "lidar_scan"
        prompt = "Scan Room: Point camera and walk around room to capture exact 3D geometry."
        assurance = "Hardware 3D Precision (High Accuracy < 1cm exact)"
        fallbacks = ["ar_rgb_scan", "rgb_video_scan", "rgb_photo_scan"]
        reasons = [
            "Fallback to AR Motion if direct LiDAR laser meshing is unavailable or obstructed",
            "Fallback to Video Sweep if rapid motion causes tracking degradation",
            "Fallback to Multi-Corner Photos for static baseline capture",
        ]
    elif has_hw_depth:
        tier_id = "TIER_2_AR_DEPTH"
        mode = "ar_depth_scan"
        prompt = "Scan Room: Move smoothly across surfaces to map depth and walls."
        assurance = "AR Depth Sensor (~2-3cm High Accuracy)"
        fallbacks = ["ar_rgb_scan", "rgb_video_scan", "rgb_photo_scan"]
        reasons = [
            "Fallback to AR Motion if infrared ToF depth is noisy or out-of-range",
            "Fallback to Video Sweep if tracking drops",
            "Fallback to Multi-Corner Photos for manual/reference capture",
        ]
    elif has_ar:
        tier_id = "TIER_3_AR_RGB"
        mode = "ar_rgb_scan"
        prompt = "Move slowly around room: Point at floor and walls to track boundaries."
        assurance = "AR Motion Geometry (~3-5cm Metric VIO)"
        fallbacks = ["rgb_video_scan", "rgb_photo_scan"]
        reasons = [
            "Fallback to Video Sweep if visual-inertial odometry drifts",
            "Fallback to Multi-Corner Photos if lighting is too dim for continuous tracking",
        ]
    elif has_motion:
        tier_id = "TIER_4_VIDEO_SWEEP"
        mode = "rgb_video_scan"
        prompt = "Walk around room: Record continuous view with overlapping angles."
        assurance = "Structure-from-Motion Multi-View (~5-8cm Approximate)"
        fallbacks = ["rgb_photo_scan"]
        reasons = [
            "Fallback to Multi-Corner Photos if camera motion blur exceeds threshold",
        ]
    else:
        tier_id = "TIER_5_BASIC_RGB"
        mode = "rgb_photo_scan"
        prompt = "Capture Room: Take photos from room corners with good lighting."
        assurance = "AI Vision Estimated (~10-15cm - Manual Reference Recommended)"
        fallbacks = ["single_photo_reference_scaled"]
        reasons = [
            "Fallback to Single Photo with A4 / Door reference scale calibration if multiple corners cannot be accessed",
        ]

    active_b = benchmarks_by_tier.get(tier_id, all_benchmarks[-1])

    return ScanOrchestrationEvaluation(
        evaluated_tier=tier_id,
        recommended_scan_mode=mode,
        user_guidance_prompt=prompt,
        accuracy_assurance=assurance,
        fallback_chain=fallbacks,
        fallback_reasons=reasons,
        active_benchmark=active_b,
        all_tier_benchmarks=all_benchmarks,
        evaluated_at=datetime.now(timezone.utc),
    )


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
    budget_plan: Optional[BudgetPlan] = None
    video_scan_report: Optional[VideoScanReport] = None
    reconstruction_report: Optional[MultiViewReconstructionReport] = None
    spatial_planes: List[SpatialPlane] = Field(default_factory=list)
    ar_assisted_report: Optional[ARAssistedScanReport] = None
    native_spatial_report: Optional[NativeSpatialScanReport] = None
    orchestration_evaluation: Optional[ScanOrchestrationEvaluation] = None
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
            renovation_tier=self.budget_plan.renovation_tier.value if self.budget_plan else "MODERATE",
            preserve_ids=preserve_ids,
            replace_ids=replace_ids,
            remove_ids=remove_ids,
            restyle_ids=restyle_ids,
            goals=goals or [],
            free_text_prompt=free_text,
        )
