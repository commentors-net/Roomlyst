"""
Milestone 6.4 — Cross-Segment Ecosystem Workflow Orchestration & Role-Based Governance Tests.
Validates multi-participant transitions (Homeowner -> Designer -> Merchant -> Contractor -> Agent),
Role-Based Access Control (RBAC), privacy redaction, immutable audit logging,
and Phase 6 Exit Gate compliance.
"""

import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient

from services.api.app.main import app
from services.api.app.db.repository import repository
from packages.room_model import (
    CanonicalRoomModel,
    CurrencyCode,
    EcosystemAuditEvent,
    EcosystemHandoffRecord,
    EcosystemRole,
    Geometry,
    HandoffStatus,
    HandoffTransitionType,
    RoleScopedProjectView,
    WorkflowOrchestrationSummary,
)

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_orchestration_state():
    """Reset repository handoffs, audit events, and projects prior to each test."""
    repository.handoffs.clear()
    repository.ecosystem_audit_events.clear()
    repository._seed_handoffs()


# =====================================================================
# Unit Tests: Ecosystem Domain Models & Scopes
# =====================================================================

def test_ecosystem_role_and_transitions_enums():
    """Validates ecosystem role definitions and transition types."""
    assert EcosystemRole.HOMEOWNER.value == "HOMEOWNER"
    assert EcosystemRole.INTERIOR_DESIGNER.value == "INTERIOR_DESIGNER"
    assert EcosystemRole.CONTRACTOR.value == "CONTRACTOR"
    assert EcosystemRole.MERCHANT_SELLER.value == "MERCHANT_SELLER"
    assert EcosystemRole.PROPERTY_AGENT.value == "PROPERTY_AGENT"

    assert HandoffTransitionType.HOMEOWNER_TO_DESIGNER.value == "HOMEOWNER_TO_DESIGNER"
    assert HandoffTransitionType.DESIGNER_TO_CONTRACTOR.value == "DESIGNER_TO_CONTRACTOR"
    assert HandoffTransitionType.DESIGNER_TO_MERCHANT.value == "DESIGNER_TO_MERCHANT"
    assert HandoffTransitionType.DESIGNER_TO_AGENT.value == "DESIGNER_TO_AGENT"

    assert HandoffStatus.PENDING_ACCEPTANCE.value == "PENDING_ACCEPTANCE"
    assert HandoffStatus.ACTIVE.value == "ACTIVE"
    assert HandoffStatus.COMPLETED.value == "COMPLETED"
    assert HandoffStatus.REVOKED.value == "REVOKED"


def test_handoff_record_model_instantiation():
    """Validates EcosystemHandoffRecord structure, permitted scopes, and timestamps."""
    h = EcosystemHandoffRecord(
        project_id="proj_alpha",
        transition_type=HandoffTransitionType.HOMEOWNER_TO_DESIGNER,
        source_actor_id="user_homeowner",
        source_role=EcosystemRole.HOMEOWNER,
        target_actor_id="designer_01",
        target_role=EcosystemRole.INTERIOR_DESIGNER,
        target_actor_name="Studio One",
        permitted_scopes=["read_scans", "edit_specifications"],
        transferred_artifact_ids=["room_01"],
        notes="Please prepare modern redesign.",
    )

    assert h.handoff_id.startswith("hnd_")
    assert h.status == HandoffStatus.PENDING_ACCEPTANCE
    assert "read_scans" in h.permitted_scopes
    assert h.accepted_at is None


def test_ecosystem_audit_event_immutability():
    """Validates audit event logging and sensitive flag."""
    evt = EcosystemAuditEvent(
        project_id="proj_alpha",
        actor_id="designer_01",
        actor_name="Elena Vance",
        actor_role=EcosystemRole.INTERIOR_DESIGNER,
        action="EXPORT_DOSSIER",
        resource_type="dossier",
        resource_id="dos_123",
        metadata={"format": "pdf"},
        is_sensitive=True,
    )

    assert evt.event_id.startswith("aud_")
    assert evt.action == "EXPORT_DOSSIER"
    assert evt.is_sensitive is True


# =====================================================================
# Repository Tests: Handoff Lifecycle & Privacy Redactions
# =====================================================================

def test_repository_seeded_handoffs_and_audit():
    """Verifies default seeded handoffs and immutable audit events."""
    assert len(repository.handoffs) >= 2
    assert "hnd_seed_01" in repository.handoffs
    assert "hnd_seed_02" in repository.handoffs

    audits = repository.list_ecosystem_audit_events("proj_seed_01")
    assert len(audits) >= 3
    assert any(a.action == "INITIATE_HANDOFF" for a in audits)


def test_repository_handoff_lifecycle():
    """Tests initiate -> accept -> complete -> revoke handoff transitions."""
    proj = repository.create_project(name="Villa Royale", currency="MYR")

    # 1. Initiate Designer -> Merchant handoff
    h = repository.initiate_handoff(
        project_id=proj.id,
        transition_type=HandoffTransitionType.DESIGNER_TO_MERCHANT,
        source_actor_id="designer_lead",
        source_role=EcosystemRole.INTERIOR_DESIGNER,
        target_actor_id="merch_ikea",
        target_role=EcosystemRole.MERCHANT_SELLER,
        target_actor_name="IKEA Business",
        permitted_scopes=["view_specified_furniture", "confirm_stock"],
        notes="Product specification for Scandinavian dining set.",
    )

    assert h.status == HandoffStatus.PENDING_ACCEPTANCE
    assert h.handoff_id in repository.handoffs

    # Verify audit event recorded
    audits = repository.list_ecosystem_audit_events(proj.id)
    assert len(audits) == 1
    assert audits[0].action == "INITIATE_HANDOFF"

    # 2. Accept handoff
    accepted = repository.accept_handoff(
        handoff_id=h.handoff_id,
        actor_id="merch_ikea",
        actor_name="IKEA Trade Team",
    )
    assert accepted.status == HandoffStatus.ACTIVE
    assert accepted.accepted_at is not None

    # 3. Complete handoff
    completed = repository.complete_handoff(h.handoff_id)
    assert completed.status == HandoffStatus.COMPLETED
    assert completed.completed_at is not None

    # 4. Revoke handoff
    revoked = repository.revoke_handoff(h.handoff_id, reason="Project scope updated")
    assert revoked.status == HandoffStatus.REVOKED

    # Check total audit entries for this project
    updated_audits = repository.list_ecosystem_audit_events(proj.id)
    assert len(updated_audits) == 4
    assert updated_audits[-1].action == "REVOKE_HANDOFF"
    assert updated_audits[-1].is_sensitive is True


def test_repository_workflow_orchestration_summary():
    """Tests 5-phase lifecycle aggregation across ecosystem boundaries."""
    proj = repository.create_project(name="Penthouse 42", currency="MYR")
    summary = repository.get_workflow_orchestration_summary(proj.id)

    assert summary.project_id == proj.id
    assert summary.project_name == "Penthouse 42"
    assert summary.homeowner_phase_status in ("IN_PROGRESS", "COMPLETED")
    assert summary.contractor_phase_status == "NOT_STARTED"
    assert summary.total_participants >= 1


def test_repository_role_scoped_privacy_redaction():
    """
    Validates Phase 6 Exit Gate:
    Ensures strict privacy redaction across Contractor, Merchant, and Agent roles.
    """
    proj = repository.create_project(
        name="Serenity Residence",
        currency="MYR",
        property_address="12 Jalan Ampang, Kuala Lumpur",
    )

    # 1. Contractor perspective: sensitive homeowner contacts & designer margins are shielded
    contractor_view = repository.get_role_scoped_project_view(proj.id, EcosystemRole.CONTRACTOR)
    assert contractor_view.role == EcosystemRole.CONTRACTOR
    assert "confirmed_and_estimated_measurements_checklist" in contractor_view.accessible_sections
    assert "homeowner_personal_phone" in contractor_view.redacted_fields
    assert "designer_markups_and_commissions" in contractor_view.redacted_fields
    assert contractor_view.data_payload["is_full_access"] is False

    # 2. Merchant perspective: full floorplans and contractor tenders shielded
    merchant_view = repository.get_role_scoped_project_view(proj.id, EcosystemRole.MERCHANT_SELLER)
    assert merchant_view.role == EcosystemRole.MERCHANT_SELLER
    assert "full_architectural_floorplans" in merchant_view.redacted_fields
    assert "contractor_tender_packages" in merchant_view.redacted_fields
    assert "specified_catalog_products" in merchant_view.accessible_sections

    # 3. Property Agent perspective: contractor labor rates shielded, staging accessible
    agent_view = repository.get_role_scoped_project_view(proj.id, EcosystemRole.PROPERTY_AGENT)
    assert agent_view.role == EcosystemRole.PROPERTY_AGENT
    assert "virtually_staged_media_pairs" in agent_view.accessible_sections
    assert "subcontractor_unit_labor_rates" in agent_view.redacted_fields

    # 4. Homeowner / Designer perspective: full access
    designer_view = repository.get_role_scoped_project_view(proj.id, EcosystemRole.INTERIOR_DESIGNER)
    assert designer_view.role == EcosystemRole.INTERIOR_DESIGNER
    assert len(designer_view.redacted_fields) == 0
    assert designer_view.data_payload["is_full_access"] is True


# =====================================================================
# REST API Endpoint Tests
# =====================================================================

def test_api_initiate_and_accept_handoff():
    """Tests POST /orchestration/handoffs and POST /orchestration/handoffs/{id}/accept."""
    payload = {
        "project_id": "proj_api_test",
        "transition_type": "DESIGNER_TO_CONTRACTOR",
        "source_actor_id": "designer_01",
        "source_role": "INTERIOR_DESIGNER",
        "target_actor_id": "contractor_01",
        "target_role": "CONTRACTOR",
        "target_actor_name": "BuildCraft Ltd",
        "permitted_scopes": ["view_boq", "submit_bid"],
        "notes": "Tender invitation for carpentry package.",
    }

    res = client.post("/api/v1/orchestration/handoffs", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["transition_type"] == "DESIGNER_TO_CONTRACTOR"
    assert data["status"] == "PENDING_ACCEPTANCE"
    handoff_id = data["handoff_id"]

    # Accept handoff
    accept_payload = {
        "actor_id": "contractor_01",
        "actor_name": "BuildCraft Lead Estimator",
    }
    res_acc = client.post(f"/api/v1/orchestration/handoffs/{handoff_id}/accept", json=accept_payload)
    assert res_acc.status_code == 200
    acc_data = res_acc.json()
    assert acc_data["status"] == "ACTIVE"
    assert acc_data["accepted_at"] is not None


def test_api_complete_and_revoke_handoff():
    """Tests POST /complete and POST /revoke endpoints."""
    res_comp = client.post("/api/v1/orchestration/handoffs/hnd_seed_01/complete")
    assert res_comp.status_code == 200
    assert res_comp.json()["status"] == "COMPLETED"

    res_rev = client.post(
        "/api/v1/orchestration/handoffs/hnd_seed_02/revoke",
        json={"reason": "Contractor declined tender"},
    )
    assert res_rev.status_code == 200
    assert res_rev.json()["status"] == "REVOKED"


def test_api_list_handoffs_and_filters():
    """Tests GET /orchestration/handoffs endpoint."""
    res = client.get("/api/v1/orchestration/handoffs?project_id=proj_seed_01")
    assert res.status_code == 200
    handoffs = res.json()
    assert len(handoffs) >= 2


def test_api_get_orchestration_summary():
    """Tests GET /projects/{id}/orchestration-summary endpoint."""
    res = client.get("/api/v1/projects/proj_seed_01/orchestration-summary")
    assert res.status_code == 200
    data = res.json()
    assert data["project_id"] == "proj_seed_01"
    assert "homeowner_phase_status" in data
    assert "designer_phase_status" in data
    assert len(data["handoffs"]) >= 2


def test_api_get_project_audit_log():
    """Tests GET /projects/{id}/audit-log endpoint."""
    res = client.get("/api/v1/projects/proj_seed_01/audit-log")
    assert res.status_code == 200
    logs = res.json()
    assert len(logs) >= 3
    assert logs[0]["actor_role"] in ("HOMEOWNER", "INTERIOR_DESIGNER")


def test_api_get_role_scoped_project_view():
    """Tests GET /projects/{id}/role-view enforcing Phase 6 Exit Gate privacy redactions."""
    # Contractor perspective
    res_c = client.get("/api/v1/projects/proj_seed_01/role-view?role=CONTRACTOR")
    assert res_c.status_code == 200
    data_c = res_c.json()
    assert data_c["role"] == "CONTRACTOR"
    assert len(data_c["redacted_fields"]) >= 4

    # Property Agent perspective
    res_a = client.get("/api/v1/projects/proj_seed_01/role-view?role=PROPERTY_AGENT")
    assert res_a.status_code == 200
    data_a = res_a.json()
    assert data_a["role"] == "PROPERTY_AGENT"
    assert "virtually_staged_media_pairs" in data_a["accessible_sections"]

    # Invalid role returns 400
    res_inv = client.get("/api/v1/projects/proj_seed_01/role-view?role=INVALID_ROLE")
    assert res_inv.status_code == 400
