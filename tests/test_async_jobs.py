import io
import time
import numpy as np
from PIL import Image
from fastapi.testclient import TestClient

from services.api.app.main import app

client = TestClient(app)


def _create_test_image_bytes():
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


def test_async_room_analysis_and_redesign_pipeline():
    img_bytes = _create_test_image_bytes()
    room_id = f"room_async_{int(time.time())}"

    # 1. Dispatch asynchronous room analysis job
    files = {"file": ("room.jpg", img_bytes, "image/jpeg")}
    res_start = client.post(f"/api/v1/rooms/{room_id}/analyze-async", files=files)
    assert res_start.status_code == 200
    start_data = res_start.json()
    job_id = start_data["job_id"]
    assert start_data["status"] == "CREATED"

    # 2. Poll job status until complete (or short loop)
    max_wait = 10
    final_status = None
    for _ in range(max_wait * 5):
        time.sleep(0.08)
        res_poll = client.get(f"/api/v1/jobs/{job_id}")
        assert res_poll.status_code == 200
        poll_data = res_poll.json()
        final_status = poll_data["status"]
        if final_status in {"READY_FOR_REVIEW", "COMPLETED", "FAILED_RETRYABLE", "FAILED_FINAL"}:
            break

    assert final_status == "READY_FOR_REVIEW"
    assert poll_data["progress_percent"] == 100
    assert poll_data["latency_ms"] is not None
    assert poll_data["cost_usd"] is not None

    # 3. Verify Room record was populated in database
    from services.api.app.db.session import SessionLocal
    from services.api.app.db.models import Room
    with SessionLocal() as db:
        room = db.query(Room).filter(Room.id == room_id).first()
        assert room is not None
        assert room.room_model_data is not None
        assert len(room.measurements) >= 2

    # 4. Dispatch asynchronous redesign generation
    res_redesign = client.post(
        f"/api/v1/rooms/{room_id}/design-requests-async",
        json={
            "styles": ["Warm Modern Minimalist"],
            "goals": ["increase_natural_light"],
            "budget_amount": 15000.0,
            "budget_currency": "MYR",
            "free_text_prompt": "Keep sofa and windows. Change floor finish.",
        },
    )
    assert res_redesign.status_code == 200
    redesign_job_id = res_redesign.json()["job_id"]

    # 5. Poll redesign job status
    redesign_final_status = None
    for _ in range(max_wait * 5):
        time.sleep(0.08)
        res_poll2 = client.get(f"/api/v1/jobs/{redesign_job_id}")
        assert res_poll2.status_code == 200
        poll2_data = res_poll2.json()
        redesign_final_status = poll2_data["status"]
        if redesign_final_status in {"COMPLETED", "FAILED_RETRYABLE", "FAILED_FINAL"}:
            break

    assert redesign_final_status == "COMPLETED"
    assert poll2_data["result_data"] is not None
    assert len(poll2_data["result_data"]["variants"]) == 3
