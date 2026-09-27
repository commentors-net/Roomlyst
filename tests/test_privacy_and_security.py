"""
Tests for Milestone 1.6: MVP Privacy, Security, Operations, and Release Gate.
Covers:
- EXIF/GPS Metadata Sanitization (Blueprint Section 23).
- Cascading Project & Media Deletion (Blueprint Section 23, 24, 49).
- Rate Limiting & Abuse Protection (Blueprint Section 24).
- Admin Support, Failed Jobs Inspection & Retry (Blueprint Section 29).
- Telemetry & Compute Cost Accounting (Blueprint Section 30).
- Audited Elevated Media Access (Blueprint Section 23 Item 11 & Section 29).
"""

import io
import os
from PIL import Image
import pytest
from fastapi.testclient import TestClient

from services.api.app.core.rate_limit import SlidingWindowRateLimiter, generation_limiter
from services.api.app.core.sanitizer import (
    has_exif_gps,
    inspect_image_privacy,
    sanitize_image,
)
from services.api.app.core.security import create_access_token, hash_password
from services.api.app.db.models import (
    AdminAuditLog,
    JobCostRecord,
    MediaAsset,
    ProcessingJob,
    Project,
    Room,
    User,
)
from services.api.app.db.session import SessionLocal
from services.api.app.jobs.state_machine import JobStatus
from services.api.app.main import app
from services.api.app.storage import get_storage_provider


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def admin_token():
    with SessionLocal() as db:
        admin_user = User(
            id="usr_admin_test",
            email="admin@roomlyst.internal",
            hashed_password=hash_password("AdminPass123!"),
            role="admin",
            is_active=True,
        )
        db.add(admin_user)
        db.commit()
    return create_access_token(subject="usr_admin_test", claims={"role": "admin"})


@pytest.fixture
def user_token():
    with SessionLocal() as db:
        regular_user = User(
            id="usr_homeowner_test",
            email="homeowner@roomlyst.com",
            hashed_password=hash_password("HomeownerPass123!"),
            role="homeowner",
            is_active=True,
        )
        db.add(regular_user)
        db.commit()
    return create_access_token(subject="usr_homeowner_test", claims={"role": "homeowner"})


def create_image_with_gps() -> bytes:
    """Creates a sample test JPEG image with embedded GPS EXIF metadata."""
    img = Image.new("RGB", (200, 200), color=(120, 150, 180))
    exif = img.getexif()
    # Tag 0x010E: ImageDescription
    exif[0x010E] = "Living Room Private Photo"
    # Tag 0x8825: GPSInfo IFD
    gps_ifd = exif.get_ifd(0x8825)
    gps_ifd[1] = "N"
    gps_ifd[2] = (3.1415, 101.6869, 50.0)  # Coordinates near Kuala Lumpur

    buf = io.BytesIO()
    img.save(buf, format="JPEG", exif=exif)
    return buf.getvalue()


# =====================================================================
# 1. EXIF / GPS Metadata Sanitization Tests (Section 23)
# =====================================================================

def test_exif_gps_stripping():
    """Verify raw image with GPS metadata is completely stripped and sanitized."""
    raw_bytes = create_image_with_gps()

    # Verify input image has GPS metadata
    before_privacy = inspect_image_privacy(raw_bytes)
    assert before_privacy["contains_gps"] is True
    assert before_privacy["privacy_compliant"] is False

    # Apply sanitizer
    sanitized_bytes = sanitize_image(raw_bytes)

    # Verify sanitized output has 0 GPS tags
    after_privacy = inspect_image_privacy(sanitized_bytes)
    assert after_privacy["contains_gps"] is False
    assert after_privacy["privacy_compliant"] is True
    assert has_exif_gps(sanitized_bytes) is False


def test_upload_endpoint_strips_gps_exif(client):
    """Verify that uploading a room photo automatically strips EXIF GPS data."""
    raw_gps_bytes = create_image_with_gps()

    files = {"file": ("room_gps_test.jpg", raw_gps_bytes, "image/jpeg")}
    data = {"room_name": "Sanitized Living Room", "platform": "ios", "has_lidar": "false"}

    response = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data)
    assert response.status_code == 200

    saved_url = response.json()["original_image_url"].lstrip("/")
    assert os.path.exists(saved_url)

    with open(saved_url, "rb") as f:
        stored_bytes = f.read()

    assert not has_exif_gps(stored_bytes)
    privacy_report = inspect_image_privacy(stored_bytes)
    assert privacy_report["privacy_compliant"] is True


# =====================================================================
# 2. Cascading Project and Media Deletion Tests (Section 23 & 49)
# =====================================================================

def test_cascading_project_deletion(client):
    """
    Blueprint Section 49: User can delete a project.
    Verify that deleting a project cascades and purges rooms, media, and storage files.
    """
    storage = get_storage_provider()

    # 1. Create project with room and media asset
    with SessionLocal() as db:
        proj = Project(id="proj_del_test", name="Deletable Renovation", user_id="usr_demo")
        room = Room(id="room_del_test", project_id=proj.id, name="Living Room")
        db.add(proj)
        db.add(room)
        db.commit()

    # Upload mock files into storage
    file_key = "uploads/proj_del_test/room_del_test/photo.jpg"
    storage.upload_file(file_key, b"synthetic room photo content")

    with SessionLocal() as db:
        room = db.query(Room).filter(Room.id == "room_del_test").first()
        room.original_image_key = file_key
        asset = MediaAsset(
            id="med_del_test",
            room_id="room_del_test",
            storage_key=file_key,
            asset_type="original_photo",
        )
        db.add(asset)
        db.commit()

    # Verify file exists in storage before deletion
    assert storage.download_file(file_key) == b"synthetic room photo content"

    # 2. Call DELETE /projects/{project_id}
    del_resp = client.delete("/api/v1/projects/proj_del_test")
    assert del_resp.status_code == 200
    del_data = del_resp.json()
    assert del_data["status"] == "deleted"
    assert del_data["deleted_rooms_count"] >= 1

    # 3. Verify database entities are deleted
    with SessionLocal() as db:
        assert db.query(Project).filter(Project.id == "proj_del_test").first() is None
        assert db.query(Room).filter(Room.id == "room_del_test").first() is None
        assert db.query(MediaAsset).filter(MediaAsset.id == "med_del_test").first() is None

    # 4. Verify storage file was permanently removed
    with pytest.raises(Exception):
        storage.download_file(file_key)


def test_media_asset_deletion(client, user_token):
    """Verify single media asset can be deleted securely."""
    storage = get_storage_provider()
    key = "uploads/test_asset_to_delete.jpg"
    storage.upload_file(key, b"temp image data")

    with SessionLocal() as db:
        proj = Project(id="proj_user_1", name="User Proj", user_id="usr_homeowner_test")
        room = Room(id="room_user_1", project_id=proj.id, name="Room 1")
        asset = MediaAsset(id="med_single_del", room_id=room.id, storage_key=key, asset_type="render")
        db.add(proj)
        db.add(room)
        db.add(asset)
        db.commit()

    headers = {"Authorization": f"Bearer {user_token}"}
    del_resp = client.delete("/api/v1/media/med_single_del", headers=headers)
    assert del_resp.status_code == 200

    with SessionLocal() as db:
        assert db.query(MediaAsset).filter(MediaAsset.id == "med_single_del").first() is None


# =====================================================================
# 3. Rate Limiting Tests (Section 24)
# =====================================================================

def test_rate_limiting_enforcement():
    """Verify sliding window rate limiter emits HTTP 429 when threshold exceeded."""
    limiter = SlidingWindowRateLimiter(default_limit=3, window_seconds=60)
    limiter.reset()

    class MockClient:
        host = "192.168.1.100"

    class MockRequest:
        headers = {}
        client = MockClient()

    req = MockRequest()

    # First 3 requests should pass
    limiter.check(req, limit=3)
    limiter.check(req, limit=3)
    limiter.check(req, limit=3)

    # 4th request must be rejected with HTTP 429
    with pytest.raises(Exception) as excinfo:
        limiter.check(req, limit=3)
    assert excinfo.value.status_code == 429
    assert "Rate limit exceeded" in excinfo.value.detail
    assert "Retry-After" in excinfo.value.headers


# =====================================================================
# 4. Admin Support, Cost Telemetry & Audited Access (Sections 29 & 30)
# =====================================================================

def test_admin_endpoints_require_admin_role(client, user_token):
    """Verify regular homeowner user is forbidden from accessing admin endpoints (HTTP 403)."""
    headers = {"Authorization": f"Bearer {user_token}"}
    resp = client.get("/api/v1/admin/telemetry/costs", headers=headers)
    assert resp.status_code == 403
    assert "Admin privileges required" in resp.json()["detail"]


def test_admin_failed_jobs_and_retry(client, admin_token):
    """
    Blueprint Section 29: Admin can inspect failed jobs and retry them.
    """
    headers = {"Authorization": f"Bearer {admin_token}"}
    storage = get_storage_provider()
    key = "uploads/failed_job_room.jpg"
    storage.upload_file(key, b"dummy photo")

    with SessionLocal() as db:
        proj = Project(id="proj_fail_test", name="Failed Job Project", user_id="usr_demo")
        room = Room(id="room_fail_test", project_id=proj.id, name="Living Room", original_image_key=key)
        job = ProcessingJob(
            id="job_failed_01",
            room_id=room.id,
            job_type="room_analysis",
            status=JobStatus.FAILED_RETRYABLE.value,
            error_message="Simulated GPU OOM or pipeline timeout",
        )
        db.add(proj)
        db.add(room)
        db.add(job)
        db.commit()

    # 1. Admin lists failed jobs
    failed_resp = client.get("/api/v1/admin/jobs/failed", headers=headers)
    assert failed_resp.status_code == 200
    failed_list = failed_resp.json()
    assert len(failed_list) >= 1
    target = next((j for j in failed_list if j["id"] == "job_failed_01"), None)
    assert target is not None
    assert target["error_message"] == "Simulated GPU OOM or pipeline timeout"

    # 2. Admin retries the failed job
    retry_resp = client.post("/api/v1/admin/jobs/job_failed_01/retry", headers=headers)
    assert retry_resp.status_code == 200
    assert retry_resp.json()["status"] == "CREATED"

    # 3. Verify audit log entry was created (Blueprint Section 23 Item 11)
    audit_resp = client.get("/api/v1/admin/audit-logs", headers=headers)
    assert audit_resp.status_code == 200
    audits = audit_resp.json()
    assert any(a["action"] == "retry_job" and "job_failed_01" in a["target_resource"] for a in audits)


def test_admin_cost_telemetry(client, admin_token):
    """
    Blueprint Section 30 & 49: Per-job processing cost is measurable and visible to admin.
    """
    headers = {"Authorization": f"Bearer {admin_token}"}

    with SessionLocal() as db:
        job = ProcessingJob(id="job_costed_1", room_id="room_1", job_type="redesign_generation")
        cost = JobCostRecord(
            job_id=job.id,
            project_id="proj_alpha",
            provider="replicate_sdxl",
            model="sdxl-controlnet-depth",
            input_size="1024x1024",
            processing_seconds=3.42,
            gpu_type="NVIDIA-A10G",
            estimated_compute_cost=0.005,
            generation_api_cost=0.015,
            total_cost_usd=0.020,
        )
        db.add(job)
        db.add(cost)
        db.commit()

    resp = client.get("/api/v1/admin/telemetry/costs", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_cost_usd"] >= 0.020
    assert "replicate_sdxl" in data["breakdown_by_provider"]
    assert "proj_alpha" in data["breakdown_by_project"]
    assert data["job_count"] >= 1


def test_admin_elevated_media_access_is_audited(client, admin_token):
    """
    Blueprint Section 23 Item 11 & Section 29:
    Support staff should not automatically see private room media.
    Elevated access must be explicit and audited.
    """
    headers = {"Authorization": f"Bearer {admin_token}"}
    storage = get_storage_provider()
    key = "uploads/sensitive_room_photo.jpg"
    storage.upload_file(key, b"confidential client photo")

    with SessionLocal() as db:
        room = Room(id="room_priv_test", project_id="proj_1", name="Master Bedroom")
        asset = MediaAsset(id="med_confidential_01", room_id=room.id, storage_key=key, asset_type="original_photo")
        db.add(room)
        db.add(asset)
        db.commit()

    # Admin requests elevated access with business justification
    payload = {"reason": "Customer ticket #CS-4091: Client reported false positive column detection"}
    resp = client.post("/api/v1/admin/media/med_confidential_01/elevated-access", json=payload, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["audited"] is True
    assert "signed_url" in data

    # Verify audit log recorded this access
    audit_resp = client.get("/api/v1/admin/audit-logs", headers=headers)
    assert audit_resp.status_code == 200
    audits = audit_resp.json()
    assert any(
        a["action"] == "elevated_media_access"
        and "med_confidential_01" in a["target_resource"]
        and "CS-4091" in a["reason"]
        for a in audits
    )
