"""
Comprehensive Authentication & Identity Isolation Test Suite.
Fulfills Prompt 06 Acceptance Criteria:
- No unresolved shared usr_default ownership path can expose persistent user projects across unrelated sessions.
- Positive and negative authorization tests for anonymous create/list/read/update/delete/generate.
- Cross-account access prevention (User A vs User B).
- Explicit isolated demo behavior preserved.
"""

import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient

from services.api.app.core.security import create_access_token, hash_password, decode_guest_token
from services.api.app.db.models import Project, Room, MediaAsset, User
from services.api.app.db.session import SessionLocal
from services.api.app.main import app
from services.api.app.storage import get_storage_provider


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def user_a():
    user_id = "usr_alice_homeowner"
    with SessionLocal() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            user = User(
                id=user_id,
                email="alice@roomlyst.com",
                hashed_password=hash_password("PasswordAlice123!"),
                role="homeowner",
                is_active=True,
            )
            db.add(user)
            db.commit()
    token = create_access_token(subject=user_id, claims={"role": "homeowner", "email": "alice@roomlyst.com"})
    return {"id": user_id, "token": token, "headers": {"Authorization": f"Bearer {token}"}}


@pytest.fixture
def user_b():
    user_id = "usr_bob_attacker"
    with SessionLocal() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            user = User(
                id=user_id,
                email="bob@roomlyst.com",
                hashed_password=hash_password("PasswordBob123!"),
                role="homeowner",
                is_active=True,
            )
            db.add(user)
            db.commit()
    token = create_access_token(subject=user_id, claims={"role": "homeowner", "email": "bob@roomlyst.com"})
    return {"id": user_id, "token": token, "headers": {"Authorization": f"Bearer {token}"}}


@pytest.fixture
def admin_user():
    user_id = "usr_system_admin"
    with SessionLocal() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            user = User(
                id=user_id,
                email="admin@roomlyst.internal",
                hashed_password=hash_password("AdminPass123!"),
                role="admin",
                is_active=True,
            )
            db.add(user)
            db.commit()
    token = create_access_token(subject=user_id, claims={"role": "admin", "email": "admin@roomlyst.internal"})
    return {"id": user_id, "token": token, "headers": {"Authorization": f"Bearer {token}"}}


# =====================================================================
# 1. Anonymous Project Creation & Isolated Guest Sessions
# =====================================================================

def test_anonymous_create_assigns_guest_session_not_usr_default(client):
    """
    Prompt 06: Prevent unauthenticated users from receiving shared identity 'usr_default'.
    An anonymous project creation must issue an isolated guest session.
    """
    resp = client.post("/api/v1/projects", json={"name": "Anonymous Condo Renovation"})
    assert resp.status_code == 200
    data = resp.json()
    proj_id = data["id"]

    # Verify cookie and header
    assert "guest_session_id" in resp.cookies or "X-Guest-Session-ID" in resp.headers
    guest_sid = resp.cookies.get("guest_session_id") or resp.headers.get("X-Guest-Session-ID")

    with SessionLocal() as db:
        db_proj = db.query(Project).filter(Project.id == proj_id).first()
        assert db_proj is not None
        assert db_proj.user_id != "usr_default", "VULNERABILITY: Project was assigned shared usr_default!"
        assert db_proj.user_id.startswith("usr_guest_")
        payload = decode_guest_token(guest_sid)
        assert payload is not None
        assert payload["sub"] == db_proj.user_id


def test_anonymous_list_returns_empty_when_no_session(client):
    """
    An anonymous caller with no session headers or cookies receives an empty project list,
    preventing any leak of other users' projects or historical demo projects.
    """
    # Create fresh TestClient with no cookies
    anon_client = TestClient(app)
    resp = anon_client.get("/api/v1/projects")
    assert resp.status_code == 200
    assert resp.json() == [], "Anonymous caller must not see any persistent user projects"


def test_isolated_guest_sessions_cannot_see_each_other(client):
    """
    Guest X and Guest Y should have isolated project listings and cannot access each other's projects.
    """
    # Guest X creates a project
    client_x = TestClient(app)
    resp_x = client_x.post("/api/v1/projects", json={"name": "Guest X Living Room"})
    assert resp_x.status_code == 200
    proj_x_id = resp_x.json()["id"]

    # Guest Y creates a project
    client_y = TestClient(app)
    resp_y = client_y.post("/api/v1/projects", json={"name": "Guest Y Penthouse"})
    assert resp_y.status_code == 200
    proj_y_id = resp_y.json()["id"]

    # Guest X lists projects -> only sees proj_x
    list_x = client_x.get("/api/v1/projects").json()
    assert any(p["id"] == proj_x_id for p in list_x)
    assert not any(p["id"] == proj_y_id for p in list_x)

    # Guest Y lists projects -> only sees proj_y
    list_y = client_y.get("/api/v1/projects").json()
    assert any(p["id"] == proj_y_id for p in list_y)
    assert not any(p["id"] == proj_x_id for p in list_y)

    # Guest Y cannot read Guest X's project directly
    cross_read = client_y.get(f"/api/v1/projects/{proj_x_id}")
    assert cross_read.status_code in (401, 403), "Guest Y accessed Guest X's project!"

    # Guest Y cannot update Guest X's project
    cross_update = client_y.put(f"/api/v1/projects/{proj_x_id}", json={"name": "Tampered by Y"})
    assert cross_update.status_code in (401, 403)

    # Guest Y cannot delete Guest X's project
    cross_del = client_y.delete(f"/api/v1/projects/{proj_x_id}")
    assert cross_del.status_code in (401, 403)


# =====================================================================
# 2. Cross-Account Authorization Enforcement (User A vs User B)
# =====================================================================

def test_authenticated_cross_account_project_isolation(client, user_a, user_b):
    """
    User A's project cannot be listed, viewed, updated, or deleted by User B.
    """
    # 1. User A creates project
    resp_a = client.post(
        "/api/v1/projects",
        json={"name": "Alice Private Villa", "currency": "MYR"},
        headers=user_a["headers"],
    )
    assert resp_a.status_code == 200
    proj_a_id = resp_a.json()["id"]

    # 2. User B lists projects -> Alice's project must NOT appear
    resp_b_list = client.get("/api/v1/projects", headers=user_b["headers"])
    assert resp_b_list.status_code == 200
    assert not any(p["id"] == proj_a_id for p in resp_b_list.json())

    # 3. User B attempts GET on Alice's project -> 403 Forbidden
    resp_b_get = client.get(f"/api/v1/projects/{proj_a_id}", headers=user_b["headers"])
    assert resp_b_get.status_code == 403
    assert "Not authorized" in resp_b_get.json()["detail"]

    # 4. User B attempts PUT on Alice's project -> 403 Forbidden
    resp_b_put = client.put(
        f"/api/v1/projects/{proj_a_id}",
        json={"name": "Hacked by Bob"},
        headers=user_b["headers"],
    )
    assert resp_b_put.status_code == 403

    # 5. User B attempts DELETE on Alice's project -> 403 Forbidden
    resp_b_del = client.delete(f"/api/v1/projects/{proj_a_id}", headers=user_b["headers"])
    assert resp_b_del.status_code == 403

    # 6. Anonymous caller attempts GET on Alice's project -> 401 Unauthorized
    resp_anon_get = client.get(f"/api/v1/projects/{proj_a_id}")
    assert resp_anon_get.status_code == 401


def test_cross_account_generation_blocked(client, user_a, user_b):
    """
    User B cannot trigger design redesign generation on User A's room.
    """
    # 1. Create project and room for User A
    with SessionLocal() as db:
        proj = Project(id="proj_alice_secure", user_id=user_a["id"], name="Alice Sanctum")
        room = Room(
            id="room_alice_secure",
            project_id=proj.id,
            name="Alice Master Bedroom",
            room_model_data={"id": "room_alice_secure", "room_type": "bedroom", "surfaces": [], "objects": [], "versions": []},
        )
        db.merge(proj)
        db.merge(room)
        db.commit()

    # 2. User B attempts to trigger redesign generation on Alice's room -> 403 Forbidden
    gen_resp = client.post(
        f"/api/v1/rooms/{room.id}/design-requests",
        json={"styles": ["Warm Modern Minimalist"]},
        headers=user_b["headers"],
    )
    assert gen_resp.status_code == 403
    assert "Not authorized" in gen_resp.json()["detail"]


def test_admin_can_view_all_projects(client, user_a, admin_user):
    """
    Admin privileges allow viewing and managing projects across accounts.
    """
    resp_a = client.post(
        "/api/v1/projects",
        json={"name": "Alice Studio for Admin Audit"},
        headers=user_a["headers"],
    )
    proj_id = resp_a.json()["id"]

    # Admin reads Alice's project -> 200 OK
    admin_get = client.get(f"/api/v1/projects/{proj_id}", headers=admin_user["headers"])
    assert admin_get.status_code == 200
    assert admin_get.json()["id"] == proj_id


def test_demo_projects_accessible_read_only(client):
    """
    Pre-seeded or sample demo projects (starting with proj_demo_) remain accessible
    for read-only onboarding and verification.
    """
    from services.api.app.api.v1.endpoints import repository
    from packages.room_model import ProjectStatus

    # Register sample demo project in repository
    demo_rec = repository.create_project(
        name="[DEMO] Sample Minimalist Living Room",
        status=ProjectStatus.BRIEFING,
        user_id="usr_demo",
    )
    demo_rec.id = "proj_demo_sample_test"
    repository.projects["proj_demo_sample_test"] = demo_rec

    # Any anonymous caller can read demo project
    anon_resp = client.get("/api/v1/projects/proj_demo_sample_test")
    assert anon_resp.status_code == 200
    assert anon_resp.json()["name"] == "[DEMO] Sample Minimalist Living Room"
