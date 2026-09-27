import numpy as np
from PIL import Image
from services.ai_worker.pipelines.quality import ImageQualityChecker
from services.ai_worker.pipelines.depth import LocalDepthEstimator
from services.ai_worker.pipelines.room_analyzer import RoomAnalyzer
from services.ai_worker.pipelines.generation import LocalRedesignGenerator
from packages.room_model import ObjectAction


def _create_sample_room_image(width=800, height=600):
    """Creates a synthetic sharp living room test image with texture."""
    np.random.seed(42)
    # Base structure
    arr = np.zeros((height, width, 3), dtype=np.uint8)
    # Ceiling
    arr[0:int(height*0.25), :] = [240, 240, 245]
    # Walls
    arr[int(height*0.25):int(height*0.7), :] = [210, 205, 195]
    # Flooring
    arr[int(height*0.7):, :] = [160, 120, 80]
    # Add sharp window box with frame
    arr[int(height*0.3):int(height*0.55), int(width*0.5):int(width*0.85)] = [130, 180, 220]
    # Add sofa box
    arr[int(height*0.5):int(height*0.8), int(width*0.2):int(width*0.6)] = [80, 85, 95]
    # Add high-frequency texture noise simulating room texture/fabrics
    noise = np.random.randint(-15, 15, (height, width, 3))
    arr = np.clip(arr.astype(int) + noise, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def test_quality_checker_valid_image():
    img = _create_sample_room_image()
    checker = ImageQualityChecker()
    report = checker.validate_image(img)
    assert report.passed
    assert not report.is_blurry
    assert not report.is_under_exposed
    assert not report.is_over_exposed


def test_quality_checker_blurry_image():
    # Completely uniform gray image has 0 laplacian variance (blurred)
    img = Image.new("RGB", (600, 600), (128, 128, 128))
    checker = ImageQualityChecker()
    report = checker.validate_image(img)
    assert not report.passed
    assert report.is_blurry
    assert any("blurry" in msg.lower() for msg in report.feedback_messages)


def test_quality_checker_dark_image():
    img = Image.new("RGB", (600, 600), (10, 10, 10))
    checker = ImageQualityChecker()
    report = checker.validate_image(img)
    assert not report.passed
    assert report.is_under_exposed
    assert any("dark" in msg.lower() for msg in report.feedback_messages)


def test_depth_estimator():
    img = _create_sample_room_image()
    estimator = LocalDepthEstimator()
    result = estimator.estimate_depth(img)
    assert result.provider == "local-depth-estimator"
    assert result.latency_ms > 0
    assert "depth_image" in result.data


def test_room_analyzer_and_redesign_pipeline(tmp_path):
    img = _create_sample_room_image()
    analyzer = RoomAnalyzer()
    room = analyzer.analyze_photo(img, room_name="Living Room 101")

    assert len(room.surfaces) >= 3
    assert len(room.openings) >= 1
    assert len(room.objects) >= 3
    assert len(room.measurements) >= 3

    # Set user choices
    room.set_action_for_element(room.objects[0].id, ObjectAction.KEEP)
    room.set_action_for_element(room.objects[1].id, ObjectAction.REPLACE)

    # Compile constraints
    constraints = room.build_design_constraint(
        styles=["warm", "modern", "minimalist"],
        budget_amount=12000.0,
        budget_currency="MYR",
    )

    # Generate redesign concepts
    generator = LocalRedesignGenerator(output_dir=str(tmp_path))
    res = generator.generate_redesigns(img, room, constraints, count=3)

    assert res.provider == "roomlyst-controlnet-pipeline"
    assert len(room.versions) == 1
    assert len(room.versions[0].variants) == 3
    for v in room.versions[0].variants:
        assert v.structural_preservation_score >= 0.90
