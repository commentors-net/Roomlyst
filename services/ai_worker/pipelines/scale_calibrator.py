"""
Scale Calibrator Pipeline.
Fulfills Milestone 2.2 & Blueprint Section 12 (Measurement and Scale Without LiDAR).
Enables metric scale calibration via user-provided dimensions, standard paper,
door heights, floor tiles, and reference markers.
"""

from typing import Any, Dict, List, Optional
from packages.room_model import (
    CanonicalRoomModel,
    ReferenceScaleType,
    ScaleCalibration,
)


class ReferencePreset:
    def __init__(
        self,
        preset_id: str,
        title: str,
        description: str,
        reference_type: ReferenceScaleType,
        dimension_type: str,
        value_meters: float,
        guidance: str,
    ):
        self.preset_id = preset_id
        self.title = title
        self.description = description
        self.reference_type = reference_type
        self.dimension_type = dimension_type
        self.value_meters = value_meters
        self.guidance = guidance

    def to_dict(self) -> Dict[str, Any]:
        return {
            "preset_id": self.preset_id,
            "title": self.title,
            "description": self.description,
            "reference_type": self.reference_type.value,
            "dimension_type": self.dimension_type,
            "value_meters": self.value_meters,
            "guidance": self.guidance,
        }


class ScaleCalibrator:
    """
    Manages scale calibration presets and applies mathematical scaling across
    canonical room geometry, boundary surfaces, and measurements.
    """

    PRESETS: List[ReferencePreset] = [
        ReferencePreset(
            preset_id="preset_known_wall",
            title="Known Wall Dimension",
            description="Measure any wall with a standard tape measure",
            reference_type=ReferenceScaleType.KNOWN_WALL_DIMENSION,
            dimension_type="width",
            value_meters=4.20,
            guidance="Measure the width of the main wall from corner to corner and enter the exact value.",
        ),
        ReferencePreset(
            preset_id="preset_door_height",
            title="Standard Door Height",
            description="Standard interior architectural doorway (2.10 m)",
            reference_type=ReferenceScaleType.STANDARD_DOOR_HEIGHT,
            dimension_type="height",
            value_meters=2.10,
            guidance="Aligns vertical room scale to standard 2.10m residential door clearance.",
        ),
        ReferencePreset(
            preset_id="preset_a4_paper",
            title="A4 Paper Sheet on Floor",
            description="Standard ISO 216 paper sheet (0.297 m long edge)",
            reference_type=ReferenceScaleType.A4_PAPER,
            dimension_type="length",
            value_meters=0.297,
            guidance="Place a standard sheet of paper on the floor before photographing.",
        ),
        ReferencePreset(
            preset_id="preset_floor_tile_60",
            title="Large Floor Tile (60 x 60 cm)",
            description="Standard 600 mm porcelain / ceramic floor tile",
            reference_type=ReferenceScaleType.FLOOR_TILE,
            dimension_type="width",
            value_meters=0.60,
            guidance="Calibrates room floor area based on 60cm square tile grid.",
        ),
        ReferencePreset(
            preset_id="preset_floor_tile_30",
            title="Medium Floor Tile (30 x 30 cm)",
            description="Standard 300 mm ceramic tile",
            reference_type=ReferenceScaleType.FLOOR_TILE,
            dimension_type="width",
            value_meters=0.30,
            guidance="Calibrates room floor area based on 30cm square tile grid.",
        ),
        ReferencePreset(
            preset_id="preset_credit_card",
            title="Standard Credit / ID Card",
            description="ISO/IEC 7810 ID-1 card (85.6 mm width)",
            reference_type=ReferenceScaleType.CREDIT_CARD,
            dimension_type="width",
            value_meters=0.0856,
            guidance="Place a card on a table or counter as a known optical scale reference.",
        ),
    ]

    @classmethod
    def get_presets(cls) -> List[Dict[str, Any]]:
        return [p.to_dict() for p in cls.PRESETS]

    def calibrate(
        self,
        room: CanonicalRoomModel,
        target_real_value: float,
        reference_type: ReferenceScaleType = ReferenceScaleType.KNOWN_WALL_DIMENSION,
        reference_dimension_type: str = "width",
        reference_entity_id: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> ScaleCalibration:
        """
        Executes scale calibration on the room model.
        """
        if target_real_value <= 0:
            raise ValueError("Target real value must be greater than 0 meters.")

        return room.calibrate_scale(
            target_real_value=target_real_value,
            reference_type=reference_type,
            reference_dimension_type=reference_dimension_type,
            reference_entity_id=reference_entity_id,
            notes=notes,
        )
