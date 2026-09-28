import io
import pytest
import numpy as np
from PIL import Image
from fastapi.testclient import TestClient

from packages.room_model import (
    CanonicalRoomModel,
    VideoScanReport,
    VideoScanMetadata,
)
from services.ai_worker.pipelines.video_scan_analyzer import VideoScanAnalyzer
from services.api.app.main import app
from services.api.app.db.session import SessionLocal
from services.api.app.db.models import Room


@pytest.fixture
def client():
    return TestClient(app)


def _generate_synthetic_frame(index: int, width=320, height=240, blurry=False) -> Image.Image:
    """Generates synthetic room video frame with distinct edges or blur."""
    arr = np.zeros((height, width, 3), dtype=np.uint8)
    shift = (index * 25) % 100

    # Ceiling
    arr[0:int(height * 0.25), :] = [230, 230, 240]
    # Wall with features
    arr[int(height * 0.25):int(height * 0.75), :] = [180 + (index % 15), 185, 200]
    # Window / Door edge
    w_start = int((width * 0.2) + shift) % (width - 60)
    arr[int(height * 0.3):int(height * 0.65), w_start:w_start + 50] = [70, 140, 220]
    # Floor
    arr[int(height * 0.75):, :] = [120, 95, 75]

    if not blurry:
        # Add high-contrast gradient/texture
        arr[::4, ::4, :] = 255
    else:
        # Uniform smooth to simulate motion blur
        arr = np.full((height, width, 3), 150, dtype=np.uint8)

    return Image.fromarray(arr)


def _image_to_bytes(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


class TestVideoScanAnalyzer:
    def test_sharpness_calculation(self):
        analyzer = VideoScanAnalyzer()
        sharp_img = _generate_synthetic_frame(0, blurry=False)
        blurry_img = _generate_synthetic_frame(0, blurry=True)

        sharp_score = analyzer.calculate_sharpness(sharp_img)
        blurry_score = analyzer.calculate_sharpness(blurry_img)

        assert sharp_score > blurry_score
        assert sharp_score > 50.0
        assert blurry_score < 20.0

    def test_consecutive_displacement(self):
        analyzer = VideoScanAnalyzer()
        img1 = _generate_synthetic_frame(0)
        img1_clone = _generate_synthetic_frame(0)
        img2 = _generate_synthetic_frame(3)

        disp_zero = analyzer.calculate_consecutive_displacement(img1, img1_clone)
        disp_diff = analyzer.calculate_consecutive_displacement(img1, img2)

        assert disp_zero < 0.01
        assert disp_diff > 0.02

    def test_sample_keyframes_and_duplicate_filtering(self):
        analyzer = VideoScanAnalyzer()
        # Generate sequence where some frames are identical
        frames = [
            _generate_synthetic_frame(0),
            _generate_synthetic_frame(0), # duplicate
            _generate_synthetic_frame(1),
            _generate_synthetic_frame(2),
            _generate_synthetic_frame(3),
            _generate_synthetic_frame(4),
        ]
        timestamps = [0.0, 0.5, 1.5, 3.0, 4.5, 6.0]

        keyframes, metadata = analyzer.sample_keyframes(
            frames=frames,
            timestamps=timestamps,
            min_keyframe_interval_sec=0.8,
            min_sharpness_threshold=30.0,
        )

        assert len(keyframes) >= 4
        # Duplicate frame (index 1) should be filtered out
        frame_indices = [kf.frame_index for kf in keyframes]
        assert 1 not in frame_indices
        assert 0 in frame_indices

    def test_evaluate_video_scan_suitability(self):
        analyzer = VideoScanAnalyzer()
        frames = [_generate_synthetic_frame(i) for i in range(6)]
        timestamps = [i * 1.5 for i in range(6)]

        report = analyzer.evaluate_video_scan(
            room_id="room_test_suitability",
            frames=frames,
            timestamps=timestamps,
            video_duration_seconds=9.0,
            fps=30.0,
            panning_speeds=[12.0, 14.0, 16.0, 13.0, 15.0],
        )

        assert report.room_id == "room_test_suitability"
        assert report.is_suitable_for_reconstruction is True
        assert report.quality_assessment in ["EXCELLENT", "ACCEPTABLE"]
        assert report.metadata.sampled_keyframes_count >= 4
        assert report.metadata.motion_stability_score >= 0.80
        assert len(report.guidanceNotes if hasattr(report, "guidanceNotes") else report.guidance_notes) > 0

    def test_evaluate_video_scan_insufficient_frames(self):
        analyzer = VideoScanAnalyzer()
        # Only 2 blurry frames
        frames = [_generate_synthetic_frame(0, blurry=True), _generate_synthetic_frame(1, blurry=True)]
        timestamps = [0.0, 1.0]

        report = analyzer.evaluate_video_scan(
            room_id="room_test_fail",
            frames=frames,
            timestamps=timestamps,
            video_duration_seconds=2.0,
            fps=30.0,
            panning_speeds=[35.0, 40.0], # too fast
        )

        assert report.is_suitable_for_reconstruction is False
        assert report.quality_assessment in ["INSUFFICIENT_COVERAGE", "UNSTABLE"]


class TestVideoScanApiEndpoints:
    def test_video_chunked_upload_lifecycle(self, client):
        # 1. Init session
        init_resp = client.post(
            "/api/v1/scan/video/init",
            json={
                "room_id": "room_chunk_test",
                "total_chunks": 2,
                "total_bytes": 1024,
                "video_format": "mp4",
            },
        )
        assert init_resp.status_code == 200
        session_data = init_resp.json()
        session_id = session_data["session_id"]
        assert session_data["room_id"] == "room_chunk_test"

        # 2. Upload chunk 0
        chunk_0_resp = client.post(
            "/api/v1/scan/video/chunk",
            data={"session_id": session_id, "chunk_index": 0},
            files={"chunk_data": ("chunk_0.bin", b"A" * 512, "application/octet-stream")},
        )
        assert chunk_0_resp.status_code == 200
        assert chunk_0_resp.json()["received_chunks"] == 1

        # 3. Upload chunk 1
        chunk_1_resp = client.post(
            "/api/v1/scan/video/chunk",
            data={"session_id": session_id, "chunk_index": 1},
            files={"chunk_data": ("chunk_1.bin", b"B" * 512, "application/octet-stream")},
        )
        assert chunk_1_resp.status_code == 200
        assert chunk_1_resp.json()["received_chunks"] == 2

        # 4. Complete session
        complete_resp = client.post(
            "/api/v1/scan/video/complete",
            json={"session_id": session_id},
        )
        assert complete_resp.status_code == 200
        complete_data = complete_resp.json()
        assert complete_data["status"] == "COMPLETED"
        assert complete_data["total_bytes_received"] == 1024
        assert "report" in complete_data

    def test_video_sample_and_analyze_endpoint(self, client):
        room_id = "room_vscan_full_test"
        # Seed room model in DB first
        db = SessionLocal()
        room_model = CanonicalRoomModel(
            id=room_id,
            name="Living Room Video Scan",
        )
        db_room = Room(
            id=room_id,
            project_id="proj_test_01",
            name="Living Room Video Scan",
            room_type="living_room",
            status="DRAFT",
            room_model_data=room_model.model_dump(mode="json"),
        )
        db.add(db_room)
        db.commit()
        db.close()

        # Prepare 5 synthetic keyframe files
        files = []
        for i in range(5):
            img = _generate_synthetic_frame(i)
            b = _image_to_bytes(img)
            files.append(("files", (f"keyframe_{i}.jpg", b, "image/jpeg")))

        resp = client.post(
            "/api/v1/scan/video/sample-and-analyze",
            data={
                "room_id": room_id,
                "video_duration_seconds": 12.0,
                "fps": 30.0,
            },
            files=files,
        )
        assert resp.status_code == 200
        report = resp.json()
        assert report["room_id"] == room_id
        assert report["is_suitable_for_reconstruction"] is True
        assert len(report["keyframes"]) >= 4
        assert report["metadata"]["sampled_keyframes_count"] >= 4

        # Verify GET /rooms/{room_id}/video-scan-report
        get_resp = client.get(f"/api/v1/rooms/{room_id}/video-scan-report")
        assert get_resp.status_code == 200
        get_report = get_resp.json()
        assert get_report["session_id"] == report["session_id"]
        assert get_report["quality_assessment"] in ["EXCELLENT", "ACCEPTABLE"]
