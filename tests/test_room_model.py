import pytest
from packages.room_model import (
    CanonicalRoomModel,
    Measurement,
    MeasurementSource,
    ObjectAction,
    ObjectType,
    OpeningType,
    RoomObject,
    RoomOpening,
    RoomSurface,
    SurfaceType,
    BoundingBox2D,
)


def test_measurement_provenance_and_approximation():
    # User verified measurement is not approximate
    meas_verified = Measurement(
        entity_type="wall",
        measurement_type="width",
        value=4.5,
        confidence=0.98,
        source=MeasurementSource.USER_VERIFIED,
        verified_by_user=True,
    )
    assert not meas_verified.is_approximate
    assert meas_verified.display_string == "4.50 m"

    # Monocular depth measurement should always be approximate
    meas_mono = Measurement(
        entity_type="wall",
        measurement_type="width",
        value=4.21,
        confidence=0.72,
        source=MeasurementSource.MONOCULAR_DEPTH,
        verified_by_user=False,
    )
    assert meas_mono.is_approximate
    assert meas_mono.display_string == "Approx. 4.2 m"

    # LiDAR high confidence
    meas_lidar = Measurement(
        entity_type="wall",
        measurement_type="width",
        value=4.22,
        confidence=0.96,
        source=MeasurementSource.LIDAR_NATIVE,
        verified_by_user=False,
    )
    assert not meas_lidar.is_approximate
    assert meas_lidar.display_string == "4.22 m"


def test_bounding_box_validation():
    valid_box = BoundingBox2D(x_min=0.1, y_min=0.2, x_max=0.8, y_max=0.9)
    assert valid_box.x_min == 0.1

    with pytest.raises(ValueError):
        BoundingBox2D(x_min=0.8, y_min=0.2, x_max=0.3, y_max=0.9)


def test_canonical_room_model_constraint_compilation():
    room = CanonicalRoomModel(name="Living Room", room_type="living_room")

    # Add surfaces
    floor = RoomSurface(
        id="floor_01",
        surface_type=SurfaceType.FLOOR,
        name="Tiled Floor",
        action=ObjectAction.REPLACE,
        target_material="chevron_oak",
    )
    wall = RoomSurface(
        id="wall_01",
        surface_type=SurfaceType.WALL,
        name="Main Wall",
        action=ObjectAction.KEEP,
    )
    room.surfaces.extend([floor, wall])

    # Add opening (window)
    window = RoomOpening(
        id="win_01",
        opening_type=OpeningType.WINDOW,
        name="Large Window",
        action=ObjectAction.KEEP,
    )
    room.openings.append(window)

    # Add furniture
    sofa = RoomObject(
        id="sofa_01",
        name="3-Seater Grey Sofa",
        category="sofa",
        action=ObjectAction.KEEP,
    )
    cabinet = RoomObject(
        id="cab_01",
        name="Old TV Console",
        category="tv_unit",
        action=ObjectAction.REMOVE,
    )
    room.objects.extend([sofa, cabinet])

    # Compile constraints
    constraints = room.build_design_constraint(
        styles=["warm", "modern", "minimalist"],
        goals=["increase_space", "brighter_tones"],
        budget_amount=15000.0,
        budget_currency="MYR",
    )

    assert "win_01" in constraints.preserve_ids
    assert "wall_01" in constraints.preserve_ids
    assert "sofa_01" in constraints.preserve_ids
    assert "floor_01" in constraints.replace_ids
    assert "cab_01" in constraints.remove_ids
    assert constraints.budget_amount == 15000.0
    assert constraints.budget_currency == "MYR"
