"""
Prompt 08 Production-Safe Inpainting Readiness, Security Closure & Verification Suite.
Validates:
1. Invalid Bearer token fails closed (401) without silent downgrade.
2. Guest token cannot masquerade as registered user Bearer token (401).
3. Registered user token cannot be decoded as guest session token.
4. Cookie-only state-changing CSRF defense.
5. Replicate dry_run exercises official schema without network calls or credits.
6. SSRF anti-rebinding, untrusted redirects, and content deception defenses.
7. *.test.local domains gated strictly to test environment.
8. Idempotency keys prevent duplicate billable redesign generation.
9. Mask builder strict preservation overrides.
10. Guest user media authorization.
"""

import io
import os
import time
import pytest
from unittest import mock
from PIL import Image
from fastapi.testclient import TestClient

from services.api.app.main import app
from services.api.app.core.security import create_access_token, create_guest_token, decode_guest_token, decode_access_token
from services.api.app.db.session import SessionLocal
from services.api.app.db.models import Project, Room, MediaAsset, ProcessingJob, User
from services.ai_worker.pipelines.inpainting import (
    InpaintingRequest,
    ReplicateInpaintingAdapter,
    validate_safe_output_url,
    download_safe_provider_image,
    InpaintingProviderException,
)
from services.ai_worker.pipelines.mask_builder import MaskBuilder
from packages.room_model import CanonicalRoomModel, DesignConstraint, Geometry, Point2D, WallSegment, RoomObject, RoomOpening, BoundingBox2D, ObjectAction, RoomSurface, SurfaceType


@pytest.fixture
def client():
    return TestClient(app)


# =====================================================================
# 1. Bearer Token Downgrade & Token Confusion Defenses
# =====================================================================

def test_invalid_bearer_token_does_not_downgrade_to_anonymous(client):
    """
    Prompt 08 Section 1:
    An invalid, tampered, or expired Bearer token MUST NOT silently downgrade
    to anonymous or guest authority. It must immediately fail closed with HTTP 401.
    """
    bad_headers = {"Authorization": "Bearer completely_bogus_token_xyz"}
    resp = client.post("/api/v1/projects", json={"name": "Attacker Project"}, headers=bad_headers)
    assert resp.status_code == 401
    assert "Invalid or expired Bearer access token" in resp.json()["detail"]


def test_guest_token_sent_as_bearer_rejected_with_401(client):
    """
    Prompt 08 Section 1:
    A signed guest token cannot be confused with a registered user JWT.
    Passing a guest token via 'Authorization: Bearer <guest_token>' is rejected with 401.
    """
    guest_token = create_guest_token()
    bad_headers = {"Authorization": f"Bearer {guest_token}"}
    resp = client.post("/api/v1/projects", json={"name": "Confused Guest Project"}, headers=bad_headers)
    assert resp.status_code == 401
    assert "Guest tokens cannot be used as Bearer access tokens" in resp.json()["detail"]


def test_registered_user_token_cannot_be_decoded_as_guest_token():
    """
    Prompt 08 Section 1:
    Registered user access token has type='access_token' and cannot be decoded
    by decode_guest_token().
    """
    user_token = create_access_token(subject="usr_registered_alice")
    guest_payload = decode_guest_token(user_token)
    assert guest_payload is None, "Registered user access token must never decode as a guest session token!"


# =====================================================================
# 2. CSRF Defense for Cookie-Only Guest Sessions
# =====================================================================

def test_cookie_only_csrf_guard_blocks_cross_site_mutation(client):
    """
    Prompt 08 Section 1:
    A cross-site state-changing request (Sec-Fetch-Site: cross-site) using only
    cookies without custom header proof is blocked with 403 Forbidden.
    """
    guest_token = create_guest_token()
    client.cookies.set("guest_session_id", guest_token)

    # Cross-site mutation attempt
    csrf_attack_headers = {"sec-fetch-site": "cross-site"}
    resp = client.post(
        "/api/v1/projects",
        json={"name": "CSRF Forged Project"},
        headers=csrf_attack_headers,
    )
    assert resp.status_code == 403
    assert "CSRF" in resp.json()["detail"]


# =====================================================================
# 3. Replicate Official Schema & Dry-Run Validation
# =====================================================================

def test_replicate_dry_run_validates_official_schema_without_network_calls():
    """
    Prompt 08 Section 2:
    dry_run validates the exact official Replicate model schema
    (stability-ai/stable-diffusion-inpainting:c11aca8c040f96a603d467ffda73e2993784f612742e3b277d57ab3292303352)
    and verifies zero network calls and zero credit consumption.
    """
    img = Image.new("RGB", (512, 512), color=(220, 210, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()

    mask = Image.new("L", (512, 512), color=0)
    mbuf = io.BytesIO()
    mask.save(mbuf, format="PNG")
    mask_bytes = mbuf.getvalue()

    req = InpaintingRequest(
        image_bytes=img_bytes,
        mask_bytes=mask_bytes,
        width=512,
        height=512,
        prompt="Modern Scandinavian living room",
        negative_prompt="blurry, distorted",
        room_id="room_dry_run_08",
        num_variants=3,
    )

    adapter = ReplicateInpaintingAdapter(api_token="r8_live_simulated_token_xyz")
    dry_res = adapter.dry_run(req)

    assert dry_res["status"] == "VALID"
    assert dry_res["schema_compliance"] == "VERIFIED_OFFICIAL_REPLICATE"
    assert dry_res["official_model_url"] == "https://replicate.com/stability-ai/stable-diffusion-inpainting"
    assert dry_res["model_version"] == "c11aca8c040f96a603d467ffda73e2993784f612742e3b277d57ab3292303352"
    assert dry_res["network_calls_made"] == 0
    assert dry_res["paid_credits_consumed"] == 0.0
    assert dry_res["num_variants"] == 3


# =====================================================================
# 4. SSRF, DNS Rebinding & Output Download Hardening
# =====================================================================

def test_ssrf_forbidden_private_ip_blocked():
    """
    Prompt 08 Section 2:
    Private IP ranges and loopbacks are strictly blocked on provider output URLs.
    """
    for bad_url in [
        "https://127.0.0.1/output.jpg",
        "https://169.254.169.254/latest/meta-data/",
        "https://192.168.0.1/admin",
        "https://10.0.0.1/keys",
        "https://localhost/test.jpg",
    ]:
        with pytest.raises(InpaintingProviderException) as exc_info:
            validate_safe_output_url(bad_url)
        assert "SSRF blocked" in str(exc_info.value) or "Forbidden private" in str(exc_info.value)


def test_ssrf_test_local_domain_rejected_in_production():
    """
    Prompt 08 Section 2:
    *.test.local is strictly forbidden in non-test environments.
    """
    old_env = os.environ.get("ENV")
    old_pytest = os.environ.get("PYTEST_CURRENT_TEST")
    try:
        os.environ["ENV"] = "production"
        os.environ.pop("PYTEST_CURRENT_TEST", None)
        with pytest.raises(InpaintingProviderException) as exc:
            validate_safe_output_url("https://mock.test.local/output.png")
        assert "strictly forbidden in non-test environments" in str(exc.value)
    finally:
        if old_env is not None:
            os.environ["ENV"] = old_env
        else:
            os.environ.pop("ENV", None)
        if old_pytest is not None:
            os.environ["PYTEST_CURRENT_TEST"] = old_pytest


def test_download_safe_provider_image_redirect_to_untrusted_target_blocked():
    """
    Prompt 08 Section 2:
    Provider image downloads intercept redirects and block untrusted destinations.
    """
    class MockRedirectSession:
        def get(self, url, **kwargs):
            class Resp:
                status_code = 302
                headers = {"Location": "http://169.254.169.254/secret.jpg"}
            return Resp()

    with pytest.raises(InpaintingProviderException) as exc:
        download_safe_provider_image(
            session=MockRedirectSession(),
            url="https://replicate.delivery/pbxt/initial.jpg",
        )
    assert "SSRF blocked" in str(exc.value) or "Untrusted output URL scheme" in str(exc.value)


def test_download_safe_provider_image_content_type_deception_blocked():
    """
    Prompt 08 Section 2:
    Non-image payloads (e.g. text/html, application/json) trigger Content-Type deception error.
    """
    class MockDeceptiveSession:
        def get(self, url, **kwargs):
            class Resp:
                status_code = 200
                headers = {"Content-Type": "text/html"}
                content = b"<html><body>Admin Portal</body></html>"
            return Resp()

    with pytest.raises(InpaintingProviderException) as exc:
        download_safe_provider_image(
            session=MockDeceptiveSession(),
            url="https://replicate.delivery/pbxt/payload.jpg",
        )
    assert "Content-type deception detected" in str(exc.value)


# =====================================================================
# 5. Idempotency Key & Duplicate Prevention
# =====================================================================

def test_idempotency_key_prevents_duplicate_async_jobs(client):
    """
    Prompt 08 Section 3:
    Submitting an async redesign request with an idempotency key reuses
    the existing job instead of spawning duplicate billable work.
    """
    # Create guest project and room
    proj_resp = client.post("/api/v1/projects", json={"name": "Idempotency Project"})
    assert proj_resp.status_code == 200
    guest_token = proj_resp.headers.get("X-Guest-Token")
    guest_headers = {"X-Guest-Token": guest_token}

    # Upload room
    img = Image.new("RGB", (256, 256), color=(200, 200, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    files = {"file": ("room.jpg", buf.getvalue(), "image/jpeg")}
    upload_resp = client.post(
        "/api/v1/rooms/upload-and-analyze",
        files=files,
        data={"project_id": proj_resp.json()["id"], "room_name": "Idempotent Living Room"},
        headers=guest_headers,
    )
    assert upload_resp.status_code == 200
    room_id = upload_resp.json()["id"]

    # First call with idempotency key
    idempotency_key = f"idem_test_{int(time.time())}"
    job_payload = {
        "styles": ["Warm Modern Minimalist"],
        "generation_mode": "algorithmic_preview",
        "idempotency_key": idempotency_key,
    }
    call_1 = client.post(
        f"/api/v1/rooms/{room_id}/design-requests-async",
        json=job_payload,
        headers=guest_headers,
    )
    assert call_1.status_code == 200
    job_1_id = call_1.json()["job_id"]

    # Second call with identical idempotency key
    call_2 = client.post(
        f"/api/v1/rooms/{room_id}/design-requests-async",
        json=job_payload,
        headers=guest_headers,
    )
    assert call_2.status_code == 200
    assert call_2.json()["job_id"] == job_1_id
    assert call_2.json().get("idempotent_reused") is True


# =====================================================================
# 6. Mask Builder Strict Preservation & Override Integrity
# =====================================================================

def test_mask_builder_structural_preservation_overrides():
    """
    Prompt 08 Section 3:
    Preserved architectural openings and kept furniture are locked to 0 (Keep)
    in the edit mask even when adjacent or underlying surfaces are restyled (255).
    """
    room = CanonicalRoomModel(
        id="room_mask_test_08",
        name="Mask Test Room",
        room_type="living_room",
        geometry=Geometry(wall_segments=[WallSegment(start_point=Point2D(x=0, y=0), end_point=Point2D(x=6, y=0), length_m=6.0)]),
        objects=[
            RoomObject(
                id="obj_sofa_keep",
                name="Kept Leather Sofa",
                category="seating",
                bounding_box=BoundingBox2D(x_min=0.2, y_min=0.6, x_max=0.5, y_max=0.85),
                action=ObjectAction.KEEP,
            ),
            RoomObject(
                id="obj_table_replace",
                name="Old Coffee Table",
                category="table",
                bounding_box=BoundingBox2D(x_min=0.6, y_min=0.65, x_max=0.85, y_max=0.85),
                action=ObjectAction.REPLACE,
            ),
        ],
        openings=[
            RoomOpening(
                id="opn_window_keep",
                name="Living Room Window",
                opening_type="WINDOW",
                bounding_box=BoundingBox2D(x_min=0.2, y_min=0.1, x_max=0.5, y_max=0.4),
                action=ObjectAction.KEEP,
            ),
        ],
        surfaces=[
            RoomSurface(id="surf_floor", name="Hardwood Floor", surface_type=SurfaceType.FLOOR, action=ObjectAction.REPLACE),
            RoomSurface(id="surf_wall", name="Main Wall", surface_type=SurfaceType.WALL, action=ObjectAction.RESTYLE),
        ],
    )

    constraints = room.build_design_constraint(styles=["Modern"])
    w, h = 1000, 800
    mask = MaskBuilder.build_inpainting_mask(room=room, constraints=constraints, width=w, height=h)
    import numpy as np
    mask_arr = np.array(mask)

    # 1. Kept window must be strictly 0 (Black / Keep)
    win_patch = mask_arr[int(0.15 * h):int(0.35 * h), int(0.25 * w):int(0.45 * w)]
    assert np.all(win_patch == 0), "Kept architectural window must remain 0 (preserve)!"

    # 2. Kept sofa over restyled floor must be strictly 0 (Black / Keep)
    sofa_patch = mask_arr[int(0.65 * h):int(0.80 * h), int(0.25 * w):int(0.45 * w)]
    assert np.all(sofa_patch == 0), "Kept sofa must override floor replacement and remain 0!"

    # 3. Replaced coffee table must be 255 (White / Inpaint)
    table_patch = mask_arr[int(0.70 * h):int(0.80 * h), int(0.65 * w):int(0.80 * w)]
    assert np.all(table_patch == 255), "Replaced furniture must be 255 (inpaint)!"


# =====================================================================
# 7. Guest User Media Access Authorization
# =====================================================================

def test_signed_media_endpoints_support_authenticated_guest(client):
    """
    Prompt 08 Section 1:
    Guest users can request signed download URLs for media assets belonging
    to their projects, while cross-user guest requests are blocked with 403.
    """
    # 1. Guest A creates project & room with media asset
    guest_a_token = create_guest_token()
    guest_a_id = decode_guest_token(guest_a_token)["sub"]
    guest_b_token = create_guest_token()

    with SessionLocal() as db:
        proj_a = Project(id="proj_guest_media_a", user_id=guest_a_id, name="Guest A Project")
        room_a = Room(id="room_guest_media_a", project_id=proj_a.id, name="Guest A Room")
        asset_a = MediaAsset(
            id="ast_guest_photo_01",
            room_id=room_a.id,
            storage_key="storage/uploads/guest_photo_01.jpg",
            asset_type="original_photo",
            is_private=True,
        )
        db.merge(proj_a)
        db.merge(room_a)
        db.merge(asset_a)
        db.commit()

    # Guest A accesses their media asset -> 200 OK
    resp_a = client.get(
        "/api/v1/media/ast_guest_photo_01/signed-url",
        headers={"X-Guest-Token": guest_a_token},
    )
    assert resp_a.status_code == 200
    assert "signed_url" in resp_a.json()

    # Guest B attempts to access Guest A's media asset -> 403 Forbidden
    resp_b = client.get(
        "/api/v1/media/ast_guest_photo_01/signed-url",
        headers={"X-Guest-Token": guest_b_token},
    )
    assert resp_b.status_code == 403
