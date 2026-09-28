"""
Tests for Milestone 4.1 — Material and Quantity Estimation.
Covers:
- Surface-area-derived approximate quantities (flooring, paint, wallpaper, baseboards, tiles).
- Configurable waste-factor allowances and irregular room adjustments.
- Confidence-aware estimation ranges with upper/lower bounds.
- Contractor verification workflows for critical dimensions.
- REST Endpoints (/rooms/{id}/material-takeoff, /rooms/{id}/material-takeoff/verify-dimension).
- Persistence on CanonicalRoomModel.
"""

import pytest
from fastapi.testclient import TestClient
from packages.room_model.schema import (
    CanonicalRoomModel,
    CriticalDimensionType,
    DimensionVerificationStatus,
    Geometry,
    MaterialCategory,
    Measurement,
    MeasurementSource,
    NativeSpatialScanReport,
    OpeningType,
    RoomOpening,
    RoomShapeType,
    RoomSurface,
    SurfaceType,
)
from services.ai_worker.pipelines.material_estimator import MaterialEstimatorEngine, material_estimator
from services.api.app.db.repository import repository
from services.api.app.main import app


@pytest.fixture
def sample_room_model():
    """Generates a sample 5.0m x 4.0m x 2.8m canonical room model."""
    room = CanonicalRoomModel(
        id="room_takeoff_test_01",
        project_id="proj_takeoff_01",
        name="Renovation Living Room",
        room_type="living_room",
        geometry=Geometry(
            shape_type=RoomShapeType.RECTANGULAR,
            confidence=0.92,
            wall_length_m=5.0,
            wall_width_m=4.0,
            wall_height_m=2.8,
            floor_area_sqm=20.0,
            wall_perimeter_m=18.0,
        ),
        openings=[
            RoomOpening(
                id="door_main",
                name="Main Entry Door",
                opening_type=OpeningType.DOOR,
                width_m=0.9,
                height_m=2.1,
                wall_id="wall_1",
            ),
            RoomOpening(
                id="window_main",
                name="Living Room Window",
                opening_type=OpeningType.WINDOW,
                width_m=1.5,
                height_m=1.2,
                wall_id="wall_2",
            ),
        ],
    )
    return room


def test_compute_material_takeoff_basic(sample_room_model):
    """Verifies area calculations, opening deductions, and basic item generation."""
    report = material_estimator.compute_material_takeoff(sample_room_model)

    assert report.room_id == "room_takeoff_test_01"
    assert report.gross_floor_area_sqm == 20.0
    assert report.ceiling_area_sqm == 20.0

    # Door (0.9 * 2.1 = 1.89) + Window (1.5 * 1.2 = 1.80) = 3.69 sqm deducted
    assert report.openings_deducted_area_sqm == pytest.approx(3.69, rel=0.01)

    # Gross wall area = 18.0 * 2.8 = 50.4 sqm; Net wall area = 50.4 - 3.69 = 46.71 sqm
    assert report.net_wall_area_sqm == pytest.approx(46.71, rel=0.01)

    # Baseboard perimeter = 18.0 - 0.9 = 17.1 m
    assert report.baseboard_perimeter_m == pytest.approx(17.1, rel=0.01)

    # Check items generated
    categories = [itm.category for itm in report.items]
    assert MaterialCategory.FLOORING in categories
    assert MaterialCategory.WALL_PAINT in categories
    assert MaterialCategory.CEILING_PAINT in categories
    assert MaterialCategory.SKIRTING_BASEBOARD in categories
    assert MaterialCategory.WALLPAPER in categories

    # Verify flooring quantities
    flooring = next(itm for itm in report.items if itm.category == MaterialCategory.FLOORING)
    assert flooring.net_quantity == 20.0
    assert flooring.waste_factor_pct == 10.0
    assert flooring.gross_quantity == 22.0
    assert flooring.packaging_spec is not None
    assert flooring.estimated_packages == 16  # ceil(22.0 / 1.44) = 16


def test_custom_waste_factor_and_irregular_shape(sample_room_model):
    """Tests overriding waste factors and automatic increase for irregular rooms."""
    sample_room_model.geometry.shape_type = RoomShapeType.L_SHAPED

    custom_waste = {"FLOORING": 20.0, "WALL_PAINT": 15.0}
    report = material_estimator.compute_material_takeoff(
        sample_room_model, custom_waste_factors=custom_waste
    )

    flooring = next(itm for itm in report.items if itm.category == MaterialCategory.FLOORING)
    assert flooring.waste_factor_pct == 20.0
    assert flooring.gross_quantity == 24.0  # 20 + 20% = 24.0

    paint = next(itm for itm in report.items if itm.category == MaterialCategory.WALL_PAINT)
    assert paint.waste_factor_pct == 15.0

    # Skirting should have automatically bumped to 15.0% due to L_SHAPED
    skirting = next(itm for itm in report.items if itm.category == MaterialCategory.SKIRTING_BASEBOARD)
    assert skirting.waste_factor_pct == 15.0


def test_confidence_and_provenance_bounds(sample_room_model):
    """Tests that LiDAR scans produce tighter error tolerances than basic RGB scans."""
    # Basic RGB room (no native spatial report)
    report_rgb = material_estimator.compute_material_takeoff(sample_room_model)
    flooring_rgb = next(itm for itm in report_rgb.items if itm.category == MaterialCategory.FLOORING)
    assert flooring_rgb.uncertainty_pct >= 12.0
    assert report_rgb.accuracy_tier == "APPROXIMATE"

    # LiDAR room
    sample_room_model.native_spatial_report = NativeSpatialScanReport(
        scan_id="native_lidar_1",
        room_id=sample_room_model.id,
        platform="apple_roomplan",
        hardware_type="LIDAR_PRO",
        confidence_score=0.99,
        measurement_provenance="LIDAR_NATIVE",
    )
    report_lidar = material_estimator.compute_material_takeoff(sample_room_model)
    flooring_lidar = next(itm for itm in report_lidar.items if itm.category == MaterialCategory.FLOORING)
    assert flooring_lidar.uncertainty_pct <= 5.0
    assert report_lidar.accuracy_tier == "EXACT"
    assert report_lidar.overall_confidence >= 0.95


def test_critical_dimension_verification_flow(sample_room_model):
    """Tests contractor verification of floor area and quantity recalculation."""
    report = material_estimator.compute_material_takeoff(sample_room_model)
    floor_dim = next(d for d in report.critical_dimensions if d.dimension_type == CriticalDimensionType.FLOOR_AREA)
    assert floor_dim.verification_status == DimensionVerificationStatus.UNVERIFIED
    assert floor_dim.estimated_value == 20.0

    # Contractor measures 21.5 sqm on-site
    updated_report = material_estimator.verify_critical_dimension(
        report=report,
        dimension_id=floor_dim.dimension_id,
        verified_value=21.5,
        verified_by="Lead Builder Dave",
        status=DimensionVerificationStatus.CONTRACTOR_VERIFIED,
    )

    updated_floor_dim = next(d for d in updated_report.critical_dimensions if d.dimension_id == floor_dim.dimension_id)
    assert updated_floor_dim.verification_status == DimensionVerificationStatus.CONTRACTOR_VERIFIED
    assert updated_floor_dim.verified_value == 21.5
    assert updated_floor_dim.verified_by == "Lead Builder Dave"

    # Flooring item net and gross quantities must have updated
    flooring = next(itm for itm in updated_report.items if itm.category == MaterialCategory.FLOORING)
    assert flooring.net_quantity == 21.5
    assert flooring.gross_quantity == round(21.5 * 1.10, 2)  # 23.65
    assert flooring.requires_contractor_verification is False


def test_api_material_takeoff_endpoints(sample_room_model):
    """Tests POST and GET endpoints for Material Takeoff."""
    client = TestClient(app)
    repository.save_room(sample_room_model)

    # 1. POST /api/v1/rooms/{id}/material-takeoff
    payload = {"custom_waste_factors": {"FLOORING": 12.0}}
    res = client.post(f"/api/v1/rooms/{sample_room_model.id}/material-takeoff", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert data["room_id"] == sample_room_model.id
    assert len(data["items"]) >= 5
    assert len(data["critical_dimensions"]) >= 4

    # 2. GET /api/v1/rooms/{id}/material-takeoff
    res_get = client.get(f"/api/v1/rooms/{sample_room_model.id}/material-takeoff")
    assert res_get.status_code == 200
    assert res_get.json()["report_id"] == data["report_id"]

    # 3. POST /api/v1/rooms/{id}/material-takeoff/verify-dimension
    verify_payload = {
        "dimension_id": "dim_floor_area",
        "verified_value": 22.0,
        "verified_by": "Architect Bob",
        "status": "CONTRACTOR_VERIFIED",
    }
    res_verify = client.post(
        f"/api/v1/rooms/{sample_room_model.id}/material-takeoff/verify-dimension",
        json=verify_payload,
    )
    assert res_verify.status_code == 200
    data_verified = res_verify.json()
    floor_dim = next(d for d in data_verified["critical_dimensions"] if d["dimension_id"] == "dim_floor_area")
    assert floor_dim["verified_value"] == 22.0
    assert floor_dim["verification_status"] == "CONTRACTOR_VERIFIED"
