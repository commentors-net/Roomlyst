"""
Milestone 5.3 Tests: Professional Output, Studio Branding, Measurement Schedules, and Export Dossier.
Verifies studio branding configuration, tabular measurement and assumption schedules,
high-resolution export dossier compilation, and standalone printable HTML generation.
"""

from fastapi.testclient import TestClient
import pytest

from services.api.app.main import app
from services.api.app.db.repository import repository
from packages.room_model import (
    CanonicalRoomModel,
    DesignConstraint,
    DesignVariant,
    DesignVersion,
    Geometry,
    Measurement,
    MeasurementSource,
    StudioBranding,
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


def test_default_and_update_project_branding(client):
    """Test getting default branding and updating studio branding profile."""
    proj = repository.create_project(name="Penthouse Suite")

    # 1. Fetch default branding
    res = client.get(f"/api/v1/projects/{proj.id}/branding")
    assert res.status_code == 200
    data = res.json()
    assert data["firm_name"] == "Roomlyst Studio Design"
    assert data["primary_color_hex"] == "#2563EB"

    # 2. Update studio branding
    update_payload = {
        "firm_name": "Studio Aethelgard & Partners",
        "tagline": "Architectural Elegance & Sustainable Interieur",
        "logo_url": "https://assets.aethelgard.com/logo.png",
        "contact_email": "partners@aethelgard.com",
        "contact_phone": "+60 3 2181 8888",
        "website": "https://aethelgard.com",
        "license_number": "PAM-AR-2026-9901",
        "primary_color_hex": "#0F172A",
        "secondary_color_hex": "#0D9488",
        "custom_disclaimer": "All spatial dimensions and material estimates are subject to on-site contractor confirmation.",
    }

    res_update = client.post(f"/api/v1/projects/{proj.id}/branding", json=update_payload)
    assert res_update.status_code == 200
    updated = res_update.json()
    assert updated["firm_name"] == "Studio Aethelgard & Partners"
    assert updated["tagline"] == "Architectural Elegance & Sustainable Interieur"
    assert updated["license_number"] == "PAM-AR-2026-9901"
    assert updated["secondary_color_hex"] == "#0D9488"
    assert "contractor confirmation" in updated["custom_disclaimer"]

    # 3. Verify persistence
    res_get = client.get(f"/api/v1/projects/{proj.id}/branding")
    assert res_get.status_code == 200
    assert res_get.json()["firm_name"] == "Studio Aethelgard & Partners"


def test_generate_export_dossier_single_room(client):
    """Test generating a presentation-ready handover dossier for a single-room project."""
    proj = repository.create_project(name="Modernist Loft")

    # Add a room with confirmed and estimated dimensions
    room = CanonicalRoomModel(
        id="room_loft_01",
        project_id=proj.id,
        name="Main Living Area",
        room_type="living_room",
        geometry=Geometry(floor_area_sqm=36.5, ceiling_height_m=2.85),
        original_image_url="https://storage.roomlyst.com/loft_before.jpg",
        measurements=[
            Measurement(
                entity_type="Room Dimension",
                measurement_type="Length",
                value=6.20,
                unit="m",
                confidence=0.98,
                source=MeasurementSource.USER_VERIFIED,
                verified_by_user=True,
            ),
            Measurement(
                entity_type="Room Dimension",
                measurement_type="Width",
                value=5.88,
                unit="m",
                confidence=0.92,
                source=MeasurementSource.LIDAR_NATIVE,
                verified_by_user=False,
            ),
            Measurement(
                entity_type="Room Dimension",
                measurement_type="Ceiling Height",
                value=2.85,
                unit="m",
                confidence=0.75,
                source=MeasurementSource.MONOCULAR_DEPTH,
                verified_by_user=False,
            ),
        ],
    )
    v1 = DesignVersion(
        version_id="ver_loft_01",
        room_id="room_loft_01",
        constraints=DesignConstraint(),
        version_number=1,
        selected_variant_id="var_loft_selected",
        variants=[
            DesignVariant(
                variant_id="var_loft_selected",
                title="Industrial Warmth",
                style="Industrial Warmth",
                description="Exposed microcement and oiled oak",
                style_name="Industrial Warmth",
                image_url="https://storage.roomlyst.com/industrial_warmth.jpg",
                estimated_cost=48500.0,
            )
        ],
    )
    room.versions.append(v1)
    repository.save_room(room)

    res = client.get(f"/api/v1/projects/{proj.id}/export-dossier")
    assert res.status_code == 200
    dossier = res.json()

    assert dossier["project_id"] == proj.id
    assert dossier["project_name"] == "Modernist Loft"
    assert dossier["total_rooms"] == 1
    assert dossier["total_floor_area_sqm"] == 36.5
    assert dossier["total_estimated_budget"] == 48500.0
    assert len(dossier["room_sheets"]) == 1
    assert dossier["room_sheets"][0]["selected_variant_title"] == "Industrial Warmth"

    # Tabular measurement schedules verification
    schedules = dossier["measurement_schedules"]
    assert len(schedules) >= 3
    types = [s["dimension_type"] for s in schedules]
    assert "Length" in types
    assert "Width" in types
    assert "Ceiling Height" in types

    # Ceiling height has low confidence (0.75), requires site check
    ceiling_item = next(s for s in schedules if s["dimension_type"] == "Ceiling Height")
    assert ceiling_item["requires_site_verification"] is True
    assert ceiling_item["confidence"] == 0.75

    # Architectural assumptions verification
    assumptions = dossier["assumption_schedules"]
    assert len(assumptions) >= 6
    categories = [a["category"] for a in assumptions]
    assert "STRUCTURAL" in categories
    assert "MEP_ELECTRICAL" in categories
    assert "MEP_PLUMBING" in categories
    assert "WATERPROOFING" in categories


def test_generate_export_dossier_multi_room(client):
    """Test generating a multi-room handover dossier aggregating metrics."""
    proj = repository.create_project(name="Twin Villa")

    # Room 1: Living
    r1 = CanonicalRoomModel(
        id="room_tv_01",
        project_id=proj.id,
        name="Grand Salon",
        geometry=Geometry(floor_area_sqm=45.0),
    )
    v1 = DesignVersion(
        version_id="ver_01",
        room_id="room_tv_01",
        constraints=DesignConstraint(),
        version_number=1,
        selected_variant_id="var_01",
        variants=[
            DesignVariant(
                variant_id="var_01",
                title="Neo-Classical Salon",
                style="Neo-Classical",
                description="Elegance with wainscoting",
                style_name="Neo-Classical",
                image_url="https://storage.roomlyst.com/classical.jpg",
                estimated_cost=60000.0,
            )
        ],
    )
    r1.versions.append(v1)
    repository.save_room(r1)

    # Room 2: Master Suite
    r2 = CanonicalRoomModel(
        id="room_tv_02",
        project_id=proj.id,
        name="Master Bedroom",
        geometry=Geometry(floor_area_sqm=28.0),
    )
    v2 = DesignVersion(
        version_id="ver_02",
        room_id="room_tv_02",
        constraints=DesignConstraint(),
        version_number=1,
        selected_variant_id="var_02",
        variants=[
            DesignVariant(
                variant_id="var_02",
                title="Serene Japandi Suite",
                style="Japandi",
                description="Organic oak slats and recessed lighting",
                style_name="Japandi",
                image_url="https://storage.roomlyst.com/japandi_suite.jpg",
                estimated_cost=35000.0,
            )
        ],
    )
    r2.versions.append(v2)
    repository.save_room(r2)

    res = client.get(f"/api/v1/projects/{proj.id}/export-dossier")
    assert res.status_code == 200
    dossier = res.json()

    assert dossier["total_rooms"] == 2
    assert dossier["total_floor_area_sqm"] == 73.0
    assert dossier["total_estimated_budget"] == 95000.0
    assert len(dossier["room_sheets"]) == 2


def test_export_package_endpoint(client):
    """Test structured JSON export package download endpoint."""
    proj = repository.create_project(name="Urban Studio")
    res = client.get(f"/api/v1/projects/{proj.id}/export-package")
    assert res.status_code == 200
    pkg = res.json()
    assert pkg["project_name"] == "Urban Studio"
    assert "download_bundle_url" in pkg
    assert "measurement_schedules" in pkg
    assert "assumption_schedules" in pkg


def test_branded_report_html_endpoint(client):
    """Test standalone printable HTML report endpoint."""
    proj = repository.create_project(name="Heritage Shophouse")
    repository.update_project_branding(
        proj.id,
        {
            "firm_name": "Atelier Peranakan",
            "tagline": "Restoring History with Modernity",
            "license_number": "ARCH-KL-8821",
        },
    )

    res = client.get(f"/api/v1/projects/{proj.id}/branded-report")
    assert res.status_code == 200
    assert res.headers["content-type"].startswith("text/html")
    html_content = res.text

    assert "<!DOCTYPE html>" in html_content
    assert "Atelier Peranakan" in html_content
    assert "Heritage Shophouse" in html_content
    assert "ARCH-KL-8821" in html_content
    assert "Architectural &amp; Construction Assumptions Schedule" in html_content or "Architectural & Construction Assumptions Schedule" in html_content
    assert "Designer Sign-off" in html_content or "Prepared By (Lead Designer)" in html_content
    assert "Client Acceptance" in html_content or "Accepted & Acknowledged By" in html_content


def test_export_endpoints_not_found(client):
    """Test 404 behavior for invalid project IDs."""
    res_dossier = client.get("/api/v1/projects/non_existent_project/export-dossier")
    assert res_dossier.status_code == 404

    res_pkg = client.get("/api/v1/projects/non_existent_project/export-package")
    assert res_pkg.status_code == 404

    res_report = client.get("/api/v1/projects/non_existent_project/branded-report")
    assert res_report.status_code == 404

    res_branding = client.get("/api/v1/projects/non_existent_project/branding")
    assert res_branding.status_code == 404
