import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/capability/domain/device_capability.dart';
import 'package:roomlyst/features/capture/presentation/video_scan_screen.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  group('Milestone 3.1 Guided RGB Video Scan Model Tests', () {
    test('VideoScanMetadataModel parses JSON accurately', () {
      final json = {
        'video_duration_seconds': 14.5,
        'fps': 30.0,
        'total_frames_recorded': 435,
        'sampled_keyframes_count': 12,
        'average_motion_speed_deg_per_sec': 13.8,
        'motion_stability_score': 0.94,
        'excessive_motion_warnings_count': 1,
        'coverage_score': 0.88,
        'is_stable_sequence': true,
      };

      final meta = VideoScanMetadataModel.fromMap(json);
      expect(meta.videoDurationSeconds, 14.5);
      expect(meta.fps, 30.0);
      expect(meta.totalFramesRecorded, 435);
      expect(meta.sampledKeyframesCount, 12);
      expect(meta.averageMotionSpeedDegPerSec, 13.8);
      expect(meta.motionStabilityScore, 0.94);
      expect(meta.excessiveMotionWarningsCount, 1);
      expect(meta.coverageScore, 0.88);
      expect(meta.isStableSequence, isTrue);
    });

    test('VideoKeyframeModel parses keyframe telemetry', () {
      final json = {
        'keyframe_id': 'kf_test_01',
        'frame_index': 45,
        'timestamp_seconds': 1.5,
        'image_url': 'storage/vscan/kf_01.jpg',
        'sharpness_score': 168.5,
        'camera_motion_speed': 12.2,
        'detected_wall_view': 'main_wall',
        'estimated_coverage_pct': 35.0,
      };

      final kf = VideoKeyframeModel.fromMap(json);
      expect(kf.keyframeId, 'kf_test_01');
      expect(kf.frameIndex, 45);
      expect(kf.timestampSeconds, 1.5);
      expect(kf.imageUrl, 'storage/vscan/kf_01.jpg');
      expect(kf.sharpnessScore, 168.5);
      expect(kf.cameraMotionSpeed, 12.2);
      expect(kf.detectedWallView, 'main_wall');
      expect(kf.estimatedCoveragePct, 35.0);
    });

    test('VideoScanReportModel and RoomModelData integration', () {
      final json = {
        'session_id': 'vscan_sess_99',
        'room_id': 'room_rgb_only_01',
        'metadata': {
          'video_duration_seconds': 15.0,
          'fps': 30.0,
          'total_frames_recorded': 450,
          'sampled_keyframes_count': 8,
          'motion_stability_score': 0.91,
          'excessive_motion_warnings_count': 0,
          'coverage_score': 0.85,
          'is_stable_sequence': true,
        },
        'keyframes': [
          {
            'keyframe_id': 'kf_01',
            'frame_index': 0,
            'timestamp_seconds': 0.0,
            'image_url': 'kf_01.jpg',
            'sharpness_score': 180.0,
          },
          {
            'keyframe_id': 'kf_02',
            'frame_index': 60,
            'timestamp_seconds': 2.0,
            'image_url': 'kf_02.jpg',
            'sharpness_score': 175.0,
          },
        ],
        'quality_assessment': 'EXCELLENT',
        'guidance_notes': [
          'Steady panning speed maintained throughout scan.',
          'Keyframes exhibit high edge sharpness suitable for dense SfM/NeRF reconstruction.',
        ],
        'is_suitable_for_reconstruction': true,
        'created_at': '2026-09-28T15:30:00Z',
      };

      final report = VideoScanReportModel.fromMap(json);
      expect(report.sessionId, 'vscan_sess_99');
      expect(report.roomId, 'room_rgb_only_01');
      expect(report.isSuitableForReconstruction, isTrue);
      expect(report.qualityAssessment, 'EXCELLENT');
      expect(report.keyframes.length, 2);
      expect(report.guidanceNotes.length, 2);

      final roomJson = {
        'id': 'room_rgb_only_01',
        'name': 'Living Room Sweep',
        'room_type': 'living_room',
        'status': 'READY_FOR_REVIEW',
        'video_scan_report': json,
      };

      final room = RoomModelData.fromMap(roomJson);
      expect(room.videoScanReport, isNotNull);
      expect(room.videoScanReport!.sessionId, 'vscan_sess_99');
      expect(room.videoScanReport!.isSuitableForReconstruction, isTrue);
      expect(room.videoScanReport!.keyframes.length, 2);
    });

    testWidgets('VideoScanScreen renders motion HUD and sweep controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoScanScreen(
            projectId: 'proj_test',
            projectName: 'Living Room',
            capability: MockCapabilityProfiles.androidBasicCameraOnly,
          ),
        ),
      );

      // Verify Screen title & HUD
      expect(find.text('Living Room — Video Scan'), findsOneWidget);
      expect(find.text('READY TO RECORD'), findsOneWidget);
      expect(find.text('Record Sweep'), findsOneWidget);
      expect(find.text('Room Sweep Coverage'), findsOneWidget);
      expect(find.text('Main Wall'), findsOneWidget);
      expect(find.text('Floor Line'), findsOneWidget);

      // Tap Record Sweep button
      await tester.tap(find.text('Record Sweep'));
      await tester.pump();

      expect(find.text('Stop Sweep'), findsOneWidget);
      expect(find.textContaining('RECORDING SWEEP'), findsOneWidget);

      // Tap Stop Sweep button
      await tester.tap(find.text('Stop Sweep'));
      await tester.pump();

      expect(find.text('Record Sweep'), findsOneWidget);
    });
  });
}
