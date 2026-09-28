"""
tests/test_design_variant_management.py
=======================================
Milestone 2.5: Design Variant Management, Branching, Comparison, and Favorites.
Compliant with Blueprint Section 16 & 39.2.
"""

import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient

from packages.room_model.schema import (
    CanonicalRoomModel,
    DesignConstraint,
    DesignVariant,
    DesignVersion,
    Geometry,
    Point2D,
    WallSegment,
)
from services.ai_worker.pipelines.generation import LocalRedesignGenerator
from services.ai_worker.pipelines.variant_manager import VariantManager


# ---------------------------------------------------------------------------
# Fixtures & Helpers
# ---------------------------------------------------------------------------

@pytest.fixture
def variant_manager():
    return VariantManager()


@pytest.fixture
def redesign_generator(tmp_path):
    return LocalRedesignGenerator(output_dir=str(tmp_path))


@pytest.fixture
def sample_image():
    return Image.new("RGB", (300, 200), color=(220, 210, 200))


def _make_room_with_versions() -> CanonicalRoomModel:
    """Helper creating a canonical room model with 2 design versions."""
    ws = [
        WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=4.0, y=0.0), length_m=4.0),
        WallSegment(start_point=Point2D(x=4.0, y=0.0), end_point=Point2D(x=4.0, y=3.0), length_m=3.0),
        WallSegment(start_point=Point2D(x=4.0, y=3.0), end_point=Point2D(x=0.0, y=3.0), length_m=4.0),
        WallSegment(start_point=Point2D(x=0.0, y=3.0), end_point=Point2D(x=0.0, y=0.0), length_m=3.0),
    ]
    geom = Geometry(wall_segments=ws, floor_area_sqm=12.0)
    room = CanonicalRoomModel(
        room_type="living_room",
        geometry=geom,
    )

    # Version 1 (Initial Generation)
    v1_variants = [
        DesignVariant(
            variant_id="var_v1_01",
            title="Concept 1: Warm Modern",
            style="Warm Modern",
            image_url="/storage/v1_01.jpg",
            description="Warm tones with oak floor",
            structural_preservation_score=0.95,
            changes_made=["Preserved sofa", "Oak flooring", "Travertine coffee table"],
            estimated_cost=5000.0,
        ),
        DesignVariant(
            variant_id="var_v1_02",
            title="Concept 2: Japandi",
            style="Japandi",
            image_url="/storage/v1_02.jpg",
            description="Organic minimalism",
            structural_preservation_score=0.93,
            changes_made=["Preserved sofa", "Light birch flooring", "Slatted console"],
            estimated_cost=6200.0,
        ),
    ]
    ver1 = DesignVersion(
        id="ver_001",
        room_id=room.id,
        version_number=1,
        branch_label="Main Branch",
        constraints=DesignConstraint(styles=["Warm Modern"]),
        variants=v1_variants,
    )
    room.versions.append(ver1)

    # Version 2 (Branched from Concept 2)
    v2_variants = [
        DesignVariant(
            variant_id="var_v2_01",
            title="Concept 2A: Darker Japandi",
            style="Japandi",
            image_url="/storage/v2_01.jpg",
            description="Japandi with walnut finishes",
            structural_preservation_score=0.92,
            changes_made=["Preserved sofa", "Walnut flooring", "Slatted console"],
            estimated_cost=7000.0,
            parent_variant_id="var_v1_02",
        ),
    ]
    ver2 = DesignVersion(
        id="ver_002",
        room_id=room.id,
        parent_version_id="ver_001",
        parent_variant_id="var_v1_02",
        branch_label="Darker Walnut Iteration",
        version_number=2,
        constraints=DesignConstraint(styles=["Japandi"]),
        variants=v2_variants,
    )
    room.versions.append(ver2)

    return room


# ---------------------------------------------------------------------------
# 1. VariantManager Unit Tests
# ---------------------------------------------------------------------------

class TestVariantManagerUnit:
    def test_find_variant(self, variant_manager):
        room = _make_room_with_versions()
        v = variant_manager.find_variant(room, "var_v1_02")
        assert v is not None
        assert v.style == "Japandi"
        assert v.variant_id == "var_v1_02"

    def test_find_variant_not_found(self, variant_manager):
        room = _make_room_with_versions()
        assert variant_manager.find_variant(room, "non_existent") is None

    def test_find_version(self, variant_manager):
        room = _make_room_with_versions()
        ver = variant_manager.find_version(room, "ver_002")
        assert ver is not None
        assert ver.branch_label == "Darker Walnut Iteration"
        assert ver.parent_version_id == "ver_001"

    def test_toggle_favorite_on_and_off(self, variant_manager):
        room = _make_room_with_versions()
        # Toggle ON
        v = variant_manager.toggle_favorite(room, "var_v1_01", notes="Top pick for living room")
        assert v is not None
        assert v.is_favorite is True
        assert v.favorite_notes == "Top pick for living room"
        assert v.starred_at is not None

        # Toggle OFF
        v2 = variant_manager.toggle_favorite(room, "var_v1_01")
        assert v2 is not None
        assert v2.is_favorite is False
        assert v2.starred_at is None

    def test_toggle_favorite_explicit_state(self, variant_manager):
        room = _make_room_with_versions()
        v = variant_manager.toggle_favorite(room, "var_v1_02", is_favorite=True)
        assert v.is_favorite is True
        v = variant_manager.toggle_favorite(room, "var_v1_02", is_favorite=True)
        assert v.is_favorite is True  # idempotent when explicit

    def test_get_favorites(self, variant_manager):
        room = _make_room_with_versions()
        variant_manager.toggle_favorite(room, "var_v1_01")
        variant_manager.toggle_favorite(room, "var_v2_01")

        favs = variant_manager.get_favorites(room)
        assert len(favs) == 2
        var_ids = [f["variant"]["variant_id"] for f in favs]
        assert "var_v1_01" in var_ids
        assert "var_v2_01" in var_ids

    def test_compare_variants_deltas(self, variant_manager):
        room = _make_room_with_versions()
        var_a = variant_manager.find_variant(room, "var_v1_01")
        var_b = variant_manager.find_variant(room, "var_v1_02")

        comp = variant_manager.compare_variants(var_a, var_b)
        assert comp.variant_a_id == "var_v1_01"
        assert comp.variant_b_id == "var_v1_02"
        # cost delta: 6200 - 5000 = 1200
        assert comp.cost_delta == 1200.0
        # preservation delta: 0.93 - 0.95 = -0.02
        assert abs(comp.preservation_score_delta - (-0.02)) < 0.001
        # shared changes: "Preserved sofa"
        assert "Preserved sofa" in comp.shared_changes
        # unique to A: "Oak flooring", "Travertine coffee table"
        assert "Oak flooring" in comp.changes_unique_to_a
        # unique to B: "Light birch flooring", "Slatted console"
        assert "Light birch flooring" in comp.changes_unique_to_b

    def test_get_version_tree(self, variant_manager):
        room = _make_room_with_versions()
        tree = variant_manager.get_version_tree(room)
        assert len(tree) == 2
        assert tree[0]["branch_label"] == "Main Branch"
        assert tree[1]["branch_label"] == "Darker Walnut Iteration"
        assert tree[1]["parent_version_id"] == "ver_001"


# ---------------------------------------------------------------------------
# 2. Redesign Pipeline Branching Tests
# ---------------------------------------------------------------------------

class TestBranchingGeneration:
    def test_generate_redesigns_with_branch_metadata(self, redesign_generator, sample_image):
        ws = [
            WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=4.0, y=0.0), length_m=4.0),
            WallSegment(start_point=Point2D(x=4.0, y=0.0), end_point=Point2D(x=4.0, y=3.0), length_m=3.0),
            WallSegment(start_point=Point2D(x=4.0, y=3.0), end_point=Point2D(x=0.0, y=3.0), length_m=4.0),
            WallSegment(start_point=Point2D(x=0.0, y=3.0), end_point=Point2D(x=0.0, y=0.0), length_m=3.0),
        ]
        room = CanonicalRoomModel(room_type="living_room", geometry=Geometry(wall_segments=ws, floor_area_sqm=12.0))

        # 1. Generate root version
        res1 = redesign_generator.generate_redesigns(
            image=sample_image,
            room_model=room,
            constraints=DesignConstraint(styles=["Warm Modern"]),
            count=3,
        )
        ver1 = res1.data
        assert ver1.version_number == 1
        assert ver1.parent_version_id is None
        assert ver1.branch_label == "Main Branch"
        assert len(ver1.variants) == 3

        # 2. Branch from Concept 1
        selected_parent_variant = ver1.variants[0].variant_id
        res2 = redesign_generator.generate_redesigns(
            image=sample_image,
            room_model=room,
            constraints=DesignConstraint(styles=["Japandi"], free_text_prompt="Use lighter timber"),
            count=3,
            parent_version_id=ver1.id,
            parent_variant_id=selected_parent_variant,
            branch_label="Japandi Light Timber Branch",
        )
        ver2 = res2.data
        assert ver2.version_number == 2
        assert ver2.parent_version_id == ver1.id
        assert ver2.parent_variant_id == selected_parent_variant
        assert ver2.branch_label == "Japandi Light Timber Branch"
        # Check variants inherit parent_variant_id
        for v in ver2.variants:
            assert v.parent_variant_id == selected_parent_variant

        # Room model now contains both versions
        assert len(room.versions) == 2


# ---------------------------------------------------------------------------
# 3. REST API Endpoint Tests
# ---------------------------------------------------------------------------

@pytest.fixture
def client():
    from services.api.app.main import app
    return TestClient(app)


def _create_test_room(client) -> str:
    """Helper to upload an image and create a room."""
    img = Image.new("RGB", (200, 150), color=(180, 160, 140))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    files = {"file": ("room.jpg", buf.read(), "image/jpeg")}
    data = {"room_name": "Variant Test Room", "room_type": "living_room"}
    resp = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data)
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


class TestVariantManagementEndpoints:
    def test_get_versions_empty_initially(self, client):
        room_id = _create_test_room(client)
        resp = client.get(f"/api/v1/rooms/{room_id}/versions")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_generate_and_get_versions(self, client):
        room_id = _create_test_room(client)
        # Generate initial version
        gen_resp = client.post(
            f"/api/v1/rooms/{room_id}/design-requests",
            json={
                "styles": ["Warm Modern Minimalist"],
                "budget_amount": 16000.0,
            },
        )
        assert gen_resp.status_code == 200
        initial_version = gen_resp.json()
        assert initial_version["version_number"] == 1
        assert len(initial_version["variants"]) == 3

        # Query versions
        vers_resp = client.get(f"/api/v1/rooms/{room_id}/versions")
        assert vers_resp.status_code == 200
        versions = vers_resp.json()
        assert len(versions) == 1
        assert versions[0]["id"] == initial_version["id"]

    def test_get_specific_version_by_id(self, client):
        room_id = _create_test_room(client)
        gen_resp = client.post(
            f"/api/v1/rooms/{room_id}/design-requests",
            json={"styles": ["Scandinavian"]},
        )
        ver_id = gen_resp.json()["id"]

        resp = client.get(f"/api/v1/rooms/{room_id}/versions/{ver_id}")
        assert resp.status_code == 200
        assert resp.json()["id"] == ver_id

    def test_branch_version_endpoint(self, client):
        room_id = _create_test_room(client)
        # Generate root version
        gen_resp = client.post(
            f"/api/v1/rooms/{room_id}/design-requests",
            json={"styles": ["Warm Modern"]},
        )
        parent_ver = gen_resp.json()
        parent_var_id = parent_ver["variants"][0]["variant_id"]

        # Call branch endpoint
        branch_payload = {
            "parent_version_id": parent_ver["id"],
            "parent_variant_id": parent_var_id,
            "branch_label": "Oak Flooring Exploration",
            "styles": ["Japandi"],
            "budget_amount": 18000.0,
            "free_text_prompt": "Darker oak tone with matte finish",
        }
        branch_resp = client.post(f"/api/v1/rooms/{room_id}/versions/branch", json=branch_payload)
        assert branch_resp.status_code == 200, branch_resp.text
        branch_data = branch_resp.json()
        assert branch_data["parent_version_id"] == parent_ver["id"]
        assert branch_data["parent_variant_id"] == parent_var_id
        assert branch_data["branch_label"] == "Oak Flooring Exploration"
        assert branch_data["version_number"] == 2
        assert len(branch_data["variants"]) == 3

        # Verify room now has 2 versions
        all_vers = client.get(f"/api/v1/rooms/{room_id}/versions").json()
        assert len(all_vers) == 2

    def test_favorite_toggle_and_retrieval_endpoints(self, client):
        room_id = _create_test_room(client)
        gen_resp = client.post(
            f"/api/v1/rooms/{room_id}/design-requests",
            json={"styles": ["Warm Modern Minimalist"]},
        )
        variant_id = gen_resp.json()["variants"][0]["variant_id"]

        # 1. Star as favorite
        fav_resp = client.post(
            f"/api/v1/rooms/{room_id}/variants/{variant_id}/favorite",
            json={"is_favorite": True, "notes": "Preferred choice for renovation"},
        )
        assert fav_resp.status_code == 200
        fav_data = fav_resp.json()
        assert fav_data["is_favorite"] is True
        assert fav_data["favorite_notes"] == "Preferred choice for renovation"

        # 2. Get favorites list
        list_resp = client.get(f"/api/v1/rooms/{room_id}/favorites")
        assert list_resp.status_code == 200
        fav_list = list_resp.json()
        assert len(fav_list) == 1
        assert fav_list[0]["variant"]["variant_id"] == variant_id

        # 3. Un-favorite
        unfav_resp = client.post(
            f"/api/v1/rooms/{room_id}/variants/{variant_id}/favorite",
            json={"is_favorite": False},
        )
        assert unfav_resp.status_code == 200
        assert unfav_resp.json()["is_favorite"] is False

        # Favorites list should now be empty
        assert client.get(f"/api/v1/rooms/{room_id}/favorites").json() == []

    def test_compare_variants_endpoint(self, client):
        room_id = _create_test_room(client)
        gen_resp = client.post(
            f"/api/v1/rooms/{room_id}/design-requests",
            json={"styles": ["Warm Modern Minimalist"]},
        )
        variants = gen_resp.json()["variants"]
        var_a_id = variants[0]["variant_id"]
        var_b_id = variants[1]["variant_id"]

        comp_resp = client.get(
            f"/api/v1/rooms/{room_id}/variants/compare?variant_a_id={var_a_id}&variant_b_id={var_b_id}"
        )
        assert comp_resp.status_code == 200, comp_resp.text
        comp = comp_resp.json()
        assert comp["variant_a_id"] == var_a_id
        assert comp["variant_b_id"] == var_b_id
        assert "cost_delta" in comp
        assert "preservation_score_delta" in comp
        assert isinstance(comp["shared_changes"], list)
        assert isinstance(comp["changes_unique_to_a"], list)
        assert isinstance(comp["changes_unique_to_b"], list)

    def test_compare_variants_non_existent_returns_404(self, client):
        room_id = _create_test_room(client)
        resp = client.get(
            f"/api/v1/rooms/{room_id}/variants/compare?variant_a_id=fake_a&variant_b_id=fake_b"
        )
        assert resp.status_code == 404
