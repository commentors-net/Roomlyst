import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  group('Multi-View and Coverage Model Tests', () {
    test('CoverageReportModel parses API payload correctly', () {
      final jsonMap = {
        'total_frames': 4,
        'valid_frames': 4,
        'estimated_coverage_pct': 100.0,
        'actionable_guidance': [
          'Full room coverage achieved with multi-view loop closure.'
        ],
      };

      final report = CoverageReportModel.fromMap(jsonMap);
      expect(report.totalFrames, 4);
      expect(report.validFrames, 4);
      expect(report.estimatedCoveragePct, 100.0);
      expect(report.actionableGuidance.first, contains('Full room coverage'));
    });

    test('RoomModelData retains coverage report', () {
      final roomJson = {
        'id': 'room_123',
        'name': 'Multi-View Living Room',
        'room_type': 'living_room',
        'status': 'READY_FOR_REVIEW',
        'coverage_report': {
          'total_frames': 3,
          'valid_frames': 3,
          'estimated_coverage_pct': 85.0,
          'actionable_guidance': [
            'Almost complete: Capture the final corner.'
          ],
        },
        'objects': [
          {'id': 'obj_1', 'name': 'Sofa', 'category': 'sofa', 'confidence': 0.90},
        ],
      };

      final room = RoomModelData.fromMap(roomJson);
      expect(room.coverageReport, isNotNull);
      expect(room.coverageReport!.validFrames, 3);
      expect(room.coverageReport!.estimatedCoveragePct, 85.0);
      expect(room.objects.length, 1);
    });
  });
}
