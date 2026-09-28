"""
Tests for Milestone 4.4: Renovation Plan Output & Contractor Handover Brief.
Compliant with Blueprint Section 41 & Milestone 4.4 requirements.
"""

import pytest
from fastapi.testclient import TestClient

from packages.room_model import (
    BudgetPlan,
    CanonicalRoomModel,
    CurrencyCode,
    DesignConstraint,
    DesignVariant,
    DesignVersion,
    Geometry,
    MaterialCategory,
    MaterialTakeoffItem,
    MaterialTakeoffReport,
    Measurement,
    MeasurementSource,
    ObjectAction,
    OpeningType,
    Point2D,
    ProductCategory,
    ProductDimensions,
    ProductFitStatus,
    ProductRecommendation,
    ProductRecommendationReport,
    CatalogProduct,
    RenovationPlanVersion,
    RenovationTier,
    RoomObject,
    RoomOpening,
    RoomSurface,
    SurfaceType,
    WallSegment,
)
from services.ai_worker.pipelines.renovation_plan_builder import RenovationPlanBuilder
from services.api.app.db.repository import repository
from services.api.app.main import app


@pytest.fixture(scope="module")
def builder() -> RenovationPlanBuilder:
    return RenovationPlanBuilder()


@pytest.fixture(scope="module")
def client() -> TestClient:
    return TestClient(app)


def _make_comprehensive_room() -> CanonicalRoomModel:
    ws = [
        WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=5.0, y=0.0), length_m=5.0),
        WallSegment(start_point=Point2D(x=5.0, y=0.0), end_point=Point2D(x=5.0, y=4.0), length_m=4.0),
        WallSegment(start_point=Point2D(x=5.0, y=4.0), end_point=Point2D(x=0.0, y=4.0), length_m=5.0),
        WallSegment(start_point=Point2D(x=0.0, y=4.0), end_point=Point2D(x=0.0, y=0.0), length_m=4.0),
    ]
    geom = Geometry(
        wall_segments=ws,
        ceiling_height_m=2.85,
        floor_area_sqm=20.0,
        estimated_width_m=4.0,
        estimated_length_m=5.0,
    )

    measurements = [
        Measurement(
            id="m_wall_len",
            name="Main North Wall Length",
            value=5.0,
            unit="m",
            source=MeasurementSource.LIDAR_NATIVE,
            confidence=0.98,
            verified_by_user=True,
            measurement_type="length",
            entity_type="wall",
            entity_id="ws_0",
        ),
        Measurement(
            id="m_ceil_h",
            name="Ceiling Height",
            value=2.85,
            unit="m",
            source=MeasurementSource.USER_VERIFIED,
            confidence=1.0,
            verified_by_user=True,
            measurement_type="height",
            entity_type="room",
            entity_id="room_plan_test_01",
        ),
        Measurement(
            id="m_window_w",
            name="Window Width",
            value=1.80,
            unit="m",
            source=MeasurementSource.MONOCULAR_DEPTH,
            confidence=0.82,
            verified_by_user=False,
            measurement_type="width",
            entity_type="opening",
            entity_id="opn_window",
        ),
    ]

    objects = [
        RoomObject(id="obj_sofa_1", name="Old Fabric Sofa", category="sofa", action=ObjectAction.REPLACE),
        RoomObject(id="obj_tv_unit", name="Built-in Bookshelf", category="storage", action=ObjectAction.KEEP),
        RoomObject(id="obj_carpet", name="Worn Rug", category="rug", action=ObjectAction.REMOVE),
    ]

    openings = [
        RoomOpening(id="opn_main_door", name="Entry Doorway", opening_type=OpeningType.DOOR, action=ObjectAction.KEEP),
        RoomOpening(id="opn_window", name="Living Balcony Window", opening_type=OpeningType.WINDOW, action=ObjectAction.KEEP),
    ]

    surfaces = [
        RoomSurface(id="surf_floor", name="Existing Parquet Floor", surface_type=SurfaceType.FLOOR, action=ObjectAction.REPLACE),
        RoomSurface(id="surf_north_wall", name="North Feature Wall", surface_type=SurfaceType.WALL, action=ObjectAction.RESTYLE),
    ]

    # Variants
    var1 = DesignVariant(
        variant_id="var_plan_001",
        title="Japandi Warm Harmony",
        style="Japandi",
        image_url="https://images.roomlyst.com/var_001.jpg",
        description="Warm oak accents with textured lime wash walls.",
        structural_preservation_score=0.95,
        changes_made=["Replaced sofa with low profile Japandi bench", "Engineered oak flooring"],
        is_favorite=True,
    )
    ver = DesignVersion(
        id="ver_001",
        room_id="room_plan_test_01",
        constraints=DesignConstraint(room_type="living_room", styles=["Japandi"]),
        variants=[var1],
    )

    # Takeoff
    takeoff = MaterialTakeoffReport(
        report_id="takeoff_plan_01",
        room_id="room_plan_test_01",
        gross_floor_area_sqm=20.0,
        net_wall_area_sqm=42.5,
        ceiling_area_sqm=20.0,
        baseboard_perimeter_m=16.2,
        openings_deducted_area_sqm=4.8,
        default_waste_factors={"FLOORING": 10.0, "WALL_PAINT": 10.0},
        items=[
            MaterialTakeoffItem(
                item_id="it_floor",
                category=MaterialCategory.FLOORING,
                name="Engineered Oak Plank",
                description="Premium engineered oak flooring planks",
                net_quantity=20.0,
                unit="sqm",
                waste_factor_pct=10.0,
                waste_quantity=2.0,
                gross_quantity=22.0,
                min_recommended_quantity=21.0,
                max_recommended_quantity=23.0,
                packaging_spec="2.2 sqm / carton",
                estimated_packages=10,
            ),
        ],
        accuracy_tier="EXACT",
    )

    # Product recommendations
    prod = CatalogProduct(
        id="prod_sofa_101",
        sku="SF-JAP-01",
        name="Muji Style Low Profile Sofa",
        brand="Muji",
        category=ProductCategory.SOFA,
        dimensions=ProductDimensions(width_m=2.0, depth_m=0.85, height_m=0.75),
        price=2800.0,
        currency=CurrencyCode.MYR,
        retailer="Muji MY",
        availability="IN_STOCK",
        lead_time_days=5,
    )
    rec = ProductRecommendation(
        target_element_id="obj_sofa_1",
        target_element_label="Old Fabric Sofa",
        product=prod,
        match_score=0.96,
        fit_status=ProductFitStatus.PERFECT_FIT,
        fit_notes="Maintains 0.65m walkway clearance.",
        is_assigned=True,
    )
    recs_report = ProductRecommendationReport(
        report_id="recs_plan_01",
        room_id="room_plan_test_01",
        recommendations=[rec],
        applied_style="Japandi",
        applied_tier=RenovationTier.MODERATE,
        applied_currency=CurrencyCode.MYR,
        total_recommended_spend=2800.0,
    )

    # Budget plan
    budget = BudgetPlan(
        plan_id="bgt_plan_01",
        total_budget=25000.0,
        currency=CurrencyCode.MYR,
        renovation_tier=RenovationTier.MODERATE,
        total_estimated_cost=20500.0,
        total_allocated=25000.0,
        subtotal_materials=12500.0,
        subtotal_labor=8000.0,
        contingency_pct=10.0,
        contingency_amount=2050.0,
        tax_name="SST",
        tax_rate_pct=8.0,
        tax_amount=1804.0,
        grand_total=24354.0,
        is_within_budget=True,
        disclaimer="Indicative renovation budget estimate.",
    )

    return CanonicalRoomModel(
        id="room_plan_test_01",
        project_id="proj_plan_test_01",
        name="Master Living Room",
        room_type="living_room",
        geometry=geom,
        measurements=measurements,
        objects=objects,
        openings=openings,
        surfaces=surfaces,
        versions=[ver],
        material_takeoff=takeoff,
        product_recommendations=recs_report,
        budget_plan=budget,
    )


# ---------------------------------------------------------------------------
# 1. Complete Renovation Plan Generation Tests
# ---------------------------------------------------------------------------

class TestRenovationPlanGeneration:
    def test_complete_renovation_plan_generation(self, builder):
        room = _make_comprehensive_room()
        plan = builder.generate_plan(
            room=room,
            selected_variant_id="var_plan_001",
            selected_tier=RenovationTier.MODERATE,
            currency=CurrencyCode.MYR,
            project_name="Bukit Tunku Residence",
            plan_title="Contractor Handover Specification v1",
        )

        assert isinstance(plan, RenovationPlanVersion)
        assert plan.version_number == 1
        assert plan.version_tag == "v1"
        assert plan.room_id == room.id
        assert plan.project_id == room.project_id
        assert "Bukit Tunku" in plan.project_summary or "Master Living Room" in plan.project_summary

        # Check Room info
        assert plan.room_information["floor_area_sqm"] == 20.0
        assert plan.room_information["ceiling_height_m"] == 2.85

        # Check Selected Design
        assert plan.selected_design["variant_id"] == "var_plan_001"
        assert plan.selected_design["title"] == "Japandi Warm Harmony"

        # Check Scope of Work & Items
        assert len(plan.items_to_retain) >= 2  # door, window, bookshelf
        assert len(plan.items_to_remove) >= 1  # worn rug
        assert len(plan.items_to_replace) >= 2  # sofa, floor, wall

        # Check Materials Takeoff
        assert plan.materials_and_quantities is not None
        assert plan.materials_and_quantities["gross_floor_area_sqm"] == 20.0
        assert len(plan.materials_and_quantities["items"]) == 1

        # Check Products
        assert len(plan.product_recommendations) == 1
        assert plan.product_recommendations[0]["is_assigned"] is True
        assert plan.product_recommendations[0]["brand"] == "Muji"

        # Check Budget
        assert plan.budget_estimate is not None
        assert plan.budget_estimate["total_budget"] == 25000.0
        assert plan.budget_estimate["grand_total"] == 24354.0

        # Check Measurement Confidence
        meas = plan.measurement_confidence
        assert meas["total_measurements"] == 3
        assert meas["confirmed_measurements_count"] == 2  # wall len (lidar/user) + ceiling (user)
        assert meas["unverified_measurements_count"] == 1  # window (monocular)

        # Check Execution Sequence
        assert len(plan.execution_sequence) == 11
        safety_critical_phases = [p for p in plan.execution_sequence if p.is_safety_critical]
        assert len(safety_critical_phases) >= 2

        # Check Markdown Export
        assert plan.export_markdown is not None
        assert "# Contractor Handover Specification v1" in plan.export_markdown
        assert "## 1. Project Summary" in plan.export_markdown
        assert "## 13. Suggested Advisory Execution Sequence" in plan.export_markdown
        assert "Statutory Notice:" in plan.safety_critical_disclaimer

    def test_missing_optional_information_handled_gracefully(self, builder):
        """Plan generation works cleanly when budget, takeoff, and recommendations are absent."""
        room = CanonicalRoomModel(
            id="room_bare_001",
            name="Empty Guest Room",
            room_type="bedroom",
            geometry=Geometry(floor_area_sqm=15.0, ceiling_height_m=2.70),
        )

        plan = builder.generate_plan(
            room=room,
            selected_style="Minimalist",
            selected_tier=RenovationTier.ECONOMY,
            currency=CurrencyCode.SGD,
        )

        assert plan.version_number == 1
        assert plan.version_tag == "v1"
        assert plan.materials_and_quantities is None
        assert plan.product_recommendations == []
        assert plan.budget_estimate is None
        assert plan.measurement_confidence["total_measurements"] == 0
        assert len(plan.execution_sequence) == 11
        assert plan.export_markdown is not None

    def test_estimated_vs_confirmed_measurements_distinguished(self, builder):
        """Uncertain AI measurements must be clearly flagged and require verification."""
        room = _make_comprehensive_room()
        plan = builder.generate_plan(room=room)

        meas_items = plan.measurement_confidence["measurements"]
        unverified_items = [m for m in meas_items if m["requires_manual_verification"]]
        confirmed_items = [m for m in meas_items if m["is_confirmed"]]

        assert len(unverified_items) == 1
        assert unverified_items[0]["label"] == "Window Width"
        assert unverified_items[0]["is_confirmed"] is False

        assert len(confirmed_items) == 2
        for ci in confirmed_items:
            assert ci["is_confirmed"] is True
            assert ci["requires_manual_verification"] is False

        # Warnings must specifically mention unverified items
        assert any("Window Width" in w or "unverified" in w for w in plan.warnings_and_verifications)

    def test_plan_versioning_and_regeneration(self, builder):
        """Regenerating a plan generates v2, v3 without losing earlier versions."""
        room = _make_comprehensive_room()
        assert len(room.renovation_plans) == 0

        # Generate v1
        plan_v1 = builder.generate_plan(room=room, plan_title="Initial Scheme")
        assert plan_v1.version_number == 1
        assert plan_v1.version_tag == "v1"
        assert len(room.renovation_plans) == 1

        # Generate v2 with changed tier
        plan_v2 = builder.generate_plan(room=room, selected_tier=RenovationTier.PREMIUM, plan_title="Premium Upgrade")
        assert plan_v2.version_number == 2
        assert plan_v2.version_tag == "v2"
        assert plan_v2.selected_tier == RenovationTier.PREMIUM
        assert len(room.renovation_plans) == 2

        # Generate v3
        plan_v3 = builder.generate_plan(room=room, selected_style="Scandinavian", plan_title="Scandi Alternative")
        assert plan_v3.version_number == 3
        assert plan_v3.version_tag == "v3"
        assert len(room.renovation_plans) == 3

        # Historical v1 and v2 are intact
        assert room.renovation_plans[0].version_tag == "v1"
        assert room.renovation_plans[1].version_tag == "v2"
        assert room.renovation_plans[2].version_tag == "v3"


# ---------------------------------------------------------------------------
# 2. REST API Endpoints Tests
# ---------------------------------------------------------------------------

class TestRenovationPlanEndpoints:
    def test_create_renovation_plan_endpoint(self, client):
        room = _make_comprehensive_room()
        repository.save_room(room)

        payload = {
            "selected_variant_id": "var_plan_001",
            "selected_style": "Japandi",
            "selected_tier": "MODERATE",
            "currency": "MYR",
            "project_name": "Lakefront Villa",
            "plan_title": "Lakefront Phase 1 Plan",
        }

        res = client.post(f"/api/v1/rooms/{room.id}/renovation-plans", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data["plan_id"]
        assert data["version_tag"] == "v1"
        assert data["room_id"] == room.id
        assert data["selected_style"] == "Japandi"
        assert "execution_sequence" in data
        assert len(data["execution_sequence"]) == 11

    def test_get_renovation_plans_list(self, client):
        room = _make_comprehensive_room()
        repository.save_room(room)

        # Create v1
        client.post(f"/api/v1/rooms/{room.id}/renovation-plans", json={"plan_title": "First Draft"})
        # Create v2
        client.post(f"/api/v1/rooms/{room.id}/renovation-plans", json={"plan_title": "Second Draft"})

        res = client.get(f"/api/v1/rooms/{room.id}/renovation-plans")
        assert res.status_code == 200
        plans = res.json()
        assert len(plans) >= 2
        tags = [p["version_tag"] for p in plans]
        assert "v1" in tags
        assert "v2" in tags

    def test_get_single_renovation_plan(self, client):
        room = _make_comprehensive_room()
        repository.save_room(room)

        res_create = client.post(f"/api/v1/rooms/{room.id}/renovation-plans", json={"plan_title": "Target Plan"})
        plan_id = res_create.json()["plan_id"]

        res = client.get(f"/api/v1/rooms/{room.id}/renovation-plans/{plan_id}")
        assert res.status_code == 200
        data = res.json()
        assert data["plan_id"] == plan_id
        assert data["title"] == "Target Plan"

    def test_export_renovation_plan_markdown(self, client):
        room = _make_comprehensive_room()
        repository.save_room(room)

        res_create = client.post(f"/api/v1/rooms/{room.id}/renovation-plans", json={})
        plan_id = res_create.json()["plan_id"]

        res = client.get(f"/api/v1/rooms/{room.id}/renovation-plans/{plan_id}/export?format=markdown")
        assert res.status_code == 200
        data = res.json()
        assert data["format"] == "markdown"
        assert data["plan_id"] == plan_id
        assert "content" in data
        assert "## 1. Project Summary" in data["content"]

    def test_export_renovation_plan_json(self, client):
        room = _make_comprehensive_room()
        repository.save_room(room)

        res_create = client.post(f"/api/v1/rooms/{room.id}/renovation-plans", json={})
        plan_id = res_create.json()["plan_id"]

        res = client.get(f"/api/v1/rooms/{room.id}/renovation-plans/{plan_id}/export?format=json")
        assert res.status_code == 200
        data = res.json()
        assert data["plan_id"] == plan_id
        assert "scope_of_work" in data
        assert "execution_sequence" in data

    def test_plan_not_found_returns_404(self, client):
        room = _make_comprehensive_room()
        repository.save_room(room)

        res = client.get(f"/api/v1/rooms/{room.id}/renovation-plans/non_existent_plan")
        assert res.status_code == 404
        assert "not found" in res.json()["detail"].lower()

    def test_room_not_found_returns_404(self, client):
        res = client.post("/api/v1/rooms/non_existent_room/renovation-plans", json={})
        assert res.status_code == 404
        assert "Room not found" in res.json()["detail"]
