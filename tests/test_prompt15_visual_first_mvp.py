"""
Tests for Prompt 15: Visual-First MVP: Photo → Three Genuine Redesigns → Before/After.
Validates:
1. End-to-end room upload, photo persistence, and signed media URLs.
2. Project rooms hydration across reloads (preventing blank before/after).
3. 3-Variant synthesis with Concept A/B/C labels and consumer intents:
   - Empty & Redesign (Default)
   - Home Office
   - Cozy Lounge / Reading Corner
   - Guest Nook
   - Storage + Workspace
   - Surprise Me
4. Honest capability disclosure and fail-closed AI inpainting provider behavior.
5. Interactive Before & After media accessibility and URL resolution.
"""

import io
import json
import os
import pytest
from PIL import Image
from fastapi.testclient import TestClient

from services.api.app.main import app
from services.api.app.storage import get_storage_provider
from services.api.app.db.session import SessionLocal
from services.api.app.db.models import Project, Room, User
from services.api.app.db.repository import repository

client = TestClient(app)


def create_synthetic_room_photo() -> bytes:
    """Creates a deterministic synthetic test room photo."""
    img = Image.new("RGB", (640, 480), color=(140, 160, 180))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_project_rooms_hydration_across_reload():
    """
    Diagnoses and verifies the root cause of blank before/after:
    Ensures that GET /api/v1/projects/{id} properly populates proj.rooms and proj.room_ids
    so that reloading the page restores the room photo and previous design variants.
    """
    # 1. Create a guest project
    res_proj = client.post("/api/v1/projects", json={"name": "Loft Renovation", "currency": "MYR"})
    assert res_proj.status_code == 200
    proj_data = res_proj.json()
    proj_id = proj_data["id"]
    guest_token = res_proj.headers.get("X-Guest-Token") or res_proj.headers.get("X-Guest-Session-ID")
    headers = {"X-Guest-Token": guest_token} if guest_token else {}

    # 2. Upload room photo
    raw_img = create_synthetic_room_photo()
    files = {"file": ("my_living_room.jpg", raw_img, "image/jpeg")}
    data = {"room_name": "Main Living Room", "project_id": proj_id, "platform": "web"}
    res_up = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data, headers=headers)
    assert res_up.status_code == 200
    room_data = res_up.json()
    room_id = room_data["id"]
    assert room_data["original_image_url"] is not None
    assert "/storage/uploads/" in room_data["original_image_url"]

    # 3. Generate 3 redesign concepts
    gen_payload = {
        "styles": ["Empty & Redesign", "Warm Modern Minimalist"],
        "goals": ["modernize", "declutter"],
        "budget_amount": 12000,
        "budget_currency": "MYR",
        "free_text_prompt": "Empty & Redesign room with clean architectural surfaces",
        "generation_mode": "algorithmic_preview",
    }
    res_gen = client.post(f"/api/v1/rooms/{room_id}/design-requests", json=gen_payload, headers=headers)
    assert res_gen.status_code == 200
    version_data = res_gen.json()
    assert len(version_data["variants"]) == 3

    # 4. Simulate page refresh / project reopening: Call GET /api/v1/projects/{proj_id}
    res_reload = client.get(f"/api/v1/projects/{proj_id}", headers=headers)
    assert res_reload.status_code == 200
    reloaded_proj = res_reload.json()

    # Verify rooms are hydrated and not null/empty
    assert "rooms" in reloaded_proj
    assert reloaded_proj["rooms"] is not None
    assert len(reloaded_proj["rooms"]) >= 1

    reloaded_room = reloaded_proj["rooms"][0]
    assert reloaded_room["id"] == room_id
    assert reloaded_room["original_image_url"] is not None
    assert len(reloaded_room["versions"]) >= 1
    assert len(reloaded_room["versions"][0]["variants"]) == 3


def test_intent_based_redesigns_consumer_choices():
    """
    Verifies that all 6 plain-language consumer intents produce 3 distinct variants
    with Concept A, Concept B, Concept C titles and honest descriptions.
    """
    # Upload fresh room
    raw_img = create_synthetic_room_photo()
    files = {"file": ("intent_test.jpg", raw_img, "image/jpeg")}
    res_up = client.post("/api/v1/rooms/upload-and-analyze", files=files, data={"room_name": "Consumer Intent Test"})
    assert res_up.status_code == 200
    room_id = res_up.json()["id"]
    guest_token = res_up.headers.get("X-Guest-Token")
    headers = {"X-Guest-Token": guest_token} if guest_token else {}

    intents = [
        "Empty & Redesign",
        "Home Office",
        "Cozy Lounge / Reading Corner",
        "Guest Nook",
        "Storage + Workspace",
        "Surprise Me",
    ]

    for intent in intents:
        gen_payload = {
            "styles": [intent],
            "goals": ["modernize"],
            "budget_amount": 15000,
            "budget_currency": "MYR",
            "free_text_prompt": f"Transform into {intent}",
            "generation_mode": "algorithmic_preview",
        }
        res_gen = client.post(f"/api/v1/rooms/{room_id}/design-requests", json=gen_payload, headers=headers)
        assert res_gen.status_code == 200
        variants = res_gen.json()["variants"]
        assert len(variants) == 3

        # Check Concept A, B, C titles
        assert variants[0]["title"].startswith("Concept A:")
        assert variants[1]["title"].startswith("Concept B:")
        assert variants[2]["title"].startswith("Concept C:")

        # Check honest description disclosure
        for v in variants:
            assert "Algorithmic Concept Preview" in v["description"]
            assert v["image_url"] is not None
            assert "/storage/outputs/" in v["image_url"]
            assert v["structural_preservation_score"] >= 0.85


def test_signed_media_resolution_end_to_end():
    """
    Verifies that the original room photo and variant output images return HTTP 200
    when accessed via their signed URLs (preventing blank image rendering in the browser).
    """
    raw_img = create_synthetic_room_photo()
    files = {"file": ("media_test.jpg", raw_img, "image/jpeg")}
    res_up = client.post("/api/v1/rooms/upload-and-analyze", files=files)
    assert res_up.status_code == 200
    room_id = res_up.json()["id"]
    orig_url = res_up.json()["original_image_url"]
    guest_token = res_up.headers.get("X-Guest-Token")
    headers = {"X-Guest-Token": guest_token} if guest_token else {}

    # 1. Fetch original room photo via signed URL
    res_img = client.get(orig_url)
    assert res_img.status_code == 200
    assert len(res_img.content) > 0
    assert res_img.headers["content-type"] in ("image/jpeg", "image/png", "application/octet-stream")

    # 2. Generate designs
    gen_payload = {
        "styles": ["Empty & Redesign"],
        "generation_mode": "algorithmic_preview",
    }
    res_gen = client.post(f"/api/v1/rooms/{room_id}/design-requests", json=gen_payload, headers=headers)
    assert res_gen.status_code == 200
    variants = res_gen.json()["variants"]

    # 3. Fetch each variant redesign image via signed URL
    for v in variants:
        v_url = v["image_url"]
        res_v = client.get(v_url)
        assert res_v.status_code == 200
        assert len(res_v.content) > 0


def test_unconfigured_ai_inpainting_fails_closed():
    """
    Financial and security gate test:
    When ai_inpainting is requested and no external provider token is configured,
    the API must return HTTP 503 PROVIDER_UNCONFIGURED and NOT secretly fabricate output.
    """
    raw_img = create_synthetic_room_photo()
    files = {"file": ("unconf_test.jpg", raw_img, "image/jpeg")}
    res_up = client.post("/api/v1/rooms/upload-and-analyze", files=files)
    assert res_up.status_code == 200
    room_id = res_up.json()["id"]
    guest_token = res_up.headers.get("X-Guest-Token")
    headers = {"X-Guest-Token": guest_token} if guest_token else {}

    # Ensure REPLICATE_API_TOKEN is empty and TEST_MOCK_DIFFUSION is not set
    old_token = os.environ.get("REPLICATE_API_TOKEN")
    old_mock = os.environ.get("TEST_MOCK_DIFFUSION")
    try:
        os.environ["REPLICATE_API_TOKEN"] = ""
        os.environ.pop("TEST_MOCK_DIFFUSION", None)

        gen_payload = {
            "styles": ["Warm Modern Minimalist"],
            "generation_mode": "ai_inpainting",
        }
        res_gen = client.post(f"/api/v1/rooms/{room_id}/design-requests", json=gen_payload, headers=headers)
        assert res_gen.status_code == 503
        detail = res_gen.json().get("detail", {})
        assert detail.get("error_code") == "PROVIDER_UNCONFIGURED"
        assert detail.get("suggested_mode") == "algorithmic_preview"
    finally:
        if old_token:
            os.environ["REPLICATE_API_TOKEN"] = old_token
        if old_mock:
            os.environ["TEST_MOCK_DIFFUSION"] = old_mock
