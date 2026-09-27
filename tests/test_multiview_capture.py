import io
import pytest
import numpy as np
from PIL import Image
from fastapi.testclient import TestClient

from packages.room_model import (
    BoundingBox2D,
    CanonicalRoomModel,
    MeasurementSource,
    ObjectAction,
    RoomObject,
)
from services.ai_worker.pipelines.multiview_analyzer import (
    MultiViewAssociator,
    MultiViewRoomAnalyzer,
)
from services.api.app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def _create_corner_image(corner_idx: int, width=640, height=480) -> Image.Image:
    """Generates distinct corner images with realistic distinct architectural features."""
    np.random.seed(corner_idx * 100)
    arr = np.zeros((height, width, 3), dtype=np.uint8)
    # Ceiling
    arr[0:int(height * 0.25), :] = [230, 230, 240]
    # Walls
    arr[int(height * 0.25):int(height * 0.75), :] = [190, 195, 205]
    # Flooring
    arr[int(height * 0.75):, :] = [130, 100, 70]

    # Draw distinct architectural structures depending on corner perspective
    if corner_idx == 1:
        # Window on right
        arr[int(height * 0.3):int(height * 0.6), int(width * 0.6):int(width * 0.9)] = [100, 180, 240]
        # Sofa on bottom-left
        arr[int(height * 0.55):int(height * 0.78), int(width * 0.15):int(width * 0.5)] = [60, 70, 85]
    elif corner_idx == 2:
        # Window on left
        arr[int(height * 0.3):int(height * 0.6), int(width * 0.1):int(width * 0.4)] = [100, 180, 240]
        # TV Unit on bottom-right
        arr[int(height * 0.5):int(height * 0.75), int(width * 0.6):int(width * 0.9)] = [40, 45, 50]
    elif corner_idx == 3:
        # Doorway on right
        arr[int(height * 0.3):int(height * 0.8), int(width * 0.7):int(width * 0.9)] = [90, 60, 40]
        # Sofa angled on center
        arr[int(height * 0.5):int(height * 0.78), int(width * 0.3):int(width * 0.65)] = [60, 70, 85]
    else:
        # Wall cabinet on left
        arr[int(height * 0.35):int(height * 0.75), int(width * 0.15):int(width * 0.55)] = [80, 90, 100]

    # Add high-frequency noise so images are sharp
    noise = np.random.randint(-10, 10, (height, width, 3))
    arr = np.clip(arr.astype(int) + noise, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def _image_to_bytes(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


# =========================================================================
# 1. MultiViewAssociator Unit Tests
# =========================================================================

def test_duplicate_frame_detection():
    img1 = _create_corner_image(1)
    img1_clone = img1.copy()
    img2 = _create_corner_image(2)

    diff_identical = MultiViewAssociator.compute_image_difference(img1, img1_clone)
    diff_distinct = MultiViewAssociator.compute_image_difference(img1, img2)

    assert diff_identical < 0.05
    assert diff_distinct > 0.08


def test_cross_image_object_association():
    # View 1 detects a sofa and a coffee table
    v1_sofa = RoomObject(
        name="Grey Sofa",
        category="sofa",
        confidence=0.84,
        bounding_box=BoundingBox2D(x_min=0.1, y_min=0.5, x_max=0.5, y_max=0.8),
    )
    v1_table = RoomObject(
        name="Coffee Table",
        category="coffee_table",
        confidence=0.80,
        bounding_box=BoundingBox2D(x_min=0.4, y_min=0.6, x_max=0.6, y_max=0.8),
    )

    # View 2 observes the same sofa from another angle and a TV unit
    v2_sofa = RoomObject(
        name="Grey Sofa View 2",
        category="sofa",
        confidence=0.86,
        bounding_box=BoundingBox2D(x_min=0.2, y_min=0.5, x_max=0.6, y_max=0.85),
    )
    v2_tv = RoomObject(
        name="TV Unit",
        category="tv_unit",
        confidence=0.82,
        bounding_box=BoundingBox2D(x_min=0.7, y_min=0.4, x_max=0.9, y_max=0.7),
    )

    fused = MultiViewAssociator.associate_objects([[v1_sofa, v1_table], [v2_sofa, v2_tv]])

    # Should fuse into 3 distinct items (sofa, coffee_table, tv_unit) instead of 4
    assert len(fused) == 3
    sofa_item = next(o for o in fused if o.category == "sofa")
    assert sofa_item.views_observed == 2
    assert sofa_item.confidence > 0.84
    # Bounding box should span merged observation
    assert sofa_item.bounding_box.x_min == 0.1
    assert sofa_item.bounding_box.x_max == 0.6

    table_item = next(o for o in fused if o.category == "coffee_table")
    assert table_item.views_observed == 1


# =========================================================================
# 2. MultiViewRoomAnalyzer Pipeline Tests
# =========================================================================

def test_multiview_coverage_and_reconstruction():
    analyzer = MultiViewRoomAnalyzer()

    # 4 distinct corner images
    images = [_create_corner_image(i) for i in range(1, 5)]
    labels = ["Corner 1 (Entry)", "Corner 2 (Left)", "Corner 3 (Opposite)", "Corner 4 (Right)"]

    room = analyzer.analyze_multi_view(
        images=images,
        viewpoint_labels=labels,
        room_name="Multi-Corner Living Room",
    )

    assert len(room.frames) == 4
    for f in room.frames:
        assert not f.is_duplicate

    assert room.coverage_report is not None
    assert room.coverage_report.valid_frames == 4
    assert room.coverage_report.estimated_coverage_pct >= 95.0
    assert room.coverage_report.has_sufficient_overlap is True

    # Geometry & measurements calibrated to multi-view
    assert room.geometry.reconstruction_method == "multiview_sfm_depth_fusion"
    assert len(room.measurements) >= 3
    for m in room.measurements:
        assert m.source == MeasurementSource.MULTIVIEW_RECONSTRUCTION
        assert m.accuracy_tier == "APPROXIMATE"
        assert m.confidence >= 0.88


def test_multiview_duplicate_frame_rejection():
    analyzer = MultiViewRoomAnalyzer()

    img1 = _create_corner_image(1)
    img1_duplicate = img1.copy()
    img2 = _create_corner_image(2)

    room = analyzer.analyze_multi_view(
        images=[img1, img1_duplicate, img2],
        viewpoint_labels=["Corner 1", "Corner 1 (Duplicate)", "Corner 2"],
    )

    assert room.coverage_report.rejected_frames == 1
    assert room.coverage_report.valid_frames == 2
    assert any(f.is_duplicate for f in room.frames)


# =========================================================================
# 3. Multi-Photo Ingestion API Tests
# =========================================================================

def test_api_multi_capture_and_analyze(client):
    img1_bytes = _image_to_bytes(_create_corner_image(1))
    img2_bytes = _image_to_bytes(_create_corner_image(2))
    img3_bytes = _image_to_bytes(_create_corner_image(3))

    files = [
        ("files", ("corner1.jpg", img1_bytes, "image/jpeg")),
        ("files", ("corner2.jpg", img2_bytes, "image/jpeg")),
        ("files", ("corner3.jpg", img3_bytes, "image/jpeg")),
    ]
    data = {
        "room_name": "Penthouse Multi-View Living Room",
        "room_type": "living_room",
        "viewpoint_labels": "Corner 1 - Entry,Corner 2 - Left,Corner 3 - Far Wall",
        "platform": "ios",
    }

    res = client.post("/api/v1/rooms/multi-capture-and-analyze", files=files, data=data)
    assert res.status_code == 200
    res_data = res.json()

    assert len(res_data["frames"]) == 3
    assert res_data["coverage_report"]["valid_frames"] == 3
    assert res_data["coverage_report"]["estimated_coverage_pct"] >= 80.0

    measurements = res_data["measurements"]
    assert len(measurements) > 0
    for m in measurements:
        assert m["source"] in ("MULTIVIEW_RECONSTRUCTION", "multiview_reconstruction")
        assert m["accuracy_tier"] == "APPROXIMATE"
