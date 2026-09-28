# ADR-019: Capability-Based Scan Orchestration & Graceful Degradation

**Status:** Accepted  
**Date:** 2026-09-28  
**Milestone:** 3.5 — Capability-Based Scan Orchestration  
**Author:** Roomlyst Engineering  
**Supersedes:** None  
**Related:** ADR-002 (Canonical Room Model), ADR-009 (Adaptive Device Capability & Graceful Degradation), ADR-015 (Guided RGB Video Scan), ADR-016 (Multi-View 3D Reconstruction), ADR-017 (AR-Assisted Non-LiDAR Path), ADR-018 (LiDAR and Native Spatial Mesh Path)

---

## Context

Blueprint Section 8.5 & 8.6, Section 6 & 7 (*Device Capability Matrix and Adaptive Strategy*), and Section 10 (*The Single Canonical Room Model*) dictate that Roomlyst must automatically select the optimal indoor capture pipeline based on the device's runtime sensor capabilities. Furthermore, when environmental conditions or hardware tracking degrade during capture (e.g. LiDAR laser occlusion, visual-inertial odometry drift, low light, or rapid motion blur), the application must step down gracefully along a transparent fallback hierarchy without interrupting the user experience or corrupting downstream redesign, feasibility, and budget estimation workflows.

### 5-Tier Capture Hierarchy
1. **Tier 1: Apple RoomPlan LiDAR (`TIER_1_LIDAR` -> `lidar_scan`)**: Direct millimeter-to-centimeter laser meshing (< 1cm exact accuracy, ~15s capture, ~$0.005 compute cost).
2. **Tier 2: Android ARCore Depth / ToF (`TIER_2_AR_DEPTH` -> `ar_depth_scan`)**: Hardware time-of-flight depth (~2-3cm accuracy, ~20s capture, ~$0.010 compute cost).
3. **Tier 3: ARKit / ARCore Motion Odometry (`TIER_3_AR_RGB` -> `ar_rgb_scan`)**: Visual-Inertial Odometry metric motion (~3-5cm accuracy, ~25s capture, ~$0.015 compute cost).
4. **Tier 4: Guided Monocular Video Sweep (`TIER_4_VIDEO_SWEEP` -> `rgb_video_scan`)**: HD keyframe sweep with Structure-from-Motion multi-view point cloud synthesis (~5-8cm accuracy, ~30s capture, ~$0.025 compute cost).
5. **Tier 5: Multi-Corner Photo Capture (`TIER_5_BASIC_RGB` -> `rgb_photo_scan`)**: 3-4 corner photos with optional A4 paper / door frame reference scale calibration (~12cm accuracy, ~45s capture, ~$0.020 compute cost).

---

## Decision

### 1. Backend Schema & Telemetry Benchmark Engine

In `packages/room_model/schema.py`:
- **`TierBenchmarkMetrics`**: Encapsulates empirical accuracy, latency, confidence, stability, and cloud compute cost:
  - `tier_id`, `tier_name`, `hardware_description`, `scan_mode`, `primary_framework`, `typical_accuracy_cm`, `accuracy_tier`, `expected_confidence`, `mean_capture_time_sec`, `mean_processing_time_sec`, `relative_compute_cost_usd`, `scale_stability`, `loop_closure_reliability`, and `supported_devices_sample`.
- **`get_standard_tier_benchmarks()`**: Returns the canonical 5-tier comparative benchmark matrix.
- **`ScanOrchestrationEvaluation`**: Captures evaluated tier, recommended scan mode, guidance prompt, accuracy assurance, fallback chain, fallback reasons, active benchmark, and all tier benchmarks.
- **`evaluate_scan_orchestration(profile: Any)`**: Evaluates hardware flags (`has_lidar`, `has_hardware_depth`, `has_ar`, `has_motion_sensors`), handles graceful degradation chaining, and attaches telemetry forecasts.
- **`CanonicalRoomModel`**: Added `orchestration_evaluation: Optional[ScanOrchestrationEvaluation] = None` field, preserving complete scan provenance and routing history directly on the canonical model.
- Exported all models and helper methods in `packages/room_model/__init__.py`.

### 2. REST API Endpoints

In `services/api/app/api/v1/endpoints.py`:
- `GET /api/v1/scan/orchestration/telemetry-benchmarks`: Exposes the 5-tier comparative matrix to clients for live UI display.
- `POST /api/v1/scan/orchestration/evaluate-route`: Evaluates a device capability payload and returns the optimal scan mode and fallback chain.
- `POST /api/v1/rooms/{room_id}/scan-orchestration`: Evaluates and attaches orchestration telemetry directly to an existing `CanonicalRoomModel`.

### 3. Flutter Mobile Layer

In `apps/mobile`:
- **Domain Models (`lib/features/projects/domain/project.dart`):**
  - Added `TierBenchmarkMetricsModel` and `ScanOrchestrationEvaluationModel` with `.fromMap()` and `.toMap()`.
  - Added `orchestrationEvaluation` to `RoomModelData`.
- **Network & Service Layer:**
  - `ApiClient`: Added `getScanTelemetryBenchmarks()`, `evaluateScanRoute(profile)`, and `attachScanOrchestration(roomId, profile)`.
  - `ProjectService`: Added `fetchScanTelemetryBenchmarks()`, `evaluateScanRoute()`, and `attachScanOrchestration()`.
- **Scan Orchestrator Service (`lib/features/capture/services/scan_orchestrator.dart`):**
  - Coordinates runtime auto-selection from `DeviceCapabilityProfile`.
  - Implements `setManualMode(mode)` for user override.
  - Implements `resetToRecommended()` to restore optimal routing.
  - Implements `stepDownFallback(reason)` to traverse the graceful degradation hierarchy.
  - Provides dynamic prompt guidance and accuracy assurances.
  - Performs asynchronous background cloud sync with `ProjectService`.
- **Interactive UI Components:**
  - `CaptureOrchestrationDialog` (`lib/features/capture/presentation/capture_orchestration_dialog.dart`):
    - Visualizes the 5-tier comparative table (accuracy, capture time, compute latency, cost).
    - Highlights current mode with active diagnostics ("Optimal Selection" or "Manual Override").
    - Provides interactive selection tiles for all capture tiers.
    - Displays step-down fallback warning banners if degradation occurred.
  - `CaptureScreen` (`lib/features/capture/presentation/capture_screen.dart`):
    - Automatically initializes `ScanOrchestrator` on mount.
    - Displays persistent Orchestration Status Banner above the camera preview.
    - Adds Orchestrator action button to the AppBar for instant modal access.
    - Dynamically routes between LiDAR, AR Motion, Video Sweep, and Multi-Corner Photo modes.

---

## Consequences & Verification

- **Single App Support across All Hardware:** One unified app supports iPhone LiDAR, Android ToF/ARCore depth, standard AR devices, video sweep motion-only devices, and entry-level camera smartphones.
- **Predictable Graceful Degradation:** When tracking drops or sensors fail, users are seamlessly stepped down rather than blocked.
- **Canonical Model Integrity:** Downstream modules (AI redesign generator, budget planner, variant comparator, feasibility checker) receive the exact same `CanonicalRoomModel` regardless of capture mode.
- **Automated Verification:**
  - 148 / 148 Python unit & integration tests pass (`pytest tests/`).
  - 79 / 79 Flutter unit and widget tests pass (`flutter test`).
  - `flutter analyze` returns **0 issues** across the entire mobile codebase.
