import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/capture/presentation/ar_session_screen.dart';

void main() {
  group('AR Non-LiDAR Domain Models', () {
    test('ARCameraPoseModel serializes and deserializes correctly', () {
      final pose = ARCameraPoseModel(
        frameIndex: 12,
        timestampMs: 1500.0,
        translation: [1.2, 1.4, -0.8],
        rotationQuaternion: [0.707, 0.0, 0.707, 0.0],
        trackingState: 'TRACKING',
        featurePointsCount: 210,
        confidence: 0.98,
      );

      final map = pose.toMap();
      expect(map['frame_index'], 12);
      expect(map['timestamp_ms'], 1500.0);
      expect(map['translation'], [1.2, 1.4, -0.8]);
      expect(map['tracking_state'], 'TRACKING');
      expect(map['confidence'], 0.98);

      final fromJson = ARCameraPoseModel.fromMap(map);
      expect(fromJson.frameIndex, 12);
      expect(fromJson.featurePointsCount, 210);
      expect(fromJson.translation[0], 1.2);
    });

    test('IMUMotionSampleModel serializes and deserializes correctly', () {
      final imu = IMUMotionSampleModel(
        timestampMs: 250.0,
        acceleration: [0.05, 9.82, -0.01],
        rotationRate: [0.01, -0.02, 0.03],
        gravityVector: [0.0, 0.0, -9.81],
        headingDeg: 45.0,
        tiltDeg: 2.1,
      );

      final map = imu.toMap();
      expect(map['timestamp_ms'], 250.0);
      expect(map['acceleration'], [0.05, 9.82, -0.01]);
      expect(map['heading_deg'], 45.0);

      final fromJson = IMUMotionSampleModel.fromMap(map);
      expect(fromJson.timestampMs, 250.0);
      expect(fromJson.tiltDeg, 2.1);
      expect(fromJson.acceleration[1], 9.82);
    });

    test('DepthFromMotionPayloadModel serializes and deserializes correctly', () {
      final payload = DepthFromMotionPayloadModel(
        depthMapUrl: 'https://cdn.roomlyst.internal/depth/scan_01.png',
        sparsePointsCount: 350,
        minDepthM: 0.8,
        maxDepthM: 4.8,
        meanDepthConfidence: 0.93,
      );

      final map = payload.toMap();
      expect(map['depth_map_url'], 'https://cdn.roomlyst.internal/depth/scan_01.png');
      expect(map['sparse_points_count'], 350);
      expect(map['mean_depth_confidence'], 0.93);

      final fromJson = DepthFromMotionPayloadModel.fromMap(map);
      expect(fromJson.sparsePointsCount, 350);
      expect(fromJson.minDepthM, 0.8);
      expect(fromJson.maxDepthM, 4.8);
    });

    test('ARAssistedScanReportModel parses and calculates helper getters', () {
      final report = ARAssistedScanReportModel(
        sessionId: 'sess_ar_101',
        roomId: 'room_101',
        trackingQuality: 'EXCELLENT',
        posesCount: 36,
        imuSamplesCount: 72,
        hasDepthFromMotion: true,
        scaleFactorEstimated: 1.042,
        motionTrajectoryLengthM: 4.25,
        fusedConsistencyScore: 0.96,
        fusionTier: 'TIER_3_AR_RGB',
        notes: ['VIO loop closed', 'Depth-from-motion integrated'],
      );

      expect(report.isScaleReliable, isTrue);
      expect(report.overallConfidence, 0.96);
      expect(report.trajectoryLengthMeters, 4.25);
      expect(report.metricScaleFactor, 1.042);
      expect(report.depthPointsEstimated, 120);
      expect(report.provenanceUpgradedTo, 'AR_DEPTH_FROM_MOTION');

      final map = report.toMap();
      expect(map['session_id'], 'sess_ar_101');
      expect(map['poses_count'], 36);

      final fromJson = ARAssistedScanReportModel.fromMap(map);
      expect(fromJson.sessionId, 'sess_ar_101');
      expect(fromJson.hasDepthFromMotion, isTrue);
      expect(fromJson.scaleFactorEstimated, 1.042);
    });

    test('RoomModelData parses arAssistedReport correctly', () {
      final roomMap = {
        'id': 'room_ar_test',
        'name': 'AR Master Bedroom',
        'room_type': 'BEDROOM',
        'confidence_score': 0.95,
        'measurements': [],
        'openings': [],
        'surfaces': [],
        'objects': [],
        'ar_assisted_report': {
          'session_id': 'sess_999',
          'room_id': 'room_ar_test',
          'tracking_quality': 'GOOD',
          'poses_count': 28,
          'imu_samples_count': 56,
          'has_depth_from_motion': false,
          'scale_factor_estimated': 1.015,
          'motion_trajectory_length_m': 3.12,
          'fused_consistency_score': 0.94,
          'fusion_tier': 'TIER_3_AR_RGB',
          'notes': ['VIO trajectory baseline applied'],
        },
      };

      final room = RoomModelData.fromMap(roomMap);
      expect(room.id, 'room_ar_test');
      expect(room.arAssistedReport, isNotNull);
      expect(room.arAssistedReport!.trackingQuality, 'GOOD');
      expect(room.arAssistedReport!.trajectoryLengthMeters, 3.12);
      expect(room.arAssistedReport!.isScaleReliable, isTrue);
      expect(room.arAssistedReport!.provenanceUpgradedTo, 'AR_MOTION_VERIFIED');
    });
  });

  group('ARSessionScreen Widget Tests', () {
    testWidgets('renders AR session screen with initial report and metrics', (tester) async {
      final initialReport = ARAssistedScanReportModel(
        sessionId: 'sess_ar_widget',
        roomId: 'room_mock_01',
        trackingQuality: 'EXCELLENT',
        posesCount: 30,
        imuSamplesCount: 60,
        hasDepthFromMotion: true,
        scaleFactorEstimated: 1.025,
        motionTrajectoryLengthM: 3.85,
        fusedConsistencyScore: 0.95,
        fusionTier: 'TIER_3_AR_RGB',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ARSessionScreen(
            roomId: 'room_mock_01',
            roomName: 'Living Room',
            initialReport: initialReport,
            deviceTier: 'TIER_3_AR_RGB',
          ),
        ),
      );

      expect(find.text('Living Room • AR Motion Path'), findsOneWidget);
      expect(find.text('TIER_3_AR_RGB'), findsOneWidget);
      expect(find.text('VIO Native'), findsOneWidget);
      expect(find.text('AR Fusion Report'), findsOneWidget);
      expect(find.text('METRIC VALIDATED'), findsOneWidget);
      expect(find.text('EXCELLENT'), findsOneWidget);
      expect(find.text('3.85 m'), findsOneWidget);
      expect(find.text('1.025x'), findsOneWidget);
      expect(find.text('95.0%'), findsOneWidget);
      expect(find.text('Fuse AR Odometry with 3D Model'), findsOneWidget);
    });
  });
}
