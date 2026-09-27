import io
import numpy as np
from PIL import Image
from fastapi.testclient import TestClient

from packages.room_model import CanonicalRoomModel, MeasurementSource, ObjectAction
from services.ai_worker.pipelines.cloud_generation import CloudInpaintingProvider
from services.ai_worker.pipelines.mask_builder import MaskBuilder
from services.api.app.main import app

client = TestClient(app)


def _create_test_image():
    np.random.seed(42)
    arr = np.zeros((600, 800, 3), dtype=np.uint8)
    arr[0:400, :] = [210, 205, 195]
    arr[400:, :] = [160, 120, 80]
    noise = np.random.randint(-15, 15, (600, 800, 3))
    arr = np.clip(arr.astype(int) + noise, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def test_user_corrections_api_and_telemetry():
    img = _create_test_image()
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    # 1. Upload room
    res_upload = client.post(
        "/api/v1/rooms/upload-and-analyze",
        files={"file": ("living.jpg", buf.getvalue(), "image/jpeg")},
        data={"room_name": "Correction Test Room"},
    )
    assert res_upload.status_code == 200
    room = res_upload.json()
    room_id = room["id"]
    first_obj = room["objects"][0]
    obj_id = first_obj["id"]

    # 2. Apply user correction (relabel and change category)
    res_corr = client.patch(
        f"/api/v1/rooms/{room_id}/model/corrections",
        json=[
            {
                "element_id": obj_id,
                "label_override": "Custom Italian Leather Sofa",
                "category_override": "sofa_luxury",
                "is_deleted": False,
            }
        ],
    )
    assert res_corr.status_code == 200
    updated_room = res_corr.json()
    corr_obj = next(o for o in updated_room["objects"] if o["id"] == obj_id)
    assert corr_obj["name"] == "Custom Italian Leather Sofa"
    assert corr_obj["category"] == "sofa_luxury"

    # 3. Verify UserCorrectionRecord in DB
    from services.api.app.db.session import SessionLocal
    from services.api.app.db.models import UserCorrectionRecord
    with SessionLocal() as db:
        rec = db.query(UserCorrectionRecord).filter(
            UserCorrectionRecord.room_id == room_id,
            UserCorrectionRecord.element_id == obj_id,
        ).first()
        assert rec is not None
        assert rec.corrected_value == "Custom Italian Leather Sofa"

    # 4. Verify measurement endpoint
    meas_id = room["measurements"][0]["id"]
    res_verify = client.post(
        f"/api/v1/rooms/{room_id}/measurements/{meas_id}/verify",
        json={"verified_value": 4.35},
    )
    assert res_verify.status_code == 200
    assert res_verify.json()["verified_by_user"] is True
    assert res_verify.json()["source"] == "USER_VERIFIED"


def test_mask_builder_and_cloud_generation():
    img = _create_test_image()
    from services.ai_worker.pipelines.room_analyzer import RoomAnalyzer
    analyzer = RoomAnalyzer()
    room = analyzer.analyze_photo(img)

    # Set actions
    room.set_action_for_element(room.objects[0].id, ObjectAction.KEEP)
    room.set_action_for_element(room.objects[1].id, ObjectAction.REPLACE)

    constraints = room.build_design_constraint(
        styles=["Japandi Clean Organic"],
        budget_amount=20000.0,
    )

    # Test MaskBuilder
    preserve_mask, replace_mask = MaskBuilder.build_conditioning_masks(
        room=room,
        constraints=constraints,
        width=800,
        height=600,
    )
    assert preserve_mask.size == (800, 600)
    assert replace_mask.size == (800, 600)

    # Test CloudInpaintingProvider
    provider = CloudInpaintingProvider(fallback_local=True)
    res = provider.generate_redesigns(
        image=img,
        room_model=room,
        constraints=constraints,
        count=3,
    )
    assert res.provider == "cloud-inpainting-controlnet"
    assert len(res.data.variants) == 3
    assert res.data.variants[0].structural_preservation_score >= 0.90
