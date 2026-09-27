import io
import numpy as np
from PIL import Image
from fastapi.testclient import TestClient

from services.api.app.main import app

client = TestClient(app)


def _create_test_image_bytes():
    np.random.seed(42)
    arr = np.zeros((600, 800, 3), dtype=np.uint8)
    # Walls & floor
    arr[0:400, :] = [210, 205, 195]
    arr[400:, :] = [160, 120, 80]
    # Add noise texture
    noise = np.random.randint(-15, 15, (600, 800, 3))
    arr = np.clip(arr.astype(int) + noise, 0, 255).astype(np.uint8)

    img = Image.fromarray(arr)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)
    return buf.getvalue()


def test_health_check():
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "healthy"


def test_device_capabilities_tiers():
    res_c = client.get("/api/v1/devices/capabilities")
    assert res_c.status_code == 200
    assert res_c.json()["capability_tier"] == "Tier C"

    res_a = client.get("/api/v1/devices/capabilities?has_lidar=true")
    assert res_a.status_code == 200
    assert res_a.json()["capability_tier"] == "Tier A"


def test_project_crud():
    res = client.post("/api/v1/projects", json={"name": "Kuala Lumpur Apartment", "currency": "MYR"})
    assert res.status_code == 200
    proj_data = res.json()
    assert proj_data["name"] == "Kuala Lumpur Apartment"
    assert proj_data["currency"] == "MYR"

    res_list = client.get("/api/v1/projects")
    assert res_list.status_code == 200
    assert any(p["id"] == proj_data["id"] for p in res_list.json())


def test_upload_analyze_and_redesign_flow():
    img_bytes = _create_test_image_bytes()

    # 1. Upload and analyze room
    files = {"file": ("room.jpg", img_bytes, "image/jpeg")}
    data = {"room_name": "Living Room Test", "room_type": "living_room"}
    res = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data)
    assert res.status_code == 200
    room = res.json()
    room_id = room["id"]
    assert len(room["surfaces"]) >= 2
    assert len(room["objects"]) >= 2
    assert room["quality_report"]["passed"] is True

    # 2. Update element action
    first_obj_id = room["objects"][0]["id"]
    res_patch = client.patch(
        f"/api/v1/rooms/{room_id}/elements/{first_obj_id}",
        json={"action": "KEEP"},
    )
    assert res_patch.status_code == 200
    assert res_patch.json()["action"] == "KEEP"

    # 3. Generate Redesigns
    res_gen = client.post(
        f"/api/v1/rooms/{room_id}/design-requests",
        json={
            "styles": ["Warm Modern Minimalist"],
            "goals": ["increase_natural_light"],
            "budget_amount": 15000.0,
            "budget_currency": "MYR",
            "free_text_prompt": "Keep sofa and windows. Update floor to oak.",
        },
    )
    assert res_gen.status_code == 200
    version = res_gen.json()
    assert len(version["variants"]) == 3
    assert version["variants"][0]["structural_preservation_score"] >= 0.90

    # 4. Check versions history
    res_ver = client.get(f"/api/v1/rooms/{room_id}/versions")
    assert res_ver.status_code == 200
    assert len(res_ver.json()) >= 1
