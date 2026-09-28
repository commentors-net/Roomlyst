import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  group('Geometry and Feasibility Domain Models', () {
    test('GeometryModel parses wall segments and polygon vertices', () {
      final geomJson = {
        'floor_area_sqm': 20.0,
        'ceiling_height_m': 2.6,
        'estimated_width_m': 4.0,
        'estimated_length_m': 5.0,
        'room_shape': 'RECTANGULAR',
        'loop_closure_status': 'CLOSED',
        'loop_closure_gap_m': 0.0,
        'perimeter_m': 18.0,
        'polygon_vertices': [
          {'x': 0.0, 'y': 0.0},
          {'x': 4.0, 'y': 0.0},
          {'x': 4.0, 'y': 5.0},
          {'x': 0.0, 'y': 5.0},
        ],
        'wall_segments': [
          {
            'id': 'w1',
            'name': 'South Wall',
            'start_point': {'x': 0.0, 'y': 0.0},
            'end_point': {'x': 4.0, 'y': 0.0},
            'length_m': 4.0,
          },
          {
            'id': 'w2',
            'name': 'East Wall',
            'start_point': {'x': 4.0, 'y': 0.0},
            'end_point': {'x': 4.0, 'y': 5.0},
            'length_m': 5.0,
          },
        ],
      };

      final geom = GeometryModel.fromMap(geomJson);
      expect(geom.roomShape, 'RECTANGULAR');
      expect(geom.isClosed, isTrue);
      expect(geom.perimeterM, 18.0);
      expect(geom.polygonVertices.length, 4);
      expect(geom.wallSegments.length, 2);
      expect(geom.wallSegments[0].startPoint.x, 0.0);
      expect(geom.wallSegments[0].endPoint.x, 4.0);
    });

    test('FeasibilityReportModel parses clearance checks and issue types', () {
      final reportJson = {
        'overall_feasible': false,
        'critical_issues_count': 1,
        'warning_issues_count': 1,
        'min_walkway_clearance_m': 0.52,
        'summary': 'Clearance warnings detected.',
        'checks': [
          {
            'check_id': 'chk_001',
            'check_name': 'Door Swing Clearance (Entrance Door)',
            'passed': false,
            'severity': 'CRITICAL',
            'issue_type': 'DOOR_SWING_OBSTRUCTED',
            'entity_names': ['Entrance Door', 'Large Armchair'],
            'measured_clearance_m': 0.45,
            'required_clearance_m': 0.85,
            'message': 'Door swing is obstructed by Large Armchair.',
            'suggested_action': 'Move armchair 40cm back.',
          },
          {
            'check_id': 'chk_002',
            'check_name': 'Walkway: Sofa & Coffee Table',
            'passed': false,
            'severity': 'WARNING',
            'issue_type': 'WALKWAY_TOO_NARROW',
            'entity_names': ['Sofa', 'Coffee Table'],
            'measured_clearance_m': 0.52,
            'required_clearance_m': 0.60,
            'message': 'Tight pathway between Sofa and Coffee Table.',
            'suggested_action': 'Maintain at least 0.60m for comfortable passage.',
          },
        ],
      };

      final report = FeasibilityReportModel.fromMap(reportJson);
      expect(report.overallFeasible, isFalse);
      expect(report.criticalIssuesCount, 1);
      expect(report.warningIssuesCount, 1);
      expect(report.minWalkwayClearanceM, 0.52);
      expect(report.checks.length, 2);

      final critCheck = report.checks[0];
      expect(critCheck.severity, 'CRITICAL');
      expect(critCheck.issueType, 'DOOR_SWING_OBSTRUCTED');
      expect(critCheck.entityNames, contains('Large Armchair'));
      expect(critCheck.suggestedAction, contains('Move armchair'));
    });

    test('RoomModelData integrates geometry and feasibility report', () {
      final roomJson = {
        'id': 'room_789',
        'name': 'Feasibility Living Room',
        'room_type': 'living_room',
        'status': 'READY_FOR_REVIEW',
        'geometry': {
          'floor_area_sqm': 24.5,
          'room_shape': 'L_SHAPED',
          'loop_closure_status': 'SNAPPED',
          'loop_closure_gap_m': 0.08,
          'perimeter_m': 22.0,
        },
        'feasibility_report': {
          'overall_feasible': true,
          'critical_issues_count': 0,
          'warning_issues_count': 0,
          'min_walkway_clearance_m': 0.85,
          'summary': 'All physical clearances pass.',
          'checks': [
            {
              'check_id': 'c1',
              'check_name': 'Wall Perimeter Loop Closure',
              'passed': true,
              'severity': 'INFO',
              'message': 'Perimeter loop closed (snapped).',
            }
          ],
        },
      };

      final room = RoomModelData.fromMap(roomJson);
      expect(room.geometry, isNotNull);
      expect(room.geometry!.roomShape, 'L_SHAPED');
      expect(room.geometry!.isClosed, isTrue);
      expect(room.feasibilityReport, isNotNull);
      expect(room.feasibilityReport!.overallFeasible, isTrue);
      expect(room.feasibilityReport!.minWalkwayClearanceM, 0.85);
    });
  });
}
