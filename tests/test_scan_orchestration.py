"""
Tests for Milestone 3.5 — Capability-Based Scan Orchestration.
Covers:
- Automatic selection of optimal capture mode across 5 tiers (LiDAR, AR Depth, AR RGB, Video Sweep, Multi-Corner Photo).
- Graceful degradation and fallback chains with informative user guidance.
- Comparative telemetry benchmark metrics (Accuracy cm, Confidence, Latency, Cost USD, Stability).
- REST Endpoints (/api/v1/scan/orchestration/telemetry-benchmarks, /api/v1/scan/orchestration/evaluate-route, /api/v1/rooms/{room_id}/scan-orchestration).
- Single Canonical Room Model serialization and persistence of orchestration evaluation.
"""

import pytest
from fastapi.testclient import TestClient
from packages.room_model.schema import (
    CanonicalRoomModel,
    Geometry,
    RoomShapeType,
    ScanOrchestrationEvaluation,
    TierBenchmarkMetrics,
    evaluate_scan_orchestration,
    get_standard_tier_benchmarks,
)
from services.api.app.main import app
from services.api.app.db.repository import repository


def test_standard_tier_benchmarks_structure():
    """Validates that all 5 capability tiers are properly defined with comparative metrics."""
    benchmarks = get_standard_tier_benchmarks()
    assert len(benchmarks) == 5

    tier_ids = [b.tier_id for b in benchmarks]
    assert tier_ids == [
        "TIER_1_LIDAR",
        "TIER_2_AR_DEPTH",
        "TIER_3_AR_RGB",
        "TIER_4_VIDEO_SWEEP",
        "TIER_5_BASIC_RGB",
    ]

    for b in benchmarks:
        assert b.tier_id.startswith("TIER_")
        assert len(b.tier_name) > 0
        assert b.typical_accuracy_cm > 0.0
        assert 0.0 < b.expected_confidence <= 1.0
        assert b.mean_capture_time_sec > 0.0
        assert b.mean_processing_time_sec > 0.0
        assert b.relative_compute_cost_usd >= 0.0
        assert len(b.supported_devices_sample) > 0


def test_orchestration_evaluation_tier_1_lidar():
    """Tests Tier 1 resolution for devices with LiDAR hardware sensor."""
    profile = {
        "has_lidar": True,
        "has_ar": True,
        "has_motion_sensors": True,
        "device_model": "iPhone 15 Pro",
    }
    result = evaluate_scan_orchestration(profile)
    assert result.evaluated_tier == "TIER_1_LIDAR"
    assert result.recommended_scan_mode == "lidar_scan"
    assert "LiDAR" in result.accuracy_assurance or "Hardware 3D" in result.accuracy_assurance
    assert "ar_rgb_scan" in result.fallback_chain
    assert "rgb_video_scan" in result.fallback_chain
    assert "rgb_photo_scan" in result.fallback_chain
    assert len(result.fallback_reasons) == 3
    assert result.active_benchmark.tier_id == "TIER_1_LIDAR"
    assert result.active_benchmark.typical_accuracy_cm < 1.0


def test_orchestration_evaluation_tier_2_ar_depth():
    """Tests Tier 2 resolution for Android devices with hardware ToF / ARCore Depth."""
    profile = {
        "has_lidar": False,
        "has_hardware_depth": True,
        "has_arcore_depth": True,
        "has_ar": True,
        "has_motion_sensors": True,
        "device_model": "Galaxy S24 Ultra",
    }
    result = evaluate_scan_orchestration(profile)
    assert result.evaluated_tier == "TIER_2_AR_DEPTH"
    assert result.recommended_scan_mode == "ar_depth_scan"
    assert result.active_benchmark.typical_accuracy_cm <= 2.5
    assert "ar_rgb_scan" in result.fallback_chain
    assert "rgb_video_scan" in result.fallback_chain


def test_orchestration_evaluation_tier_3_ar_rgb():
    """Tests Tier 3 resolution for standard ARKit / ARCore devices without depth sensors."""
    profile = {
        "has_lidar": False,
        "has_hardware_depth": False,
        "has_ar": True,
        "has_motion_sensors": True,
        "device_model": "iPhone 14",
    }
    result = evaluate_scan_orchestration(profile)
    assert result.evaluated_tier == "TIER_3_AR_RGB"
    assert result.recommended_scan_mode == "ar_rgb_scan"
    assert "rgb_video_scan" in result.fallback_chain
    assert "rgb_photo_scan" in result.fallback_chain
    assert result.active_benchmark.typical_accuracy_cm <= 5.0


def test_orchestration_evaluation_tier_4_video_sweep():
    """Tests Tier 4 resolution for devices with motion sensors but without full AR support."""
    profile = {
        "has_lidar": False,
        "has_hardware_depth": False,
        "has_ar": False,
        "has_motion_sensors": True,
        "device_model": "Mid-tier Android Smartphone",
    }
    result = evaluate_scan_orchestration(profile)
    assert result.evaluated_tier == "TIER_4_VIDEO_SWEEP"
    assert result.recommended_scan_mode == "rgb_video_scan"
    assert "rgb_photo_scan" in result.fallback_chain
    assert result.active_benchmark.typical_accuracy_cm <= 8.0


def test_orchestration_evaluation_tier_5_basic_rgb():
    """Tests Tier 5 resolution for basic/legacy smartphones without sensors."""
    profile = {
        "has_lidar": False,
        "has_hardware_depth": False,
        "has_ar": False,
        "has_motion_sensors": False,
        "device_model": "Legacy Smartphone",
    }
    result = evaluate_scan_orchestration(profile)
    assert result.evaluated_tier == "TIER_5_BASIC_RGB"
    assert result.recommended_scan_mode == "rgb_photo_scan"
    assert "single_photo_reference_scaled" in result.fallback_chain
    assert "reference" in result.accuracy_assurance.lower() or "reference" in result.fallback_reasons[0].lower()


def test_api_telemetry_benchmarks_endpoint():
    """Tests GET /api/v1/scan/orchestration/telemetry-benchmarks returns full benchmark matrix."""
    client = TestClient(app)
    response = client.get("/api/v1/scan/orchestration/telemetry-benchmarks")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 5
    first = data[0]
    assert first["tier_id"] == "TIER_1_LIDAR"
    assert "typical_accuracy_cm" in first
    assert "relative_compute_cost_usd" in first


def test_api_evaluate_route_endpoint():
    """Tests POST /api/v1/scan/orchestration/evaluate-route API."""
    client = TestClient(app)
    payload = {
        "has_lidar": True,
        "device_model": "iPhone 16 Pro Max",
        "os_name": "iOS",
        "os_version": "18.0",
    }
    response = client.post("/api/v1/scan/orchestration/evaluate-route", json=payload)
    assert response.status_code == 200
    res = response.json()
    assert res["evaluated_tier"] == "TIER_1_LIDAR"
    assert res["recommended_scan_mode"] == "lidar_scan"
    assert len(res["fallback_chain"]) >= 3
    assert len(res["all_tier_benchmarks"]) == 5


def test_attach_scan_orchestration_to_canonical_room():
    """Tests attaching orchestration evaluation to CanonicalRoomModel."""
    client = TestClient(app)

    # Create dummy canonical room
    room_id = "test-orchestration-room-101"
    room = CanonicalRoomModel(
        id=room_id,
        project_id="proj-orch-1",
        room_type="Living Room",
        geometry=Geometry(
            shape_type=RoomShapeType.RECTANGULAR,
            confidence=0.92,
            wall_length_m=5.0,
            wall_width_m=4.0,
            wall_height_m=2.8,
            floor_area_sqm=20.0,
            wall_perimeter_m=18.0,
        ),
    )
    repository.save_room(room)

    payload = {
        "has_lidar": False,
        "has_ar": True,
        "has_motion_sensors": True,
        "device_model": "Google Pixel 8",
    }
    response = client.post(f"/api/v1/rooms/{room_id}/scan-orchestration", json=payload)
    assert response.status_code == 200
    updated_room = response.json()
    assert updated_room["orchestration_evaluation"] is not None
    assert updated_room["orchestration_evaluation"]["evaluated_tier"] == "TIER_3_AR_RGB"
    assert updated_room["orchestration_evaluation"]["recommended_scan_mode"] == "ar_rgb_scan"

    # Verify repository persistence
    loaded = repository.rooms[room_id]
    assert loaded.orchestration_evaluation is not None
    assert loaded.orchestration_evaluation.evaluated_tier == "TIER_3_AR_RGB"
