"""
tests/test_budget_aware_redesign.py
====================================
Milestone 2.4 – Budget-Aware Redesign

Unit and integration tests covering:
  - BudgetIntelligenceEngine internal helpers
  - REST endpoints: GET /rooms/budget-benchmarks,
                    POST /rooms/{id}/budget,
                    GET  /rooms/{id}/budget
"""

import pytest
from fastapi.testclient import TestClient

from packages.room_model.schema import (
    CanonicalRoomModel,
    Geometry,
    WallSegment,
    Point2D,
    RoomObject,
    ObjectAction,
    DesignConstraint,
    BudgetPlan,
    BudgetCategory,
    CurrencyCode,
    RenovationTier,
)
from services.ai_worker.pipelines.budget_estimator import BudgetIntelligenceEngine

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def engine() -> BudgetIntelligenceEngine:
    return BudgetIntelligenceEngine()


def _make_room(
    *,
    wall_segments=None,
    polygon_vertices=None,
    objects=None,
) -> CanonicalRoomModel:
    """Helper – builds a minimal CanonicalRoomModel for budget tests.
    Returns a 4m × 3m living room with ceiling height 2.7m.
    """
    ws = wall_segments or [
        WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=4.0, y=0.0), length_m=4.0),
        WallSegment(start_point=Point2D(x=4.0, y=0.0), end_point=Point2D(x=4.0, y=3.0), length_m=3.0),
        WallSegment(start_point=Point2D(x=4.0, y=3.0), end_point=Point2D(x=0.0, y=3.0), length_m=4.0),
        WallSegment(start_point=Point2D(x=0.0, y=3.0), end_point=Point2D(x=0.0, y=0.0), length_m=3.0),
    ]
    pv = polygon_vertices if polygon_vertices is not None else [
        Point2D(x=0.0, y=0.0),
        Point2D(x=4.0, y=0.0),
        Point2D(x=4.0, y=3.0),
        Point2D(x=0.0, y=3.0),
    ]
    objs = objects or []
    geom = Geometry(
        wall_segments=ws,
        polygon_vertices=pv,
        ceiling_height_m=2.7,
        estimated_width_m=4.0,
        estimated_length_m=3.0,
        floor_area_sqm=12.0,
    )
    room = CanonicalRoomModel(
        room_type="living_room",
        geometry=geom,
        objects=objs,
        overall_confidence=0.95,
    )
    return room


# ---------------------------------------------------------------------------
# 1. extract_room_quantities
# ---------------------------------------------------------------------------

class TestExtractRoomQuantities:
    def test_floor_area_from_geometry(self, engine):
        """Engine reads floor_area_sqm directly from Geometry when available."""
        room = _make_room()
        qty = engine.extract_room_quantities(room)
        assert abs(qty["floor_area_sqm"] - 12.0) < 0.5

    def test_net_wall_area_present(self, engine):
        """Wall surface area must be a positive value."""
        room = _make_room()
        qty = engine.extract_room_quantities(room)
        assert "net_wall_area_sqm" in qty
        assert qty["net_wall_area_sqm"] > 0.0

    def test_millwork_linear_m_present(self, engine):
        room = _make_room()
        qty = engine.extract_room_quantities(room)
        assert "millwork_linear_m" in qty
        assert qty["millwork_linear_m"] >= 0.0

    def test_perimeter_present(self, engine):
        room = _make_room()
        qty = engine.extract_room_quantities(room)
        assert "perimeter_m" in qty
        assert qty["perimeter_m"] > 0.0

    def test_ceiling_height_returned(self, engine):
        room = _make_room()
        qty = engine.extract_room_quantities(room)
        assert abs(qty["ceiling_height_m"] - 2.7) < 0.01

    def test_floor_area_positive(self, engine):
        room = _make_room()
        qty = engine.extract_room_quantities(room)
        assert qty["floor_area_sqm"] > 0.0

    def test_larger_room_bigger_floor_area(self, engine):
        """A 6×5 room should have larger floor area than 4×3."""
        ws_large = [
            WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=6.0, y=0.0), length_m=6.0),
            WallSegment(start_point=Point2D(x=6.0, y=0.0), end_point=Point2D(x=6.0, y=5.0), length_m=5.0),
            WallSegment(start_point=Point2D(x=6.0, y=5.0), end_point=Point2D(x=0.0, y=5.0), length_m=6.0),
            WallSegment(start_point=Point2D(x=0.0, y=5.0), end_point=Point2D(x=0.0, y=0.0), length_m=5.0),
        ]
        pv_large = [
            Point2D(x=0.0, y=0.0), Point2D(x=6.0, y=0.0),
            Point2D(x=6.0, y=5.0), Point2D(x=0.0, y=5.0),
        ]
        large_room = _make_room(wall_segments=ws_large, polygon_vertices=pv_large)
        # Override the floor_area_sqm to simulate an unset geometry
        large_room.geometry.floor_area_sqm = None
        large_room.geometry.estimated_width_m = 6.0
        large_room.geometry.estimated_length_m = 5.0
        small_room = _make_room()
        small_room.geometry.floor_area_sqm = None
        qty_large = engine.extract_room_quantities(large_room)
        qty_small = engine.extract_room_quantities(small_room)
        assert qty_large["floor_area_sqm"] >= qty_small["floor_area_sqm"]


# ---------------------------------------------------------------------------
# 2. evaluate_keep_replace_tradeoffs
# ---------------------------------------------------------------------------

class TestEvaluateKeepReplaceTradeoffs:
    def _sofa_room(self, action: ObjectAction = ObjectAction.KEEP) -> CanonicalRoomModel:
        sofa = RoomObject(
            name="sofa",
            category="sofa",
            action=action,
            confidence=0.9,
        )
        return _make_room(objects=[sofa])

    def test_keep_produces_tradeoff(self, engine):
        room = self._sofa_room(ObjectAction.KEEP)
        tradeoffs, total_savings = engine.evaluate_keep_replace_tradeoffs(
            room, currency=CurrencyCode.MYR, tier=RenovationTier.MODERATE
        )
        assert len(tradeoffs) >= 1
        t = tradeoffs[0]
        assert t.element_label == "sofa"
        assert t.action in ("keep", "restyle", "replace", "remove")

    def test_replace_produces_tradeoff(self, engine):
        room = self._sofa_room(ObjectAction.REPLACE)
        tradeoffs, _ = engine.evaluate_keep_replace_tradeoffs(
            room, currency=CurrencyCode.MYR, tier=RenovationTier.MODERATE
        )
        assert any(t.element_label == "sofa" for t in tradeoffs)

    def test_savings_non_negative(self, engine):
        room = self._sofa_room(ObjectAction.KEEP)
        tradeoffs, total_savings = engine.evaluate_keep_replace_tradeoffs(
            room, currency=CurrencyCode.MYR, tier=RenovationTier.MODERATE
        )
        for t in tradeoffs:
            assert t.savings_if_kept >= 0.0
        assert total_savings >= 0.0

    def test_empty_objects_returns_zero_savings(self, engine):
        room = _make_room(objects=[])
        tradeoffs, total_savings = engine.evaluate_keep_replace_tradeoffs(
            room, currency=CurrencyCode.MYR, tier=RenovationTier.MODERATE
        )
        assert tradeoffs == []
        assert total_savings == 0.0

    def test_multiple_items(self, engine):
        items = [
            RoomObject(name="sofa", category="sofa", action=ObjectAction.KEEP, confidence=0.9),
            RoomObject(name="coffee_table", category="coffee_table", action=ObjectAction.REPLACE, confidence=0.85),
            RoomObject(name="tv_unit", category="tv_unit", action=ObjectAction.KEEP, confidence=0.8),
        ]
        room = _make_room(objects=items)
        tradeoffs, _ = engine.evaluate_keep_replace_tradeoffs(
            room, currency=CurrencyCode.MYR, tier=RenovationTier.MODERATE
        )
        assert len(tradeoffs) == 3

    def test_sgd_tradeoffs_lower_than_myr(self, engine):
        """SGD purchasing power ratio is lower than MYR base rates for furniture."""
        room = self._sofa_room(ObjectAction.REPLACE)
        tradeoffs_myr, _ = engine.evaluate_keep_replace_tradeoffs(
            room, currency=CurrencyCode.MYR, tier=RenovationTier.MODERATE
        )
        tradeoffs_sgd, _ = engine.evaluate_keep_replace_tradeoffs(
            room, currency=CurrencyCode.SGD, tier=RenovationTier.MODERATE
        )
        # SGD furniture is PPR-adjusted; MYR is baseline (1.0)
        myr_cost = sum(t.replacement_cost_estimate for t in tradeoffs_myr)
        sgd_cost = sum(t.replacement_cost_estimate for t in tradeoffs_sgd)
        # SGD ratio=0.45 < MYR ratio=1.0, so SGD replacement cost is less
        assert sgd_cost < myr_cost


# ---------------------------------------------------------------------------
# 3. create_budget_plan – MYR MODERATE
# ---------------------------------------------------------------------------

class TestCreateBudgetPlanMYR:
    @pytest.fixture(autouse=True)
    def plan(self, engine):
        room = _make_room()
        self.plan: BudgetPlan = engine.create_budget_plan(
            room, total_budget=20_000.0, currency=CurrencyCode.MYR, tier=RenovationTier.MODERATE
        )

    def test_returns_budget_plan(self):
        assert isinstance(self.plan, BudgetPlan)

    def test_currency_is_myr(self):
        assert self.plan.currency == CurrencyCode.MYR

    def test_total_budget_stored(self):
        assert abs(self.plan.total_budget - 20_000.0) < 0.01

    def test_renovation_tier_stored(self):
        assert self.plan.renovation_tier == RenovationTier.MODERATE

    def test_allocated_items_non_empty(self):
        assert len(self.plan.allocated_items) > 0

    def test_total_estimated_cost_positive(self):
        assert self.plan.total_estimated_cost > 0.0

    def test_disclaimer_present(self):
        assert self.plan.disclaimer
        assert len(self.plan.disclaimer) > 10

    def test_remaining_budget_calculated(self):
        # remaining_budget = total_budget - total_estimated_cost
        expected = self.plan.total_budget - self.plan.total_estimated_cost
        assert abs(self.plan.remaining_budget - expected) < 1.0


# ---------------------------------------------------------------------------
# 4. create_budget_plan – SGD PREMIUM
# ---------------------------------------------------------------------------

class TestCreateBudgetPlanSGD:
    @pytest.fixture(autouse=True)
    def plan(self, engine):
        room = _make_room()
        self.plan: BudgetPlan = engine.create_budget_plan(
            room, total_budget=15_000.0, currency=CurrencyCode.SGD, tier=RenovationTier.PREMIUM
        )

    def test_currency_sgd(self):
        assert self.plan.currency == CurrencyCode.SGD

    def test_tier_premium(self):
        assert self.plan.renovation_tier == RenovationTier.PREMIUM

    def test_premium_more_expensive_than_moderate(self, engine):
        room = _make_room()
        moderate_plan = engine.create_budget_plan(
            room, total_budget=15_000.0, currency=CurrencyCode.SGD, tier=RenovationTier.MODERATE
        )
        assert self.plan.total_estimated_cost >= moderate_plan.total_estimated_cost

    def test_all_allocated_items_non_negative(self):
        for item in self.plan.allocated_items:
            assert item.estimated_cost >= 0.0, f"{item.category} has negative cost"


# ---------------------------------------------------------------------------
# 5. API endpoints
# ---------------------------------------------------------------------------

@pytest.fixture
def client():
    from services.api.app.main import app
    return TestClient(app)


def _create_room(client) -> str:
    """Helper to create a room via upload-and-analyze; returns room ID."""
    import io
    from PIL import Image

    img = Image.new("RGB", (200, 150), color=(180, 160, 140))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)
    img_bytes = buf.read()

    files = {"file": ("room.jpg", img_bytes, "image/jpeg")}
    data = {"room_name": "Budget Test Room", "room_type": "living_room"}
    resp = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data)
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


@pytest.fixture
def room_id(client):
    """Create a room via upload-and-analyze and return its ID for budget endpoint tests."""
    return _create_room(client)


class TestBudgetBenchmarksEndpoint:
    def test_get_benchmarks_200(self, client):
        resp = client.get("/api/v1/rooms/budget-benchmarks")
        assert resp.status_code == 200

    def test_benchmarks_has_tiers(self, client):
        resp = client.get("/api/v1/rooms/budget-benchmarks")
        data = resp.json()
        assert "tiers" in data

    def test_benchmarks_has_currencies(self, client):
        resp = client.get("/api/v1/rooms/budget-benchmarks")
        data = resp.json()
        body = str(data)
        assert "MYR" in body

    def test_benchmarks_not_treated_as_room_id(self, client):
        """Critical route order check: 'budget-benchmarks' must NOT match {room_id}."""
        resp = client.get("/api/v1/rooms/budget-benchmarks")
        assert resp.status_code != 404


class TestPostBudgetEndpoint:
    def test_post_budget_200(self, client, room_id):
        payload = {
            "total_budget": 20000.0,
            "currency": "MYR",
            "renovation_tier": "MODERATE",
            "actions": {},
        }
        resp = client.post(f"/api/v1/rooms/{room_id}/budget", json=payload)
        assert resp.status_code == 200, resp.text

    def test_post_budget_returns_plan(self, client, room_id):
        payload = {
            "total_budget": 20000.0,
            "currency": "MYR",
            "renovation_tier": "MODERATE",
        }
        resp = client.post(f"/api/v1/rooms/{room_id}/budget", json=payload)
        data = resp.json()
        assert "allocated_items" in data
        assert "total_estimated_cost" in data
        assert "disclaimer" in data

    def test_post_budget_disclaimer_text(self, client, room_id):
        payload = {
            "total_budget": 20000.0,
            "currency": "MYR",
            "renovation_tier": "MODERATE",
        }
        resp = client.post(f"/api/v1/rooms/{room_id}/budget", json=payload)
        data = resp.json()
        disclaimer = data.get("disclaimer", "")
        assert len(disclaimer) > 10

    def test_post_budget_sgd_premium(self, client, room_id):
        payload = {
            "total_budget": 15000.0,
            "currency": "SGD",
            "renovation_tier": "PREMIUM",
        }
        resp = client.post(f"/api/v1/rooms/{room_id}/budget", json=payload)
        assert resp.status_code == 200
        data = resp.json()
        assert data["currency"] == "SGD"

    def test_post_budget_invalid_tier_gracefully_handled(self, client, room_id):
        """Endpoint accepts unknown tier gracefully (falls back to MODERATE)."""
        payload = {
            "total_budget": 20000.0,
            "currency": "MYR",
            "renovation_tier": "ULTRA_DELUXE",
        }
        resp = client.post(f"/api/v1/rooms/{room_id}/budget", json=payload)
        # Endpoint is permissive — returns 200 with fallback tier, or 422 if validated
        assert resp.status_code in (200, 422, 400)

    def test_post_budget_invalid_currency_gracefully_handled(self, client, room_id):
        """Endpoint accepts unknown currency gracefully (falls back to MYR)."""
        payload = {
            "total_budget": 20000.0,
            "currency": "XYZ",
            "renovation_tier": "MODERATE",
        }
        resp = client.post(f"/api/v1/rooms/{room_id}/budget", json=payload)
        # Endpoint is permissive — returns 200 with MYR fallback, or 422 if validated
        assert resp.status_code in (200, 422, 400)


class TestGetBudgetEndpoint:
    def test_get_budget_after_post(self, client, room_id):
        client.post(f"/api/v1/rooms/{room_id}/budget", json={
            "total_budget": 18000.0,
            "currency": "MYR",
            "renovation_tier": "ECONOMY",
        })
        resp = client.get(f"/api/v1/rooms/{room_id}/budget")
        assert resp.status_code == 200

    def test_get_budget_returns_allocated_items(self, client, room_id):
        resp = client.get(f"/api/v1/rooms/{room_id}/budget")
        data = resp.json()
        assert "allocated_items" in data
        assert isinstance(data["allocated_items"], list)

    def test_get_budget_missing_room(self, client):
        resp = client.get("/api/v1/rooms/nonexistent-room-xyz/budget")
        assert resp.status_code in (200, 404)
