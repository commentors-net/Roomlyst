import io
import os
import pytest
import numpy as np
from PIL import Image
from fastapi.testclient import TestClient

from packages.room_model import (
    CanonicalRoomModel,
    Measurement,
    MeasurementSource,
    CameraPose,
    SpatialPlane,
    PointCloudMetadata,
    MultiViewReconstructionReport,
)
from services.ai_worker.pipelines.reconstruction_pipeline import MultiViewReconstructor
from services.api.app.main import app
from services.api.app.db.session import SessionLocal
from services.api.app.db.models import Room, Project


@pytest.fixture
def client():
    return TestClient(app)


def _generate_synthetic_view(angle_idx: int, width=320, height=240) -> Image.Image:
    """Generates synthetic perspective room view with distinct textures for testing."""
    arr = np.zeros((height, width, 3), dtype=np.uint8)
    shift = (angle_idx * 30) % 120

    # Ceiling
    arr[0:int(height * 0.25), :] = [235, 235, 245]
    # Wall with texture
    arr[int(height * 0.25):int(height * 0.75), :] = [190 + (angle_idx % 10), 195, 205]
    # Window or architectural element
    w_start = int((width * 0.15) + shift) % (width - 70)
    arr[int(height * 0.3):int(height * 0.65), w_start:w_start + 60] = [80, 150, 230]
    # Floor
    arr[int(height * 0.75):, :] = [130, 100, 80]

    # Grid texture to simulate feature points
    arr[::6, ::6, :] = 255

    return Image.fromarray(arr)


def _image_to_bytes(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


class TestMultiViewReconstructor:
    def test_estimate_camera_poses(self):
        reconstructor = MultiViewReconstructor()
        views = [_generate_synthetic_view(i) for i in range(4)]
        poses = reconstructor.estimate_camera_poses(views)

        assert len(poses) == 4
        for i, pose in enumerate(poses):
            assert isinstance(pose, CameraPose)
            assert pose.frame_id == f"frame_{i:03d}"
            assert len(pose.position) == 3
            assert len(pose.rotation_quaternion) == 4
            assert len(pose.euler_angles_deg) == 3
            assert len(pose.viewing_direction) == 3

    def test_reconstruct_point_cloud_and_ply_export(self, tmp_path):
        reconstructor = MultiViewReconstructor(output_dir=str(tmp_path))
        views = [_generate_synthetic_view(i) for i in range(3)]
        poses = reconstructor.estimate_camera_poses(views)

        points, colors, metadata = reconstructor.reconstruct_point_cloud(
            room_id="test_room_101",
            frames=views,
            poses=poses,
            target_points=1200,
        )

        assert points.shape[1] == 3
        assert colors.shape[1] == 3
        assert isinstance(metadata, PointCloudMetadata)
        assert metadata.total_points == len(points)
        assert metadata.density_pts_per_sqm > 0

        # Inspect generated ASCII PLY file header
        ply_file = os.path.join(str(tmp_path), "test_room_101_reconstructed.ply")
        assert os.path.exists(ply_file)
        with open(ply_file, "r", encoding="utf-8") as f:
            header = [f.readline().strip() for _ in range(12)]
        assert header[0] == "ply"
        assert header[1] == "format ascii 1.0"
        assert f"element vertex {len(points)}" in header
        assert "end_header" in header

    def test_extract_spatial_planes_ransac(self, tmp_path):
        reconstructor = MultiViewReconstructor(output_dir=str(tmp_path))
        views = [_generate_synthetic_view(i) for i in range(4)]
        poses = reconstructor.estimate_camera_poses(views)
        points, _, _ = reconstructor.reconstruct_point_cloud(
            room_id="test_room_planes",
            frames=views,
            poses=poses,
            target_points=2400,
        )

        planes = reconstructor.extract_spatial_planes(points)
        assert len(planes) >= 4

        plane_types = [p.plane_type for p in planes]
        assert "floor" in plane_types
        assert "ceiling" in plane_types

        floor_plane = next(p for p in planes if p.plane_type == "floor")
        assert floor_plane.inliers_count > 0
        assert floor_plane.confidence >= 0.85
        assert np.isclose(np.linalg.norm(floor_plane.normal_vector), 1.0, atol=1e-3)

        ceiling_plane = next(p for p in planes if p.plane_type == "ceiling")
        assert 2.0 <= ceiling_plane.elevation_m <= 4.0

    def test_align_to_canonical_room_model(self, tmp_path):
        reconstructor = MultiViewReconstructor(output_dir=str(tmp_path))
        views = [_generate_synthetic_view(i) for i in range(4)]

        room = CanonicalRoomModel(
            id="room_align_001",
            name="Master Bedroom",
            room_type="bedroom",
            measurements=[
                Measurement(
                    entity_type="room",
                    entity_id="width",
                    measurement_type="width",
                    value=4.0,
                    source=MeasurementSource.MONOCULAR_DEPTH,
                    confidence=0.70,
                ),
                Measurement(
                    entity_type="room",
                    entity_id="ceiling_height",
                    measurement_type="ceiling_height",
                    value=2.8,
                    source=MeasurementSource.MONOCULAR_DEPTH,
                    confidence=0.70,
                ),
            ],
        )

        report, aligned_room = reconstructor.reconstruct_room(
            room_id="room_align_001",
            frames=views,
            room_model=room,
        )

        assert aligned_room.reconstruction_report is not None
        assert report.reconstruction_status == "COMPLETED"
        assert report.spatial_consistency_score >= 0.90
        assert len(aligned_room.spatial_planes) >= 4

        # Verify upgraded measurement provenance
        upgraded_sources = [m.source for m in aligned_room.measurements]
        assert MeasurementSource.MULTIVIEW_RECONSTRUCTION in upgraded_sources
        for m in aligned_room.measurements:
            if m.source == MeasurementSource.MULTIVIEW_RECONSTRUCTION:
                assert m.confidence >= 0.90
                assert m.is_approximate is False


class TestReconstructionApiEndpoints:
    def _create_db_room(self, room_id: str) -> Room:
        db = SessionLocal()
        # Ensure project exists
        proj = db.query(Project).filter(Project.id == "test_proj_sfm").first()
        if not proj:
            proj = Project(id="test_proj_sfm", user_id="usr_demo", name="Test Project", currency="MYR")
            db.add(proj)
            db.commit()

        existing = db.query(Room).filter(Room.id == room_id).first()
        if existing:
            db.delete(existing)
            db.commit()

        initial_model = CanonicalRoomModel(
            id=room_id,
            name="Living Room 3D",
            room_type="living_room",
            measurements=[
                Measurement(
                    entity_type="room",
                    entity_id="width",
                    measurement_type="width",
                    value=4.5,
                    source=MeasurementSource.MONOCULAR_DEPTH,
                    confidence=0.65,
                ),
            ],
        )
        room = Room(
            id=room_id,
            project_id="test_proj_sfm",
            name="Living Room 3D",
            room_type="living_room",
            room_model_data=initial_model.model_dump(mode="json"),
        )
        db.add(room)
        db.commit()
        db.refresh(room)
        db.close()
        return room

    def test_sfm_pipeline_endpoint(self, client):
        room_id = "room_sfm_api_001"
        self._create_db_room(room_id)

        # Post 3 keyframe views
        files = [
            ("files", (f"view_{i}.jpg", _image_to_bytes(_generate_synthetic_view(i)), "image/jpeg"))
            for i in range(3)
        ]

        resp = client.post(
            "/api/v1/reconstruction/sfm-pipeline",
            data={"room_id": room_id},
            files=files,
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["room_id"] == room_id
        assert data["status"] == "COMPLETED"
        assert "report" in data
        assert "point_cloud" in data["report"]
        assert data["report"]["point_cloud"]["total_points"] > 0
        assert len(data["report"]["spatial_planes"]) >= 4

    def test_get_reconstruction_report_endpoint(self, client):
        room_id = "room_sfm_api_002"
        self._create_db_room(room_id)

        # Run sfm first
        client.post(
            "/api/v1/reconstruction/sfm-pipeline",
            data={"room_id": room_id},
        )

        resp = client.get(f"/api/v1/rooms/{room_id}/reconstruction-report")
        assert resp.status_code == 200
        report = resp.json()
        assert report["room_id"] == room_id
        assert "point_cloud" in report
        assert "camera_poses" in report
        assert len(report["camera_poses"]) >= 3

    def test_get_point_cloud_and_planes_endpoints(self, client):
        room_id = "room_sfm_api_003"
        self._create_db_room(room_id)

        # Run pipeline
        client.post("/api/v1/reconstruction/sfm-pipeline", data={"room_id": room_id})

        # Test point cloud endpoint
        pc_resp = client.get(f"/api/v1/rooms/{room_id}/point-cloud")
        assert pc_resp.status_code == 200
        pc_data = pc_resp.json()
        assert pc_data["total_points"] > 0
        assert "bounds_min" in pc_data

        # Test spatial planes endpoint
        planes_resp = client.get(f"/api/v1/rooms/{room_id}/spatial-planes")
        assert planes_resp.status_code == 200
        planes_data = planes_resp.json()
        assert isinstance(planes_data, list)
        assert len(planes_data) >= 4

    def test_nonexistent_room_errors(self, client):
        resp = client.get("/api/v1/rooms/non_existent_room_9999/reconstruction-report")
        assert resp.status_code == 404
        assert "not found" in resp.json()["detail"].lower()

        resp_pc = client.get("/api/v1/rooms/non_existent_room_9999/point-cloud")
        assert resp_pc.status_code == 404

        resp_planes = client.get("/api/v1/rooms/non_existent_room_9999/spatial-planes")
        assert resp_planes.status_code == 404
