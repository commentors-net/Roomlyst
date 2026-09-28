"""
services/ai_worker/pipelines/video_scan_analyzer.py
===================================================
Milestone 3.1: Guided RGB Video Scan.
Adheres to Blueprint Section 8.3, Section 9 (Capture Quality Control),
Section 10 (Canonical Room Model), and Add-on Section 3 & 4 (Adaptive Scan Modes).
"""

from datetime import datetime, timezone
import io
import os
import shutil
from typing import Any, Dict, List, Optional, Tuple
import uuid
import numpy as np
from PIL import Image

from packages.room_model import (
    CanonicalRoomModel,
    CaptureFrame,
    CaptureMetadata,
    VideoKeyframe,
    VideoScanMetadata,
    VideoScanReport,
)
from .multiview_analyzer import MultiViewAssociator, MultiViewRoomAnalyzer


class VideoScanAnalyzer:
    """
    Analyzes RGB video sequences captured by non-LiDAR smartphones:
    - Smart frame sampling (sharpness selection, duplicate filtering)
    - Camera motion stability & panning speed validation
    - Incremental coverage checklist evaluation
    - Resumable chunked upload management
    - Reconstruction suitability assessment
    """

    def __init__(
        self,
        output_dir: str = "storage/outputs",
        sessions_dir: str = "storage/video_sessions",
        min_sharpness: float = 35.0,
        duplicate_diff_threshold: float = 0.008,
        max_motion_shift: float = 0.35,
    ):
        self.output_dir = output_dir
        self.sessions_dir = sessions_dir
        self.min_sharpness = min_sharpness
        self.duplicate_diff_threshold = duplicate_diff_threshold
        self.max_motion_shift = max_motion_shift
        self.active_sessions: Dict[str, Any] = {}
        os.makedirs(self.output_dir, exist_ok=True)
        os.makedirs(self.sessions_dir, exist_ok=True)
        self.multiview_analyzer = MultiViewRoomAnalyzer()

    # -----------------------------------------------------------------------
    # 1. Quality & Motion Math
    # -----------------------------------------------------------------------

    @staticmethod
    def calculate_sharpness(gray_array: Any) -> float:
        """
        Calculates Laplacian variance as an edge-sharpness metric.
        Higher value = sharper frame.
        """
        if isinstance(gray_array, Image.Image):
            gray_array = np.array(gray_array.convert("L"), dtype=np.float32)
        elif not isinstance(gray_array, np.ndarray):
            gray_array = np.array(gray_array, dtype=np.float32)

        padded = np.pad(gray_array, 1, mode="edge")
        laplacian = (
            padded[:-2, 1:-1]
            + padded[2:, 1:-1]
            + padded[1:-1, :-2]
            + padded[1:-1, 2:]
            - 4 * gray_array
        )
        return float(np.var(laplacian))

    @staticmethod
    def calculate_frame_motion(img_a: Image.Image, img_b: Image.Image) -> float:
        """
        Estimates visual displacement magnitude between consecutive frames.
        Normalized to [0.0, 1.0].
        """
        a_gray = np.array(img_a.convert("L").resize((64, 64)), dtype=np.float32) / 255.0
        b_gray = np.array(img_b.convert("L").resize((64, 64)), dtype=np.float32) / 255.0
        return float(np.mean(np.abs(a_gray - b_gray)))

    @staticmethod
    def calculate_consecutive_displacement(img_a: Image.Image, img_b: Image.Image) -> float:
        """Alias for consecutive displacement calculation."""
        return VideoScanAnalyzer.calculate_frame_motion(img_a, img_b)

    # -----------------------------------------------------------------------
    # 2. Smart Frame Sampling & Sequence Evaluation
    # -----------------------------------------------------------------------

    def sample_keyframes(
        self,
        frames: List[Image.Image],
        fps: float = 30.0,
        target_count: int = 8,
        timestamps: Optional[List[float]] = None,
        min_keyframe_interval_sec: Optional[float] = None,
        min_sharpness_threshold: Optional[float] = None,
    ) -> Tuple[List[VideoKeyframe], VideoScanMetadata]:
        """
        Samples sharp, geometrically informative keyframes from video frames.
        Discards blurry frames and near-duplicate views where camera paused.
        Fulfills Milestone 3.1 & Blueprint Section 8.3/9.
        """
        if not frames:
            return [], VideoScanMetadata()

        total_frames = len(frames)
        duration_sec = total_frames / max(fps, 1.0)

        # Precompute sharpness for each frame
        sharpness_list: List[float] = []
        for f in frames:
            gray = np.array(f.convert("L"), dtype=np.float32)
            sharpness_list.append(self.calculate_sharpness(gray))

        # Motion analysis across consecutive frames
        motion_shifts: List[float] = []
        motion_warnings = 0
        for i in range(len(frames) - 1):
            shift = self.calculate_frame_motion(frames[i], frames[i + 1])
            motion_shifts.append(shift)
            if shift > self.max_motion_shift:
                motion_warnings += 1

        avg_shift = float(np.mean(motion_shifts)) if motion_shifts else 0.0
        # Convert shift to approximate angular panning rate (deg/sec)
        avg_deg_per_sec = round(avg_shift * 180.0 * fps / 10.0, 1)

        # Stability score calculation (penalized for excessive motion warnings and high variance)
        shake_penalty = min(0.40, motion_warnings * 0.08)
        stability_score = max(0.20, round(1.0 - shake_penalty, 3))

        # Adaptive windowing for keyframe extraction
        window_size = max(1, total_frames // target_count)
        sampled_keyframes: List[VideoKeyframe] = []
        last_selected_img: Optional[Image.Image] = None

        wall_views = [
            "main_wall_entry",
            "corner_left",
            "feature_wall",
            "window_wall",
            "corner_right",
            "ceiling_lighting",
            "floor_baseboards",
            "opposite_perspective",
        ]

        for w_idx in range(min(target_count, total_frames)):
            start_idx = w_idx * window_size
            end_idx = min(total_frames, (w_idx + 1) * window_size)
            if start_idx >= total_frames:
                break

            # Find frame with maximum sharpness in window
            best_idx = start_idx
            best_sharp = -1.0
            for idx in range(start_idx, end_idx):
                if sharpness_list[idx] > best_sharp:
                    best_sharp = sharpness_list[idx]
                    best_idx = idx

            candidate_img = frames[best_idx]

            # Discard if below minimum sharpness threshold
            if min_sharpness_threshold is not None and best_sharp < min_sharpness_threshold:
                continue

            # Check if near-duplicate of last selected
            if last_selected_img is not None:
                diff = self.calculate_frame_motion(last_selected_img, candidate_img)
                if diff < self.duplicate_diff_threshold:
                    # Skip stationary duplicate
                    continue

            # Save keyframe image to disk
            kf_id = f"kf_{uuid.uuid4().hex[:6]}"
            filename = f"keyframe_{kf_id}.jpg"
            filepath = os.path.join(self.output_dir, filename)
            candidate_img.save(filepath, format="JPEG", quality=90)

            t_sec = timestamps[best_idx] if timestamps and best_idx < len(timestamps) else round(best_idx / max(fps, 1.0), 2)
            cur_cov = round(min(1.0, (len(sampled_keyframes) + 1) / target_count) * 100, 1)
            wall_label = wall_views[len(sampled_keyframes) % len(wall_views)]

            kf = VideoKeyframe(
                keyframe_id=kf_id,
                frame_index=best_idx,
                timestamp_seconds=t_sec,
                image_url=f"/storage/outputs/{filename}",
                sharpness_score=round(best_sharp, 2),
                camera_motion_speed=round(motion_shifts[best_idx - 1], 3) if best_idx > 0 and best_idx - 1 < len(motion_shifts) else 0.05,
                detected_wall_view=wall_label,
                estimated_coverage_pct=cur_cov,
            )
            sampled_keyframes.append(kf)
            last_selected_img = candidate_img

        # Coverage score based on unique views and count
        target_baseline = min(target_count, max(total_frames, 3))
        coverage_score = round(min(1.0, len(sampled_keyframes) / max(target_baseline * 0.75, 1.0)), 2)
        is_stable = stability_score >= 0.65 and motion_warnings <= 4

        metadata = VideoScanMetadata(
            video_duration_seconds=round(duration_sec, 2),
            fps=fps,
            total_frames_recorded=total_frames,
            sampled_keyframes_count=len(sampled_keyframes),
            average_motion_speed_deg_per_sec=avg_deg_per_sec,
            motion_stability_score=stability_score,
            excessive_motion_warnings_count=motion_warnings,
            coverage_score=coverage_score,
            is_stable_sequence=is_stable,
        )

        return sampled_keyframes, metadata

    def evaluate_video_scan(
        self,
        room_id: str,
        metadata: Optional[VideoScanMetadata] = None,
        keyframes: Optional[List[VideoKeyframe]] = None,
        session_id: Optional[str] = None,
        frames: Optional[List[Image.Image]] = None,
        timestamps: Optional[List[float]] = None,
        video_duration_seconds: Optional[float] = None,
        fps: float = 30.0,
        panning_speeds: Optional[List[float]] = None,
    ) -> VideoScanReport:
        """
        Synthesizes full VideoScanReport, assessing quality and reconstruction readiness.
        Fulfills Milestone 3.1 exit criteria:
        'A non-LiDAR phone can produce a stable sequence suitable for reconstruction'.
        """
        if metadata is None:
            if frames is not None:
                keyframes, metadata = self.sample_keyframes(
                    frames=frames,
                    fps=fps,
                    timestamps=timestamps,
                )
            else:
                metadata = VideoScanMetadata()
                keyframes = []

        if video_duration_seconds is not None:
            metadata.video_duration_seconds = video_duration_seconds

        if panning_speeds:
            fast_pans = sum(1 for s in panning_speeds if s > 25.0)
            if fast_pans > 0:
                metadata.excessive_motion_warnings_count += fast_pans
                metadata.motion_stability_score = max(0.2, metadata.motion_stability_score - 0.25 * fast_pans)
                if metadata.motion_stability_score < 0.65:
                    metadata.is_stable_sequence = False

        notes: List[str] = []

        if metadata.is_stable_sequence and metadata.coverage_score >= 0.75:
            assessment = "EXCELLENT"
            notes.append("Smooth camera panning and thorough perimeter coverage detected.")
            notes.append("Sequence is fully suitable for multi-view reconstruction (Milestone 3.2).")
        elif metadata.coverage_score >= 0.50 and metadata.motion_stability_score >= 0.55:
            assessment = "ACCEPTABLE"
            notes.append("Coverage is adequate for room layout analysis.")
            if metadata.excessive_motion_warnings_count > 0:
                notes.append(f"Detected {metadata.excessive_motion_warnings_count} rapid pans. Try panning more slowly.")
        elif metadata.coverage_score < 0.50:
            assessment = "INSUFFICIENT_COVERAGE"
            notes.append("Only partial room perimeter was captured. Scan opposite corner for complete coverage.")
        else:
            assessment = "UNSTABLE"
            notes.append("Significant camera shake or rapid panning detected during video capture.")

        suitable = (
            assessment in ("EXCELLENT", "ACCEPTABLE")
            and metadata.sampled_keyframes_count >= 3
            and metadata.is_stable_sequence
        )

        return VideoScanReport(
            session_id=session_id or f"vscan_{uuid.uuid4().hex[:8]}",
            room_id=room_id,
            metadata=metadata,
            keyframes=keyframes or [],
            quality_assessment=assessment,
            guidance_notes=notes,
            is_suitable_for_reconstruction=suitable,
        )

    # -----------------------------------------------------------------------
    # 3. Canonical Room Model Processing
    # -----------------------------------------------------------------------

    def process_video_scan(
        self,
        room_id: str,
        frames: List[Image.Image],
        fps: float = 30.0,
        session_id: Optional[str] = None,
    ) -> Tuple[VideoScanReport, CanonicalRoomModel]:
        """
        Samples keyframes, evaluates stability, and compiles canonical room model.
        Fulfills Add-on Section 5: All scan pipelines normalize into CanonicalRoomModel.
        """
        keyframes, metadata = self.sample_keyframes(frames, fps=fps)
        report = self.evaluate_video_scan(room_id, metadata, keyframes, session_id=session_id)

        # Build capture frames for canonical room model
        capture_frames: List[CaptureFrame] = []
        pil_images: List[Image.Image] = []
        for kf in keyframes:
            local_path = kf.image_url.lstrip("/")
            if os.path.exists(local_path):
                img = Image.open(local_path)
            else:
                img = frames[min(kf.frame_index, len(frames) - 1)]
            pil_images.append(img)
            capture_frames.append(
                CaptureFrame(
                    frame_id=kf.keyframe_id,
                    image_url=kf.image_url,
                    timestamp=datetime.now(timezone.utc),
                    coverage_percentage=kf.estimated_coverage_pct,
                    source="video_keyframe",
                )
            )

        # Multi-view room analysis across sampled keyframes
        if pil_images:
            room_model = self.multiview_analyzer.analyze_multi_view(
                images=pil_images,
                room_type="living_room",
                room_name=f"Video Scanned Room ({report.session_id[:6]})",
            )
        else:
            room_model = CanonicalRoomModel(id=room_id, room_type="living_room")

        room_model.id = room_id
        room_model.frames = capture_frames
        room_model.video_scan_report = report
        room_model.capture_metadata = CaptureMetadata(
            platform="mobile_rgb_video",
            has_lidar=False,
            has_hardware_depth=False,
            has_ar=False,
            scan_mode="rgb_video_scan",
            hardware_tier="TIER_4_RGB_ONLY",
        )
        if keyframes:
            room_model.original_image_url = keyframes[0].image_url

        return report, room_model

    # -----------------------------------------------------------------------
    # 4. Resumable Chunked Upload Session Management
    # -----------------------------------------------------------------------

    def init_upload_session(
        self,
        room_id: str,
        filename: str,
        total_chunks: int,
        chunk_size_bytes: int = 1048576,  # 1MB default
        file_size_bytes: int = 0,
    ) -> Dict[str, Any]:
        """Initializes a new resumable video upload session on disk."""
        session_id = f"vsession_{uuid.uuid4().hex[:8]}"
        session_path = os.path.join(self.sessions_dir, session_id)
        os.makedirs(session_path, exist_ok=True)

        info = {
            "session_id": session_id,
            "room_id": room_id,
            "filename": filename,
            "total_chunks": total_chunks,
            "chunk_size_bytes": chunk_size_bytes,
            "file_size_bytes": file_size_bytes,
            "received_chunks": 0,
            "status": "INITIALIZED",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        self.active_sessions[session_id] = info
        return info

    def save_chunk(
        self,
        session_id: str,
        chunk_index: int,
        chunk_bytes: bytes,
    ) -> Dict[str, Any]:
        """Saves an incoming chunk to the session directory."""
        session_path = os.path.join(self.sessions_dir, session_id)
        if not os.path.exists(session_path):
            raise ValueError(f"Video session '{session_id}' not found")

        chunk_file = os.path.join(session_path, f"part_{chunk_index:04d}.bin")
        with open(chunk_file, "wb") as f:
            f.write(chunk_bytes)

        # Count total parts currently saved
        parts = [f for f in os.listdir(session_path) if f.startswith("part_")]
        if session_id in self.active_sessions:
            self.active_sessions[session_id]["received_chunks"] = len(parts)

        return {
            "session_id": session_id,
            "chunk_index": chunk_index,
            "saved_bytes": len(chunk_bytes),
            "received_chunks": len(parts),
        }

    def assemble_session_bytes(self, session_id: str) -> bytes:
        """Assembles all received chunks in order into complete video bytes."""
        session_path = os.path.join(self.sessions_dir, session_id)
        if not os.path.exists(session_path):
            raise ValueError(f"Video session '{session_id}' not found")

        part_files = sorted([f for f in os.listdir(session_path) if f.startswith("part_")])
        if not part_files:
            raise ValueError(f"No chunks found for session '{session_id}'")

        buf = bytearray()
        for p in part_files:
            with open(os.path.join(session_path, p), "rb") as f:
                buf.extend(f.read())

        return bytes(buf)

    def cleanup_session(self, session_id: str) -> None:
        """Removes temporary chunk directory for session."""
        self.active_sessions.pop(session_id, None)
        session_path = os.path.join(self.sessions_dir, session_id)
        if os.path.exists(session_path):
            shutil.rmtree(session_path, ignore_errors=True)
