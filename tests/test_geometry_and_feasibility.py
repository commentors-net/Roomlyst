import io
import numpy as np
import pytest
from PIL import Image
from fastapi.testclient import TestClient

from packages.room_model import (
    CanonicalRoomModel,
    FeasibilityCheck,
    FeasibilityIssueType,
    FeasibilityReport,
    FeasibilitySeverity,
    FurnitureFootprint,
    Geometry,
    LoopClosureStatus,
    Point2D,
    RoomObject,
    RoomOpening,
    RoomShapeType,
    OpeningType,
    WallSegment,
)
from services.ai_worker.pipelines.feasibility_analyzer import GeometryAndFeasibilityAnalyzer
from services.api.app.main import app

client = TestClient(app)


def _create_test_image_bytes():
    np.random.seed(42)
    arr = np.zeros((600, 800, 3), dtype=np.uint8)
    arr[0:400, :] = [210, 205, 195]
    arr[400:, :] = [160, 120, 80]
    noise = np.random.randint(-15, 15, (600, 800, 3))
    arr = np.clip(arr.astype(int) + noise, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)
    return buf.getvalue()


def test_rectangular_wall_loop_closure():
    """Verify standard rectangular room wall synthesis and Shoelace area."""
    room = CanonicalRoomModel(
        name="Rectangular Room",
        geometry=Geometry(
            estimated_width_m=4.0,
            estimated_length_m=5.0,
            ceiling_height_m=2.5,
        ),
    )
    analyzer = GeometryAndFeasibilityAnalyzer()
    analyzer.process_geometry(room)

    geom = room.geometry
    assert geom.room_shape == RoomShapeType.RECTANGULAR
    assert geom.loop_closure_status == LoopClosureStatus.CLOSED
    assert geom.loop_closure_gap_m == 0.0
    assert len(geom.wall_segments) == 4
    assert len(geom.polygon_vertices) == 4
    assert pytest.approx(geom.perimeter_m, 0.01) == 18.0
    assert pytest.approx(geom.floor_area_sqm, 0.01) == 20.0


def test_wall_loop_snapping_and_open_gap():
    """Verify endpoint snapping for small gaps and open status for large gaps."""
    analyzer = GeometryAndFeasibilityAnalyzer()

    # Case A: Small gap of 8cm (0.08m) -> should auto-snap
    room_snap = CanonicalRoomModel(
        name="Snapping Room",
        geometry=Geometry(
            wall_segments=[
                WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=4.0, y=0.0), length_m=4.0),
                WallSegment(start_point=Point2D(x=4.0, y=0.0), end_point=Point2D(x=4.0, y=5.0), length_m=5.0),
                WallSegment(start_point=Point2D(x=4.0, y=5.0), end_point=Point2D(x=0.0, y=5.0), length_m=4.0),
                # Ends at (0.08, 0.0) instead of (0.0, 0.0) -> gap is 0.08m
                WallSegment(start_point=Point2D(x=0.0, y=5.0), end_point=Point2D(x=0.08, y=0.0), length_m=5.0),
            ]
        ),
    )
    analyzer.process_geometry(room_snap)
    assert room_snap.geometry.loop_closure_status == LoopClosureStatus.SNAPPED
    assert room_snap.geometry.loop_closure_gap_m == 0.08
    assert room_snap.geometry.wall_segments[-1].end_point.x == 0.0
    assert room_snap.geometry.wall_segments[-1].end_point.y == 0.0

    # Case B: Large gap of 40cm (0.40m) -> should remain open
    room_open = CanonicalRoomModel(
        name="Open Loop Room",
        geometry=Geometry(
            wall_segments=[
                WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=4.0, y=0.0), length_m=4.0),
                WallSegment(start_point=Point2D(x=4.0, y=0.0), end_point=Point2D(x=4.0, y=5.0), length_m=5.0),
                WallSegment(start_point=Point2D(x=4.0, y=5.0), end_point=Point2D(x=0.0, y=5.0), length_m=4.0),
                WallSegment(start_point=Point2D(x=0.0, y=5.0), end_point=Point2D(x=0.40, y=0.0), length_m=5.0),
            ]
        ),
    )
    analyzer.process_geometry(room_open)
    assert room_open.geometry.loop_closure_status == LoopClosureStatus.OPEN
    assert room_open.geometry.loop_closure_gap_m == 0.40


def test_non_rectangular_l_shaped_room_shoelace_area():
    """Verify Shoelace area and classification for an L-shaped room (6 vertices)."""
    # L-shaped layout: 6m x 6m outer, with a 3m x 3m cutout
    # Area = (6 * 6) - (3 * 3) = 36 - 9 = 27 m²
    l_room = CanonicalRoomModel(
        name="L-Shaped Living Room",
        geometry=Geometry(
            wall_segments=[
                WallSegment(start_point=Point2D(x=0.0, y=0.0), end_point=Point2D(x=6.0, y=0.0), length_m=6.0),
                WallSegment(start_point=Point2D(x=6.0, y=0.0), end_point=Point2D(x=6.0, y=3.0), length_m=3.0),
                WallSegment(start_point=Point2D(x=6.0, y=3.0), end_point=Point2D(x=3.0, y=3.0), length_m=3.0),
                WallSegment(start_point=Point2D(x=3.0, y=3.0), end_point=Point2D(x=3.0, y=6.0), length_m=3.0),
                WallSegment(start_point=Point2D(x=3.0, y=6.0), end_point=Point2D(x=0.0, y=6.0), length_m=3.0),
                WallSegment(start_point=Point2D(x=0.0, y=6.0), end_point=Point2D(x=0.0, y=0.0), length_m=6.0),
            ]
        ),
    )
    analyzer = GeometryAndFeasibilityAnalyzer()
    analyzer.process_geometry(l_room)

    geom = l_room.geometry
    assert geom.room_shape == RoomShapeType.L_SHAPED
    assert geom.loop_closure_status == LoopClosureStatus.CLOSED
    assert len(geom.polygon_vertices) == 6
    assert pytest.approx(geom.perimeter_m, 0.01) == 24.0
    assert pytest.approx(geom.floor_area_sqm, 0.01) == 27.0


def test_door_swing_clearance_feasibility():
    """Verify door swing clearance obstruction triggers CRITICAL feasibility issue."""
    analyzer = GeometryAndFeasibilityAnalyzer()

    # Room with door at entrance (0.90, 0.0)
    door = RoomOpening(
        name="Front Door",
        opening_type=OpeningType.DOOR,
    )
    # Sofa placed directly in front of door swing path (< 0.85m)
    sofa_blocked = RoomObject(
        name="Obstruction Sofa",
        category="sofa",
        footprint_2d=FurnitureFootprint(
            center_x=0.90,
            center_y=0.40,
            width_m=1.80,
            length_m=0.80,
            min_x=0.0,
            max_x=1.80,
            min_y=0.0,
            max_y=0.80,
        ),
    )

    room = CanonicalRoomModel(
        name="Blocked Door Room",
        geometry=Geometry(estimated_width_m=4.0, estimated_length_m=5.0),
        openings=[door],
        objects=[sofa_blocked],
    )

    report = analyzer.analyze(room)
    assert report.overall_feasible is False
    assert report.critical_issues_count >= 1

    door_check = next(c for c in report.checks if c.issue_type == FeasibilityIssueType.DOOR_SWING_OBSTRUCTED)
    assert door_check.passed is False
    assert door_check.severity == FeasibilitySeverity.CRITICAL
    assert "obstructed" in door_check.message.lower()


def test_inter_furniture_walkway_clearance_and_overlap():
    """Verify furniture overlap (CRITICAL) and narrow walkway (WARNING) detection."""
    analyzer = GeometryAndFeasibilityAnalyzer()

    # Case 1: Overlapping furniture
    sofa = RoomObject(
        name="Sofa",
        category="sofa",
        footprint_2d=FurnitureFootprint(
            center_x=2.0, center_y=2.0, width_m=2.0, length_m=0.9,
            min_x=1.0, max_x=3.0, min_y=1.55, max_y=2.45
        ),
    )
    table_overlapping = RoomObject(
        name="Coffee Table Overlap",
        category="coffee_table",
        footprint_2d=FurnitureFootprint(
            center_x=2.0, center_y=2.3, width_m=1.0, length_m=0.6,
            min_x=1.5, max_x=2.5, min_y=2.0, max_y=2.6
        ),
    )

    room_overlap = CanonicalRoomModel(
        name="Overlap Room",
        geometry=Geometry(estimated_width_m=5.0, estimated_length_m=5.0),
        objects=[sofa, table_overlapping],
    )
    report_overlap = analyzer.analyze(room_overlap)
    assert report_overlap.overall_feasible is False
    assert any(c.issue_type == FeasibilityIssueType.FURNITURE_OVERLAP for c in report_overlap.checks)

    # Case 2: Narrow walkway (clearance = 0.40m, less than 0.60m threshold)
    table_narrow = RoomObject(
        name="Coffee Table Narrow",
        category="coffee_table",
        footprint_2d=FurnitureFootprint(
            center_x=2.0, center_y=3.15, width_m=1.0, length_m=0.6,
            min_x=1.5, max_x=2.5, min_y=2.85, max_y=3.45  # 2.85 - 2.45 = 0.40m walkway
        ),
    )
    room_narrow = CanonicalRoomModel(
        name="Narrow Walkway Room",
        geometry=Geometry(estimated_width_m=5.0, estimated_length_m=5.0),
        objects=[sofa, table_narrow],
    )
    report_narrow = analyzer.analyze(room_narrow)
    assert report_narrow.warning_issues_count >= 1
    assert any(c.issue_type == FeasibilityIssueType.WALKWAY_TOO_NARROW for c in report_narrow.checks)
    assert pytest.approx(report_narrow.min_walkway_clearance_m, 0.02) == 0.40


def test_api_room_feasibility_endpoint():
    """Verify GET /api/v1/rooms/{id}/feasibility endpoint."""
    img_bytes = _create_test_image_bytes()
    files = {"file": ("feasibility_room.jpg", img_bytes, "image/jpeg")}
    data = {"room_name": "API Feasibility Room", "room_type": "living_room"}

    res_upload = client.post("/api/v1/rooms/upload-and-analyze", files=files, data=data)
    assert res_upload.status_code == 200
    room = res_upload.json()
    room_id = room["id"]

    # Verify feasibility endpoint
    res_feas = client.get(f"/api/v1/rooms/{room_id}/feasibility")
    assert res_feas.status_code == 200
    report = res_feas.json()

    assert "overall_feasible" in report
    assert "critical_issues_count" in report
    assert "warning_issues_count" in report
    assert "checks" in report
    assert isinstance(report["checks"], list)
    assert len(report["checks"]) >= 1
    assert "summary" in report
