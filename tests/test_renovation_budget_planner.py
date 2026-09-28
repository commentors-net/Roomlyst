"""
tests/test_renovation_budget_planner.py
======================================
Milestone 4.2 – Renovation Budget Planner

Comprehensive tests covering:
  - Material vs Labor cost splits across specialized trade categories
  - Physical takeoff report (4.1) quantity integration
  - Configurable contingency reserve (5% to 25%)
  - Regional tax & regulatory allowances across 7 currencies (MYR, SGD, USD, EUR, GBP, AUD, CAD)
  - 4-Tier side-by-side scenario comparisons (Economy, Moderate, Premium, Luxury)
  - REST endpoints: POST /rooms/{id}/renovation-budget, GET /rooms/{id}/budget/scenarios
"""

import pytest
from fastapi.testclient import TestClient

from packages.room_model.schema import (
    CanonicalRoomModel,
    Geometry,
    WallSegment,
    Point2D,
    CurrencyCode,
    RenovationTier,
    BudgetCategory,
    BudgetPlan,
    BudgetScenarioComparison,
    MaterialTakeoffReport,
    MaterialTakeoffItem,
    MaterialCategory,
)
from services.ai_worker.pipelines.budget_estimator import BudgetIntelligenceEngine
from services.api.app.main import app


@pytest.fixture(scope="module")
def engine() -> BudgetIntelligenceEngine:
    return BudgetIntelligenceEngine()


@pytest.fixture(scope="module")
def client() -> TestClient:
    return TestClient(app)


def _make_room(with_takeoff: bool = False) -> CanonicalRoomModel:
    ws = [
        WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=5.0, y=0.0), length_m=5.0),
        WallSegment(start_point=Point2D(x=5.0, y=0.0), end_point=Point2D(x=5.0, y=4.0), length_m=4.0),
        WallSegment(start_point=Point2D(x=5.0, y=4.0), end_point=Point2D(x=0.0, y=4.0), length_m=5.0),
        WallSegment(start_point=Point2D(x=0.0, y=4.0), end_point=Point2D(x=0.0, y=0.0), length_m=4.0),
    ]
    geom = Geometry(
        wall_segments=ws,
        ceiling_height_m=3.0,
        estimated_width_m=5.0,
        estimated_length_m=4.0,
        floor_area_sqm=20.0,
    )
    room = CanonicalRoomModel(
        id="room_renov_test_101",
        room_type="living_room",
        geometry=geom,
    )

    if with_takeoff:
        room.material_takeoff = MaterialTakeoffReport(
            room_id=room.id,
            gross_floor_area_sqm=22.5,
            net_wall_area_sqm=48.0,
            ceiling_area_sqm=22.5,
            baseboard_perimeter_m=17.2,
            openings_deducted_area_sqm=3.5,
            items=[
                MaterialTakeoffItem(
                    item_id="to_item_1",
                    category=MaterialCategory.FLOORING,
                    name="Porcelain Tile",
                    description="Floor porcelain tile finish",
                    net_quantity=22.5,
                    unit="sqm",
                    waste_factor_pct=10.0,
                    waste_quantity=2.25,
                    gross_quantity=24.75,
                    min_recommended_quantity=23.0,
                    max_recommended_quantity=26.0,
                )
            ],
        )

    return room


# ---------------------------------------------------------------------------
# 1. Material vs Labor Splits
# ---------------------------------------------------------------------------

class TestMaterialLaborSplits:
    def test_each_item_has_material_and_labor(self, engine):
        room = _make_room()
        plan = engine.create_budget_plan(
            room=room,
            total_budget=25000.0,
            currency=CurrencyCode.MYR,
            tier=RenovationTier.MODERATE,
        )
        assert len(plan.allocated_items) > 0
        for item in plan.allocated_items:
            assert item.material_cost >= 0.0
            assert item.labor_cost >= 0.0
            if item.category != BudgetCategory.CONTINGENCY:
                # Material + Labor should equal item estimated_cost
                assert abs((item.material_cost + item.labor_cost) - item.estimated_cost) < 0.05
                assert item.trade_name is not None and len(item.trade_name) > 0
            else:
                assert item.material_cost == 0.0
                assert item.labor_cost == 0.0
                assert item.trade_name == "Risk Reserve"

    def test_subtotals_sum_to_total_materials_and_labor(self, engine):
        room = _make_room()
        plan = engine.create_budget_plan(
            room=room,
            total_budget=20000.0,
            currency=CurrencyCode.SGD,
            tier=RenovationTier.PREMIUM,
        )
        sum_mat = sum(it.material_cost for it in plan.allocated_items)
        sum_lab = sum(it.labor_cost for it in plan.allocated_items)

        assert abs(plan.subtotal_materials - sum_mat) < 0.05
        assert abs(plan.subtotal_labor - sum_lab) < 0.05
        assert abs((plan.subtotal_materials + plan.subtotal_labor + plan.contingency_amount) - plan.total_estimated_cost) < 0.05


# ---------------------------------------------------------------------------
# 2. Configurable Contingency & Regional Tax
# ---------------------------------------------------------------------------

class TestContingencyAndTaxes:
    def test_custom_contingency_percentage(self, engine):
        room = _make_room()
        plan_5 = engine.create_budget_plan(
            room=room,
            total_budget=15000.0,
            contingency_pct=5.0,
        )
        plan_20 = engine.create_budget_plan(
            room=room,
            total_budget=15000.0,
            contingency_pct=20.0,
        )

        assert plan_5.contingency_pct == 5.0
        assert plan_20.contingency_pct == 20.0
        assert plan_20.contingency_amount > plan_5.contingency_amount
        expected_diff = (20.0 / 5.0)
        assert abs((plan_20.contingency_amount / plan_5.contingency_amount) - expected_diff) < 0.01

    def test_regional_tax_application(self, engine):
        room = _make_room()
        # Test SGD GST (9.0%)
        plan_sgd = engine.create_budget_plan(
            room=room,
            total_budget=30000.0,
            currency=CurrencyCode.SGD,
            contingency_pct=10.0,
            include_tax=True,
        )
        assert plan_sgd.tax_name == "GST"
        assert plan_sgd.tax_rate_pct == 9.0
        assert plan_sgd.tax_amount > 0.0
        # Grand total should be total_estimated_cost + tax
        expected_grand = round(plan_sgd.total_estimated_cost + plan_sgd.tax_amount, 2)
        assert abs(plan_sgd.grand_total - expected_grand) < 0.05

    def test_custom_tax_override(self, engine):
        room = _make_room()
        plan = engine.create_budget_plan(
            room=room,
            total_budget=20000.0,
            currency=CurrencyCode.EUR,
            include_tax=True,
            custom_tax_rate=12.5,
        )
        assert plan.tax_rate_pct == 12.5
        expected_tax = round(plan.total_estimated_cost * 0.125, 2)
        assert abs(plan.tax_amount - expected_tax) < 0.05


# ---------------------------------------------------------------------------
# 3. Material Takeoff Integration
# ---------------------------------------------------------------------------

class TestPhysicalTakeoffIntegration:
    def test_extract_quantities_uses_takeoff(self, engine):
        room_with_to = _make_room(with_takeoff=True)
        qty = engine.extract_room_quantities(room_with_to)

        # Ground truth from takeoff report
        assert qty["floor_area_sqm"] == 22.5
        assert qty["net_wall_area_sqm"] == 48.0
        assert qty["perimeter_m"] == 17.2

    def test_budget_plan_reflects_takeoff_quantities(self, engine):
        room_no_to = _make_room(with_takeoff=False)
        room_with_to = _make_room(with_takeoff=True)

        plan_no = engine.create_budget_plan(room=room_no_to, total_budget=15000.0)
        plan_with = engine.create_budget_plan(room=room_with_to, total_budget=15000.0)

        # Floor area in takeoff is 22.5 vs 20.0 in geometry
        floor_item_no = next(it for it in plan_no.allocated_items if it.category == BudgetCategory.FLOORING)
        floor_item_with = next(it for it in plan_with.allocated_items if it.category == BudgetCategory.FLOORING)

        assert floor_item_with.quantity == 22.5
        assert floor_item_no.quantity == 20.0


# ---------------------------------------------------------------------------
# 4. Multi-Tier Scenario Comparisons
# ---------------------------------------------------------------------------

class TestMultiTierScenarioComparisons:
    def test_scenarios_generated_in_plan(self, engine):
        room = _make_room()
        plan = engine.create_budget_plan(
            room=room,
            total_budget=20000.0,
            currency=CurrencyCode.USD,
            tier=RenovationTier.MODERATE,
            include_tax=True,
        )
        assert len(plan.scenarios) == 4
        tiers = [s.tier for s in plan.scenarios]
        assert tiers == [
            RenovationTier.ECONOMY,
            RenovationTier.MODERATE,
            RenovationTier.PREMIUM,
            RenovationTier.LUXURY,
        ]

    def test_scenario_costs_scale_monotonically(self, engine):
        room = _make_room()
        scenarios = engine.generate_tier_scenarios(
            room=room,
            total_budget=20000.0,
            currency=CurrencyCode.MYR,
            contingency_pct=10.0,
            include_tax=True,
        )
        assert len(scenarios) == 4
        economy, moderate, premium, luxury = scenarios

        assert economy.grand_total_estimated < moderate.grand_total_estimated
        assert moderate.grand_total_estimated < premium.grand_total_estimated
        assert premium.grand_total_estimated < luxury.grand_total_estimated

        # Material + Labor + Contingency + Tax == Grand total for each
        for s in scenarios:
            subtotal = s.subtotal_materials + s.subtotal_labor
            calc_grand = round(subtotal + s.contingency_amount + s.tax_amount, 2)
            assert abs(s.grand_total_estimated - calc_grand) < 0.1


# ---------------------------------------------------------------------------
# 5. REST Endpoints
# ---------------------------------------------------------------------------

class TestRenovationBudgetApiEndpoints:
    def test_post_renovation_budget_endpoint(self, client):
        room = _make_room(with_takeoff=True)
        from services.api.app.api.v1.endpoints import repository
        repository.save_room(room)

        resp = client.post(
            f"/api/v1/rooms/{room.id}/renovation-budget",
            json={
                "total_budget": 35000.0,
                "currency": "SGD",
                "renovation_tier": "PREMIUM",
                "contingency_pct": 15.0,
                "include_tax": True,
            },
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["currency"] == "SGD"
        assert data["renovation_tier"] == "PREMIUM"
        assert data["contingency_pct"] == 15.0
        assert data["tax_name"] == "GST"
        assert data["subtotal_materials"] > 0
        assert data["subtotal_labor"] > 0
        assert data["grand_total"] > 0
        assert len(data["scenarios"]) == 4

    def test_get_scenarios_endpoint(self, client):
        room = _make_room(with_takeoff=True)
        from services.api.app.api.v1.endpoints import repository
        repository.save_room(room)

        resp = client.get(
            f"/api/v1/rooms/{room.id}/renovation-budget/scenarios?currency=MYR&contingency_pct=12.0&include_tax=true"
        )
        assert resp.status_code == 200
        scenarios = resp.json()
        assert len(scenarios) == 4
        assert scenarios[0]["tier"] == "ECONOMY"
        assert scenarios[3]["tier"] == "LUXURY"
        assert scenarios[0]["grand_total_estimated"] < scenarios[3]["grand_total_estimated"]
