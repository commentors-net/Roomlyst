"""
Roomlyst Prompt 09 Verification Suite:
Web Application, Guest Session Continuity, Media Protection,
Algorithmic vs Inpainting Modes, Variant Favoriting, and Ollama Integration.
"""

import io
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from services.api.app.main import app
from services.api.app.core.security import create_guest_token, decode_guest_token
from services.api.app.db.repository import repository


@pytest.fixture
def client():
    return TestClient(app)


def create_test_image_bytes():
    buf = io.BytesIO()
    img = Image.new("RGB", (320, 240), color=(180, 150, 120))
    img.save(buf, format="JPEG")
    buf.seek(0)
    return buf.getvalue()


class TestPrompt09WebUI:
    """Verifies Workstream B web application serving and static assets."""

    def test_root_serves_homeowner_web_ui(self, client):
        """Root GET / must serve the HTML homeowner web application."""
        res = client.get("/")
        assert res.status_code == 200
        assert "text/html" in res.headers.get("content-type", "")
        assert "Roomlyst" in res.text
        assert "Structure-Preserving" in res.text
        assert "Algorithmic Concept Preview" in res.text
        assert "AI Inpainting" in res.text

    def test_ui_mount_serves_index(self, client):
        """GET /ui/ must also serve the web UI."""
        res = client.get("/ui/")
        assert res.status_code == 200
        assert "text/html" in res.headers.get("content-type", "")
        assert "Roomlyst" in res.text

    def test_health_check_returns_healthy(self, client):
        """GET /health must return healthy status and phase info."""
        res = client.get("/health")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "healthy"
        assert data["service"] == "roomlyst-api"


class TestPrompt09GuestSessionAndProjects:
    """Verifies guest token issuance, project isolation, and session continuity."""

    def test_create_project_issues_guest_token(self, client):
        """Anonymous project creation must issue server-signed guest token in headers and cookies."""
        res = client.post("/api/v1/projects", json={"name": "P09 Guest Project", "currency": "MYR"})
        assert res.status_code == 200
        data = res.json()
        assert data["name"] == "P09 Guest Project"

        # Check token headers
        guest_token = res.headers.get("X-Guest-Token")
        assert guest_token is not None
        payload = decode_guest_token(guest_token)
        assert payload is not None
        assert payload["sub"].startswith("usr_guest_")

        # Check cookie
        assert "guest_session_id" in res.cookies

    def test_guest_project_isolation(self, client):
        """Two different guests must not see each other's projects."""
        guest_token_1 = create_guest_token("usr_guest_alice_123")
        guest_token_2 = create_guest_token("usr_guest_bob_456")

        # Alice creates a project
        res1 = client.post(
            "/api/v1/projects",
            json={"name": "Alice Living Room", "currency": "MYR"},
            headers={"X-Guest-Token": guest_token_1},
        )
        assert res1.status_code == 200
        alice_proj_id = res1.json()["id"]

        # Alice lists projects -> sees Alice's project
        list_alice = client.get("/api/v1/projects", headers={"X-Guest-Token": guest_token_1})
        assert list_alice.status_code == 200
        alice_ids = [p["id"] for p in list_alice.json()]
        assert alice_proj_id in alice_ids

        # Bob lists projects -> cannot see Alice's project
        list_bob = client.get("/api/v1/projects", headers={"X-Guest-Token": guest_token_2})
        assert list_bob.status_code == 200
        bob_ids = [p["id"] for p in list_bob.json()]
        assert alice_proj_id not in bob_ids


class TestPrompt09RedesignWorkflow:
    """Verifies end-to-end homeowner flow: upload, element actions, generation modes, and favoriting."""

    def test_upload_and_analyze_with_guest_token(self, client):
        """Photo upload creates room model with signed media URL."""
        guest_token = create_guest_token("usr_guest_flow_test")
        img_bytes = create_test_image_bytes()

        files = {"file": ("room.jpg", img_bytes, "image/jpeg")}
        data = {"room_name": "Living Room Test", "platform": "rgb", "has_lidar": "false"}

        res = client.post(
            "/api/v1/rooms/upload-and-analyze",
            files=files,
            data=data,
            headers={"X-Guest-Token": guest_token},
        )
        assert res.status_code == 200
        room = res.json()
        assert "id" in room
        assert room["name"] == "Living Room Test"
        assert room["original_image_url"] is not None
        assert "sig=" in room["original_image_url"]

        # Test element action update
        assert len(room["objects"]) > 0 or len(room["surfaces"]) > 0
        target_elem = (room["objects"] or room["surfaces"])[0]
        elem_id = target_elem["id"]

        patch_res = client.patch(
            f"/api/v1/rooms/{room['id']}/elements/{elem_id}",
            json={"action": "REPLACE"},
            headers={"X-Guest-Token": guest_token},
        )
        assert patch_res.status_code == 200
        assert patch_res.json()["action"] == "REPLACE"

        # Test Algorithmic Concept Preview generation
        gen_res = client.post(
            f"/api/v1/rooms/{room['id']}/design-requests",
            json={
                "styles": ["Warm Modern Minimalist"],
                "goals": ["modernize"],
                "budget_amount": 12000.0,
                "budget_currency": "MYR",
                "free_text_prompt": "Keep windows, warm wood tones",
                "generation_mode": "algorithmic_preview",
            },
            headers={"X-Guest-Token": guest_token},
        )
        assert gen_res.status_code == 200
        version_data = gen_res.json()
        variants = version_data["variants"]
        assert len(variants) == 3

        # Verify each variant has signed image URL and preservation score
        for v in variants:
            assert "image_url" in v
            assert v["structural_preservation_score"] > 0.0
            assert "changes_made" in v

        # Test Favoriting a variant
        var_to_fav = variants[0].get("variant_id") or variants[0].get("id")
        fav_res = client.post(
            f"/api/v1/rooms/{room['id']}/variants/{var_to_fav}/favorite",
            json={"is_favorite": True},
            headers={"X-Guest-Token": guest_token},
        )
        assert fav_res.status_code == 200
        assert fav_res.json()["is_favorite"] is True

        # Test Listing Favorites
        list_favs = client.get(
            f"/api/v1/rooms/{room['id']}/favorites",
            headers={"X-Guest-Token": guest_token},
        )
        assert list_favs.status_code == 200
        fav_items = list_favs.json()
        fav_ids = [fv.get("variant", {}).get("variant_id") or fv.get("variant_id") for fv in fav_items]
        assert var_to_fav in fav_ids

    def test_inpainting_mode_without_token_returns_503(self, client):
        """When inpainting provider is unconfigured, requesting ai_inpainting returns 503 with suggestion."""
        guest_token = create_guest_token("usr_guest_inpaint_test")
        img_bytes = create_test_image_bytes()

        res = client.post(
            "/api/v1/rooms/upload-and-analyze",
            files={"file": ("test.jpg", img_bytes, "image/jpeg")},
            data={"room_name": "Inpaint Test Room"},
            headers={"X-Guest-Token": guest_token},
        )
        assert res.status_code == 200
        room_id = res.json()["id"]

        inpaint_res = client.post(
            f"/api/v1/rooms/{room_id}/design-requests",
            json={
                "styles": ["Modern Industrial"],
                "generation_mode": "ai_inpainting",
            },
            headers={"X-Guest-Token": guest_token},
        )
        # Should return 503 SERVICE UNAVAILABLE with structured recovery advice
        assert inpaint_res.status_code == 503
        err = inpaint_res.json()["detail"]
        assert err["error_code"] == "PROVIDER_UNCONFIGURED"
        assert err["suggested_mode"] == "algorithmic_preview"


class TestPrompt09AIEvaluation:
    """Verifies AI status endpoint and Ollama design evaluation route."""

    def test_ai_status_endpoint(self, client):
        """GET /api/v1/ai/status reports active default and provider availability."""
        res = client.get("/api/v1/ai/status")
        assert res.status_code == 200
        data = res.json()
        assert "active_default" in data
        assert "providers" in data
        assert "ollama" in data["providers"]
