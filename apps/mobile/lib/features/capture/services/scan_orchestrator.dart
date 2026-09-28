import '../../capability/domain/device_capability.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

/// Capability-based scan orchestrator for mobile runtime.
/// Fulfills Milestone 3.5.
class ScanOrchestrator {
  final DeviceCapabilityProfile deviceProfile;
  ScanMode _currentMode;
  final ScanMode _recommendedMode;
  bool _isManualOverride;
  String? _fallbackReason;
  ScanOrchestrationEvaluationModel? _evaluation;

  ScanOrchestrator({
    required this.deviceProfile,
    ScanMode? initialMode,
  })  : _currentMode = initialMode ?? deviceProfile.scanMode,
        _recommendedMode = deviceProfile.scanMode,
        _isManualOverride = initialMode != null && initialMode != deviceProfile.scanMode,
        _fallbackReason = null;

  ScanMode get currentMode => _currentMode;
  ScanMode get recommendedMode => _recommendedMode;
  bool get isManualOverride => _isManualOverride;
  String? get fallbackReason => _fallbackReason;
  ScanOrchestrationEvaluationModel? get evaluation => _evaluation;

  String get currentTierId {
    switch (_currentMode) {
      case ScanMode.lidarScan:
        return 'TIER_1_LIDAR';
      case ScanMode.hardwareDepthScan:
      case ScanMode.arDepthScan:
        return 'TIER_2_AR_DEPTH';
      case ScanMode.arRgbScan:
        return 'TIER_3_AR_RGB';
      case ScanMode.rgbVideoScan:
        return 'TIER_4_VIDEO_SWEEP';
      case ScanMode.rgbPhotoScan:
        return 'TIER_5_BASIC_RGB';
    }
  }

  String get currentTierName {
    switch (_currentMode) {
      case ScanMode.lidarScan:
        return 'Tier 1: Apple RoomPlan LiDAR';
      case ScanMode.hardwareDepthScan:
      case ScanMode.arDepthScan:
        return 'Tier 2: Android ARCore Depth / ToF';
      case ScanMode.arRgbScan:
        return 'Tier 3: ARKit / ARCore Motion Odometry';
      case ScanMode.rgbVideoScan:
        return 'Tier 4: Guided Monocular Video Sweep';
      case ScanMode.rgbPhotoScan:
        return 'Tier 5: Multi-Corner Photo Capture';
    }
  }

  String get currentGuidancePrompt {
    switch (_currentMode) {
      case ScanMode.lidarScan:
        return 'Scan Room: Point camera and walk around room to capture exact 3D geometry.';
      case ScanMode.hardwareDepthScan:
      case ScanMode.arDepthScan:
        return 'Scan Room: Move smoothly across surfaces to map depth and walls.';
      case ScanMode.arRgbScan:
        return 'Move slowly around room: Point at floor and walls to track boundaries.';
      case ScanMode.rgbVideoScan:
        return 'Walk around room: Record continuous view with overlapping angles.';
      case ScanMode.rgbPhotoScan:
        return 'Capture Room: Take photos from room corners with good lighting.';
    }
  }

  String get currentAccuracyAssurance {
    switch (_currentMode) {
      case ScanMode.lidarScan:
        return 'Hardware 3D Precision (High Accuracy < 1cm exact)';
      case ScanMode.hardwareDepthScan:
      case ScanMode.arDepthScan:
        return 'AR Depth Sensor (~2-3cm High Accuracy)';
      case ScanMode.arRgbScan:
        return 'AR Motion Geometry (~3-5cm Metric VIO)';
      case ScanMode.rgbVideoScan:
        return 'Structure-from-Motion Multi-View (~5-8cm Approximate)';
      case ScanMode.rgbPhotoScan:
        return 'AI Vision Estimated (~10-15cm - Manual Reference Recommended)';
    }
  }

  /// Sets manual user override mode
  void setManualMode(ScanMode mode) {
    _currentMode = mode;
    _isManualOverride = (_currentMode != _recommendedMode);
    _fallbackReason = null;
  }

  /// Reset to auto-recommended mode
  void resetToRecommended() {
    _currentMode = _recommendedMode;
    _isManualOverride = false;
    _fallbackReason = null;
  }

  /// Step down gracefully along the fallback chain when tracking or sensor inputs degrade
  bool stepDownFallback(String reason) {
    _fallbackReason = reason;
    switch (_currentMode) {
      case ScanMode.lidarScan:
        _currentMode = ScanMode.arRgbScan;
        _isManualOverride = false;
        return true;
      case ScanMode.hardwareDepthScan:
      case ScanMode.arDepthScan:
        _currentMode = ScanMode.arRgbScan;
        _isManualOverride = false;
        return true;
      case ScanMode.arRgbScan:
        _currentMode = ScanMode.rgbVideoScan;
        _isManualOverride = false;
        return true;
      case ScanMode.rgbVideoScan:
        _currentMode = ScanMode.rgbPhotoScan;
        _isManualOverride = false;
        return true;
      case ScanMode.rgbPhotoScan:
        // Already at baseline tier
        return false;
    }
  }

  /// Evaluates and syncs with cloud telemetry API
  Future<ScanOrchestrationEvaluationModel?> syncWithCloud() async {
    try {
      final payload = {
        'has_lidar': deviceProfile.hasLiDAR,
        'has_hardware_depth': deviceProfile.hasHardwareDepth,
        'has_arcore_depth': deviceProfile.hasARCoreDepth,
        'has_ar': deviceProfile.hasAR,
        'has_arkit': deviceProfile.hasARKit,
        'has_arcore': deviceProfile.hasARCore,
        'has_motion_sensors': deviceProfile.hasMotionSensors,
        'device_model': deviceProfile.deviceModel,
        'os_name': deviceProfile.operatingSystem,
        'os_version': deviceProfile.osVersion,
      };
      _evaluation = await ProjectService.evaluateScanRoute(payload);
      return _evaluation;
    } catch (_) {
      return null;
    }
  }
}
