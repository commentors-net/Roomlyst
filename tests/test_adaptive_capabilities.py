import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient
from packages.room_model import (
    CanonicalRoomModel,
    CaptureMetadata,
    Measurement,
    MeasurementSource,
)
from services.ai_worker.pipelines.room_analyzer import RoomAnalyzer
from services.api.app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def _create_synthetic_image_bytes():
    img = Image.new("RGB", (640, 480), color=(200, 200, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


# =========================================================================
# 1. Canonical Schema & Accuracy Tier Tests
# =========================================================================

def test_measurement_accuracy_tiers():
    """Validates accuracy tiers per Add-on Section 6."""
    # EXACT: LiDAR native or User verified
    m_lidar = Measurement(
        entity_type="wall",
        measurement_type="length",
        value=5.0,
        confidence=0.96,
        source=MeasurementSource.LIDAR_NATIVE,
    )
    assert m_lidar.accuracy_tier == "EXACT"
    assert m_lidar.accuracy_label == "Exact"
    assert not m_lidar.is_approximate

    m_user = Measurement(
        entity_type="wall",
        measurement_type="length",
        value=5.0,
        confidence=1.0,
        source=MeasurementSource.USER_VERIFIED,
        verified_by_user=True,
    )
    assert m_user.accuracy_tier == "EXACT"
    assert m_user.accuracy_label == "Exact"

    # APPROXIMATE: AR Depth from motion or Multiview
    m_ar = Measurement(
        entity_type="wall",
        measurement_type="length",
        value=4.95,
        confidence=0.88,
        source=MeasurementSource.AR_DEPTH_FROM_MOTION,
    )
    assert m_ar.accuracy_tier == "APPROXIMATE"
    assert m_ar.accuracy_label == "Approximate"
    assert m_ar.is_approximate

    m_mvs = Measurement(
        entity_type="wall",
        measurement_type="length",
        value=4.92,
        confidence=0.80,
        source=MeasurementSource.MULTIVIEW_RECONSTRUCTION,
    )
    assert m_mvs.accuracy_tier == "APPROXIMATE"
    assert m_mvs.accuracy_label == "Approximate"

    # REQUIRES_CONFIRMATION: Monocular depth estimate
    m_mono = Measurement(
        entity_type="wall",
        measurement_type="length",
        value=4.8,
        confidence=0.74,
        source=MeasurementSource.MONOCULAR_DEPTH,
    )
    assert m_mono.accuracy_tier == "REQUIRES_CONFIRMATION"
    assert m_mono.accuracy_label == "Estimated - Confirmation Needed"
    assert m_mono.is_approximate


# =========================================================================
# 2. RoomAnalyzer Adaptive Calibration Tests
# =========================================================================

def test_room_analyzer_calibrates_to_lidar():
    img = Image.new("RGB", (640, 480), color=(220, 220, 220))
    analyzer = RoomAnalyzer()
    meta = CaptureMetadata(
        scan_mode="lidar_scan",
        has_hardware_depth=True,
        has_arkit=True,
        has_roomplan=True,
        capability_confidence=0.98,
    )

    room = analyzer.analyze_photo(img, room_name="LiDAR Living Room", capture_metadata=meta)
    assert room.capture_metadata is not None
    assert room.capture_metadata.scan_mode == "lidar_scan"

    # Check that measurements inherit LiDAR native source and high confidence
    for meas in room.measurements:
        assert meas.source == MeasurementSource.LIDAR_NATIVE
        assert meas.confidence >= 0.95
        assert meas.accuracy_tier == "EXACT"


def test_room_analyzer_calibrates_to_ar_depth():
    img = Image.new("RGB", (640, 480), color=(220, 220, 220))
    analyzer = RoomAnalyzer()
    meta = CaptureMetadata(
        scan_mode="ar_depth_scan",
        has_arcore=True,
        has_arcore_depth=True,
        capability_confidence=0.88,
    )

    room = analyzer.analyze_photo(img, room_name="AR Depth Room", capture_metadata=meta)
    for meas in room.measurements:
        assert meas.source == MeasurementSource.AR_DEPTH_FROM_MOTION
        assert 0.80 <= meas.confidence <= 0.90
        assert meas.accuracy_tier == "APPROXIMATE"


def test_room_analyzer_calibrates_to_monocular_rgb():
    img = Image.new("RGB", (640, 480), color=(220, 220, 220))
    analyzer = RoomAnalyzer()
    meta = CaptureMetadata(
        scan_mode="rgb_photo_scan",
        has_hardware_depth=False,
        has_arkit=False,
        has_arcore=False,
        capability_confidence=0.74,
    )

    room = analyzer.analyze_photo(img, room_name="Budget Phone Room", capture_metadata=meta)
    for meas in room.measurements:
        assert meas.source == MeasurementSource.MONOCULAR_DEPTH
        assert 0.70 <= meas.confidence <= 0.80
        assert meas.accuracy_tier == "REQUIRES_CONFIRMATION"


# =========================================================================
# 3. GET /devices/capabilities Endpoint Tests
# =========================================================================

def test_api_capabilities_tier_a_lidar(client):
    res = client.get("/api/v1/devices/capabilities?platform=ios&has_lidar=true&has_arkit=true&has_roomplan=true")
    assert res.status_code == 200
    data = res.json()
    assert data["capability_tier"] == "Tier A"
    assert data["scan_mode"] == "lidar_scan"
    assert data["has_lidar"] is True
    assert "Point camera and walk around room" in data["user_guidance_prompt"]
    assert "Hardware 3D Precision" in data["accuracy_assurance"]


def test_api_capabilities_tier_b_arcore_depth(client):
    res = client.get("/api/v1/devices/capabilities?platform=android&has_arcore=true&has_arcore_depth=true")
    assert res.status_code == 200
    data = res.json()
    assert data["capability_tier"] == "Tier B"
    assert data["scan_mode"] == "ar_depth_scan"
    assert data["has_arcore_depth"] is True
    assert "Move smoothly across surfaces" in data["user_guidance_prompt"]


def test_api_capabilities_tier_b_arkit_rgb_no_lidar(client):
    res = client.get("/api/v1/devices/capabilities?platform=ios&has_lidar=false&has_arkit=true")
    assert res.status_code == 200
    data = res.json()
    assert data["capability_tier"] == "Tier B"
    assert data["scan_mode"] == "ar_rgb_scan"
    assert "Move slowly around room" in data["user_guidance_prompt"]


def test_api_capabilities_tier_c_basic_camera(client):
    res = client.get("/api/v1/devices/capabilities?platform=android&has_arcore=false&has_motion_sensors=false")
    assert res.status_code == 200
    data = res.json()
    assert data["capability_tier"] == "Tier C"
    assert data["scan_mode"] == "rgb_photo_scan"
    assert "Capture Room: Take photos from room corners" in data["user_guidance_prompt"]


# =========================================================================
# 4. End-to-End Upload with Adaptive Capture Metadata
# =========================================================================

def test_upload_and_analyze_with_adaptive_metadata(client):
    img_bytes = _create_synthetic_image_bytes()
    files = {"file": ("room.jpg", img_bytes, "image/jpeg")}
    data = {
        "room_name": "Adaptive Living Room",
        "room_type": "living_room",
        "scan_mode": "lidar_scan",
        "has_hardware_depth": "true",
        "has_arkit": "true",
        "has_roomplan": "true",
    }

    res = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data)
    assert res.status_code == 200
    res_data = res.json()
    model = res_data
    assert model["capture_metadata"]["scan_mode"] == "lidar_scan"
    assert model["capture_metadata"]["has_hardware_depth"] is True

    # Check accuracy tiers on measurements
    measurements = model["measurements"]
    assert len(measurements) > 0
    for m in measurements:
        assert m["source"] in ("LIDAR_NATIVE", "lidar_native")
        assert m["accuracy_tier"] == "EXACT"
