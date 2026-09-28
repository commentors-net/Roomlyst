// Device Capability Models & Adaptive Scan Strategy.
// Fulfills Blueprint Section 6 & 7 and Roomlyst Add-on (Adaptive Device Capability and Scan Strategy).

enum ScanMode {
  lidarScan,
  hardwareDepthScan,
  arDepthScan,
  arRgbScan,
  rgbVideoScan,
  rgbPhotoScan;

  String get id {
    switch (this) {
      case ScanMode.lidarScan:
        return 'lidar_scan';
      case ScanMode.hardwareDepthScan:
        return 'hardware_depth_scan';
      case ScanMode.arDepthScan:
        return 'ar_depth_scan';
      case ScanMode.arRgbScan:
        return 'ar_rgb_scan';
      case ScanMode.rgbVideoScan:
        return 'rgb_video_scan';
      case ScanMode.rgbPhotoScan:
        return 'rgb_photo_scan';
    }
  }

  static ScanMode fromId(String id) {
    switch (id) {
      case 'lidar_scan':
        return ScanMode.lidarScan;
      case 'hardware_depth_scan':
        return ScanMode.hardwareDepthScan;
      case 'ar_depth_scan':
        return ScanMode.arDepthScan;
      case 'ar_rgb_scan':
        return ScanMode.arRgbScan;
      case 'rgb_video_scan':
        return ScanMode.rgbVideoScan;
      default:
        return ScanMode.rgbPhotoScan;
    }
  }
}

class DeviceCapabilityProfile {
  final String operatingSystem;
  final String osVersion;
  final String deviceModel;
  final bool cameraAvailable;
  final bool hasLiDAR;
  final bool hasHardwareDepth;
  final bool hasARKit;
  final bool hasRoomPlan;
  final bool hasARCore;
  final bool hasARCoreDepth;
  final bool hasMotionSensors;
  final int? availableMemoryMB;
  final double capabilityConfidence;
  final String? unsupportedReason;
  final String capabilityTier; // Tier A, Tier B, Tier C
  final ScanMode scanMode;

  const DeviceCapabilityProfile({
    required this.operatingSystem,
    required this.osVersion,
    required this.deviceModel,
    this.cameraAvailable = true,
    this.hasLiDAR = false,
    this.hasHardwareDepth = false,
    this.hasARKit = false,
    this.hasRoomPlan = false,
    this.hasARCore = false,
    this.hasARCoreDepth = false,
    this.hasMotionSensors = true,
    this.availableMemoryMB,
    this.capabilityConfidence = 0.70,
    this.unsupportedReason,
    required this.capabilityTier,
    required this.scanMode,
  });

  bool get hasAR => hasARKit || hasARCore;
  bool get isHardwareDepthAvailable => hasLiDAR || hasHardwareDepth || hasARCoreDepth;
  String get platform => operatingSystem;

  String get tierBadgeText {
    switch (capabilityTier) {
      case 'Tier A':
        return 'Tier A: LiDAR Hardware Active';
      case 'Tier B':
        return hasARCoreDepth || hasHardwareDepth
            ? 'Tier B: AR Depth Sensor Active'
            : 'Tier B: AR Motion Assisted';
      default:
        return 'Tier C: Standard Camera AI';
    }
  }

  /// Action-oriented user guidance prompt per Add-on Section 3.
  /// Simple, non-technical instructions for the user.
  String get userGuidancePrompt {
    switch (scanMode) {
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

  String get captureGuidanceText => userGuidancePrompt;

  /// User-facing accuracy expectation per Add-on Section 6.
  String get accuracyAssuranceText {
    if (hasLiDAR) {
      return 'Hardware 3D Precision (High Accuracy < 2cm)';
    } else if (hasARCoreDepth || hasHardwareDepth) {
      return 'AR Depth Sensor (~ 3-5cm Accuracy)';
    } else if (hasAR) {
      return 'AR Motion Geometry (~ 5-8cm Approximate)';
    } else {
      return 'AI Vision Estimated (~ 10-15cm - Manual Confirmation Recommended)';
    }
  }

  /// Resolves optimal scan mode according to Add-on Section 1 & 4 (Graceful Fallback).
  static ScanMode resolveOptimalScanMode({
    required bool hasLiDAR,
    required bool hasHardwareDepth,
    required bool hasARKit,
    required bool hasRoomPlan,
    required bool hasARCore,
    required bool hasARCoreDepth,
    required bool hasMotionSensors,
    required bool cameraAvailable,
  }) {
    if (!cameraAvailable) {
      return ScanMode.rgbPhotoScan;
    }
    // 1. Hardware LiDAR / dedicated depth sensor (Tier A)
    if (hasLiDAR) {
      return ScanMode.lidarScan;
    }
    // 2. Platform depth API (RoomPlan on iOS / ARCore Depth on Android) (Tier B)
    if (hasHardwareDepth) {
      return ScanMode.hardwareDepthScan;
    }
    if (hasARCoreDepth || (hasARKit && hasRoomPlan)) {
      return ScanMode.arDepthScan;
    }
    // 3. AR tracking + RGB camera without hardware depth (Tier B)
    if (hasARKit || hasARCore) {
      return ScanMode.arRgbScan;
    }
    // 4. Standard RGB video with motion/IMU (Tier C)
    if (hasMotionSensors) {
      return ScanMode.rgbVideoScan;
    }
    // 5. Standard RGB photo capture (Tier C)
    return ScanMode.rgbPhotoScan;
  }

  static String resolveTier(ScanMode mode) {
    switch (mode) {
      case ScanMode.lidarScan:
        return 'Tier A';
      case ScanMode.hardwareDepthScan:
      case ScanMode.arDepthScan:
      case ScanMode.arRgbScan:
        return 'Tier B';
      case ScanMode.rgbVideoScan:
      case ScanMode.rgbPhotoScan:
        return 'Tier C';
    }
  }

  factory DeviceCapabilityProfile.fromMap(Map<String, dynamic> map) {
    final os = (map['operating_system'] ?? map['platform'] ?? 'unknown').toString();
    final osVer = (map['os_version'] ?? map['system_version'] ?? '1.0.0').toString();
    final model = (map['device_model'] ?? 'Standard Smartphone').toString();
    final cameraAvail = map['camera_available'] as bool? ?? map['camera_supported'] as bool? ?? true;
    final lidar = map['has_lidar'] as bool? ?? map['lidar_supported'] as bool? ?? false;
    final hwDepth = map['has_hardware_depth'] as bool? ?? false;
    final arkit = map['has_arkit'] as bool? ?? (os == 'ios' && (map['ar_supported'] as bool? ?? false));
    final roomplan = map['has_roomplan'] as bool? ?? false;
    final arcore = map['has_arcore'] as bool? ?? (os == 'android' && (map['ar_supported'] as bool? ?? false));
    final arcoreDepth = map['has_arcore_depth'] as bool? ?? false;
    final motion = map['has_motion_sensors'] as bool? ?? true;

    final resolvedMode = map['scan_mode'] != null
        ? ScanMode.fromId(map['scan_mode'].toString())
        : resolveOptimalScanMode(
            hasLiDAR: lidar,
            hasHardwareDepth: hwDepth,
            hasARKit: arkit,
            hasRoomPlan: roomplan,
            hasARCore: arcore,
            hasARCoreDepth: arcoreDepth,
            hasMotionSensors: motion,
            cameraAvailable: cameraAvail,
          );

    final resolvedTier = map['capability_tier'] as String? ?? resolveTier(resolvedMode);
    final conf = (map['capability_confidence'] as num?)?.toDouble() ??
        (resolvedTier == 'Tier A' ? 0.96 : resolvedTier == 'Tier B' ? 0.85 : 0.70);

    return DeviceCapabilityProfile(
      operatingSystem: os,
      osVersion: osVer,
      deviceModel: model,
      cameraAvailable: cameraAvail,
      hasLiDAR: lidar,
      hasHardwareDepth: hwDepth,
      hasARKit: arkit,
      hasRoomPlan: roomplan,
      hasARCore: arcore,
      hasARCoreDepth: arcoreDepth,
      hasMotionSensors: motion,
      availableMemoryMB: map['available_memory_mb'] as int?,
      capabilityConfidence: conf,
      unsupportedReason: map['unsupported_reason'] as String?,
      capabilityTier: resolvedTier,
      scanMode: resolvedMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'operating_system': operatingSystem,
      'os_version': osVersion,
      'device_model': deviceModel,
      'camera_available': cameraAvailable,
      'has_lidar': hasLiDAR,
      'has_hardware_depth': hasHardwareDepth,
      'has_arkit': hasARKit,
      'has_roomplan': hasRoomPlan,
      'has_arcore': hasARCore,
      'has_arcore_depth': hasARCoreDepth,
      'has_motion_sensors': hasMotionSensors,
      'available_memory_mb': availableMemoryMB,
      'capability_tier': capabilityTier,
      'scan_mode': scanMode.id,
      'capability_confidence': capabilityConfidence,
      'unsupported_reason': unsupportedReason,
      'user_guidance_prompt': userGuidancePrompt,
      'accuracy_assurance': accuracyAssuranceText,
      // Backwards-compatible fields
      'platform': operatingSystem,
      'lidar_supported': hasLiDAR,
      'ar_supported': hasAR,
      'camera_supported': cameraAvailable,
      'recommended_capture_mode': scanMode.id,
    };
  }
}

/// Development Overrides and Mock Profiles per Add-on Section 9.
/// Enables comprehensive testing of capability adaptation without physical hardware.
class MockCapabilityProfiles {
  static const DeviceCapabilityProfile iphoneWithLiDAR = DeviceCapabilityProfile(
    operatingSystem: 'ios',
    osVersion: 'iOS 17.4',
    deviceModel: 'iPhone 15 Pro Max',
    cameraAvailable: true,
    hasLiDAR: true,
    hasHardwareDepth: true,
    hasARKit: true,
    hasRoomPlan: true,
    hasARCore: false,
    hasARCoreDepth: false,
    hasMotionSensors: true,
    availableMemoryMB: 8192,
    capabilityConfidence: 0.98,
    capabilityTier: 'Tier A',
    scanMode: ScanMode.lidarScan,
  );

  static const DeviceCapabilityProfile iphoneWithoutLiDAR = DeviceCapabilityProfile(
    operatingSystem: 'ios',
    osVersion: 'iOS 17.4',
    deviceModel: 'iPhone 15',
    cameraAvailable: true,
    hasLiDAR: false,
    hasHardwareDepth: false,
    hasARKit: true,
    hasRoomPlan: false,
    hasARCore: false,
    hasARCoreDepth: false,
    hasMotionSensors: true,
    availableMemoryMB: 6144,
    capabilityConfidence: 0.82,
    capabilityTier: 'Tier B',
    scanMode: ScanMode.arRgbScan,
  );

  static const DeviceCapabilityProfile androidWithARCoreDepth = DeviceCapabilityProfile(
    operatingSystem: 'android',
    osVersion: 'Android 14 (API 34)',
    deviceModel: 'Samsung Galaxy S24 Ultra',
    cameraAvailable: true,
    hasLiDAR: false,
    hasHardwareDepth: true,
    hasARKit: false,
    hasRoomPlan: false,
    hasARCore: true,
    hasARCoreDepth: true,
    hasMotionSensors: true,
    availableMemoryMB: 12288,
    capabilityConfidence: 0.88,
    capabilityTier: 'Tier B',
    scanMode: ScanMode.arDepthScan,
  );

  static const DeviceCapabilityProfile androidWithARCoreNoDepth = DeviceCapabilityProfile(
    operatingSystem: 'android',
    osVersion: 'Android 13 (API 33)',
    deviceModel: 'Google Pixel 6a',
    cameraAvailable: true,
    hasLiDAR: false,
    hasHardwareDepth: false,
    hasARKit: false,
    hasRoomPlan: false,
    hasARCore: true,
    hasARCoreDepth: false,
    hasMotionSensors: true,
    availableMemoryMB: 6144,
    capabilityConfidence: 0.78,
    capabilityTier: 'Tier B',
    scanMode: ScanMode.arRgbScan,
  );

  static const DeviceCapabilityProfile androidBasicCameraOnly = DeviceCapabilityProfile(
    operatingSystem: 'android',
    osVersion: 'Android 12 (API 31)',
    deviceModel: 'Xiaomi Redmi 9A',
    cameraAvailable: true,
    hasLiDAR: false,
    hasHardwareDepth: false,
    hasARKit: false,
    hasRoomPlan: false,
    hasARCore: false,
    hasARCoreDepth: false,
    hasMotionSensors: true,
    availableMemoryMB: 2048,
    capabilityConfidence: 0.70,
    capabilityTier: 'Tier C',
    scanMode: ScanMode.rgbPhotoScan,
  );

  static const DeviceCapabilityProfile unsupportedDevice = DeviceCapabilityProfile(
    operatingSystem: 'android',
    osVersion: 'Android 8.0 (API 26)',
    deviceModel: 'Legacy Device',
    cameraAvailable: false,
    hasLiDAR: false,
    hasHardwareDepth: false,
    hasARKit: false,
    hasRoomPlan: false,
    hasARCore: false,
    hasARCoreDepth: false,
    hasMotionSensors: false,
    availableMemoryMB: 1024,
    capabilityConfidence: 0.20,
    unsupportedReason: 'No camera hardware detected',
    capabilityTier: 'Tier C',
    scanMode: ScanMode.rgbPhotoScan,
  );

  static const List<Map<String, dynamic>> allPresets = [
    {'name': 'iPhone 15 Pro (LiDAR & RoomPlan - Tier A)', 'profile': iphoneWithLiDAR},
    {'name': 'Samsung S24 (ARCore Depth API - Tier B)', 'profile': androidWithARCoreDepth},
    {'name': 'iPhone 15 (ARKit RGB - Tier B)', 'profile': iphoneWithoutLiDAR},
    {'name': 'Pixel 6a (ARCore Motion - Tier B)', 'profile': androidWithARCoreNoDepth},
    {'name': 'Redmi 9A (Standard RGB Camera - Tier C)', 'profile': androidBasicCameraOnly},
    {'name': 'Live Hardware Detection', 'profile': null},
  ];
}
