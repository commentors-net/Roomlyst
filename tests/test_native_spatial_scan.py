"""
Tests for Milestone 3.4 — LiDAR / Native Spatial Path.
Covers:
- NativeSpatialNormalizer (RoomPlan & Hardware-Depth normalization).
- Metric measurements with strict provenance (LIDAR_NATIVE or HARDWARE_DEPTH, is_approximate=False, accuracy_tier='EXACT', confidence >= 0.95).
- Closed-loop wall polygon synthesis, openings association, furniture footprints.
- REST Endpoints (/api/v1/scan/native-spatial/normalize, /api/v1/rooms/{room_id}/native-spatial-report).
- Full compatibility with existing Canonical Room Model downstream flows.
"""

import pytest
from fastapi.testclient import TestClient
from packages.room_model.schema import (
    CanonicalRoomModel,
    MeasurementSource,
    NativeSurfaceScan,
    NativeOpeningScan,
    NativeObjectScan,
    NativeSpatialScanPayload,
    SurfaceType,
    OpeningType,
)
from services.ai_worker.pipelines.native_spatial_normalizer import NativeSpatialNormalizer
from services.api.app.main import app
from services.api.app.db.repository import repository


@pytest.fixture
def sample_apple_roomplan_payload():
    """Generates a realistic Apple RoomPlan scan payload for a 5.0m x 4.0m room."""
    surfaces = [
        NativeSurfaceScan(
            surface_id="wall_1",
            category="wall",
            dimensions_m=[5.0, 2.8, 0.15],
            transform_matrix=[
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                2.5, 0.0, 1.4, 1.0,
            ],
            translation=[2.5, 0.0, 1.4],
            normal_vector=[0.0, -1.0, 0.0],
            confidence=0.99,
        ),
        NativeSurfaceScan(
            surface_id="wall_2",
            category="wall",
            dimensions_m=[4.0, 2.8, 0.15],
            transform_matrix=[
                0.0, 1.0, 0.0, 0.0,
                -1.0, 0.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                5.0, 2.0, 1.4, 1.0,
            ],
            translation=[5.0, 2.0, 1.4],
            normal_vector=[1.0, 0.0, 0.0],
            confidence=0.98,
        ),
        NativeSurfaceScan(
            surface_id="wall_3",
            category="wall",
            dimensions_m=[5.0, 2.8, 0.15],
            transform_matrix=[
                -1.0, 0.0, 0.0, 0.0,
                0.0, -1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                2.5, 4.0, 1.4, 1.0,
            ],
            translation=[2.5, 4.0, 1.4],
            normal_vector=[0.0, 1.0, 0.0],
            confidence=0.99,
        ),
        NativeSurfaceScan(
            surface_id="wall_4",
            category="wall",
            dimensions_m=[4.0, 2.8, 0.15],
            transform_matrix=[
                0.0, -1.0, 0.0, 0.0,
                1.0, 0.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 2.0, 1.4, 1.0,
            ],
            translation=[0.0, 2.0, 1.4],
            normal_vector=[-1.0, 0.0, 0.0],
            confidence=0.97,
        ),
        NativeSurfaceScan(
            surface_id="floor_1",
            category="floor",
            dimensions_m=[5.0, 4.0, 0.02],
            translation=[2.5, 2.0, 0.0],
            normal_vector=[0.0, 0.0, 1.0],
            confidence=0.99,
        ),
        NativeSurfaceScan(
            surface_id="ceiling_1",
            category="ceiling",
            dimensions_m=[5.0, 4.0, 0.02],
            translation=[2.5, 2.0, 2.8],
            normal_vector=[0.0, 0.0, -1.0],
            confidence=0.98,
        ),
    ]

    openings = [
        NativeOpeningScan(
            opening_id="door_1",
            category="door",
            dimensions_m=[0.9, 2.1],
            translation=[1.2, 0.0, 1.05],
            parent_wall_id="wall_1",
            confidence=0.98,
        ),
        NativeOpeningScan(
            opening_id="window_1",
            category="window",
            dimensions_m=[1.6, 1.3],
            translation=[2.8, 4.0, 1.4],
            parent_wall_id="wall_3",
            confidence=0.96,
        ),
    ]

    objects = [
        NativeObjectScan(
            object_id="table_1",
            category="table",
            label="Modern Dining Table",
            dimensions_m=[1.8, 0.9, 0.76],
            translation=[2.5, 2.0, 0.38],
            rotation_deg=0.0,
            confidence=0.97,
        ),
        NativeObjectScan(
            object_id="sofa_1",
            category="sofa",
            label="Fabric 3-Seater Sofa",
            dimensions_m=[2.2, 0.95, 0.85],
            translation=[1.0, 2.5, 0.425],
            rotation_deg=90.0,
            confidence=0.95,
        ),
    ]

    return NativeSpatialScanPayload(
        room_id="test_lidar_room_001",
        device_tier="TIER_1_LIDAR",
        platform="apple_roomplan",
        surfaces=surfaces,
        openings=openings,
        objects=objects,
        mesh_vertices_count=185000,
    )


def test_apple_roomplan_normalization(sample_apple_roomplan_payload):
    """Test full Apple RoomPlan payload normalization into CanonicalRoomModel."""
    normalizer = NativeSpatialNormalizer()
    room, report = normalizer.normalize_native_scan(sample_apple_roomplan_payload)

    assert room.id == "test_lidar_room_001"
    assert room.native_spatial_report is not None
    assert report.platform == "apple_roomplan"
    assert report.hardware_type == "APPLE_LIDAR_ROOMPLAN"
    assert report.measurement_provenance == "LIDAR_NATIVE"
    assert report.surfaces_detected == 6
    assert report.openings_detected == 2
    assert report.objects_detected == 2
    assert report.confidence_score >= 0.95

    # Check surfaces
    assert len(room.surfaces) == 6
    assert len(room.spatial_planes) == 6
    wall_surfaces = [s for s in room.surfaces if s.surface_type == SurfaceType.WALL]
    assert len(wall_surfaces) == 4

    # Check openings
    assert len(room.openings) == 2
    door = next(o for o in room.openings if o.opening_type == OpeningType.DOOR)
    window = next(o for o in room.openings if o.opening_type == OpeningType.WINDOW)
    assert door is not None
    assert window is not None

    # Check objects and footprints
    assert len(room.objects) == 2
    table = next(obj for obj in room.objects if obj.category == "table")
    assert table.name == "Modern Dining Table"
    assert table.footprint_2d is not None
    assert table.footprint_2d.width_m == 1.8
    assert table.footprint_2d.length_m == 0.9

    # Check geometry & closed polygon
    assert room.geometry is not None
    assert room.geometry.is_closed is True
    assert len(room.geometry.wall_segments) == 4
    assert len(room.geometry.polygon_vertices) == 4
    assert pytest.approx(room.geometry.perimeter_m, rel=1e-2) == 18.0  # 2*(5+4) = 18m
    assert pytest.approx(room.geometry.floor_area_sqm, rel=1e-2) == 20.0  # 5*4 = 20m²

    # Check metric measurements provenance
    assert len(room.measurements) >= 3
    for meas in room.measurements:
        assert meas.source == MeasurementSource.LIDAR_NATIVE
        assert meas.is_approximate is False
        assert meas.accuracy_tier == "EXACT"
        assert meas.confidence >= 0.95


def test_android_hardware_depth_normalization():
    """Test Android ARCore Depth / ToF normalization with HARDWARE_DEPTH provenance."""
    surfaces = [
        NativeSurfaceScan(
            surface_id="w1",
            category="wall",
            dimensions_m=[4.2, 2.6, 0.15],
            translation=[2.1, 0.0, 1.3],
            normal_vector=[0.0, -1.0, 0.0],
            confidence=0.96,
        ),
        NativeSurfaceScan(
            surface_id="w2",
            category="wall",
            dimensions_m=[3.5, 2.6, 0.15],
            translation=[4.2, 1.75, 1.3],
            normal_vector=[1.0, 0.0, 0.0],
            confidence=0.95,
        ),
        NativeSurfaceScan(
            surface_id="w3",
            category="wall",
            dimensions_m=[4.2, 2.6, 0.15],
            translation=[2.1, 3.5, 1.3],
            normal_vector=[0.0, 1.0, 0.0],
            confidence=0.96,
        ),
        NativeSurfaceScan(
            surface_id="w4",
            category="wall",
            dimensions_m=[3.5, 2.6, 0.15],
            translation=[0.0, 1.75, 1.3],
            normal_vector=[-1.0, 0.0, 0.0],
            confidence=0.95,
        ),
    ]

    payload = NativeSpatialScanPayload(
        room_id="android_tof_room_002",
        device_tier="TIER_2_AR_DEPTH",
        platform="android_hardware_depth",
        surfaces=surfaces,
        openings=[],
        objects=[],
        mesh_vertices_count=98000,
    )

    normalizer = NativeSpatialNormalizer()
    room, report = normalizer.normalize_native_scan(payload)

    assert report.measurement_provenance == "HARDWARE_DEPTH"
    assert report.hardware_type == "ANDROID_TOF_DEPTH"
    for meas in room.measurements:
        assert meas.source == MeasurementSource.HARDWARE_DEPTH
        assert meas.is_approximate is False
        assert meas.accuracy_tier == "EXACT"
        assert meas.confidence >= 0.95


def test_native_spatial_endpoints(sample_apple_roomplan_payload):
    """Test REST API endpoints for native spatial scan normalization and report retrieval."""
    client = TestClient(app)

    # 1. Normalize native spatial scan
    res = client.post(
        "/api/v1/scan/native-spatial/normalize",
        json=sample_apple_roomplan_payload.model_dump(),
    )
    assert res.status_code == 200
    data = res.json()
    assert "report" in data
    assert "room_model" in data
    assert data["report"]["platform"] == "apple_roomplan"
    assert data["report"]["measurement_provenance"] == "LIDAR_NATIVE"

    room_id = sample_apple_roomplan_payload.room_id

    # 2. Retrieve native spatial report
    res_report = client.get(f"/api/v1/rooms/{room_id}/native-spatial-report")
    assert res_report.status_code == 200
    report_data = res_report.json()
    assert report_data["room_id"] == room_id
    assert report_data["measurement_provenance"] == "LIDAR_NATIVE"
    assert report_data["surfaces_detected"] == 6
    assert report_data["openings_detected"] == 2
    assert report_data["objects_detected"] == 2

    # Verify room model has been persisted in repository
    saved_room = repository.get_room(room_id)
    assert saved_room is not None
    assert saved_room.native_spatial_report is not None
    assert saved_room.geometry is not None
    assert saved_room.geometry.is_closed is True


def test_native_spatial_report_not_found():
    """Test 404 behavior when native spatial report has not been computed for a room."""
    client = TestClient(app)
    # Create empty room
    empty_room = CanonicalRoomModel(id="empty_test_room_003", name="Empty Room")
    repository.save_room(empty_room)

    res = client.get("/api/v1/rooms/empty_test_room_003/native-spatial-report")
    assert res.status_code == 404
    assert "No native spatial scan report available" in res.json()["detail"]
