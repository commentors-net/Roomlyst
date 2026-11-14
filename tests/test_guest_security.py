"""
tests/test_guest_security.py
============================
Comprehensive test suite fulfilling Roomlyst Prompt 07:
- Guest identity security and server-issued cryptographic token verification.
- Adversarial tests: forged guest ID, tampered token, expired token, conflicting headers.
- Route authorization coverage: cross-user rooms, element mutations, background jobs, media.
- Guest session persistence across app restart.
- Secure guest-to-account migration workflow.
- Legacy 'usr_default' record protection.
- Replicate inpainting adapter dry-run validation (zero network calls, zero paid credits).
- Provider SSRF prevention on returned output URLs.
- Truthful mock diffusion sandbox provenance.
"""

from datetime import datetime, timedelta, timezone
import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient

from services.ai_worker.pipelines.inpainting import (
    InpaintingProviderException,
    InpaintingRequest,
    MockInpaintingProvider,
    ReplicateInpaintingAdapter,
    run_inpainting_pipeline,
)
from services.api.app.core.security import (
    create_access_token,
    create_guest_token,
    decode_guest_token,
    hash_password,
)
from services.api.app.db.models import Project, Room, MediaAsset, ProcessingJob, User
from services.api.app.db.repository import repository, ProjectRecord
from services.api.app.db.session import SessionLocal
from services.api.app.main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def user_alice():
    user_id = "usr_alice_owner"
    with SessionLocal() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            user = User(
                id=user_id,
                email="alice_p07@roomlyst.com",
                hashed_password=hash_password("PasswordAlice123!"),
                role="homeowner",
                is_active=True,
            )
            db.add(user)
            db.commit()
    token = create_access_token(subject=user_id, claims={"role": "homeowner", "email": "alice_p07@roomlyst.com"})
    return {"id": user_id, "token": token, "headers": {"Authorization": f"Bearer {token}"}}


@pytest.fixture
def user_bob():
    user_id = "usr_bob_intruder"
    with SessionLocal() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            user = User(
                id=user_id,
                email="bob_p07@roomlyst.com",
                hashed_password=hash_password("PasswordBob123!"),
                role="homeowner",
                is_active=True,
            )
            db.add(user)
            db.commit()
    token = create_access_token(subject=user_id, claims={"role": "homeowner", "email": "bob_p07@roomlyst.com"})
    return {"id": user_id, "token": token, "headers": {"Authorization": f"Bearer {token}"}}


# =====================================================================
# 1. Server-Issued Cryptographic Guest Credentials
# =====================================================================

def test_unauthenticated_create_issues_cryptographically_signed_token(client):
    """
    Prompt 07 Section A.1-2:
    Anonymous project creation must issue a server-signed guest token with expiration
    and secure cookie flags, never an unpredictable or unauthenticated raw UUID.
    """
    resp = client.post("/api/v1/projects", json={"name": "Signed Guest Living Room"})
    assert resp.status_code == 200
    proj_data = resp.json()
    proj_id = proj_data["id"]

    # Verify server issued a signed guest token
    assert "X-Guest-Token" in resp.headers or "X-Guest-Session-ID" in resp.headers
    guest_token = resp.headers.get("X-Guest-Token") or resp.headers.get("X-Guest-Session-ID")
    assert guest_token is not None

    # Cryptographically verify the token
    payload = decode_guest_token(guest_token)
    assert payload is not None, "Issued token failed cryptographic signature verification!"
    assert payload["sub"].startswith("usr_guest_")
    assert payload["type"] == "guest_session"
    assert payload["role"] == "guest"
    assert "exp" in payload

    # Verify project in DB was bound to this verified guest ID
    with SessionLocal() as db:
        db_proj = db.query(Project).filter(Project.id == proj_id).first()
        assert db_proj.user_id == payload["sub"]


def test_forged_guest_identifier_fails_closed(client):
    """
    Prompt 07 Section A.1 & A.5:
    Attacker sending an arbitrary unauthenticated string or victim UUID in X-Guest-Session-ID
    is rejected and fails closed to anonymous (zero project leakage, cannot access victim's project).
    """
    # 1. Legitimate guest creates a project
    client_legit = TestClient(app)
    create_resp = client_legit.post("/api/v1/projects", json={"name": "Legitimate Guest Project"})
    assert create_resp.status_code == 200
    victim_proj_id = create_resp.json()["id"]
    victim_user_id = create_resp.json()["user_id"]
    assert victim_user_id.startswith("usr_guest_")

    # 2. Attacker crafts request with raw forged guest ID in header (not cryptographically signed)
    client_attacker = TestClient(app)
    forged_headers = {"X-Guest-Session-ID": victim_user_id}

    # Attacker lists projects -> must receive empty list []
    list_resp = client_attacker.get("/api/v1/projects", headers=forged_headers)
    assert list_resp.status_code == 200
    assert list_resp.json() == [], "VULNERABILITY: Attacker listed victim's projects using forged raw ID!"

    # Attacker attempts to read victim's project -> must receive 401 or 403
    get_resp = client_attacker.get(f"/api/v1/projects/{victim_proj_id}", headers=forged_headers)
    assert get_resp.status_code in (401, 403), "VULNERABILITY: Attacker accessed victim's project using forged raw ID!"


def test_tampered_guest_token_fails_closed(client):
    """
    Attacker tampering with the signature or payload of a valid guest token is rejected.
    """
    # Obtain valid token
    valid_token = create_guest_token()
    # Tamper with the last 8 characters of signature
    tampered_token = valid_token[:-8] + "ABCDEF12"

    attacker_client = TestClient(app)
    headers = {"X-Guest-Token": tampered_token}

    list_resp = attacker_client.get("/api/v1/projects", headers=headers)
    assert list_resp.status_code == 200
    assert list_resp.json() == [], "Tampered token was accepted!"


def test_expired_guest_token_fails_closed(client):
    """
    A guest token with an expired timestamp is rejected and fails closed.
    """
    expired_token = create_guest_token(expires_delta=timedelta(seconds=-10))

    attacker_client = TestClient(app)
    headers = {"X-Guest-Token": expired_token}

    list_resp = attacker_client.get("/api/v1/projects", headers=headers)
    assert list_resp.status_code == 200
    assert list_resp.json() == []


def test_conflicting_identity_credentials_precedence(client, user_alice):
    """
    Prompt 07 Section A.1 & A.5:
    When both a valid user Bearer token and a guest token are supplied,
    the user Bearer token strictly takes precedence.
    """
    # Create guest project
    guest_token = create_guest_token()
    guest_payload = decode_guest_token(guest_token)
    guest_user_id = guest_payload["sub"]

    with SessionLocal() as db:
        guest_proj = Project(id="proj_guest_conflict_test", user_id=guest_user_id, name="Guest Only Project")
        db.merge(guest_proj)
        db.commit()

    # Client passes Alice's Bearer token AND the guest token
    conflicting_headers = {
        "Authorization": user_alice["headers"]["Authorization"],
        "X-Guest-Token": guest_token,
    }

    # When listing projects, Alice should see her own projects, NOT the guest's project
    list_resp = client.get("/api/v1/projects", headers=conflicting_headers)
    assert list_resp.status_code == 200
    assert not any(p["id"] == "proj_guest_conflict_test" for p in list_resp.json())

    # Alice attempting to access guest's project returns 403 Forbidden
    get_resp = client.get("/api/v1/projects/proj_guest_conflict_test", headers=conflicting_headers)
    assert get_resp.status_code == 403


# =====================================================================
# 2. Complete Authorization Coverage Across Core Routes
# =====================================================================

def test_cross_user_room_model_and_element_mutation_blocked(client, user_alice, user_bob):
    """
    Prompt 07 Section A.4:
    Verifies that get_room_model, update_room_element, and delete_room
    strictly enforce ownership across tenants.
    """
    # 1. Setup Alice's project and room in database and repository
    room_id = "room_alice_private_07"
    proj_id = "proj_alice_private_07"
    with SessionLocal() as db:
        proj = Project(id=proj_id, user_id=user_alice["id"], name="Alice Private Project")
        room = Room(
            id=room_id,
            project_id=proj_id,
            name="Alice Dining Room",
            room_model_data={
                "id": room_id,
                "project_id": proj_id,
                "name": "Alice Dining Room",
                "room_type": "dining_room",
                "surfaces": [],
                "objects": [{"id": "obj_table_1", "name": "Dining Table", "category": "furniture", "action": "KEEP"}],
                "openings": [],
                "versions": [],
            },
        )
        db.merge(proj)
        db.merge(room)
        db.commit()

    from packages.room_model import CanonicalRoomModel
    repository.rooms[room_id] = CanonicalRoomModel.model_validate(room.room_model_data)
    repository.projects[proj_id] = ProjectRecord(id=proj_id, user_id=user_alice["id"], name="Alice Private Project")

    # 2. Bob attempts to GET Alice's room model -> 403 Forbidden
    get_resp = client.get(f"/api/v1/rooms/{room_id}/model", headers=user_bob["headers"])
    assert get_resp.status_code == 403, f"Expected 403, got {get_resp.status_code}: {get_resp.text}"

    # 3. Anonymous caller attempts to GET Alice's room model -> 401 Unauthorized
    anon_resp = client.get(f"/api/v1/rooms/{room_id}/model")
    assert anon_resp.status_code in (401, 403)

    # 4. Bob attempts to mutate Alice's room element -> 403 Forbidden
    patch_resp = client.patch(
        f"/api/v1/rooms/{room_id}/elements/obj_table_1",
        json={"action": "REMOVE"},
        headers=user_bob["headers"],
    )
    assert patch_resp.status_code == 403

    # 5. Bob attempts to delete Alice's room -> 403 Forbidden
    del_resp = client.delete(f"/api/v1/rooms/{room_id}", headers=user_bob["headers"])
    assert del_resp.status_code == 403

    # 6. Alice can read her room model -> 200 OK
    alice_resp = client.get(f"/api/v1/rooms/{room_id}/model", headers=user_alice["headers"])
    assert alice_resp.status_code == 200
    assert alice_resp.json()["name"] == "Alice Dining Room"


def test_cross_user_background_job_inspection_blocked(client, user_alice, user_bob):
    """
    Prompt 07 Section A.4:
    Background jobs bind to the authorized owner and cannot be queried across tenants.
    """
    with SessionLocal() as db:
        proj = Project(id="proj_alice_job_test", user_id=user_alice["id"], name="Alice Project")
        room = Room(id="room_alice_job_test", project_id=proj.id, name="Alice Room")
        job = ProcessingJob(
            id="job_alice_secret_analysis",
            room_id=room.id,
            job_type="room_analysis",
            status="COMPLETED",
            progress_percent=100,
            current_step="Completed analysis",
            result_data={"detected_features": "Private Vault"},
        )
        db.merge(proj)
        db.merge(room)
        db.merge(job)
        db.commit()

    # Bob attempts to inspect Alice's job status -> 403 Forbidden
    bob_job_resp = client.get("/api/v1/jobs/job_alice_secret_analysis", headers=user_bob["headers"])
    assert bob_job_resp.status_code == 403
    assert "Not authorized" in bob_job_resp.json()["detail"]

    # Anonymous caller attempts to inspect Alice's job -> 401 Unauthorized
    anon_job_resp = client.get("/api/v1/jobs/job_alice_secret_analysis")
    assert anon_job_resp.status_code in (401, 403)

    # Alice inspects her own job -> 200 OK
    alice_job_resp = client.get("/api/v1/jobs/job_alice_secret_analysis", headers=user_alice["headers"])
    assert alice_job_resp.status_code == 200
    assert alice_job_resp.json()["id"] == "job_alice_secret_analysis"


# =====================================================================
# 3. Guest Session Persistence & Account Migration Workflow
# =====================================================================

def test_guest_session_persistence_across_app_restart(client):
    """
    Prompt 07 Section A.3 & C.2:
    Simulates app restart / client reinstantiation. Preserving the server-signed guest token
    allows the user to retain and mutate their projects across sessions without accidental loss.
    """
    # 1. Initial guest creates project
    c1 = TestClient(app)
    c1_resp = c1.post("/api/v1/projects", json={"name": "Pre-Restart Guest Project"})
    assert c1_resp.status_code == 200
    proj_id = c1_resp.json()["id"]
    guest_token = c1_resp.headers.get("X-Guest-Token") or c1_resp.headers.get("X-Guest-Session-ID")
    assert guest_token is not None

    # 2. Simulate fresh app start with restored guest token
    c2 = TestClient(app)
    restored_headers = {"X-Guest-Token": guest_token}

    # Verify listing finds the project
    list_resp = c2.get("/api/v1/projects", headers=restored_headers)
    assert list_resp.status_code == 200
    assert any(p["id"] == proj_id for p in list_resp.json())

    # Verify update succeeds
    update_resp = c2.put(f"/api/v1/projects/{proj_id}", json={"name": "Post-Restart Updated Name"}, headers=restored_headers)
    assert update_resp.status_code == 200
    assert update_resp.json()["name"] == "Post-Restart Updated Name"


def test_guest_to_account_migration_workflow(client, user_alice):
    """
    Prompt 07 Section A.3 & A.5:
    When a guest signs up or logs in, their projects are securely migrated to their permanent account
    upon presenting the authentic, server-signed guest token.
    """
    # 1. Create project as guest
    guest_token = create_guest_token()
    guest_payload = decode_guest_token(guest_token)
    guest_uid = guest_payload["sub"]

    proj_id = "proj_guest_to_migrate"
    with SessionLocal() as db:
        db_proj = Project(id=proj_id, user_id=guest_uid, name="Guest Living Room")
        db.merge(db_proj)
        db.commit()

    repository.projects[proj_id] = ProjectRecord(id=proj_id, user_id=guest_uid, name="Guest Living Room")

    # 2. Alice calls migration endpoint presenting the guest token
    mig_resp = client.post(
        "/api/v1/auth/migrate-guest-projects",
        json={"guest_token": guest_token},
        headers=user_alice["headers"],
    )
    assert mig_resp.status_code == 200
    mig_data = mig_resp.json()
    assert mig_data["status"] == "migrated"
    assert proj_id in mig_data["migrated_project_ids"]

    # 3. Verify project ownership has transitioned to Alice
    with SessionLocal() as db:
        updated_proj = db.query(Project).filter(Project.id == proj_id).first()
        assert updated_proj.user_id == user_alice["id"]

    # Alice can now access the migrated project directly with her Bearer token
    get_resp = client.get(f"/api/v1/projects/{proj_id}", headers=user_alice["headers"])
    assert get_resp.status_code == 200
    assert get_resp.json()["name"] == "Guest Living Room"


def test_legacy_usr_default_records_protected(client, user_bob):
    """
    Prompt 07 Section A.3 & A.5:
    Legacy usr_default records are strictly protected from being claimed or exposed to arbitrary guests.
    """
    with SessionLocal() as db:
        legacy_proj = Project(id="proj_legacy_default_safe", user_id="usr_default", name="Legacy Protected Project")
        db.merge(legacy_proj)
        db.commit()

    repository.projects["proj_legacy_default_safe"] = ProjectRecord(
        id="proj_legacy_default_safe",
        user_id="usr_default",
        name="Legacy Protected Project",
    )

    # 1. Arbitrary guest cannot see or access legacy project
    guest_token = create_guest_token()
    guest_resp = client.get("/api/v1/projects/proj_legacy_default_safe", headers={"X-Guest-Token": guest_token})
    assert guest_resp.status_code in (401, 403)

    # 2. Migration endpoint rejects attempting to migrate usr_default
    bad_migration = client.post(
        "/api/v1/auth/migrate-guest-projects",
        json={"guest_token": "usr_default"},
        headers=user_bob["headers"],
    )
    assert bad_migration.status_code == 400


# =====================================================================
# 4. Inpainting Operational Safety: Dry-Run & SSRF Prevention
# =====================================================================

def test_replicate_dry_run_validation():
    """
    Prompt 07 Section B.6:
    Validates official Replicate prediction request construction and parameter schema
    without transmitting user photos, making network calls, or consuming paid credits.
    """
    img = Image.new("RGB", (512, 512), color=(200, 200, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()

    mask = Image.new("L", (512, 512), color=0)
    # Paint 255 in center
    for x in range(128, 384):
        for y in range(128, 384):
            mask.putpixel((x, y), 255)
    mask_buf = io.BytesIO()
    mask.save(mask_buf, format="PNG")
    mask_bytes = mask_buf.getvalue()

    req = InpaintingRequest(
        image_bytes=img_bytes,
        mask_bytes=mask_bytes,
        width=512,
        height=512,
        prompt="Modern Scandinavian oak coffee table",
        style="Scandinavian",
        room_id="room_dry_run_test",
        num_variants=3,
    )

    adapter = ReplicateInpaintingAdapter(api_token="r8_test_token_sample123456")
    dry_run_report = adapter.dry_run(req)

    assert dry_run_report["status"] == "VALID"
    assert dry_run_report["dry_run"] is True
    assert dry_run_report["provider_name"] == "replicate-sd-inpainting"
    assert dry_run_report["model"] == "stability-ai/stable-diffusion-inpainting"
    assert dry_run_report["num_variants"] == 3
    assert dry_run_report["estimated_cost_usd"] == 0.015
    assert dry_run_report["network_calls_made"] == 0
    assert dry_run_report["paid_credits_consumed"] == 0.0
    assert "r8_test_token_sample123456" not in str(dry_run_report)  # Token masked


def test_replicate_output_url_ssrf_blocked():
    """
    Prompt 07 Section B.3:
    Rejects untrusted provider output URLs, blocking attempts to query private networks
    or internal cloud metadata endpoints.
    """
    img = Image.new("RGB", (256, 256), color=(180, 180, 180))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()

    mask_bytes = Image.new("L", (256, 256), color=255).tobytes()

    req = InpaintingRequest(
        image_bytes=img_bytes,
        mask_bytes=mask_bytes,
        width=256,
        height=256,
        prompt="Nordic sofa",
        room_id="room_ssrf_test",
        num_variants=1,
    )

    class MockSSRFSession:
        def post(self, url, **kwargs):
            class Resp:
                status_code = 201
                def json(self):
                    return {"id": "pred_ssrf_test", "status": "succeeded", "output": ["http://169.254.169.254/latest/meta-data/"]}
            return Resp()

        def get(self, url, **kwargs):
            class Resp:
                status_code = 200
                def json(self):
                    return {"id": "pred_ssrf_test", "status": "succeeded", "output": ["http://169.254.169.254/latest/meta-data/"]}
            return Resp()

    adapter = ReplicateInpaintingAdapter(api_token="r8_test_valid_token", http_client=MockSSRFSession())

    with pytest.raises(InpaintingProviderException) as exc_info:
        adapter.inpaint(req)

    assert "SSRF blocked" in str(exc_info.value) or "Untrusted output" in str(exc_info.value)


def test_mock_diffusion_sandbox_truthful_provenance(tmp_path):
    """
    Prompt 07 Section B.4:
    Never labels mock gradient/noise images as genuine neural output.
    DesignVariant metadata must truthfully identify sandbox output.
    """
    from packages.room_model import CanonicalRoomModel, DesignConstraint, Geometry, Point2D, WallSegment

    room = CanonicalRoomModel(
        id="room_mock_prov_test",
        name="Mock Provenance Living Room",
        room_type="living_room",
        geometry=Geometry(wall_segments=[WallSegment(start_point=Point2D(x=0, y=0), end_point=Point2D(x=4, y=0), length_m=4.0)]),
        objects=[],
        openings=[],
    )

    img = Image.new("RGB", (256, 256), color=(210, 200, 190))
    constraints = DesignConstraint(styles=["Warm Modern Minimalist"])

    result = run_inpainting_pipeline(
        room_model=room,
        image=img,
        constraints=constraints,
        provider=MockInpaintingProvider(),
        output_dir=str(tmp_path),
    )

    version = result.data
    assert len(version.variants) == 3
    for v in version.variants:
        assert "Mock Sandbox Concept" in v.title
        assert "Not genuine neural output" in v.description
        assert "mock-sdxl-inpainting" in v.description
