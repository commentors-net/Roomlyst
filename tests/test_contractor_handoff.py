"""
Milestone 6.2 — Contractor Handoff & Tender Bid Management Tests
Tests contractor brief generation, confirmed-vs-estimated measurement separation,
Bill of Quantities (BOQ) with wastage allowances, RFQ lifecycle, bidding compliance,
and bid comparative evaluation.
"""

import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient

from services.api.app.main import app
from services.api.app.db.repository import repository
from packages.room_model import (
    TradeCategory,
    RFQStatus,
    BidStatus,
    CanonicalRoomModel,
    Measurement,
    MeasurementSource,
)

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_contractor_test_state():
    """Reset repository project and contractor collections prior to each test."""
    repository.projects.clear()
    repository.rooms.clear()
    repository.contractor_briefs.clear()
    repository.rfqs.clear()
    repository.contractor_bids.clear()


def test_contractor_brief_generation_and_measurement_separation():
    """Tests contractor brief compiles trade packages, BOQ, and separates confirmed vs unconfirmed measurements."""
    proj = repository.create_project(
        name="Penthouse Suite 12",
        currency="MYR",
        property_address="Mont Kiara, Kuala Lumpur",
    )

    # Attach a room with mixed measurement provenance
    room = CanonicalRoomModel(
        project_id=proj.id,
        name="Master Bedroom",
        room_type="bedroom",
        measurements=[
            Measurement(
                entity_type="room",
                measurement_type="length",
                name="Room Length",
                value=6.0,
                unit="m",
                source=MeasurementSource.USER_VERIFIED,
                confidence=1.0,
                verified_by_user=True,
            ),
            Measurement(
                entity_type="wall",
                measurement_type="length",
                name="Joinery Wall Span",
                value=4.8,
                unit="m",
                source=MeasurementSource.MONOCULAR_DEPTH,
                confidence=0.78,
                verified_by_user=False,
            ),
            Measurement(
                entity_type="room",
                measurement_type="height",
                name="Ceiling Height",
                value=3.1,
                unit="m",
                source=MeasurementSource.LIDAR_NATIVE,
                confidence=0.96,
                verified_by_user=True,
            ),
        ]
    )
    repository.save_room(room)
    proj.room_ids.append(room.id)

    brief = repository.generate_contractor_brief(
        project_id=proj.id,
        room_id=room.id,
        site_access_notes="Loading bay slot booked for 8:30 AM weekdays.",
    )

    assert brief.brief_id.startswith("cbrief_")
    assert brief.project_id == proj.id
    assert len(brief.work_packages) >= 5
    assert len(brief.boq_items) >= 4

    # Confirmed vs Unconfirmed measurement count
    assert brief.confirmed_measurements_count == 2
    assert brief.unconfirmed_measurements_count == 1
    assert len(brief.verification_checklist) == 3

    # Check that unconfirmed joinery wall is flagged for site verification
    joinery_check = next(c for c in brief.verification_checklist if "Joinery" in c.dimension_label)
    assert not joinery_check.is_physically_verified
    assert joinery_check.critical_for_trade == TradeCategory.CARPENTRY_JOINERY

    # Verify BOQ wastage allowances
    tile_item = next(b for b in brief.boq_items if b.trade == TradeCategory.MASONRY_TILING)
    assert tile_item.waste_factor_pct == 10.0
    assert tile_item.total_quantity_with_waste > tile_item.quantity

    # Statutory disclaimer check
    assert "Statutory Notice" in brief.statutory_disclaimer
    assert brief.printable_html is not None
    assert "<!DOCTYPE html>" in brief.printable_html


def test_contractor_checklist_item_sign_off():
    """Tests contractor/surveyor on-site physical measurement verification update."""
    proj = repository.create_project(name="Eco Residence", currency="MYR")
    brief = repository.generate_contractor_brief(proj.id)

    unconfirmed_item = next(c for c in brief.verification_checklist if not c.is_physically_verified)
    initial_unconfirmed = brief.unconfirmed_measurements_count

    verified_item = repository.verify_checklist_item(
        brief_id=brief.brief_id,
        checklist_id=unconfirmed_item.checklist_id,
        verified_by_name="Master Joiner Tan",
        notes="Laser checked on site. Exact span is 4.52m.",
    )

    assert verified_item.is_physically_verified is True
    assert verified_item.verified_by_name == "Master Joiner Tan"
    assert verified_item.verified_at is not None
    assert brief.unconfirmed_measurements_count == initial_unconfirmed - 1


def test_contractor_rfq_and_bid_compliance_workflow():
    """Tests RFQ creation, contractor quote submission, and compliance validation."""
    proj = repository.create_project(name="Bangsar Villa", currency="MYR")
    brief = repository.generate_contractor_brief(proj.id)

    # Issue RFQ
    rfq = repository.create_quote_request(
        project_id=proj.id,
        brief_id=brief.brief_id,
        title="Main Renovation Tender - Bangsar Villa",
        target_trades=[TradeCategory.CARPENTRY_JOINERY, TradeCategory.MASONRY_TILING, TradeCategory.ELECTRICAL_LIGHTING],
        invited_contractors=["Apex Builders", "Straits Craft Carpentry"],
    )

    assert rfq.rfq_id.startswith("rfq_")
    assert rfq.status == RFQStatus.BIDDING_OPEN
    assert len(rfq.target_trades) == 3

    # Attempt bid submission without compliance acknowledgment -> should raise ValueError
    with pytest.raises(ValueError, match="Contractor must acknowledge"):
        repository.submit_contractor_bid(
            rfq_id=rfq.rfq_id,
            contractor_id="c_noncompliant",
            contractor_name="Rogue Contractors",
            license_no="UNKNOWN",
            contact_email="rogue@example.com",
            overall_bid_amount=10000.0,
            trade_specialties=[TradeCategory.CARPENTRY_JOINERY],
            statutory_compliance_acknowledged=False,
            on_site_verification_acknowledged=True,
        )

    # Valid compliant bid submission
    bid1 = repository.submit_contractor_bid(
        rfq_id=rfq.rfq_id,
        contractor_id="c_apex",
        contractor_name="Apex Builders Sdn Bhd",
        license_no="CIDB-G5-2024-9988",
        contact_email="tender@apexbuilders.my",
        overall_bid_amount=13900.0,
        trade_specialties=[TradeCategory.MASONRY_TILING, TradeCategory.CARPENTRY_JOINERY],
        estimated_lead_time_days=12,
        statutory_compliance_acknowledged=True,
        on_site_verification_acknowledged=True,
        submission_notes="Includes premium waterproof membrane underlay.",
    )

    assert bid1.bid_id.startswith("bid_")
    assert bid1.status == BidStatus.SUBMITTED
    assert bid1.statutory_compliance_acknowledged is True
    assert bid1.on_site_verification_acknowledged is True
    assert len(rfq.bids) == 1


def test_bid_comparison_and_tender_awarding():
    """Tests side-by-side bid comparison, variance analysis, and tender contract awarding."""
    proj = repository.create_project(name="Damansara Heights Bungalow", currency="MYR")
    brief = repository.generate_contractor_brief(proj.id)

    rfq = repository.create_quote_request(
        project_id=proj.id,
        brief_id=brief.brief_id,
        title="Tender - Joinery & Wet Works",
        target_trades=[TradeCategory.CARPENTRY_JOINERY, TradeCategory.MASONRY_TILING],
    )

    # Submit 2 competitive bids
    bid_apex = repository.submit_contractor_bid(
        rfq_id=rfq.rfq_id,
        contractor_id="c_apex",
        contractor_name="Apex Builders",
        license_no="CIDB-G5-88",
        contact_email="apex@example.com",
        overall_bid_amount=13500.0,
        trade_specialties=[TradeCategory.MASONRY_TILING],
        estimated_lead_time_days=10,
    )

    bid_straits = repository.submit_contractor_bid(
        rfq_id=rfq.rfq_id,
        contractor_id="c_straits",
        contractor_name="Straits Craft Carpentry",
        license_no="CIDB-G3-44",
        contact_email="straits@example.com",
        overall_bid_amount=14800.0,
        trade_specialties=[TradeCategory.CARPENTRY_JOINERY],
        estimated_lead_time_days=14,
    )

    # Evaluate comparison
    comparison = repository.evaluate_and_compare_bids(rfq.rfq_id)
    assert comparison.total_bids_count == 2
    assert comparison.lowest_bid_amount == 13500.0
    assert comparison.highest_bid_amount == 14800.0
    assert comparison.recommended_bid_id == bid_apex.bid_id
    assert len(comparison.bids_ranked) == 2

    # Award to Apex Builders
    awarded = repository.award_contractor_bid(rfq.rfq_id, bid_apex.bid_id)
    assert awarded.status == BidStatus.ACCEPTED
    assert rfq.awarded_bid_id == bid_apex.bid_id
    assert rfq.status == RFQStatus.AWARDED

    # Ensure other bid was marked rejected
    assert bid_straits.status == BidStatus.REJECTED


def test_contractor_api_endpoints_integration():
    """Tests FastAPI HTTP REST endpoints for contractor brief, RFQ, bids, and printable HTML."""
    proj = repository.create_project(name="API Test Manor", currency="MYR")

    # 1. Generate contractor brief
    res = client.post(
        f"/api/v1/projects/{proj.id}/contractor-brief",
        json={"site_access_notes": "Service elevator available daily from 9 AM to 5 PM."},
    )
    assert res.status_code == 201
    brief_data = res.json()
    brief_id = brief_data["brief_id"]
    assert len(brief_data["work_packages"]) >= 5
    assert len(brief_data["boq_items"]) >= 4

    # 2. Get printable HTML
    html_res = client.get(f"/api/v1/contractor-briefs/{brief_id}/printable")
    assert html_res.status_code == 200
    assert "text/html" in html_res.headers["content-type"]
    assert "MANDATORY STATUTORY NOTICE" in html_res.text

    # 3. Verify checklist item
    checklist_id = brief_data["verification_checklist"][0]["checklist_id"]
    verify_res = client.post(
        f"/api/v1/contractor-briefs/{brief_id}/verify-item",
        json={
            "checklist_id": checklist_id,
            "verified_by_name": "Chief Surveyor Wong",
            "notes": "Dimension verified on site.",
        },
    )
    assert verify_res.status_code == 200
    assert verify_res.json()["is_physically_verified"] is True

    # 4. Create RFQ
    rfq_res = client.post(
        f"/api/v1/projects/{proj.id}/rfqs",
        json={
            "title": "Turnkey Renovation Tender",
            "brief_id": brief_id,
            "target_trades": ["CARPENTRY_JOINERY", "MASONRY_TILING"],
            "invited_contractors": ["VoltSmart", "Apex"],
        },
    )
    assert rfq_res.status_code == 201
    rfq_id = rfq_res.json()["rfq_id"]

    # 5. Submit Bid
    bid_res = client.post(
        f"/api/v1/rfqs/{rfq_id}/bids",
        json={
            "contractor_id": "c_volt",
            "contractor_name": "VoltSmart Electrical & Joinery",
            "license_no": "CIDB-G4-9900",
            "contact_email": "bids@voltsmart.my",
            "overall_bid_amount": 14200.0,
            "trade_specialties": ["ELECTRICAL_LIGHTING", "CARPENTRY_JOINERY"],
            "statutory_compliance_acknowledged": True,
            "on_site_verification_acknowledged": True,
        },
    )
    assert bid_res.status_code == 201
    bid_id = bid_res.json()["bid_id"]

    # 6. Compare bids
    compare_res = client.get(f"/api/v1/rfqs/{rfq_id}/compare")
    assert compare_res.status_code == 200
    assert compare_res.json()["total_bids_count"] == 1

    # 7. Award tender
    award_res = client.post(f"/api/v1/rfqs/{rfq_id}/award/{bid_id}")
    assert award_res.status_code == 200
    assert award_res.json()["status"] == "ACCEPTED"
