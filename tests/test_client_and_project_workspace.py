"""
Tests for Milestone 5.1: Client and Project Workspace for Professional Interior Designers.
Compliant with Blueprint Section 41 & Milestone 5.1 requirements.
"""

import pytest
from fastapi.testclient import TestClient

from packages.room_model import (
    BudgetPlan,
    CanonicalRoomModel,
    CurrencyCode,
    Geometry,
    Point2D,
    ProjectRole,
    ProjectStatus,
    WallSegment,
)
from services.api.app.db.repository import repository
from services.api.app.main import app


@pytest.fixture
def client():
    return TestClient(app)


class TestClientManagement:
    def test_create_and_get_client(self, client):
        payload = {
            "name": "Datin Sarah Tan",
            "email": "sarah.tan@example.com",
            "phone": "+60123456789",
            "company": "Tan Holdings",
            "address": "12 Jalan Kiara, Mont Kiara, Kuala Lumpur",
            "notes": "Prefers organic Japandi aesthetic with sustainable wood finishes.",
            "budget_preference": 150000.0,
            "currency": "MYR",
            "preferred_styles": ["Japandi", "Warm Minimalist"],
        }
        resp = client.post("/api/v1/clients", json=payload)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        client_id = data["client_id"]
        assert data["name"] == "Datin Sarah Tan"
        assert data["budget_preference"] == 150000.0
        assert "Japandi" in data["preferred_styles"]

        # Fetch client
        get_resp = client.get(f"/api/v1/clients/{client_id}")
        assert get_resp.status_code == 200
        get_data = get_resp.json()
        assert get_data["client_id"] == client_id
        assert get_data["email"] == "sarah.tan@example.com"

    def test_list_clients(self, client):
        client.post("/api/v1/clients", json={"name": "Client Alpha", "currency": "MYR"})
        client.post("/api/v1/clients", json={"name": "Client Beta", "currency": "SGD"})

        resp = client.get("/api/v1/clients")
        assert resp.status_code == 200
        clients_list = resp.json()
        assert len(clients_list) >= 2
        names = [c["name"] for c in clients_list]
        assert "Client Alpha" in names
        assert "Client Beta" in names

    def test_update_client(self, client):
        create_resp = client.post("/api/v1/clients", json={"name": "Old Name", "notes": "Initial note"})
        client_id = create_resp.json()["client_id"]

        update_resp = client.put(
            f"/api/v1/clients/{client_id}",
            json={
                "name": "Updated VIP Client",
                "notes": "VIP tier expedited delivery required",
                "budget_preference": 200000.0,
            },
        )
        assert update_resp.status_code == 200
        updated = update_resp.json()
        assert updated["name"] == "Updated VIP Client"
        assert updated["notes"] == "VIP tier expedited delivery required"
        assert updated["budget_preference"] == 200000.0

    def test_delete_client_unlinks_project(self, client):
        # Create client
        c_resp = client.post("/api/v1/clients", json={"name": "Temporary Client"})
        c_id = c_resp.json()["client_id"]

        # Create project linked to client
        p_resp = client.post(
            "/api/v1/projects",
            json={"name": "Linked Residence", "client_id": c_id},
        )
        p_id = p_resp.json()["id"]

        # Verify linked
        assert p_resp.json()["client_id"] == c_id

        # Delete client
        del_resp = client.delete(f"/api/v1/clients/{c_id}")
        assert del_resp.status_code == 200

        # Project still exists, but client_id is cleared
        p_check = client.get(f"/api/v1/projects/{p_id}")
        assert p_check.status_code == 200
        assert p_check.json()["client_id"] is None

    def test_client_not_found(self, client):
        resp = client.get("/api/v1/clients/cli_nonexistent_999")
        assert resp.status_code == 404


class TestProjectWorkspaceManagement:
    def test_create_project_with_workspace_metadata(self, client):
        c_resp = client.post("/api/v1/clients", json={"name": "Dr. Alex Wong"})
        c_id = c_resp.json()["client_id"]

        payload = {
            "name": "Damansara Heights Bungalow",
            "currency": "MYR",
            "client_id": c_id,
            "property_address": "88 Jalan Medang Serai, Bukit Damansara",
            "status": "CONCEPT_DESIGN",
            "designer_notes": "Focus on high-ceiling living space and concealed air-conditioning.",
        }
        resp = client.post("/api/v1/projects", json=payload)
        assert resp.status_code == 200, resp.text
        proj = resp.json()
        assert proj["client_id"] == c_id
        assert proj["status"] == "CONCEPT_DESIGN"
        assert proj["property_address"] == "88 Jalan Medang Serai, Bukit Damansara"
        assert "high-ceiling" in proj["designer_notes"]

    def test_update_project_status_and_notes(self, client):
        p_resp = client.post("/api/v1/projects", json={"name": "Condo Refurbishment"})
        p_id = p_resp.json()["id"]

        update_resp = client.put(
            f"/api/v1/projects/{p_id}",
            json={
                "status": "CLIENT_REVIEW",
                "designer_notes": "Awaiting client sign-off on master bedroom colorway.",
                "target_completion_date": "2026-12-15",
            },
        )
        assert update_resp.status_code == 200
        updated = update_resp.json()
        assert updated["status"] == "CLIENT_REVIEW"
        assert updated["designer_notes"] == "Awaiting client sign-off on master bedroom colorway."
        assert updated["target_completion_date"] == "2026-12-15"

    def test_collaborator_management(self, client):
        p_resp = client.post("/api/v1/projects", json={"name": "Studio Collab Project"})
        p_id = p_resp.json()["id"]

        # Add collaborator
        collab_payload = {
            "user_id": "usr_designer_02",
            "email": "elena@designstudio.com",
            "name": "Elena Rostova",
            "role": "LEAD_DESIGNER",
        }
        add_resp = client.post(f"/api/v1/projects/{p_id}/collaborators", json=collab_payload)
        assert add_resp.status_code == 200
        assert add_resp.json()["role"] == "LEAD_DESIGNER"
        assert add_resp.json()["name"] == "Elena Rostova"

        # List collaborators
        list_resp = client.get(f"/api/v1/projects/{p_id}/collaborators")
        assert list_resp.status_code == 200
        collabs = list_resp.json()
        assert len(collabs) == 1
        assert collabs[0]["user_id"] == "usr_designer_02"

        # Remove collaborator
        del_resp = client.delete(f"/api/v1/projects/{p_id}/collaborators/usr_designer_02")
        assert del_resp.status_code == 200

        # Verify empty
        list_resp_after = client.get(f"/api/v1/projects/{p_id}/collaborators")
        assert list_resp_after.status_code == 200
        assert len(list_resp_after.json()) == 0

    def test_multi_room_project_summary(self, client):
        # 1. Create client and project
        c_resp = client.post("/api/v1/clients", json={"name": "Ken & Lisa"})
        c_id = c_resp.json()["client_id"]

        p_resp = client.post(
            "/api/v1/projects",
            json={
                "name": "Subang Jaya Villa",
                "client_id": c_id,
                "property_address": "Subang Jaya, Selangor",
                "currency": "MYR",
                "status": "CONCEPT_DESIGN",
            },
        )
        p_id = p_resp.json()["id"]

        # 2. Add Room 1 (Living Room: 25 sqm, RM 35,000 budget)
        ws1 = [
            WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=5.0, y=0.0), length_m=5.0),
            WallSegment(start_point=Point2D(x=5.0, y=0.0), end_point=Point2D(x=5.0, y=5.0), length_m=5.0),
            WallSegment(start_point=Point2D(x=5.0, y=5.0), end_point=Point2D(x=0.0, y=5.0), length_m=5.0),
            WallSegment(start_point=Point2D(x=0.0, y=5.0), end_point=Point2D(x=0.0, y=0.0), length_m=5.0),
        ]
        r1 = CanonicalRoomModel(
            id="room_villa_living",
            project_id=p_id,
            name="Open Concept Living Room",
            room_type="living_room",
            geometry=Geometry(wall_segments=ws1, floor_area_sqm=25.0),
            budget_plan=BudgetPlan(total_budget=35000.0, grand_total=35000.0, currency=CurrencyCode.MYR),
        )
        repository.save_room(r1)

        # 3. Add Room 2 (Master Bedroom: 18 sqm, RM 22,000 budget)
        ws2 = [
            WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=4.5, y=0.0), length_m=4.5),
            WallSegment(start_point=Point2D(x=4.5, y=0.0), end_point=Point2D(x=4.5, y=4.0), length_m=4.0),
            WallSegment(start_point=Point2D(x=4.5, y=4.0), end_point=Point2D(x=0.0, y=4.0), length_m=4.5),
            WallSegment(start_point=Point2D(x=0.0, y=4.0), end_point=Point2D(x=0.0, y=0.0), length_m=4.0),
        ]
        r2 = CanonicalRoomModel(
            id="room_villa_bedroom",
            project_id=p_id,
            name="Master Bedroom Suite",
            room_type="bedroom",
            geometry=Geometry(wall_segments=ws2, floor_area_sqm=18.0),
            budget_plan=BudgetPlan(total_budget=22000.0, grand_total=22000.0, currency=CurrencyCode.MYR),
        )
        repository.save_room(r2)

        # 4. Request Project Workspace Summary
        sum_resp = client.get(f"/api/v1/projects/{p_id}/summary")
        assert sum_resp.status_code == 200, sum_resp.text
        summary = sum_resp.json()

        assert summary["project_id"] == p_id
        assert summary["name"] == "Subang Jaya Villa"
        assert summary["client"]["name"] == "Ken & Lisa"
        assert summary["total_rooms"] == 2
        assert summary["total_floor_area_sqm"] == 43.0  # 25 + 18
        assert summary["total_estimated_budget"] == 57000.0  # 35000 + 22000
        assert len(summary["rooms_summary"]) == 2
        r_names = [r["name"] for r in summary["rooms_summary"]]
        assert "Open Concept Living Room" in r_names
        assert "Master Bedroom Suite" in r_names
