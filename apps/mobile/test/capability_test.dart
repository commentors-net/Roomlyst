import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/capability/domain/device_capability.dart';

void main() {
  group('DeviceCapabilityProfile Tests', () {
    test('Mock profiles have valid properties and graceful fallbacks', () {
      final pLiDAR = MockCapabilityProfiles.iphoneWithLiDAR;
      expect(pLiDAR.capabilityTier, 'Tier A');
      expect(pLiDAR.scanMode, ScanMode.lidarScan);
      expect(pLiDAR.tierBadgeText, contains('LiDAR Hardware Active'));
      expect(pLiDAR.accuracyAssuranceText, contains('Hardware 3D Precision'));

      final pS24 = MockCapabilityProfiles.androidWithARCoreDepth;
      expect(pS24.capabilityTier, 'Tier B');
      expect(pS24.scanMode, ScanMode.arDepthScan);
      expect(pS24.tierBadgeText, contains('AR Depth Sensor Active'));

      final pRedmi = MockCapabilityProfiles.androidBasicCameraOnly;
      expect(pRedmi.capabilityTier, 'Tier C');
      expect(pRedmi.scanMode, ScanMode.rgbPhotoScan);
      expect(pRedmi.tierBadgeText, contains('Standard Camera AI'));
      expect(pRedmi.userGuidancePrompt, contains('Capture Room: Take photos from room corners'));
    });

    test('resolveOptimalScanMode handles priority correctly', () {
      // LiDAR has highest priority
      expect(
        DeviceCapabilityProfile.resolveOptimalScanMode(
          hasLiDAR: true,
          hasHardwareDepth: true,
          hasARKit: true,
          hasRoomPlan: true,
          hasARCore: false,
          hasARCoreDepth: false,
          hasMotionSensors: true,
          cameraAvailable: true,
        ),
        ScanMode.lidarScan,
      );

      // ARCore Depth when no LiDAR
      expect(
        DeviceCapabilityProfile.resolveOptimalScanMode(
          hasLiDAR: false,
          hasHardwareDepth: false,
          hasARKit: false,
          hasRoomPlan: false,
          hasARCore: true,
          hasARCoreDepth: true,
          hasMotionSensors: true,
          cameraAvailable: true,
        ),
        ScanMode.arDepthScan,
      );

      // ARKit RGB without hardware depth
      expect(
        DeviceCapabilityProfile.resolveOptimalScanMode(
          hasLiDAR: false,
          hasHardwareDepth: false,
          hasARKit: true,
          hasRoomPlan: false,
          hasARCore: false,
          hasARCoreDepth: false,
          hasMotionSensors: true,
          cameraAvailable: true,
        ),
        ScanMode.arRgbScan,
      );

      // Motion sensors only
      expect(
        DeviceCapabilityProfile.resolveOptimalScanMode(
          hasLiDAR: false,
          hasHardwareDepth: false,
          hasARKit: false,
          hasRoomPlan: false,
          hasARCore: false,
          hasARCoreDepth: false,
          hasMotionSensors: true,
          cameraAvailable: true,
        ),
        ScanMode.rgbVideoScan,
      );

      // Standard RGB Camera
      expect(
        DeviceCapabilityProfile.resolveOptimalScanMode(
          hasLiDAR: false,
          hasHardwareDepth: false,
          hasARKit: false,
          hasRoomPlan: false,
          hasARCore: false,
          hasARCoreDepth: false,
          hasMotionSensors: false,
          cameraAvailable: true,
        ),
        ScanMode.rgbPhotoScan,
      );
    });

    test('fromMap and toMap roundtrip serialization', () {
      final map = MockCapabilityProfiles.androidWithARCoreDepth.toMap();
      final reconstructed = DeviceCapabilityProfile.fromMap(map);

      expect(reconstructed.operatingSystem, 'android');
      expect(reconstructed.capabilityTier, 'Tier B');
      expect(reconstructed.scanMode, ScanMode.arDepthScan);
      expect(reconstructed.hasARCoreDepth, true);
    });
  });
}
