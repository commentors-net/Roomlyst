"""
tests/test_furniture_seller_capabilities.py
===========================================
Milestone 6.1 — Furniture Seller Capabilities & In-Room Placement

Validates:
1. Merchant registry onboarding, store slug collisions, listing, filtering, and updates.
2. Seller catalog product onboarding with 3D model assets and inventory status.
3. Strict spatial fit verification enforcing Blueprint Section 35:
   - Confidence threshold (< 0.85 blocks fit claims and flags for physical field measurement).
   - 3D Doorway ingress clearance check.
   - Room destination clearance check.
4. Interactive in-room 3D/2D product placement visualization lifecycle.
5. Commerce referral tracking, deep-link attribution token injection, and GMV analytics.
"""

import pytest
from fastapi.testclient import TestClient

from packages.room_model.schema import (
    CanonicalRoomModel,
    CatalogProduct,
    Geometry,
    Measurement,
    MeasurementSource,
    MerchantRecord,
    OpeningType,
    ProductAvailability,
    ProductCategory,
    ProductDimensions,
    ProductFitStatus,
    ProductPlacementVisualization,
    RoomOpening,
    RoomObject,
    SellerFitVerification,
)
from services.ai_worker.pipelines.product_recommender import product_recommender
from services.api.app.api.v1.endpoints import router
from services.api.app.db.repository import repository
from services.api.app.main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_test_room():
    """Seeds a test room in repository."""
    room = CanonicalRoomModel(
        id="test-seller-room-101",
        name="Penthouse Living Room",
        geometry=Geometry(
            estimated_width_m=5.0,
            estimated_length_m=6.5,
            ceiling_height_m=2.8,
            floor_area_sqm=32.5,
        ),
        openings=[
            RoomOpening(
                id="door-main",
                name="Main Entrance Door",
                opening_type=OpeningType.DOOR,
                width_m=0.90,
                height_m=2.10,
            )
        ],
        measurements=[
            Measurement(
                entity_type="room",
                measurement_type="width",
                value=5.0,
                unit="m",
                confidence=0.95,
                source=MeasurementSource.LIDAR_NATIVE,
            ),
            Measurement(
                entity_type="room",
                measurement_type="length",
                value=6.5,
                unit="m",
                confidence=0.92,
                source=MeasurementSource.LIDAR_NATIVE,
            ),
        ],
    )
    repository.save_room(room)
    return room


# =====================================================================
# 1. Merchant Onboarding & Directory Tests
# =====================================================================

def test_merchant_onboarding_and_directory():
    """Tests creating, fetching, listing, and updating a furniture merchant."""
    create_payload = {
        "business_name": "Nordic Living Studio",
        "store_slug": "nordic-living",
        "contact_email": "partners@nordicliving.se",
        "phone": "+46 8 123 4567",
        "website": "https://nordicliving.se",
        "logo_url": "https://assets.roomlyst.com/merchants/nordic.png",
        "country": "SE",
        "supported_currencies": ["EUR", "USD"],
        "commission_rate_pct": 10.5,
        "is_verified": True,
    }

    response = client.post("/api/v1/merchants", json=create_payload)
    assert response.status_code == 201
    data = response.json()
    merchant_id = data["merchant_id"]
    assert data["business_name"] == "Nordic Living Studio"
    assert data["store_slug"] == "nordic-living"
    assert data["commission_rate_pct"] == 10.5
    assert data["is_verified"] is True

    # Test duplicate slug rejection (409)
    dup_res = client.post("/api/v1/merchants", json=create_payload)
    assert dup_res.status_code == 409

    # Test get merchant by id
    get_res = client.get(f"/api/v1/merchants/{merchant_id}")
    assert get_res.status_code == 200
    assert get_res.json()["contact_email"] == "partners@nordicliving.se"

    # Test list merchants with country filter
    list_res = client.get("/api/v1/merchants?country=SE")
    assert list_res.status_code == 200
    merchants_se = list_res.json()
    assert any(m["merchant_id"] == merchant_id for m in merchants_se)

    # Test patch merchant details
    patch_res = client.patch(
        f"/api/v1/merchants/{merchant_id}",
        json={"commission_rate_pct": 12.0, "phone": "+46 8 999 8888"},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["commission_rate_pct"] == 12.0
    assert patch_res.json()["contact_phone"] == "+46 8 999 8888"


# =====================================================================
# 2. Seller Catalog Product Onboarding Tests
# =====================================================================

def test_seller_product_onboarding_with_3d_assets():
    """Tests merchant uploading a 3D-ready catalog product."""
    merchants = client.get("/api/v1/merchants").json()
    merchant_id = merchants[0]["merchant_id"]
    initial_listing_count = merchants[0]["active_listing_count"]

    prod_payload = {
        "name": "Kobenhavn Oak Dining Table",
        "category": "DINING_TABLE",
        "dimensions": {
            "width_m": 2.0,
            "depth_m": 0.95,
            "height_m": 0.76,
        },
        "price": 3200.0,
        "currency": "USD",
        "product_url": "https://merchant.com/kobenhavn-table",
        "image_url": "https://assets.roomlyst.com/products/kobenhavn.jpg",
        "model_3d_url": "https://assets.roomlyst.com/models/kobenhavn.glb",
        "brand": "Nordic Living",
        "sku": "NORDIC-DINING-01",
        "style_tags": ["SCANDINAVIAN", "MINIMALIST"],
        "material_tags": ["Solid White Oak", "Matte Polyurethane"],
        "color_options": ["Natural Oak", "Smoked Oak"],
        "description": "Handcrafted minimalist Scandinavian solid oak dining table.",
        "availability": "IN_STOCK",
        "lead_time_days": 10,
    }

    create_res = client.post(f"/api/v1/merchants/{merchant_id}/products", json=prod_payload)
    assert create_res.status_code == 201
    prod = create_res.json()
    assert prod["name"] == "Kobenhavn Oak Dining Table"
    assert prod["seller_id"] == merchant_id
    assert prod["model_3d_url"] == "https://assets.roomlyst.com/models/kobenhavn.glb"
    assert prod["dimensions"]["width_m"] == 2.0

    # Verify merchant's active listing count incremented
    updated_merchant = client.get(f"/api/v1/merchants/{merchant_id}").json()
    assert updated_merchant["active_listing_count"] == initial_listing_count + 1

    # Verify merchant product query
    list_prods_res = client.get(f"/api/v1/merchants/{merchant_id}/products")
    assert list_prods_res.status_code == 200
    seller_prods = list_prods_res.json()
    assert any(p["id"] == prod["id"] for p in seller_prods)


# =====================================================================
# 3. Strict Spatial Fit Verification Tests (Blueprint Section 35)
# =====================================================================

def test_strict_fit_verification_high_confidence(setup_test_room):
    """Verifies that high-confidence room measurements permit positive fit claims."""
    # Find or use an existing catalog product
    products = client.get("/api/v1/catalog/products").json()
    sofa = next(p for p in products if p["category"] == "SOFA" or "sofa" in p["name"].lower())

    fit_req = {
        "room_id": setup_test_room.id,
    }

    res = client.post(f"/api/v1/catalog/products/{sofa['id']}/check-fit", json=fit_req)
    assert res.status_code == 200
    fit_data = res.json()

    assert fit_data["product_id"] == sofa["id"]
    assert fit_data["room_id"] == setup_test_room.id
    assert fit_data["is_fit_claim_permitted"] is True
    assert fit_data["measurement_confidence"] >= 0.85
    assert fit_data["requires_field_measurement"] is False
    assert fit_data["doorway_ingress_check"] is True
    assert fit_data["doorway_clearance_margin_m"] > 0.0


def test_strict_fit_verification_low_confidence_blocks_claim():
    """Blueprint Section 35: Measurement confidence < 0.85 MUST block fit claim."""
    low_conf_room = CanonicalRoomModel(
        id="room-low-conf-999",
        name="Uncertain Low Light Bedroom",
        geometry=Geometry(
            estimated_width_m=3.5,
            estimated_length_m=4.0,
            ceiling_height_m=2.6,
        ),
        measurements=[
            Measurement(
                entity_type="room",
                measurement_type="width",
                value=3.5,
                unit="m",
                confidence=0.65,  # Below 0.85 threshold!
                source=MeasurementSource.MONOCULAR_DEPTH,
            )
        ],
    )
    repository.save_room(low_conf_room)

    products = client.get("/api/v1/catalog/products").json()
    bed = next((p for p in products if p["category"] == "bed"), products[0])

    res = client.post(
        f"/api/v1/catalog/products/{bed['id']}/check-fit",
        json={"room_id": "room-low-conf-999"},
    )
    assert res.status_code == 200
    fit_data = res.json()

    # Must disallow positive fit claim
    assert fit_data["is_fit_claim_permitted"] is False
    assert fit_data["fit_status"] == "CLEARANCE_WARNING"
    assert fit_data["requires_field_measurement"] is True
    assert "Unconfirmed Fit" in fit_data["notes"]
    assert "below the required 85% threshold" in fit_data["notes"]


def test_strict_fit_verification_doorway_ingress_hazard():
    """Verifies that items too large for entrance doorways fail ingress check."""
    narrow_door_room = CanonicalRoomModel(
        id="room-narrow-entrance",
        name="Vintage Cottage",
        geometry=Geometry(estimated_width_m=4.0, estimated_length_m=4.0, ceiling_height_m=2.5),
        openings=[
            RoomOpening(
                id="narrow-door",
                name="Narrow Doorway",
                opening_type=OpeningType.DOOR,
                width_m=0.60,  # Only 60cm wide entrance door!
                height_m=1.90,
            )
        ],
        measurements=[
            Measurement(
                entity_type="room",
                measurement_type="width",
                value=4.0,
                unit="m",
                confidence=0.92,
                source=MeasurementSource.LIDAR_NATIVE,
            )
        ],
    )
    repository.save_room(narrow_door_room)

    # Giant sectional sofa (min dimension = 0.85m > 0.60m door)
    giant_sofa = CatalogProduct(
        id="giant-sectional-sofa",
        sku="GIANT-SOFA-01",
        name="Colossal Sectional 4-Piece",
        category=ProductCategory.SOFA,
        brand="Luxury Living",
        retailer="Luxury Living",
        dimensions=ProductDimensions(width_m=3.4, depth_m=1.8, height_m=0.88),
        price=6500.0,
    )
    product_recommender.add_product(giant_sofa)

    res = client.post(
        f"/api/v1/catalog/products/{giant_sofa.id}/check-fit",
        json={"room_id": narrow_door_room.id},
    )
    assert res.status_code == 200
    fit_data = res.json()

    assert fit_data["doorway_ingress_check"] is False
    assert fit_data["doorway_clearance_margin_m"] < 0.0
    assert fit_data["fit_status"] == "OVERSIZED"
    assert "Doorway Ingress Hazard" in fit_data["notes"]


# =====================================================================
# 4. Product Placement Visualization Lifecycle Tests
# =====================================================================

def test_product_placement_visualization_lifecycle(setup_test_room):
    """Tests placing, retrieving, and removing interactive in-room 3D/2D products."""
    products = client.get("/api/v1/catalog/products").json()
    product = products[0]

    placement_payload = {
        "product_id": product["id"],
        "position_x": 1.25,
        "position_y": 2.50,
        "position_z": 0.0,
        "rotation_deg": 45.0,
        "scale_factor": 1.0,
        "bounding_box": {
            "width_m": 1.8,
            "depth_m": 0.8,
            "height_m": 0.75,
        },
        "model_3d_url": "https://assets.roomlyst.com/models/test-placement.glb",
        "is_locked": False,
    }

    # 1. Place product in room
    add_res = client.post(
        f"/api/v1/rooms/{setup_test_room.id}/visualizations",
        json=placement_payload,
    )
    assert add_res.status_code == 201
    placed = add_res.json()
    placement_id = placed["placement_id"]
    assert placed["room_id"] == setup_test_room.id
    assert placed["product_id"] == product["id"]
    assert placed["position_x"] == 1.25
    assert placed["rotation_deg"] == 45.0

    # 2. List placements for room
    list_res = client.get(f"/api/v1/rooms/{setup_test_room.id}/visualizations")
    assert list_res.status_code == 200
    placements = list_res.json()
    assert len(placements) >= 1
    assert any(p["placement_id"] == placement_id for p in placements)

    # 3. Delete placement
    del_res = client.delete(f"/api/v1/rooms/{setup_test_room.id}/visualizations/{placement_id}")
    assert del_res.status_code == 200
    assert del_res.json()["status"] == "success"

    # Verify deleted
    after_res = client.get(f"/api/v1/rooms/{setup_test_room.id}/visualizations")
    assert not any(p["placement_id"] == placement_id for p in after_res.json())


# =====================================================================
# 5. Commerce Referral Tracking & Attribution Analytics Tests
# =====================================================================

def test_commerce_tracking_and_attribution():
    """Tests referral link generation, click-out tracking, and GMV calculations."""
    track_req = {
        "product_id": "prod-castlery-todd",
        "product_name": "Todd Modular Sofa",
        "retailer_url": "https://castlery.com/products/todd-sofa",
        "merchant_id": "merch-castlery",
        "project_id": "proj-modern-loft",
        "designer_id": "des-clara-chen",
        "event_type": "CLICK_OUT",
    }

    # 1. Track outbound click
    click_res = client.post("/api/v1/commerce/track-click", json=track_req)
    assert click_res.status_code == 200
    event = click_res.json()

    assert event["event_type"] == "CLICK_OUT"
    assert event["affiliate_token"] == "roomlyst_proj-modern-loft_des-clara-chen"
    assert "ref=roomlyst_proj-modern-loft_des-clara-chen" in event["tracked_destination_url"]
    assert "utm_source=roomlyst" in event["tracked_destination_url"]

    # 2. Track lead submission
    lead_req = dict(track_req)
    lead_req["event_type"] = "LEAD_SUBMISSION"
    client.post("/api/v1/commerce/track-click", json=lead_req)

    # 3. Get attribution summary for project
    attr_res = client.get("/api/v1/commerce/attribution?project_id=proj-modern-loft")
    assert attr_res.status_code == 200
    summary = attr_res.json()

    assert summary["total_clicks"] >= 1
    assert summary["total_leads"] >= 1
    assert summary["estimated_gmv_influenced"] > 0.0
    assert len(summary["events"]) >= 2
