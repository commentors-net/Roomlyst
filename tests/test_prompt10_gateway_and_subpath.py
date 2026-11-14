"""
Roomlyst Prompt 10 Verification Suite:
Multi-Application LAN Gateway, Subpath Proxy Routing,
Header Preservation, Media URL Signing, and Isolation.
"""

import io
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from services.api.app.main import app
from services.api.app.core.config import settings
from services.api.app.core.security import (
    create_guest_token,
    decode_guest_token,
)
from services.api.app.storage.local import LocalStorageProvider


@pytest.fixture
def client():
    return TestClient(app)


def create_test_image_bytes():
    buf = io.BytesIO()
    img = Image.new("RGB", (320, 240), color=(140, 160, 190))
    img.save(buf, format="JPEG")
    buf.seek(0)
    return buf.getvalue()


class TestPrompt10SubpathAndProxyRouting:
    """Verifies gateway proxy headers and subpath routing behavior."""

    def test_direct_root_serves_html(self, client):
        """Root GET / must serve the HTML homeowner web application."""
        res = client.get("/")
        assert res.status_code == 200
        assert "text/html" in res.headers.get("content-type", "")
        assert "Roomlyst" in res.text
        assert "API_BASE" in res.text

    def test_proxied_request_with_forwarded_prefix(self, client):
        """Request arriving with X-Forwarded-Prefix: /roomlyst is handled cleanly."""
        headers = {
            "X-Forwarded-Prefix": "/roomlyst",
            "X-Forwarded-Proto": "http",
            "X-Forwarded-For": "192.168.0.12",
        }
        res = client.get("/health", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "healthy"

    def test_proxied_api_status_call(self, client):
        """API endpoints work under proxy forwarding headers."""
        headers = {"X-Forwarded-Prefix": "/roomlyst"}
        res = client.get("/api/v1/ai/status", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert "providers" in data
        assert "ollama" in data["providers"]

    def test_ui_mount_preserves_subpath_index(self, client):
        """GET /ui/ provides fallback access."""
        res = client.get("/ui/")
        assert res.status_code == 200
        assert "Roomlyst" in res.text


class TestPrompt10SignedMediaAndSecurity:
    """Verifies signed media tokens, signature verification, and secret safety."""

    def test_secret_key_is_not_empty_or_default(self):
        """SECRET_KEY must be a valid, non-trivial string."""
        assert len(settings.SECRET_KEY) >= 16
        # Must not be an unconfigured placeholder
        assert settings.SECRET_KEY != "CHANGEME"
        assert settings.SECRET_KEY != "placeholder"

    def test_media_url_signature_generation(self, tmp_path):
        """Media URL signing and expiration query parameters."""
        storage = LocalStorageProvider(base_dir=str(tmp_path), secret_key=settings.SECRET_KEY)
        test_key = "uploads/room_test_10.jpg"
        signed_url = storage.get_signed_url(test_key, expires_in=300)
        assert "/storage/" in signed_url
        assert "sig=" in signed_url
        assert "exp=" in signed_url

    def test_guest_token_cross_tenant_isolation(self, client):
        """Tokens issued for one guest cannot access projects belonging to another guest."""
        token_guest_a = create_guest_token("usr_guest_alpha")
        token_guest_b = create_guest_token("usr_guest_beta")

        # Guest A creates project
        res_a = client.post(
            "/api/v1/projects",
            json={"name": "Alpha Living Room", "currency": "MYR"},
            headers={"X-Guest-Token": token_guest_a},
        )
        assert res_a.status_code == 200
        proj_a_id = res_a.json()["id"]

        # Guest B cannot see Guest A project in their listing
        res_b = client.get("/api/v1/projects", headers={"X-Guest-Token": token_guest_b})
        assert res_b.status_code == 200
        b_ids = [p["id"] for p in res_b.json()]
        assert proj_a_id not in b_ids


class TestPrompt10EndToEndHomeownerFlow:
    """Verifies complete homeowner flow through API endpoints."""

    def test_complete_room_redesign_cycle(self, client):
        guest_token = create_guest_token("usr_guest_p10_full")
        headers = {"X-Guest-Token": guest_token}

        # 1. Project Creation
        res = client.post("/api/v1/projects", json={"name": "P10 Suite Project", "currency": "MYR"}, headers=headers)
        assert res.status_code == 200
        proj_id = res.json()["id"]

        # 2. Upload synthetic room
        img_bytes = create_test_image_bytes()
        files = {"file": ("p10_room.jpg", img_bytes, "image/jpeg")}
        data = {"room_name": "P10 Suite Room", "project_id": proj_id}
        upload_res = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data, headers=headers)
        assert upload_res.status_code == 200
        room = upload_res.json()
        room_id = room["id"]
        assert room["original_image_url"] is not None

        # 3. Patch element
        elements = (room.get("objects") or []) + (room.get("surfaces") or [])
        assert len(elements) > 0
        elem_id = elements[0]["id"]
        patch_res = client.patch(
            f"/api/v1/rooms/{room_id}/elements/{elem_id}",
            json={"action": "REPLACE"},
            headers=headers,
        )
        assert patch_res.status_code == 200
        assert patch_res.json()["action"] == "REPLACE"

        # 4. Generate 3 Algorithmic Variants
        gen_res = client.post(
            f"/api/v1/rooms/{room_id}/design-requests",
            json={
                "styles": ["Scandinavian Light"],
                "goals": ["brighten"],
                "budget_amount": 9000.0,
                "budget_currency": "MYR",
                "generation_mode": "algorithmic_preview",
            },
            headers=headers,
        )
        assert gen_res.status_code == 200
        variants = gen_res.json()["variants"]
        assert len(variants) == 3

        # 5. Favorite variant
        var_id = variants[0].get("variant_id") or variants[0].get("id")
        fav_res = client.post(
            f"/api/v1/rooms/{room_id}/variants/{var_id}/favorite",
            json={"is_favorite": True},
            headers=headers,
        )
        assert fav_res.status_code == 200
        assert fav_res.json()["is_favorite"] is True

        # 6. List favorites
        fav_list = client.get(f"/api/v1/rooms/{room_id}/favorites", headers=headers)
        assert fav_list.status_code == 200
        assert len(fav_list.json()) >= 1
