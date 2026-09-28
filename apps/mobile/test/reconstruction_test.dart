import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/capture/presentation/reconstruction_viewer_screen.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  group('Milestone 3.2 Multi-View Reconstruction Model Tests', () {
    test('CameraPoseModel deserializes correctly', () {
      final json = {
        'view_id': 'view_001',
        'position': [0.5, 1.2, -0.8],
        'rotation_quaternion': [0.0, 0.7071, 0.0, 0.7071],
        'yaw_deg': 90.0,
        'pitch_deg': -5.0,
        'roll_deg': 1.0,
        'reprojection_error_px': 0.75,
        'confidence': 0.94,
      };

      final pose = CameraPoseModel.fromMap(json);
      expect(pose.viewId, 'view_001');
      expect(pose.position, [0.5, 1.2, -0.8]);
      expect(pose.rotationQuaternion.length, 4);
      expect(pose.yawDeg, 90.0);
      expect(pose.pitchDeg, -5.0);
      expect(pose.rollDeg, 1.0);
      expect(pose.reprojectionErrorPx, 0.75);
      expect(pose.confidence, 0.94);
    });

    test('SpatialPlaneModel deserializes correctly with readable labels', () {
      final floorJson = {
        'plane_id': 'plane_floor_001',
        'plane_type': 'FLOOR',
        'normal_vector': [0.0, 1.0, 0.0],
        'distance_d': 0.0,
        'inlier_count': 650,
        'area_sqm': 16.5,
        'elevation_m': 0.0,
        'confidence': 0.96,
      };

      final floor = SpatialPlaneModel.fromMap(floorJson);
      expect(floor.planeId, 'plane_floor_001');
      expect(floor.planeType, 'FLOOR');
      expect(floor.readableType, 'Floor Plane');
      expect(floor.areaSqm, 16.5);
      expect(floor.inlierCount, 650);
      expect(floor.elevationM, 0.0);

      final wallJson = {
        'plane_id': 'plane_wall_north',
        'plane_type': 'WALL_NORTH',
        'normal_vector': [0.0, 0.0, -1.0],
        'distance_d': 2.5,
        'inlier_count': 420,
        'area_sqm': 11.2,
        'confidence': 0.93,
      };

      final wall = SpatialPlaneModel.fromMap(wallJson);
      expect(wall.readableType, 'North Wall');
      expect(wall.normalVector, [0.0, 0.0, -1.0]);
    });

    test('PointCloudMetadataModel deserializes correctly', () {
      final json = {
        'file_path': 'storage/point_clouds/room_01_dense.ply',
        'format': 'ply',
        'vertex_count': 2500,
        'bounding_box_min': [-2.0, 0.0, -2.5],
        'bounding_box_max': [2.0, 2.8, 2.5],
        'point_density_pts_per_sqm': 151.5,
      };

      final pc = PointCloudMetadataModel.fromMap(json);
      expect(pc.filePath, 'storage/point_clouds/room_01_dense.ply');
      expect(pc.format, 'ply');
      expect(pc.vertexCount, 2500);
      expect(pc.boundingBoxMin, [-2.0, 0.0, -2.5]);
      expect(pc.boundingBoxMax, [2.0, 2.8, 2.5]);
      expect(pc.pointDensityPtsPerSqm, 151.5);
    });

    test('MultiViewReconstructionReportModel and RoomModelData integration', () {
      final reportJson = {
        'room_id': 'room_full_test',
        'status': 'SUCCESS',
        'point_cloud': {
          'file_path': 'storage/point_clouds/room_full.ply',
          'format': 'ply',
          'vertex_count': 3200,
          'bounding_box_min': [-2.2, 0.0, -2.5],
          'bounding_box_max': [2.2, 2.8, 2.5],
          'point_density_pts_per_sqm': 180.0,
        },
        'camera_poses': [
          {
            'view_id': 'view_000',
            'position': [0.0, 1.4, 0.0],
            'yaw_deg': 0.0,
            'confidence': 0.95,
          },
        ],
        'extracted_planes': [
          {
            'plane_id': 'plane_floor',
            'plane_type': 'FLOOR',
            'normal_vector': [0.0, 1.0, 0.0],
            'distance_d': 0.0,
            'inlier_count': 780,
            'area_sqm': 18.0,
            'elevation_m': 0.0,
            'confidence': 0.95,
          },
          {
            'plane_id': 'plane_ceiling',
            'plane_type': 'CEILING',
            'normal_vector': [0.0, -1.0, 0.0],
            'distance_d': -2.8,
            'inlier_count': 640,
            'area_sqm': 18.0,
            'elevation_m': 2.8,
            'confidence': 0.94,
          },
        ],
        'mean_reprojection_error_px': 0.72,
        'consistency_score': 0.95,
        'spatial_consistency_tier': 'TIER_1_CONSISTENT',
        'processing_time_ms': 145.0,
        'summary': 'SfM Reconstruction successful with 3200 points and 2 planes.',
      };

      final report = MultiViewReconstructionReportModel.fromMap(reportJson);
      expect(report.status, 'SUCCESS');
      expect(report.pointCloud.vertexCount, 3200);
      expect(report.extractedPlanes.length, 2);
      expect(report.spatialConsistencyTier, 'TIER_1_CONSISTENT');
      expect(report.meanReprojectionErrorPx, 0.72);

      final roomJson = {
        'id': 'room_full_test',
        'name': 'Living Room Reconstruction',
        'room_type': 'living_room',
        'status': 'READY_FOR_REVIEW',
        'reconstruction_report': reportJson,
        'spatial_planes': reportJson['extracted_planes'],
      };

      final room = RoomModelData.fromMap(roomJson);
      expect(room.reconstructionReport, isNotNull);
      expect(room.reconstructionReport!.pointCloud.vertexCount, 3200);
      expect(room.spatialPlanes.length, 2);
      expect(room.spatialPlanes[0].planeType, 'FLOOR');
      expect(room.spatialPlanes[1].planeType, 'CEILING');
    });
  });

  group('ReconstructionViewerScreen Widget Tests', () {
    testWidgets('renders reconstruction report with planes, point cloud, and poses', (tester) async {
      final mockReport = MultiViewReconstructionReportModel(
        roomId: 'room_widget_test',
        status: 'SUCCESS',
        spatialConsistencyTier: 'TIER_1_CONSISTENT',
        consistencyScore: 0.94,
        meanReprojectionErrorPx: 0.68,
        pointCloud: PointCloudMetadataModel(
          filePath: 'storage/point_clouds/test.ply',
          format: 'ply',
          vertexCount: 2400,
          boundingBoxMin: [-2.0, 0.0, -2.5],
          boundingBoxMax: [2.0, 2.7, 2.5],
          pointDensityPtsPerSqm: 145.0,
        ),
        extractedPlanes: [
          SpatialPlaneModel(
            planeId: 'floor_01',
            planeType: 'FLOOR',
            areaSqm: 15.0,
            inlierCount: 500,
            elevationM: 0.0,
            confidence: 0.95,
          ),
          SpatialPlaneModel(
            planeId: 'ceiling_01',
            planeType: 'CEILING',
            areaSqm: 15.0,
            inlierCount: 450,
            elevationM: 2.7,
            confidence: 0.93,
          ),
        ],
        cameraPoses: [
          CameraPoseModel(
            viewId: 'view_000',
            position: [0.0, 1.4, 0.0],
            yawDeg: 0.0,
            pitchDeg: -4.0,
            reprojectionErrorPx: 0.65,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReconstructionViewerScreen(
            roomId: 'room_widget_test',
            roomName: 'Master Bedroom',
            initialReport: mockReport,
          ),
        ),
      );

      // Verify header and tier
      expect(find.text('Master Bedroom — 3D Reconstruction'), findsOneWidget);
      expect(find.text('TIER 1 CONSISTENT'), findsOneWidget);

      // Verify point cloud stats
      expect(find.text('2400 Vertices'), findsOneWidget);
      expect(find.text('PLY'), findsOneWidget);
      expect(find.textContaining('145.0 pts/m²'), findsOneWidget);

      // Verify spatial planes
      expect(find.text('Floor Plane'), findsOneWidget);
      expect(find.text('Ceiling Plane'), findsOneWidget);
      expect(find.text('15.0 m²'), findsNWidgets(2));

      // Verify camera views
      expect(find.text('view_000'), findsOneWidget);
      expect(find.text('Re-run Multi-View Reconstruction'), findsOneWidget);
    });
  });
}
