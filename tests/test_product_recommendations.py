"""
tests/test_product_recommendations.py
====================================
Milestone 4.3 – Product and Catalogue Recommendations

Unit and integration tests covering:
  - Normalized product catalogue query and filtering
  - Spatial clearance and dimension-fit verification
  - Contextual product recommendation engine for room objects
  - REST endpoints:
      GET  /catalog/products
      GET  /catalog/products/{id}
      POST /rooms/{id}/recommendations
      GET  /rooms/{id}/recommendations
"""

import pytest
from fastapi.testclient import TestClient

from packages.room_model.schema import (
    CanonicalRoomModel,
    CatalogProduct,
    CurrencyCode,
    Geometry,
    ObjectAction,
    Point2D,
    ProductAvailability,
    ProductCategory,
    ProductDimensions,
    ProductFitStatus,
    ProductRecommendationReport,
    RenovationTier,
    RoomObject,
    WallSegment,
)
from services.ai_worker.pipelines.product_recommender import ProductRecommendationEngine
from services.api.app.main import app


@pytest.fixture(scope="module")
def engine() -> ProductRecommendationEngine:
    return ProductRecommendationEngine()


@pytest.fixture(scope="module")
def client() -> TestClient:
    return TestClient(app)


def _make_sample_room() -> CanonicalRoomModel:
    ws = [
        WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=5.0, y=0.0), length_m=5.0),
        WallSegment(start_point=Point2D(x=5.0, y=0.0), end_point=Point2D(x=5.0, y=4.0), length_m=4.0),
        WallSegment(start_point=Point2D(x=5.0, y=4.0), end_point=Point2D(x=0.0, y=4.0), length_m=5.0),
        WallSegment(start_point=Point2D(x=0.0, y=4.0), end_point=Point2D(x=0.0, y=0.0), length_m=4.0),
    ]
    geom = Geometry(
        wall_segments=ws,
        ceiling_height_m=2.9,
        floor_area_sqm=20.0,
    )
    objects = [
        RoomObject(
            id="obj_sofa_101",
            name="Old Fabric Sofa",
            category="sofa",
            action=ObjectAction.REPLACE,
            confidence=0.92,
        ),
        RoomObject(
            id="obj_table_102",
            name="Scratched Coffee Table",
            category="coffee_table",
            action=ObjectAction.REPLACE,
            confidence=0.88,
        ),
    ]
    return CanonicalRoomModel(
        id="room_recs_test_201",
        room_type="living_room",
        geometry=geom,
        objects=objects,
    )


# ---------------------------------------------------------------------------
# 1. Product Catalog Query and Filtering
# ---------------------------------------------------------------------------

class TestCatalogFiltering:
    def test_catalog_non_empty(self, engine):
        cat = engine.get_catalog()
        assert len(cat) >= 10
        for p in cat:
            assert p.sku
            assert p.price > 0
            assert p.dimensions.width_m > 0
            assert p.dimensions.depth_m > 0
            assert p.dimensions.height_m > 0

    def test_filter_by_category(self, engine):
        sofas = engine.query_catalog(category=ProductCategory.SOFA)
        assert len(sofas) >= 3
        for s in sofas:
            assert s.category == ProductCategory.SOFA

    def test_filter_by_style(self, engine):
        japandi_items = engine.query_catalog(style="Japandi")
        assert len(japandi_items) > 0
        for item in japandi_items:
            assert any("japandi" in st.lower() for st in item.styles)

    def test_filter_by_tier_and_currency(self, engine):
        moderate_myr = engine.query_catalog(
            tier=RenovationTier.MODERATE,
            currency=CurrencyCode.MYR,
        )
        assert len(moderate_myr) > 0
        for item in moderate_myr:
            assert item.tier == RenovationTier.MODERATE
            assert item.currency == CurrencyCode.MYR

    def test_keyword_search(self, engine):
        oak_results = engine.query_catalog(search_query="oak")
        assert len(oak_results) > 0
        for p in oak_results:
            assert "oak" in p.name.lower() or "oak" in p.brand.lower() or (p.description and "oak" in p.description.lower())

    def test_get_product_by_id(self, engine):
        prod = engine.get_product_by_id("prod_sofa_001")
        assert prod is not None
        assert prod.name == "Nordic Three-Seater Fabric Sofa"
        assert prod.brand == "Castlery"


# ---------------------------------------------------------------------------
# 2. Spatial Clearance and Fit Checking
# ---------------------------------------------------------------------------

class TestSpatialFitChecking:
    def test_perfect_fit(self, engine):
        prod = engine.get_product_by_id("prod_sofa_001")
        assert prod is not None
        # Target space: 2.6m wide, 1.2m deep, 2.8m high ceiling
        status, notes, variance = engine.check_spatial_fit(
            product=prod,
            target_width_m=2.6,
            target_depth_m=1.2,
            target_height_m=1.0,
            ceiling_height_m=2.8,
        )
        assert status == ProductFitStatus.PERFECT_FIT
        assert "Fits target space" in notes

    def test_tight_fit(self, engine):
        prod = engine.get_product_by_id("prod_sofa_001")
        assert prod is not None
        # Product width is 2.15, depth is 0.92.
        # If target space is 2.20m wide (margin 0.05m < 0.15m), should be tight fit
        status, notes, _ = engine.check_spatial_fit(
            product=prod,
            target_width_m=2.20,
            target_depth_m=1.10,
            target_height_m=1.0,
            ceiling_height_m=2.8,
        )
        assert status == ProductFitStatus.TIGHT_FIT
        assert "Tight clearance" in notes

    def test_oversized(self, engine):
        prod = engine.get_product_by_id("prod_sofa_001")
        assert prod is not None
        # Product width is 2.15. If target space is 1.50m wide, product exceeds by > 15%
        status, notes, _ = engine.check_spatial_fit(
            product=prod,
            target_width_m=1.50,
            target_depth_m=0.80,
            target_height_m=1.0,
            ceiling_height_m=2.8,
        )
        assert status == ProductFitStatus.OVERSIZED
        assert "exceeds target space" in notes

    def test_ceiling_clearance_warning(self, engine):
        # Create tall product (2.95m high) with a 2.8m ceiling
        tall_prod = CatalogProduct(
            id="prod_tall_001",
            sku="TL-01",
            name="Floor-to-Ceiling Bookcase",
            brand="Bespoke",
            category=ProductCategory.STORAGE_SHELF,
            dimensions=ProductDimensions(width_m=1.2, depth_m=0.4, height_m=2.95),
            price=1500.0,
            retailer="Cabinet Co",
        )
        status, notes, _ = engine.check_spatial_fit(
            product=tall_prod,
            target_width_m=1.5,
            target_depth_m=0.6,
            target_height_m=2.95,
            ceiling_height_m=2.8,
        )
        assert status == ProductFitStatus.CLEARANCE_WARNING
        assert "exceeds available ceiling clearance" in notes


# ---------------------------------------------------------------------------
# 3. Contextual Recommendation Engine
# ---------------------------------------------------------------------------

class TestContextualRecommendations:
    def test_recommend_for_room_with_replace_objects(self, engine):
        room = _make_sample_room()
        report = engine.recommend_for_room(
            room=room,
            preferred_style="Warm Modern Minimalist",
            preferred_tier=RenovationTier.MODERATE,
            preferred_currency=CurrencyCode.MYR,
        )
        assert isinstance(report, ProductRecommendationReport)
        assert report.room_id == room.id
        assert len(report.recommendations) > 0

        # Must recommend products for sofa and coffee table
        categories = [r.product.category for r in report.recommendations]
        assert ProductCategory.SOFA in categories
        assert ProductCategory.COFFEE_TABLE in categories

        # Match scores should be populated
        for rec in report.recommendations:
            assert rec.match_score >= 0.5
            assert rec.fit_status in [ProductFitStatus.PERFECT_FIT, ProductFitStatus.TIGHT_FIT]
            assert rec.budget_status != ""

        assert report.total_recommended_spend > 0.0

    def test_recommend_attaches_to_room_model(self, engine):
        room = _make_sample_room()
        engine.recommend_for_room(room)
        assert room.product_recommendations is not None
        assert len(room.product_recommendations.recommendations) > 0


# ---------------------------------------------------------------------------
# 4. REST API Endpoints
# ---------------------------------------------------------------------------

class TestProductRecommendationEndpoints:
    def test_query_catalog_endpoint(self, client):
        resp = client.get("/api/v1/catalog/products?category=SOFA&tier=MODERATE")
        assert resp.status_code == 200
        products = resp.json()
        assert len(products) > 0
        for p in products:
            assert p["category"] == "SOFA"
            assert p["tier"] == "MODERATE"

    def test_get_product_endpoint(self, client):
        resp = client.get("/api/v1/catalog/products/prod_sofa_001")
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == "prod_sofa_001"
        assert data["brand"] == "Castlery"

    def test_get_product_not_found(self, client):
        resp = client.get("/api/v1/catalog/products/non_existent_sku")
        assert resp.status_code == 404

    def test_post_recommendations_endpoint(self, client):
        room = _make_sample_room()
        from services.api.app.api.v1.endpoints import repository
        repository.save_room(room)

        resp = client.post(
            f"/api/v1/rooms/{room.id}/recommendations",
            json={
                "preferred_style": "Japandi",
                "preferred_tier": "MODERATE",
                "preferred_currency": "MYR",
                "max_items_per_category": 2,
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["room_id"] == room.id
        assert data["applied_style"] == "Japandi"
        assert len(data["recommendations"]) > 0
        assert data["total_recommended_spend"] > 0

    def test_get_recommendations_endpoint(self, client):
        room = _make_sample_room()
        from services.api.app.api.v1.endpoints import repository
        repository.save_room(room)

        resp = client.get(f"/api/v1/rooms/{room.id}/recommendations")
        assert resp.status_code == 200
        data = resp.json()
        assert data["room_id"] == room.id
        assert len(data["recommendations"]) > 0
