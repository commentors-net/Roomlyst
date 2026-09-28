"""
Milestone 5.2 Tests: Collaboration, Design Approvals, Comments, and Review Links.
Verifies spatial pinned comments, approval states, tokenized share links, and permissions.
"""

from fastapi.testclient import TestClient
import pytest

from services.api.app.main import app
from services.api.app.db.repository import repository
from packages.room_model import (
    ApprovalStatus,
    CanonicalRoomModel,
    CommentStatus,
    DesignConstraint,
    DesignVariant,
    DesignVersion,
    SharePermissionTier,
)


@pytest.fixture(autouse=True)
def clean_repository():
    """Ensures clean repository state between tests."""
    repository.projects.clear()
    repository.rooms.clear()
    repository.clients.clear()
    repository.comments.clear()
    repository.approvals.clear()
    repository.share_links.clear()


@pytest.fixture
def client():
    return TestClient(app)


def test_post_and_list_comments(client):
    """Test adding spatial and general comments to a room design."""
    # Create project and room with a design version
    proj = repository.create_project(name="Bangsar Bangalow")
    room = CanonicalRoomModel(
        id="room_collab_01",
        project_id=proj.id,
        name="Living Room",
        original_image_url="https://storage.roomlyst.com/original.jpg",
    )
    v1 = DesignVersion(
        version_id="ver_01",
        room_id="room_collab_01",
        constraints=DesignConstraint(),
        version_number=1,
        variants=[
            DesignVariant(
                variant_id="var_01",
                title="Japandi Living",
                style="Japandi",
                description="Minimalist calm living room",
                style_name="Japandi",
                image_url="https://storage.roomlyst.com/japandi.jpg",
                estimated_cost=25000.0,
            )
        ],
    )
    room.versions.append(v1)
    repository.save_room(room)

    # Post a pinned comment
    cmt_payload = {
        "author_id": "usr_client_01",
        "author_name": "Dato Sri Tan",
        "author_role": "CLIENT",
        "text": "Can we switch this sofa fabric to scratch-resistant linen?",
        "variant_id": "var_01",
        "pin_x": 0.45,
        "pin_y": 0.62,
        "element_id": "obj_sofa_01",
    }
    res = client.post("/api/v1/rooms/room_collab_01/comments", json=cmt_payload)
    assert res.status_code == 200
    cmt_data = res.json()
    assert cmt_data["comment_id"].startswith("cmt_")
    assert cmt_data["author_name"] == "Dato Sri Tan"
    assert cmt_data["pin_x"] == 0.45
    assert cmt_data["status"] == "OPEN"

    # List comments
    res_list = client.get("/api/v1/rooms/room_collab_01/comments")
    assert res_list.status_code == 200
    comments = res_list.json()
    assert len(comments) == 1
    assert comments[0]["text"] == "Can we switch this sofa fabric to scratch-resistant linen?"


def test_update_comment_status_and_delete(client):
    """Test resolving and deleting a design comment."""
    proj = repository.create_project(name="Solaris Loft")
    room = CanonicalRoomModel(id="room_collab_02", project_id=proj.id)
    repository.save_room(room)

    cmt = repository.add_comment(
        room_id="room_collab_02",
        author_id="usr_designer_01",
        author_name="Sarah Architect",
        author_role="LEAD_DESIGNER",
        text="Acoustic paneling to be installed here.",
    )

    # Resolve comment
    patch_res = client.patch(
        f"/api/v1/comments/{cmt.comment_id}/status",
        json={"status": "RESOLVED"},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["status"] == "RESOLVED"

    # Verify filtered list
    open_res = client.get("/api/v1/rooms/room_collab_02/comments?status=OPEN")
    assert open_res.status_code == 200
    assert len(open_res.json()) == 0

    resolved_res = client.get("/api/v1/rooms/room_collab_02/comments?status=RESOLVED")
    assert resolved_res.status_code == 200
    assert len(resolved_res.json()) == 1

    # Delete comment
    del_res = client.delete(f"/api/v1/comments/{cmt.comment_id}")
    assert del_res.status_code == 200
    assert client.get("/api/v1/rooms/room_collab_02/comments").json() == []


def test_design_approval_workflow(client):
    """Test formal client approval workflow and history."""
    proj = repository.create_project(name="Damansara Heights")
    room = CanonicalRoomModel(id="room_collab_03", project_id=proj.id)
    repository.save_room(room)

    # Initial state should be PENDING_REVIEW
    get_res = client.get("/api/v1/rooms/room_collab_03/approvals")
    assert get_res.status_code == 200
    assert get_res.json()["current_status"] == "PENDING_REVIEW"
    assert get_res.json()["history"] == []

    # 1. Request changes
    changes_payload = {
        "status": "CHANGES_REQUESTED",
        "decided_by_name": "Dato Sri Tan",
        "decided_by_role": "CLIENT",
        "notes": "Please offer warmer lighting tone and lower the estimated millwork cost.",
        "variant_id": "var_concept_01",
    }
    c_res = client.post("/api/v1/rooms/room_collab_03/approvals", json=changes_payload)
    assert c_res.status_code == 200
    assert c_res.json()["status"] == "CHANGES_REQUESTED"
    assert c_res.json()["decided_at"] is not None

    # Verify status changed
    get_res2 = client.get("/api/v1/rooms/room_collab_03/approvals")
    assert get_res2.json()["current_status"] == "CHANGES_REQUESTED"
    assert len(get_res2.json()["history"]) == 1

    # 2. Final approval
    approve_payload = {
        "status": "APPROVED",
        "decided_by_name": "Dato Sri Tan",
        "decided_by_role": "CLIENT",
        "notes": "Revision 2 accepted. Ready for contractor tender.",
        "variant_id": "var_concept_02",
    }
    appr_res = client.post("/api/v1/rooms/room_collab_03/approvals", json=approve_payload)
    assert appr_res.status_code == 200
    assert appr_res.json()["status"] == "APPROVED"

    get_res3 = client.get("/api/v1/rooms/room_collab_03/approvals")
    assert get_res3.json()["current_status"] == "APPROVED"
    assert len(get_res3.json()["history"]) == 2


def test_shareable_review_links_lifecycle(client):
    """Test generating, listing, and revoking review links."""
    proj = repository.create_project(name="Ampang Residence")

    # Generate share link
    link_payload = {
        "room_id": "room_amp_01",
        "created_by": "designer_elena",
        "permission": "CAN_APPROVE",
        "allow_comments": True,
        "allow_approvals": True,
        "expires_in_days": 7,
    }
    res = client.post(f"/api/v1/projects/{proj.id}/share-links", json=link_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["link_id"].startswith("shl_")
    token = data["token"]
    assert len(token) >= 16
    assert data["permission"] == "CAN_APPROVE"
    assert data["allow_approvals"] is True

    # List links
    list_res = client.get(f"/api/v1/projects/{proj.id}/share-links")
    assert list_res.status_code == 200
    assert len(list_res.json()) == 1

    # Revoke link
    del_res = client.delete(f"/api/v1/share-links/{data['link_id']}")
    assert del_res.status_code == 200
    assert client.get(f"/api/v1/projects/{proj.id}/share-links").json() == []

    # Accessing revoked token should 404
    revoked_access = client.get(f"/api/v1/review/{token}")
    assert revoked_access.status_code == 404


def test_public_review_session_access_and_actions(client):
    """Test client accessing review presentation session and interacting via token."""
    proj = repository.create_project(name="Mont Kiara Penthouse", property_address="Unit 22-01")
    room = CanonicalRoomModel(
        id="room_mk_01",
        project_id=proj.id,
        name="Master Bedroom",
        original_image_url="https://storage.roomlyst.com/mk_bed_orig.jpg",
    )
    v1 = DesignVersion(
        version_id="ver_mk_01",
        room_id="room_mk_01",
        constraints=DesignConstraint(),
        version_number=1,
        variants=[
            DesignVariant(
                variant_id="var_mk_japandi",
                title="Warm Japandi Suite",
                style="Japandi",
                description="Cozy natural wood palette",
                style_name="Warm Japandi",
                image_url="https://storage.roomlyst.com/mk_japandi.jpg",
                estimated_cost=32000.0,
                is_favorite=True,
            )
        ],
    )
    room.versions.append(v1)
    repository.save_room(room)

    # Create link with CAN_APPROVE permission
    link = repository.create_share_link(
        project_id=proj.id,
        room_id="room_mk_01",
        permission=SharePermissionTier.CAN_APPROVE,
        allow_comments=True,
        allow_approvals=True,
    )

    # 1. Fetch review session package
    session_res = client.get(f"/api/v1/review/{link.token}")
    assert session_res.status_code == 200
    session_data = session_res.json()
    assert session_data["project_name"] == "Mont Kiara Penthouse"
    assert session_data["room_name"] == "Master Bedroom"
    assert session_data["original_image_url"] == "https://storage.roomlyst.com/mk_bed_orig.jpg"
    assert session_data["selected_variant_id"] == "var_mk_japandi"
    assert session_data["selected_variant_style"] == "Japandi"
    assert session_data["allow_approvals"] is True

    # 2. Post a comment via review token
    comment_payload = {
        "author_id": "guest_client",
        "author_name": "Mrs. Lee",
        "text": "Love the wall wood slats! Can we ensure the bed frame is included in the quote?",
        "pin_x": 0.5,
        "pin_y": 0.4,
    }
    cmt_res = client.post(f"/api/v1/review/{link.token}/comments", json=comment_payload)
    assert cmt_res.status_code == 200
    assert cmt_res.json()["author_name"] == "Mrs. Lee"

    # 3. Submit approval decision via review token
    decide_payload = {
        "status": "APPROVED",
        "decided_by_name": "Mrs. Lee",
        "notes": "Approved for tender!",
    }
    dec_res = client.post(f"/api/v1/review/{link.token}/decide", json=decide_payload)
    assert dec_res.status_code == 200
    assert dec_res.json()["status"] == "APPROVED"

    # Verify session now reflects approved state
    updated_session = client.get(f"/api/v1/review/{link.token}").json()
    assert updated_session["approval_status"] == "APPROVED"
    assert len(updated_session["comments"]) == 1


def test_review_permission_enforcement(client):
    """Test permission tier restrictions (CAN_VIEW blocks comments and approvals)."""
    proj = repository.create_project(name="Bangsar South Studio")
    room = CanonicalRoomModel(id="room_bs_01", project_id=proj.id)
    repository.save_room(room)

    # Create view-only link
    view_only_link = repository.create_share_link(
        project_id=proj.id,
        room_id="room_bs_01",
        permission=SharePermissionTier.CAN_VIEW,
        allow_comments=False,
        allow_approvals=False,
    )

    # Comment attempt should fail with 403
    cmt_attempt = client.post(
        f"/api/v1/review/{view_only_link.token}/comments",
        json={"author_id": "anon", "author_name": "Anon", "text": "Hello"},
    )
    assert cmt_attempt.status_code == 403

    # Approval attempt should fail with 403
    appr_attempt = client.post(
        f"/api/v1/review/{view_only_link.token}/decide",
        json={"status": "APPROVED"},
    )
    assert appr_attempt.status_code == 403
