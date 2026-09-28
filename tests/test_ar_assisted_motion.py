"""
Tests for Milestone 3.3 — AR-assisted non-LiDAR path.
Covers:
- ARMotionFusionEngine (VIO validation, trajectory distance, metric scale factor, depth-from-motion integration, confidence fusion).
- CanonicalRoomModel schema integration (ARAssistedScanReport, MeasurementSource.AR_MOTION_VERIFIED, AR_DEPTH_FROM_MOTION).
- REST Endpoints (/scan/ar-motion/ingest, /scan/ar-motion/fuse, /rooms/{room_id}/ar-report).
"""

import pytest
from fastapi.testclient import TestClient
from packages.room_model.schema import (
    CanonicalRoomModel,
    Measurement,
    MeasurementSource,
    ARCameraPose,
    IMUMotionSample,
    DepthFromMotionPayload,
    ARAssistedScanReport,
    SpatialPlane,
)
from services.ai_worker.pipelines.ar_fusion_engine import ARMotionFusionEngine
from services.api.app.main import app
from services.api.app.db.repository import repository


@pytest.fixture
def sample_ar_poses():
    """Generates a synthetic 24-step AR camera trajectory moving along an L-shaped path."""
    poses = []
    for i in range(24):
        t = i * 0.1
        # Moving along X then Z
        x = 0.1 * i if i < 12 else 1.2
        y = 1.4 + 0.02 * (i % 2)
        z = 0.0 if i < 12 else 0.1 * (i - 12)
        poses.append(
            ARCameraPose(
                frame_index=i,
                timestamp_ms=t * 1000.0,
                translation=[x, y, z],
                rotation_quaternion=[1.0, 0.0, 0.0, 0.0],
                tracking_state="TRACKING",
                feature_points_count=180 + i,
                confidence=0.96,
            )
        )
    return poses


@pytest.fixture
def sample_imu_samples():
    """Generates synthetic IMU telemetry."""
    samples = []
    for i in range(24):
        samples.append(
            IMUMotionSample(
                timestamp_ms=i * 100.0,
                acceleration=[0.02, 9.81 + 0.05 * (i % 2), 0.01],
                rotation_rate=[0.01, 0.01, 0.02],
                gravity_vector=[0.0, 0.0, -9.81],
                heading_deg=10.0 + i,
                tilt_deg=1.5,
            )
        )
    return samples


@pytest.fixture
def sample_depth_payload():
    return DepthFromMotionPayload(
        depth_map_url="https://cdn.roomlyst.internal/depth/test.png",
        sparse_points_count=220,
        min_depth_m=0.6,
        max_depth_m=5.0,
        mean_depth_confidence=0.92,
        sparse_point_samples=[
            [0.5, 0.2, 2.7, 0.95] for _ in range(15)
        ] + [
            [0.2, 0.3, 0.05, 0.92] for _ in range(15)
        ],
    )


@pytest.fixture
def base_room():
    room = CanonicalRoomModel(
        id="room_ar_test_1",
        name="Living Room AR",
        room_type="living_room",
        overall_confidence=0.75,
        measurements=[
            Measurement(
                entity_type="room",
                measurement_type="width",
                value=4.0,
                unit="m",
                confidence=0.72,
                source=MeasurementSource.MONOCULAR_DEPTH,
            ),
            Measurement(
                entity_type="room",
                measurement_type="length",
                value=5.0,
                unit="m",
                confidence=0.72,
                source=MeasurementSource.MONOCULAR_DEPTH,
            ),
            Measurement(
                entity_type="room",
                measurement_type="ceiling_height",
                value=2.8,
                unit="m",
                confidence=0.70,
                source=MeasurementSource.MONOCULAR_DEPTH,
            ),
        ],
        spatial_planes=[
            SpatialPlane(
                plane_id="plane_fl_1",
                plane_type="floor",
                coefficients=[0.0, 1.0, 0.0, 0.0],
                normal_vector=[0.0, 1.0, 0.0],
                inliers_count=800,
                elevation_m=0.0,
                confidence=0.85,
            ),
            SpatialPlane(
                plane_id="plane_cl_1",
                plane_type="ceiling",
                coefficients=[0.0, -1.0, 0.0, 2.8],
                normal_vector=[0.0, -1.0, 0.0],
                inliers_count=750,
                elevation_m=2.8,
                confidence=0.85,
            ),
        ],
    )
    return room


# ==============================================================================
# 1. ARMotionFusionEngine Unit Tests
# ==============================================================================

def test_validate_ar_tracking_valid(sample_ar_poses, sample_imu_samples):
    engine = ARMotionFusionEngine()
    is_valid, quality, score = engine.validate_ar_tracking(sample_ar_poses, sample_imu_samples)
    assert is_valid is True
    assert quality in ["EXCELLENT", "GOOD"]
    assert score >= 0.85


def test_validate_ar_tracking_too_few_poses():
    engine = ARMotionFusionEngine()
    few_poses = [
        ARCameraPose(
            frame_index=0,
            timestamp_ms=0.0,
            translation=[0.0, 0.0, 0.0],
            rotation_quaternion=[1.0, 0.0, 0.0, 0.0],
            tracking_state="TRACKING",
            feature_points_count=50,
            confidence=0.5,
        )
    ]
    is_valid, quality, score = engine.validate_ar_tracking(few_poses)
    assert is_valid is False
    assert quality == "INSUFFICIENT_DATA"
    assert score == 0.0


def test_validate_ar_tracking_high_jerkiness(sample_ar_poses):
    engine = ARMotionFusionEngine()
    # High jerkiness IMU samples (> 15 m/s^2 jitter)
    erratic_imu = [
        IMUMotionSample(
            timestamp_ms=i * 50.0,
            acceleration=[30.0 if i % 2 == 0 else 0.1, 9.81, 12.0],
            rotation_rate=[5.0, 4.0, 3.0],
            gravity_vector=[0.0, 0.0, -9.81],
        )
        for i in range(20)
    ]
    is_valid, quality, score = engine.validate_ar_tracking(sample_ar_poses, erratic_imu)
    assert score < 0.95  # Penalty applied


def test_calculate_trajectory_length(sample_ar_poses):
    engine = ARMotionFusionEngine()
    length = engine.calculate_trajectory_length(sample_ar_poses)
    assert length > 2.0  # L-shaped 1.2m + 1.1m path > 2.0m


def test_estimate_metric_scale(sample_ar_poses, base_room):
    engine = ARMotionFusionEngine()
    scale = engine.estimate_metric_scale(sample_ar_poses, base_room)
    assert 0.2 <= scale <= 5.0
    assert isinstance(scale, float)


def test_integrate_depth_from_motion(sample_depth_payload, base_room):
    engine = ARMotionFusionEngine()
    refined_planes = engine.integrate_depth_from_motion(sample_depth_payload, base_room.spatial_planes)
    assert len(refined_planes) == 2
    # Verify ceiling confidence was upgraded with depth integration
    ceiling = next(p for p in refined_planes if p.plane_type == "ceiling")
    assert ceiling.confidence > 0.85


def test_fuse_ar_reconstruction_with_depth(sample_ar_poses, sample_imu_samples, sample_depth_payload, base_room):
    engine = ARMotionFusionEngine()
    report, fused_room = engine.fuse_ar_reconstruction(
        room_model=base_room,
        poses=sample_ar_poses,
        imu_samples=sample_imu_samples,
        depth_payload=sample_depth_payload,
        device_tier="TIER_3_AR_RGB",
    )

    assert isinstance(report, ARAssistedScanReport)
    assert report.tracking_quality in ["EXCELLENT", "GOOD"]
    assert report.has_depth_from_motion is True
    assert report.fused_consistency_score >= 0.94
    assert fused_room.ar_assisted_report is not None

    # Verify measurement provenance upgraded
    for m in fused_room.measurements:
        assert m.source == MeasurementSource.AR_DEPTH_FROM_MOTION
        assert m.accuracy_tier in ["EXACT", "APPROXIMATE"]
        assert m.is_approximate is False
        assert m.confidence >= 0.94


def test_fuse_ar_reconstruction_without_depth(sample_ar_poses, sample_imu_samples, base_room):
    engine = ARMotionFusionEngine()
    report, fused_room = engine.fuse_ar_reconstruction(
        room_model=base_room,
        poses=sample_ar_poses,
        imu_samples=sample_imu_samples,
        depth_payload=None,
        device_tier="TIER_3_AR_RGB",
    )

    assert report.has_depth_from_motion is False
    assert report.fused_consistency_score >= 0.92
    for m in fused_room.measurements:
        assert m.source == MeasurementSource.AR_MOTION_VERIFIED
        assert m.accuracy_tier in ["EXACT", "APPROXIMATE"]
        assert m.is_approximate is False
        assert m.confidence >= 0.94


# ==============================================================================
# 2. REST API Integration Tests
# ==============================================================================

@pytest.fixture
def client():
    return TestClient(app)


def test_api_ingest_ar_motion(client, sample_ar_poses, sample_imu_samples, sample_depth_payload):
    payload = {
        "room_id": "test_room_ingest_01",
        "poses": [p.model_dump() for p in sample_ar_poses],
        "imu_samples": [s.model_dump() for s in sample_imu_samples],
        "depth_payload": sample_depth_payload.model_dump(),
        "device_tier": "TIER_3_AR_RGB",
    }
    resp = client.post("/api/v1/scan/ar-motion/ingest", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "INGESTED"
    assert data["poses_count"] == 24
    assert data["imu_samples_count"] == 24
    assert data["has_depth_from_motion"] is True


def test_api_fuse_ar_motion_end_to_end(client, base_room, sample_ar_poses, sample_imu_samples, sample_depth_payload):
    repository.rooms[base_room.id] = base_room

    payload = {
        "room_id": base_room.id,
        "poses": [p.model_dump() for p in sample_ar_poses],
        "imu_samples": [s.model_dump() for s in sample_imu_samples],
        "depth_payload": sample_depth_payload.model_dump(),
        "device_tier": "TIER_3_AR_RGB",
    }

    resp = client.post("/api/v1/scan/ar-motion/fuse", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "COMPLETED"
    assert "report" in data
    assert data["report"]["tracking_quality"] in ["EXCELLENT", "GOOD"]
    assert data["report"]["fused_consistency_score"] >= 0.94

    # Test GET report endpoint
    report_resp = client.get(f"/api/v1/rooms/{base_room.id}/ar-report")
    assert report_resp.status_code == 200
    report_data = report_resp.json()
    assert report_data["room_id"] == base_room.id
    assert report_data["has_depth_from_motion"] is True


def test_api_get_ar_report_not_found(client):
    resp = client.get("/api/v1/rooms/non_existent_room_9999/ar-report")
    assert resp.status_code == 404
