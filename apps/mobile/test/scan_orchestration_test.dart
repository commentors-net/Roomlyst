import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/capability/domain/device_capability.dart';
import 'package:roomlyst/features/capture/presentation/capture_orchestration_dialog.dart';
import 'package:roomlyst/features/capture/presentation/capture_screen.dart';
import 'package:roomlyst/features/capture/services/scan_orchestrator.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  group('Scan Orchestration Domain Models', () {
    test('TierBenchmarkMetricsModel serializes and deserializes correctly', () {
      final benchmark = TierBenchmarkMetricsModel(
        tierId: 'TIER_1_LIDAR',
        tierName: 'Apple RoomPlan LiDAR',
        hardwareDescription: 'Hardware LiDAR sensor with direct laser meshing',
        scanMode: 'lidar_scan',
        primaryFramework: 'Apple RoomPlan SDK',
        typicalAccuracyCm: 0.8,
        accuracyTier: 'EXACT',
        expectedConfidence: 0.98,
        meanCaptureTimeSec: 15.0,
        meanProcessingTimeSec: 4.0,
        relativeComputeCostUsd: 0.005,
        scaleStability: 'DIRECT_METRIC_LASER',
        loopClosureReliability: 'HARDWARE_CLOSED',
        supportedDevicesSample: ['iPhone 12-16 Pro', 'iPad Pro M1-M4'],
      );

      final map = benchmark.toMap();
      expect(map['tier_id'], 'TIER_1_LIDAR');
      expect(map['typical_accuracy_cm'], 0.8);
      expect(map['accuracy_tier'], 'EXACT');
      expect(map['relative_compute_cost_usd'], 0.005);
      expect((map['supported_devices_sample'] as List).length, 2);

      final fromMap = TierBenchmarkMetricsModel.fromMap(map);
      expect(fromMap.tierId, 'TIER_1_LIDAR');
      expect(fromMap.typicalAccuracyCm, 0.8);
      expect(fromMap.scanMode, 'lidar_scan');
    });

    test('ScanOrchestrationEvaluationModel parses complete evaluation and attaches to RoomModelData', () {
      final json = {
        'evaluated_tier': 'TIER_3_AR_RGB',
        'recommended_scan_mode': 'ar_rgb_scan',
        'user_guidance_prompt': 'Move slowly around room',
        'accuracy_assurance': 'AR Motion Geometry (~3-5cm Metric VIO)',
        'fallback_chain': ['rgb_video_scan', 'rgb_photo_scan'],
        'fallback_reasons': ['Tracking loss fallback', 'Dim lighting fallback'],
        'active_benchmark': {
          'tier_id': 'TIER_3_AR_RGB',
          'tier_name': 'AR RGB Odometry',
          'hardware_description': 'Standard RGB + IMU',
          'scan_mode': 'ar_rgb_scan',
          'primary_framework': 'ARKit / ARCore VIO',
          'typical_accuracy_cm': 4.5,
          'accuracy_tier': 'EXACT',
          'expected_confidence': 0.94,
          'mean_capture_time_sec': 25.0,
          'mean_processing_time_sec': 8.0,
          'relative_compute_cost_usd': 0.015,
          'scale_stability': 'VIO_ODOMETRY_SCALED',
          'loop_closure_reliability': 'KEYFRAME_LOOP_CLOSED',
          'supported_devices_sample': ['iPhone 12-16 Base', 'Pixel 7-8'],
        },
        'all_tier_benchmarks': [],
      };

      final eval = ScanOrchestrationEvaluationModel.fromMap(json);
      expect(eval.evaluatedTier, 'TIER_3_AR_RGB');
      expect(eval.recommendedScanMode, 'ar_rgb_scan');
      expect(eval.fallbackChain.length, 2);
      expect(eval.activeBenchmark, isNotNull);
      expect(eval.activeBenchmark!.typicalAccuracyCm, 4.5);

      final roomDataMap = {
        'id': 'room_orch_101',
        'name': 'Master Bedroom',
        'room_type': 'bedroom',
        'status': 'READY_FOR_REVIEW',
        'orchestration_evaluation': json,
      };

      final roomModel = RoomModelData.fromMap(roomDataMap);
      expect(roomModel.orchestrationEvaluation, isNotNull);
      expect(roomModel.orchestrationEvaluation!.evaluatedTier, 'TIER_3_AR_RGB');
      expect(roomModel.orchestrationEvaluation!.recommendedScanMode, 'ar_rgb_scan');
    });
  });

  group('ScanOrchestrator Service Logic', () {
    test('Resolves Tier 1 LiDAR when device has LiDAR sensor', () {
      const profile = DeviceCapabilityProfile(
        operatingSystem: 'iOS',
        osVersion: '17.5',
        deviceModel: 'iPhone 15 Pro',
        hasLiDAR: true,
        hasARKit: true,
        hasRoomPlan: true,
        capabilityTier: 'Tier A',
        scanMode: ScanMode.lidarScan,
      );

      final orchestrator = ScanOrchestrator(deviceProfile: profile);
      expect(orchestrator.currentMode, ScanMode.lidarScan);
      expect(orchestrator.currentTierId, 'TIER_1_LIDAR');
      expect(orchestrator.isManualOverride, isFalse);
      expect(orchestrator.currentAccuracyAssurance, contains('Hardware 3D Precision'));
    });

    test('Resolves Tier 3 AR RGB when device has AR without LiDAR', () {
      const profile = DeviceCapabilityProfile(
        operatingSystem: 'iOS',
        osVersion: '16.0',
        deviceModel: 'iPhone 13',
        hasLiDAR: false,
        hasARKit: true,
        capabilityTier: 'Tier B',
        scanMode: ScanMode.arRgbScan,
      );

      final orchestrator = ScanOrchestrator(deviceProfile: profile);
      expect(orchestrator.currentMode, ScanMode.arRgbScan);
      expect(orchestrator.currentTierId, 'TIER_3_AR_RGB');
      expect(orchestrator.currentAccuracyAssurance, contains('Metric VIO'));
    });

    test('Manual override updates mode and can be reset to auto-recommended', () {
      const profile = DeviceCapabilityProfile(
        operatingSystem: 'iOS',
        osVersion: '17.5',
        deviceModel: 'iPhone 15 Pro',
        hasLiDAR: true,
        hasARKit: true,
        hasRoomPlan: true,
        capabilityTier: 'Tier A',
        scanMode: ScanMode.lidarScan,
      );

      final orchestrator = ScanOrchestrator(deviceProfile: profile);
      expect(orchestrator.isManualOverride, isFalse);

      orchestrator.setManualMode(ScanMode.rgbVideoScan);
      expect(orchestrator.currentMode, ScanMode.rgbVideoScan);
      expect(orchestrator.currentTierId, 'TIER_4_VIDEO_SWEEP');
      expect(orchestrator.isManualOverride, isTrue);

      orchestrator.resetToRecommended();
      expect(orchestrator.currentMode, ScanMode.lidarScan);
      expect(orchestrator.isManualOverride, isFalse);
    });

    test('Graceful step-down degradation traverses fallback hierarchy', () {
      const profile = DeviceCapabilityProfile(
        operatingSystem: 'iOS',
        osVersion: '17.5',
        deviceModel: 'iPhone 15 Pro',
        hasLiDAR: true,
        hasARKit: true,
        capabilityTier: 'Tier A',
        scanMode: ScanMode.lidarScan,
      );

      final orchestrator = ScanOrchestrator(deviceProfile: profile);

      // LiDAR -> AR RGB
      final step1 = orchestrator.stepDownFallback('LiDAR obstruction detected');
      expect(step1, isTrue);
      expect(orchestrator.currentMode, ScanMode.arRgbScan);
      expect(orchestrator.fallbackReason, 'LiDAR obstruction detected');

      // AR RGB -> Video Sweep
      final step2 = orchestrator.stepDownFallback('Visual-Inertial Odometry drift detected');
      expect(step2, isTrue);
      expect(orchestrator.currentMode, ScanMode.rgbVideoScan);

      // Video Sweep -> Multi-Corner Photo
      final step3 = orchestrator.stepDownFallback('Excessive motion blur');
      expect(step3, isTrue);
      expect(orchestrator.currentMode, ScanMode.rgbPhotoScan);

      // Baseline tier has no further step-down
      final step4 = orchestrator.stepDownFallback('Cannot step down further');
      expect(step4, isFalse);
      expect(orchestrator.currentMode, ScanMode.rgbPhotoScan);
    });
  });

  group('Capture Orchestration UI Widgets', () {
    testWidgets('CaptureOrchestrationDialog renders active mode and permits mode selection', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const profile = DeviceCapabilityProfile(
        operatingSystem: 'iOS',
        osVersion: '17.5',
        deviceModel: 'iPhone 15 Pro',
        hasLiDAR: true,
        hasARKit: true,
        capabilityTier: 'Tier A',
        scanMode: ScanMode.lidarScan,
      );

      final orchestrator = ScanOrchestrator(deviceProfile: profile);
      ScanMode? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CaptureOrchestrationDialog(
              orchestrator: orchestrator,
              onModeChanged: (mode) => selected = mode,
              initialBenchmarks: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Scan Mode Orchestrator'), findsOneWidget);
      expect(find.text('OPTIMAL SELECTION'), findsOneWidget);
      expect(find.text('Tier 1: Apple RoomPlan LiDAR'), findsWidgets);
      expect(find.text('Tier 4: Guided Monocular Video Sweep'), findsOneWidget);

      // Select Video Sweep tier
      await tester.tap(find.text('Tier 4: Guided Monocular Video Sweep'));
      await tester.pump();

      // Tap Apply Manual Tier button
      await tester.tap(find.text('Apply Manual Tier'));
      await tester.pump();

      expect(selected, ScanMode.rgbVideoScan);
    });

    testWidgets('CaptureScreen renders orchestration banner and opens dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const profile = DeviceCapabilityProfile(
        operatingSystem: 'iOS',
        osVersion: '17.5',
        deviceModel: 'iPhone 15 Pro',
        hasLiDAR: true,
        hasARKit: true,
        capabilityTier: 'Tier A',
        scanMode: ScanMode.lidarScan,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CaptureScreen(
            projectId: 'proj_test_orch',
            projectName: 'Orchestration Test Project',
            capability: profile,
            autoSyncCloud: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Check orchestration banner
      expect(find.text('Tier 1: Apple RoomPlan LiDAR'), findsOneWidget);
      expect(find.text('AUTO'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      // Tap Change button
      await tester.tap(find.text('Change'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Scan Mode Orchestrator'), findsOneWidget);
    });
  });
}
