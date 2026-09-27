import pytest
from fastapi.testclient import TestClient
from packages.room_model.schema import (
    CanonicalRoomModel,
    RoomSurface,
    RoomOpening,
    RoomObject,
    Geometry,
    Measurement,
    MeasurementSource,
    ReferenceScaleType,
    ScaleCalibration,
    SurfaceType,
    OpeningType,
    ObjectType,
)
from services.ai_worker.pipelines.scale_calibrator import ScaleCalibrator
from services.api.app.main import app

client = TestClient(app)


def build_test_room() -> CanonicalRoomModel:
    """Creates a sample room model with initial approximate measurements."""
    room = CanonicalRoomModel(
        room_name="Calibration Test Room",
        room_type="bedroom",
        geometry=Geometry(
            floor_area_sqm=20.0,
            ceiling_height_m=2.5,
            estimated_width_m=4.0,
            estimated_length_m=5.0,
            confidence=0.75,
        ),
        surfaces=[
            RoomSurface(
                surface_type=SurfaceType.WALL,
                name="North Wall",
                estimated_area_sqm=10.0,
                confidence=0.85,
            ),
            RoomSurface(
                surface_type=SurfaceType.FLOOR,
                name="Oak Parquet Floor",
                estimated_area_sqm=20.0,
                confidence=0.85,
            ),
        ],
        openings=[
            RoomOpening(
                opening_type=OpeningType.DOOR,
                name="Bedroom Entrance Door",
                confidence=0.88,
            )
        ],
        objects=[
            RoomObject(
                name="Wardrobe",
                category="wardrobe",
                object_type=ObjectType.FURNITURE,
                confidence=0.88,
            )
        ],
    )

    room.measurements = [
        Measurement(
            room_id=room.id,
            entity_type="room_dimension",
            measurement_type="width",
            value=4.0,
            unit="m",
            source=MeasurementSource.MONOCULAR_DEPTH,
            confidence=0.60,
        ),
        Measurement(
            room_id=room.id,
            entity_type="surface",
            measurement_type="area",
            value=20.0,
            unit="m2",
            source=MeasurementSource.MONOCULAR_DEPTH,
            confidence=0.60,
        ),
        Measurement(
            room_id=room.id,
            entity_type="opening",
            entity_id=room.openings[0].id,
            measurement_type="height",
            value=2.0,
            unit="m",
            source=MeasurementSource.MONOCULAR_DEPTH,
            confidence=0.75,
        ),
    ]
    return room


def test_scale_calibrator_known_dimension():
    """Verify linear and quadratic rescaling with user-known wall dimension."""
    room = build_test_room()
    calibrator = ScaleCalibrator()

    # User knows real room width is 4.40m instead of 4.0m (scale_factor = 1.1)
    calib = calibrator.calibrate(
        room=room,
        target_real_value=4.40,
        reference_type=ReferenceScaleType.KNOWN_WALL_DIMENSION,
        reference_dimension_type="width",
    )

    assert room.scale_calibration is not None
    assert pytest.approx(room.scale_calibration.scale_factor, 0.001) == 1.10
    assert room.scale_calibration.reference_type == ReferenceScaleType.KNOWN_WALL_DIMENSION

    # Linear dimensions scale by 1.1x
    assert pytest.approx(room.geometry.estimated_width_m, 0.01) == 4.40
    assert pytest.approx(room.geometry.estimated_length_m, 0.01) == 5.50
    assert pytest.approx(room.geometry.ceiling_height_m, 0.01) == 2.75

    # Area scales quadratically by 1.1^2 = 1.21x
    assert pytest.approx(room.geometry.floor_area_sqm, 0.01) == 24.20
    assert pytest.approx(room.surfaces[0].estimated_area_sqm, 0.01) == 12.10
    assert pytest.approx(room.surfaces[1].estimated_area_sqm, 0.01) == 24.20

    # Measurement provenance upgraded to REFERENCE_SCALED & EXACT tier
    width_meas = next(m for m in room.measurements if m.measurement_type == "width")
    assert pytest.approx(width_meas.value, 0.01) == 4.40
    assert width_meas.source == MeasurementSource.REFERENCE_SCALED
    assert width_meas.accuracy_tier == "EXACT"
    assert width_meas.is_approximate is False
    assert width_meas.confidence >= 0.92

    area_meas = next(m for m in room.measurements if m.measurement_type == "area")
    assert pytest.approx(area_meas.value, 0.01) == 24.20
    assert area_meas.source == MeasurementSource.REFERENCE_SCALED


def test_scale_calibrator_standard_door_reference():
    """Verify scale calibration using a standard residential door height (2.10m)."""
    room = build_test_room()
    calibrator = ScaleCalibrator()

    door = room.openings[0]
    calib = calibrator.calibrate(
        room=room,
        target_real_value=2.10,
        reference_type=ReferenceScaleType.STANDARD_DOOR_HEIGHT,
        reference_dimension_type="height",
        reference_entity_id=door.id,
    )

    # 2.10 / 2.00 = 1.05 scale factor
    assert pytest.approx(room.scale_calibration.scale_factor, 0.001) == 1.05
    assert pytest.approx(room.geometry.estimated_width_m, 0.01) == 4.20


def test_scale_calibrator_presets():
    """Verify standard scale presets are defined correctly."""
    calibrator = ScaleCalibrator()
    presets = calibrator.get_presets()
    preset_ids = [p["preset_id"] for p in presets]

    assert "preset_a4_paper" in preset_ids
    assert "preset_door_height" in preset_ids
    assert "preset_floor_tile_60" in preset_ids
    assert "preset_floor_tile_30" in preset_ids
    assert "preset_credit_card" in preset_ids
    assert "preset_known_wall" in preset_ids

    a4 = next(p for p in presets if p["preset_id"] == "preset_a4_paper")
    assert pytest.approx(a4["value_meters"], 0.001) == 0.297


def test_user_measurement_verification():
    """Verify direct user confirmation of a measurement marks it USER_VERIFIED."""
    room = build_test_room()
    meas = room.measurements[0]

    success = room.verify_measurement(meas.id, verified_value=4.15)
    assert success is True
    assert meas.verified_by_user is True
    assert meas.value == 4.15
    assert meas.source == MeasurementSource.USER_VERIFIED
    assert meas.accuracy_tier == "EXACT"
    assert meas.confidence == 1.0
    assert meas.is_approximate is False


def test_scale_presets_api():
    """Verify GET /api/v1/rooms/scale-presets endpoint."""
    res = client.get("/api/v1/rooms/scale-presets")
    assert res.status_code == 200
    presets = res.json()
    assert isinstance(presets, list)
    assert len(presets) >= 6
    assert any(p["preset_id"] == "preset_a4_paper" for p in presets)


def _create_test_image_bytes():
    import numpy as np
    from PIL import Image
    import io
    np.random.seed(42)
    arr = np.zeros((600, 800, 3), dtype=np.uint8)
    arr[0:400, :] = [210, 205, 195]
    arr[400:, :] = [160, 120, 80]
    noise = np.random.randint(-15, 15, (600, 800, 3))
    arr = np.clip(arr.astype(int) + noise, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)
    return buf.getvalue()


def test_scale_calibration_api():
    """Verify POST /api/v1/rooms/{id}/scale-calibration endpoint."""
    img_bytes = _create_test_image_bytes()
    files = {"file": ("calibrate_room.jpg", img_bytes, "image/jpeg")}
    data = {"room_name": "Scale API Test Room", "room_type": "living_room"}
    res_upload = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data)
    assert res_upload.status_code == 200
    room = res_upload.json()
    room_id = room["id"]
    orig_width = room["geometry"]["estimated_width_m"] or 4.0

    target_val = round(orig_width * 1.15, 2)
    res = client.post(
        f"/api/v1/rooms/{room_id}/scale-calibration",
        json={
            "reference_type": "KNOWN_WALL_DIMENSION",
            "target_real_value": target_val,
            "reference_dimension_type": "width",
            "notes": "Calibrated via laser tape",
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["scale_calibration"] is not None
    assert pytest.approx(data["scale_calibration"]["scale_factor"], 0.01) == 1.15
    assert pytest.approx(data["geometry"]["estimated_width_m"], 0.05) == target_val


def test_verify_measurement_api():
    """Verify POST /api/v1/rooms/{id}/measurements/{measurement_id}/verify endpoint."""
    img_bytes = _create_test_image_bytes()
    files = {"file": ("verify_room.jpg", img_bytes, "image/jpeg")}
    data = {"room_name": "Verify API Test Room", "room_type": "living_room"}
    res_upload = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data)
    assert res_upload.status_code == 200
    room = res_upload.json()
    room_id = room["id"]
    assert len(room["measurements"]) > 0

    meas_id = room["measurements"][0]["id"]
    res = client.post(
        f"/api/v1/rooms/{room_id}/measurements/{meas_id}/verify",
        json={"verified_value": 4.10},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert data["verified_by_user"] is True
    assert data["source"] == "USER_VERIFIED"
