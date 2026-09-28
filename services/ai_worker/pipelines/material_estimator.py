"""
Material and Quantity Estimation Pipeline (Milestone 4.1).
Computes surface-area-derived approximate quantities, configurable waste factors,
confidence-aware estimation bounds, and contractor critical-dimension verification tracking.
"""

import math
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from packages.room_model.schema import (
    CanonicalRoomModel,
    CriticalDimensionType,
    CriticalDimensionVerification,
    DimensionVerificationStatus,
    MaterialCategory,
    MaterialTakeoffItem,
    MaterialTakeoffReport,
    MeasurementSource,
    RoomShapeType,
)


class MaterialEstimatorEngine:
    """
    Engine for automated bill-of-materials and surface takeoff synthesis.
    Fulfills Blueprint Milestone 4.1.
    """

    DEFAULT_WASTE_FACTORS: Dict[MaterialCategory, float] = {
        MaterialCategory.FLOORING: 10.0,
        MaterialCategory.WALL_PAINT: 10.0,
        MaterialCategory.WALLPAPER: 15.0,
        MaterialCategory.WALL_TILING: 12.0,
        MaterialCategory.CEILING_PAINT: 10.0,
        MaterialCategory.SKIRTING_BASEBOARD: 10.0,
        MaterialCategory.DRYWALL_PLASTER: 10.0,
    }

    def compute_material_takeoff(
        self,
        room: CanonicalRoomModel,
        custom_waste_factors: Optional[Dict[str, float]] = None,
    ) -> MaterialTakeoffReport:
        """
        Computes comprehensive material and quantity takeoff from the CanonicalRoomModel geometry.
        """
        waste_config: Dict[str, float] = {}
        for cat, default_pct in self.DEFAULT_WASTE_FACTORS.items():
            waste_config[cat.value] = default_pct

        # Apply room-shape adjustment: irregular rooms require higher waste allowances
        is_irregular = (
            room.geometry.shape_type in [RoomShapeType.L_SHAPED, RoomShapeType.IRREGULAR]
            or (room.geometry.confidence and room.geometry.confidence < 0.82)
        )
        if is_irregular:
            waste_config[MaterialCategory.FLOORING.value] = 15.0
            waste_config[MaterialCategory.WALL_TILING.value] = 15.0
            waste_config[MaterialCategory.SKIRTING_BASEBOARD.value] = 15.0

        if custom_waste_factors:
            for k, v in custom_waste_factors.items():
                k_upper = k.upper()
                if k_upper in waste_config:
                    waste_config[k_upper] = max(0.0, min(50.0, float(v)))

        # 1. Derive fundamental room spatial metrics
        floor_area = room.geometry.floor_area_sqm if (room.geometry and room.geometry.floor_area_sqm > 0) else 20.0
        wall_perimeter = room.geometry.wall_perimeter_m if (room.geometry and room.geometry.wall_perimeter_m > 0) else 18.0
        wall_height = room.geometry.wall_height_m if (room.geometry and room.geometry.wall_height_m > 0) else 2.8
        ceiling_area = floor_area

        # Deduct openings from wall area
        openings_deducted_area = 0.0
        total_door_width = 0.0
        if room.openings:
            for opn in room.openings:
                w = opn.width_m or 0.9
                h = opn.height_m or 2.0
                openings_deducted_area += round(w * h, 3)
                if opn.opening_type.value.lower() == "door":
                    total_door_width += round(w, 3)
        else:
            # Fallback standard architectural deductions (1 standard door + 1 standard window)
            openings_deducted_area = 1.89 + 1.44
            total_door_width = 0.9

        gross_wall_area = round(wall_perimeter * wall_height, 2)
        net_wall_area = max(5.0, round(gross_wall_area - openings_deducted_area, 2))
        baseboard_perimeter = max(2.0, round(wall_perimeter - total_door_width, 2))

        # 2. Determine confidence and uncertainty bounds from sensor provenance
        uncertainty_pct, confidence, accuracy_tier = self._resolve_provenance_uncertainty(room)

        # 3. Build Takeoff Items
        items: List[MaterialTakeoffItem] = []

        # A. Flooring
        flooring_waste = waste_config[MaterialCategory.FLOORING.value]
        flooring_waste_qty = round(floor_area * (flooring_waste / 100.0), 2)
        flooring_gross = round(floor_area + flooring_waste_qty, 2)
        items.append(
            MaterialTakeoffItem(
                item_id=f"item_floor_{uuid.uuid4().hex[:6]}",
                category=MaterialCategory.FLOORING,
                name="Hardwood / Engineered Flooring / Tiles",
                description="Floor surface coverage with allowance for cuts, offsets, and border alignment",
                net_quantity=floor_area,
                unit="sqm",
                waste_factor_pct=flooring_waste,
                waste_quantity=flooring_waste_qty,
                gross_quantity=flooring_gross,
                confidence_score=confidence,
                uncertainty_pct=uncertainty_pct,
                min_recommended_quantity=round(flooring_gross * (1.0 - uncertainty_pct / 100.0), 2),
                max_recommended_quantity=round(flooring_gross * (1.0 + uncertainty_pct / 100.0), 2),
                packaging_spec="Cartons of 1.44 sqm",
                estimated_packages=math.ceil(flooring_gross / 1.44),
                requires_contractor_verification=True,
            )
        )

        # B. Wall Paint (2 coats @ 10 sqm/liter)
        paint_waste = waste_config[MaterialCategory.WALL_PAINT.value]
        paint_net_liters = round((net_wall_area * 2.0) / 10.0, 2)
        paint_waste_qty = round(paint_net_liters * (paint_waste / 100.0), 2)
        paint_gross = round(paint_net_liters + paint_waste_qty, 2)
        items.append(
            MaterialTakeoffItem(
                item_id=f"item_paint_{uuid.uuid4().hex[:6]}",
                category=MaterialCategory.WALL_PAINT,
                name="Premium Interior Wall Paint (2 Coats)",
                description=f"Covers {net_wall_area} sqm net vertical wall area after opening deductions",
                net_quantity=paint_net_liters,
                unit="liters",
                waste_factor_pct=paint_waste,
                waste_quantity=paint_waste_qty,
                gross_quantity=paint_gross,
                confidence_score=confidence,
                uncertainty_pct=uncertainty_pct,
                min_recommended_quantity=round(paint_gross * (1.0 - uncertainty_pct / 100.0), 2),
                max_recommended_quantity=round(paint_gross * (1.0 + uncertainty_pct / 100.0), 2),
                packaging_spec="2.5 Liter Cans (~25 sqm coverage per coat)",
                estimated_packages=math.ceil(paint_gross / 2.5),
                requires_contractor_verification=False,
            )
        )

        # C. Ceiling Paint (2 coats @ 10 sqm/liter)
        ceil_waste = waste_config[MaterialCategory.CEILING_PAINT.value]
        ceil_net_liters = round((ceiling_area * 2.0) / 10.0, 2)
        ceil_waste_qty = round(ceil_net_liters * (ceil_waste / 100.0), 2)
        ceil_gross = round(ceil_net_liters + ceil_waste_qty, 2)
        items.append(
            MaterialTakeoffItem(
                item_id=f"item_ceil_{uuid.uuid4().hex[:6]}",
                category=MaterialCategory.CEILING_PAINT,
                name="Ceiling Emulsion / Anti-Reflective White",
                description=f"Ceiling overhead coverage ({ceiling_area} sqm)",
                net_quantity=ceil_net_liters,
                unit="liters",
                waste_factor_pct=ceil_waste,
                waste_quantity=ceil_waste_qty,
                gross_quantity=ceil_gross,
                confidence_score=confidence,
                uncertainty_pct=uncertainty_pct,
                min_recommended_quantity=round(ceil_gross * (1.0 - uncertainty_pct / 100.0), 2),
                max_recommended_quantity=round(ceil_gross * (1.0 + uncertainty_pct / 100.0), 2),
                packaging_spec="5.0 Liter Buckets",
                estimated_packages=math.ceil(ceil_gross / 5.0),
                requires_contractor_verification=False,
            )
        )

        # D. Baseboards / Skirting
        skirting_waste = waste_config[MaterialCategory.SKIRTING_BASEBOARD.value]
        skirting_waste_m = round(baseboard_perimeter * (skirting_waste / 100.0), 2)
        skirting_gross_m = round(baseboard_perimeter + skirting_waste_m, 2)
        items.append(
            MaterialTakeoffItem(
                item_id=f"item_skirt_{uuid.uuid4().hex[:6]}",
                category=MaterialCategory.SKIRTING_BASEBOARD,
                name="Perimeter Skirting / Baseboards",
                description="Floor-to-wall trim linear run after door threshold deductions",
                net_quantity=baseboard_perimeter,
                unit="m",
                waste_factor_pct=skirting_waste,
                waste_quantity=skirting_waste_m,
                gross_quantity=skirting_gross_m,
                confidence_score=confidence,
                uncertainty_pct=uncertainty_pct,
                min_recommended_quantity=round(skirting_gross_m * (1.0 - uncertainty_pct / 100.0), 2),
                max_recommended_quantity=round(skirting_gross_m * (1.0 + uncertainty_pct / 100.0), 2),
                packaging_spec="2.4m Length Timber Planks",
                estimated_packages=math.ceil(skirting_gross_m / 2.4),
                requires_contractor_verification=False,
            )
        )

        # E. Wallpaper (Accent Feature Wall - ~25% of net wall area)
        wp_waste = waste_config[MaterialCategory.WALLPAPER.value]
        wp_net = round(net_wall_area * 0.25, 2)
        wp_waste_qty = round(wp_net * (wp_waste / 100.0), 2)
        wp_gross = round(wp_net + wp_waste_qty, 2)
        items.append(
            MaterialTakeoffItem(
                item_id=f"item_wp_{uuid.uuid4().hex[:6]}",
                category=MaterialCategory.WALLPAPER,
                name="Feature Wall Wallpaper",
                description="Single accent wall calculation with vertical pattern matching allowance",
                net_quantity=wp_net,
                unit="sqm",
                waste_factor_pct=wp_waste,
                waste_quantity=wp_waste_qty,
                gross_quantity=wp_gross,
                confidence_score=confidence,
                uncertainty_pct=uncertainty_pct,
                min_recommended_quantity=round(wp_gross * (1.0 - uncertainty_pct / 100.0), 2),
                max_recommended_quantity=round(wp_gross * (1.0 + uncertainty_pct / 100.0), 2),
                packaging_spec="Standard Rolls (0.53m x 10m ≈ 5.3 sqm)",
                estimated_packages=math.ceil(wp_gross / 5.3),
                requires_contractor_verification=True,
            )
        )

        # F. Wall Tiling (Included for kitchen/bathroom or specific restyle requests)
        is_wet_room = (
            room.room_type.lower() in ["bathroom", "toilet", "kitchen", "washroom", "laundry"]
            or any(s.surface_type.value.lower() == "tile" for s in room.surfaces)
        )
        if is_wet_room:
            tiling_waste = waste_config[MaterialCategory.WALL_TILING.value]
            tiling_net = round(net_wall_area * 0.65, 2) # Wet splash zones
            tiling_waste_qty = round(tiling_net * (tiling_waste / 100.0), 2)
            tiling_gross = round(tiling_net + tiling_waste_qty, 2)
            items.append(
                MaterialTakeoffItem(
                    item_id=f"item_tile_{uuid.uuid4().hex[:6]}",
                    category=MaterialCategory.WALL_TILING,
                    name="Ceramic / Porcelain Wall Tiling",
                    description="Waterproof wall tile coverage in splash zones",
                    net_quantity=tiling_net,
                    unit="sqm",
                    waste_factor_pct=tiling_waste,
                    waste_quantity=tiling_waste_qty,
                    gross_quantity=tiling_gross,
                    confidence_score=confidence,
                    uncertainty_pct=uncertainty_pct,
                    min_recommended_quantity=round(tiling_gross * (1.0 - uncertainty_pct / 100.0), 2),
                    max_recommended_quantity=round(tiling_gross * (1.0 + uncertainty_pct / 100.0), 2),
                    packaging_spec="Boxes of 1.0 sqm",
                    estimated_packages=math.ceil(tiling_gross / 1.0),
                    requires_contractor_verification=True,
                )
            )

        # 4. Critical Dimensions for Contractor/Physical Verification
        critical_dims = self._build_critical_dimensions(room, floor_area, wall_height, wall_perimeter, uncertainty_pct, confidence)

        notes = [
            f"Calculated with {accuracy_tier} precision ({confidence * 100:.0f}% sensor confidence, ±{uncertainty_pct:.0f}% error tolerance).",
            f"Net wall area reflects {openings_deducted_area:.2f} sqm deduction across detected door and window openings.",
            "Contractor verification is strongly advised for critical dimensions prior to placing custom non-refundable orders.",
        ]

        report = MaterialTakeoffReport(
            report_id=f"takeoff_{uuid.uuid4().hex[:8]}",
            room_id=room.id,
            gross_floor_area_sqm=round(floor_area, 2),
            net_wall_area_sqm=round(net_wall_area, 2),
            ceiling_area_sqm=round(ceiling_area, 2),
            baseboard_perimeter_m=round(baseboard_perimeter, 2),
            openings_deducted_area_sqm=round(openings_deducted_area, 2),
            default_waste_factors=waste_config,
            items=items,
            critical_dimensions=critical_dims,
            overall_confidence=confidence,
            accuracy_tier=accuracy_tier,
            generated_at=datetime.now(timezone.utc),
            notes=notes,
        )

        return report

    def verify_critical_dimension(
        self,
        report: MaterialTakeoffReport,
        dimension_id: str,
        verified_value: float,
        verified_by: str = "Contractor",
        status: DimensionVerificationStatus = DimensionVerificationStatus.CONTRACTOR_VERIFIED,
    ) -> MaterialTakeoffReport:
        """
        Updates a critical dimension with on-site physical measurement, and adjusts affected items.
        """
        target_dim: Optional[CriticalDimensionVerification] = None
        for dim in report.critical_dimensions:
            if dim.dimension_id == dimension_id:
                target_dim = dim
                break

        if not target_dim:
            return report

        target_dim.verified_value = round(verified_value, 3)
        target_dim.verified_by = verified_by
        target_dim.verified_at = datetime.now(timezone.utc)
        target_dim.verification_status = status
        target_dim.confidence = 0.99
        target_dim.uncertainty_margin_pct = 1.0

        # Propagate verified values to takeoff items if floor area was verified
        if target_dim.dimension_type == CriticalDimensionType.FLOOR_AREA:
            diff_factor = verified_value / max(0.1, target_dim.estimated_value)
            for itm in report.items:
                if itm.category == MaterialCategory.FLOORING:
                    itm.net_quantity = round(verified_value, 2)
                    itm.waste_quantity = round(itm.net_quantity * (itm.waste_factor_pct / 100.0), 2)
                    itm.gross_quantity = round(itm.net_quantity + itm.waste_quantity, 2)
                    itm.min_recommended_quantity = round(itm.gross_quantity * 0.98, 2)
                    itm.max_recommended_quantity = round(itm.gross_quantity * 1.02, 2)
                    if itm.packaging_spec and "1.44" in itm.packaging_spec:
                        itm.estimated_packages = math.ceil(itm.gross_quantity / 1.44)
                    itm.requires_contractor_verification = False
            report.gross_floor_area_sqm = round(verified_value, 2)
            report.ceiling_area_sqm = round(verified_value, 2)

        return report

    def _resolve_provenance_uncertainty(self, room: CanonicalRoomModel) -> tuple[float, float, str]:
        """
        Resolves uncertainty margin, confidence score, and accuracy tier based on capture source.
        """
        if room.native_spatial_report or any(m.source == MeasurementSource.LIDAR_NATIVE for m in room.measurements):
            return 3.0, 0.98, "EXACT"
        elif any(m.source == MeasurementSource.HARDWARE_DEPTH for m in room.measurements):
            return 5.0, 0.94, "EXACT"
        elif room.ar_assisted_report or any(m.source == MeasurementSource.AR_ASSISTED_VIO for m in room.measurements):
            return 8.0, 0.90, "EXACT"
        elif room.video_scan_report or (room.geometry and room.geometry.reconstruction_method == "video_keyframe_sfm"):
            return 12.0, 0.84, "APPROXIMATE"
        else:
            return 18.0, 0.75, "APPROXIMATE"

    def _build_critical_dimensions(
        self,
        room: CanonicalRoomModel,
        floor_area: float,
        wall_height: float,
        wall_perimeter: float,
        uncertainty_pct: float,
        confidence: float,
    ) -> List[CriticalDimensionVerification]:
        """
        Extracts key architectural spans that mandate on-site physical confirmation.
        """
        dims: List[CriticalDimensionVerification] = []

        # 1. Floor Area
        dims.append(
            CriticalDimensionVerification(
                dimension_id="dim_floor_area",
                dimension_type=CriticalDimensionType.FLOOR_AREA,
                label="Room Floor Footprint Area",
                estimated_value=round(floor_area, 2),
                unit="sqm",
                confidence=confidence,
                uncertainty_margin_pct=uncertainty_pct,
                verification_status=DimensionVerificationStatus.UNVERIFIED,
                recommended_tool="Laser distance meter corner-to-corner cross check",
                warning_note="Critical for exact flooring carton and subfloor underlayment calculation",
            )
        )

        # 2. Longest Wall Span
        longest_wall_m = room.geometry.wall_length_m if (room.geometry and room.geometry.wall_length_m > 0) else round(wall_perimeter / 4.0, 2)
        dims.append(
            CriticalDimensionVerification(
                dimension_id="dim_longest_wall",
                dimension_type=CriticalDimensionType.LONGEST_WALL,
                label="Primary Long Wall Length",
                estimated_value=round(longest_wall_m, 2),
                unit="m",
                confidence=confidence,
                uncertainty_margin_pct=uncertainty_pct,
                verification_status=DimensionVerificationStatus.UNVERIFIED,
                recommended_tool="Continuous steel measuring tape (5m minimum)",
                warning_note="Verify wall span before purchasing custom cabinetry or wide modular furniture",
            )
        )

        # 3. Ceiling Height
        dims.append(
            CriticalDimensionVerification(
                dimension_id="dim_ceiling_height",
                dimension_type=CriticalDimensionType.CEILING_HEIGHT,
                label="Vertical Ceiling Clearance",
                estimated_value=round(wall_height, 2),
                unit="m",
                confidence=confidence,
                uncertainty_margin_pct=uncertainty_pct,
                verification_status=DimensionVerificationStatus.UNVERIFIED,
                recommended_tool="Vertical laser plumb line or rigid measuring rod",
                warning_note="Critical for floor-to-ceiling wardrobe fittings and curtain drop length",
            )
        )

        # 4. Entryway Passage Width
        door_width_m = 0.9
        if room.openings:
            for opn in room.openings:
                if opn.opening_type.value.lower() == "door" and opn.width_m:
                    door_width_m = opn.width_m
                    break
        dims.append(
            CriticalDimensionVerification(
                dimension_id="dim_doorway_clearance",
                dimension_type=CriticalDimensionType.DOORWAY_CLEARANCE,
                label="Main Entryway Clearance",
                estimated_value=round(door_width_m, 2),
                unit="m",
                confidence=confidence,
                uncertainty_margin_pct=uncertainty_pct,
                verification_status=DimensionVerificationStatus.UNVERIFIED,
                recommended_tool="Internal jamb-to-jamb tape measurement",
                warning_note="Confirm clear door swing and appliance/furniture delivery passage",
            )
        )

        return dims


material_estimator = MaterialEstimatorEngine()
