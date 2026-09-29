"""
Milestone 6.3 — Property Agent Virtual Staging, Empty-Room Furnishing, & Regulatory Disclosure Tests.
Validates virtual staging generation, empty-room furnishing, declutter mode,
renovation-potential cosmetic flip with ROI uplift estimation, indelible disclosure watermarking,
RESO/portal syndication packaging, printable marketing flyer generation, and REST endpoints.
"""

import io
import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from PIL import Image

from services.api.app.main import app
from services.api.app.db.repository import repository
from services.ai_worker.pipelines.virtual_stager import VirtualStagingPipeline, virtual_stager
from packages.room_model import (
    CanonicalRoomModel,
    CurrencyCode,
    Geometry,
    PortalExportPackage,
    PropertyListingRecord,
    RenovationPotentialEstimate,
    StagedRoomAsset,
    StagingType,
    VirtualStagingDisclosure,
    WatermarkPosition,
)

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_listing_test_state():
    """Reset listings and re-seed defaults prior to each test."""
    repository.listings.clear()
    repository._seed_listings()


# =====================================================================
# Unit Tests: Virtual Staging Pipeline & Regulatory Disclosure
# =====================================================================

def test_pipeline_empty_room_virtual_staging():
    """Tests virtual staging for empty/vacant rooms preserving permanent architectural boundaries."""
    pipeline = VirtualStagingPipeline()
    room = CanonicalRoomModel(
        name="Vacant Living Hall",
        room_type="living_room",
        geometry=Geometry(floor_area_sqm=32.0, ceiling_height_m=3.0),
    )

    asset = pipeline.stage_room(
        room=room,
        staging_type=StagingType.VIRTUAL_STAGING_EMPTY,
        style_theme="Nordic Hygge",
        agent_license_no="REN 99201",
        agency_name="Cornerstone Realty",
        watermark_position=WatermarkPosition.BOTTOM_RIGHT,
    )

    assert asset.asset_id.startswith("stage_")
    assert asset.staging_type == StagingType.VIRTUAL_STAGING_EMPTY
    assert asset.style_theme == "Nordic Hygge"
    assert asset.disclosure.is_virtually_staged is True
    assert asset.disclosure.watermark_applied is True
    assert "Virtually Staged" in asset.disclosure.disclosure_statement
    assert asset.disclosure.agent_license_no == "REN 99201"
    assert asset.disclosure.agency_name == "Cornerstone Realty"
    assert asset.renovation_potential is None


def test_pipeline_declutter_and_stage():
    """Tests declutter and staging mode replacing dated furniture."""
    pipeline = VirtualStagingPipeline()
    room = CanonicalRoomModel(
        name="Cluttered Bedroom",
        room_type="bedroom",
    )

    asset = pipeline.stage_room(
        room=room,
        staging_type=StagingType.DECLUTTER_AND_STAGE,
        style_theme="Warm Contemporary",
        watermark_position=WatermarkPosition.BOTTOM_LEFT,
    )

    assert asset.staging_type == StagingType.DECLUTTER_AND_STAGE
    assert asset.disclosure.watermark_position == WatermarkPosition.BOTTOM_LEFT
    assert asset.disclosure.watermark_applied is True


def test_pipeline_renovation_potential_roi_estimation():
    """Tests renovation potential cosmetic flip computes makeover cost and projected value uplift."""
    pipeline = VirtualStagingPipeline()
    room = CanonicalRoomModel(
        name="Dated 1980s Living Room",
        room_type="living_room",
        geometry=Geometry(floor_area_sqm=30.0, ceiling_height_m=2.8),
    )

    asset = pipeline.stage_room(
        room=room,
        staging_type=StagingType.RENOVATION_POTENTIAL,
        style_theme="Japandi Minimalist",
    )

    assert asset.staging_type == StagingType.RENOVATION_POTENTIAL
    assert asset.renovation_potential is not None
    rp = asset.renovation_potential
    assert len(rp.cosmetic_scope_items) >= 3
    assert rp.estimated_renovation_cost > 0
    assert rp.estimated_value_uplift_amount > rp.estimated_renovation_cost  # Positive ROI
    assert rp.indicative_value_uplift_pct > 0
    assert "Cosmetic renovation estimated at" in rp.roi_notes


def test_pipeline_composite_disclosure_watermark():
    """Tests indelibly burning regulatory disclosure watermark banner onto image bytes."""
    pipeline = VirtualStagingPipeline()

    # Generate a dummy RGB image
    img = Image.new("RGB", (400, 300), color=(180, 200, 220))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    raw_bytes = buf.getvalue()

    watermarked_bytes = pipeline.composite_disclosure_watermark(
        image_bytes=raw_bytes,
        watermark_text="VIRTUALLY STAGED — NOT ACTUAL FURNITURE",
        position=WatermarkPosition.BOTTOM_RIGHT,
    )

    assert len(watermarked_bytes) > 0
    # Verify resulting bytes decode as valid image
    result_img = Image.open(io.BytesIO(watermarked_bytes))
    assert result_img.size == (400, 300)
    assert result_img.format == "JPEG"


def test_pipeline_generate_portal_export_manifest():
    """Tests compiling RESO standard export package and compliance manifest."""
    pipeline = VirtualStagingPipeline()
    listing = repository.get_listing("list_bangsar_01")
    assert listing is not None

    bundle = pipeline.generate_portal_export_manifest(listing)
    assert isinstance(bundle, PortalExportPackage)
    assert bundle.listing_id == "list_bangsar_01"
    assert bundle.portal_format == "RESO_STANDARD"
    assert len(bundle.media_entries) >= 1
    assert "compliance_attestation" in bundle.disclosure_manifest
    assert bundle.media_entries[0]["is_virtually_staged"] is True
    assert bundle.media_entries[0]["reso_media_category"] == "VirtuallyStagedRoom"


# =====================================================================
# Repository Tests: Real Estate Listings & Workflows
# =====================================================================

def test_repository_listing_crud():
    """Tests listing creation, retrieval, filtering, and deletion."""
    initial_count = len(repository.list_listings())

    listing = repository.create_listing(
        property_title="Skyline Penthouse Suites",
        property_type="Penthouse",
        bedrooms=4,
        bathrooms=4,
        built_up_sqft=2800.0,
        listing_price=3500000.0,
        currency=CurrencyCode.MYR,
        property_address="KLCC, Kuala Lumpur",
        listing_agent_name="Evelyn Tan",
        agent_license_no="REN 77102",
        agency_name="Prestige Realty",
    )

    assert listing.listing_id in repository.listings
    assert repository.get_listing(listing.listing_id) == listing
    assert len(repository.list_listings()) == initial_count + 1

    # Filter by agent
    agent_listings = repository.list_listings(agent_license="REN 77102")
    assert len(agent_listings) == 1
    assert agent_listings[0].property_title == "Skyline Penthouse Suites"

    # Update
    updated = repository.update_listing(
        listing_id=listing.listing_id,
        listing_price=3650000.0,
        bedrooms=5,
    )
    assert updated.listing_price == 3650000.0
    assert updated.bedrooms == 5

    # Delete
    deleted = repository.delete_listing(listing.listing_id)
    assert deleted is True
    assert repository.get_listing(listing.listing_id) == None


def test_repository_stage_room_and_export_bundle():
    """Tests staging room attached to listing and generating portal bundle."""
    asset = repository.stage_room_for_listing(
        listing_id="list_damansara_02",
        room_name="Designer Open Kitchen",
        staging_type=StagingType.RENOVATION_POTENTIAL,
        style_theme="Modern European Bistro",
        floor_area_sqm=18.0,
    )

    assert asset.room_name == "Designer Open Kitchen"
    assert asset.renovation_potential is not None
    assert asset.renovation_potential.estimated_renovation_cost > 0

    listing = repository.get_listing("list_damansara_02")
    assert any(r.asset_id == asset.asset_id for r in listing.staged_rooms)

    bundle = repository.export_portal_bundle("list_damansara_02", portal_target="iproperty")
    assert bundle.total_staged_rooms == len(listing.staged_rooms)
    assert bundle.disclosure_manifest["portal_target"] == "iproperty"


def test_repository_generate_property_flyer_html():
    """Tests generating print-ready property marketing flyer HTML."""
    html = repository.generate_property_flyer_html("list_bangsar_01")
    assert "<!DOCTYPE html>" in html
    assert "The Pavilion Suites, Bangsar" in html
    assert "VIRTUALLY STAGED" in html
    assert "Regulatory Compliance Note" in html


# =====================================================================
# REST API Endpoint Tests
# =====================================================================

def test_api_create_and_get_listing():
    """Tests POST /listings and GET /listings/{id} endpoints."""
    payload = {
        "property_title": "Eco Horizon Luxury Villa",
        "mls_number": "MLS-PG-55021",
        "property_type": "Landed House",
        "bedrooms": 5,
        "bathrooms": 5,
        "built_up_sqft": 3600.0,
        "listing_price": 2200000.0,
        "currency": "MYR",
        "property_address": "Batu Kawan, Penang",
        "listing_agent_name": "Daniel Lim",
        "agent_license_no": "REA 3302",
        "agency_name": "Penang Prime Realty",
        "agent_phone": "+60 16 123 4567",
        "agent_email": "daniel@penangprime.my",
    }

    res = client.post("/api/v1/listings", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["property_title"] == "Eco Horizon Luxury Villa"
    listing_id = data["listing_id"]

    # Get by ID
    res_get = client.get(f"/api/v1/listings/{listing_id}")
    assert res_get.status_code == 200
    assert res_get.json()["mls_number"] == "MLS-PG-55021"


def test_api_list_listings():
    """Tests GET /listings with and without filter."""
    res = client.get("/api/v1/listings")
    assert res.status_code == 200
    listings = res.json()
    assert len(listings) >= 2

    # Filter with license
    res_filtered = client.get("/api/v1/listings?agent_license=REN 19482")
    assert res_filtered.status_code == 200
    filtered = res_filtered.json()
    assert len(filtered) == 1
    assert filtered[0]["listing_agent_name"] == "Sarah Wong"


def test_api_stage_room_for_listing():
    """Tests POST /listings/{id}/stage-room endpoint."""
    payload = {
        "room_name": "Junior Bedroom",
        "staging_type": "DECLUTTER_AND_STAGE",
        "style_theme": "Scandinavian Light",
        "watermark_position": "BOTTOM_RIGHT",
        "floor_area_sqm": 16.0,
    }

    res = client.post("/api/v1/listings/list_bangsar_01/stage-room", json=payload)
    assert res.status_code == 201
    asset = res.json()
    assert asset["room_name"] == "Junior Bedroom"
    assert asset["staging_type"] == "DECLUTTER_AND_STAGE"
    assert asset["disclosure"]["is_virtually_staged"] is True
    assert asset["disclosure"]["watermark_applied"] is True

    # Retrieve disclosure
    asset_id = asset["asset_id"]
    res_disc = client.get(f"/api/v1/listings/list_bangsar_01/staged-rooms/{asset_id}/disclosure")
    assert res_disc.status_code == 200
    disc = res_disc.json()
    assert disc["watermark_text"] == "VIRTUALLY STAGED — FOR ILLUSTRATIVE PURPOSES ONLY"


def test_api_stage_room_renovation_potential():
    """Tests staging room with renovation potential ROI calculation."""
    payload = {
        "room_name": "Dated Ensuite Bathroom",
        "staging_type": "RENOVATION_POTENTIAL",
        "style_theme": "Minimalist Spa Luxury",
        "floor_area_sqm": 12.0,
    }

    res = client.post("/api/v1/listings/list_damansara_02/stage-room", json=payload)
    assert res.status_code == 201
    asset = res.json()
    assert asset["renovation_potential"] is not None
    rp = asset["renovation_potential"]
    assert rp["estimated_renovation_cost"] > 0
    assert rp["estimated_value_uplift_amount"] > 0
    assert len(rp["cosmetic_scope_items"]) >= 3


def test_api_export_portal_bundle():
    """Tests POST /listings/{id}/export-portal-bundle endpoint."""
    payload = {"portal_target": "propertyguru"}
    res = client.post("/api/v1/listings/list_bangsar_01/export-portal-bundle", json=payload)
    assert res.status_code == 200
    bundle = res.json()
    assert bundle["listing_id"] == "list_bangsar_01"
    assert bundle["portal_format"] == "RESO_STANDARD"
    assert len(bundle["media_entries"]) >= 1


def test_api_marketing_flyer():
    """Tests GET /listings/{id}/marketing-flyer endpoint."""
    res = client.get("/api/v1/listings/list_bangsar_01/marketing-flyer")
    assert res.status_code == 200
    assert "text/html" in res.headers["content-type"]
    assert "The Pavilion Suites, Bangsar" in res.text


def test_api_apply_watermark_endpoint():
    """Tests POST /staging/apply-watermark endpoint with image upload."""
    img = Image.new("RGB", (300, 200), color=(100, 150, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    image_bytes = buf.getvalue()

    res = client.post(
        "/api/v1/staging/apply-watermark",
        files={"file": ("raw_room.jpg", image_bytes, "image/jpeg")},
        data={
            "watermark_text": "VIRTUALLY STAGED — BOVAEP COMPLIANT",
            "position": "BOTTOM_RIGHT",
        },
    )

    assert res.status_code == 200
    assert res.headers["content-type"] == "image/jpeg"
    watermarked_img = Image.open(io.BytesIO(res.content))
    assert watermarked_img.size == (300, 200)
