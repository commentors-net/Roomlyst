import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/capture/presentation/lidar_scan_screen.dart';

void main() {
  group('LiDAR & Native Spatial Domain Models', () {
    test('NativeSurfaceScanModel serializes and deserializes correctly', () {
      final surface = NativeSurfaceScanModel(
        surfaceId: 'surf_wall_01',
        category: 'wall',
        dimensionsM: [4.5, 2.7, 0.15],
        translation: [2.25, 0.0, 1.35],
        normalVector: [0.0, -1.0, 0.0],
        confidence: 0.98,
        provenance: 'LIDAR_NATIVE',
      );

      final map = surface.toMap();
      expect(map['surface_id'], 'surf_wall_01');
      expect(map['category'], 'wall');
      expect(map['dimensions_m'], [4.5, 2.7, 0.15]);
      expect(map['translation'], [2.25, 0.0, 1.35]);
      expect(map['confidence'], 0.98);
      expect(map['provenance'], 'LIDAR_NATIVE');

      final fromMap = NativeSurfaceScanModel.fromMap(map);
      expect(fromMap.surfaceId, 'surf_wall_01');
      expect(fromMap.surfaceType, 'wall');
      expect(fromMap.dimensions[0], 4.5);
      expect(fromMap.confidence, 0.98);
    });

    test('NativeOpeningScanModel serializes and deserializes correctly', () {
      final opening = NativeOpeningScanModel(
        openingId: 'opn_door_01',
        category: 'door',
        dimensionsM: [0.9, 2.1],
        translation: [1.0, 0.0, 1.05],
        parentWallId: 'surf_wall_01',
        confidence: 0.97,
        provenance: 'LIDAR_NATIVE',
      );

      final map = opening.toMap();
      expect(map['opening_id'], 'opn_door_01');
      expect(map['category'], 'door');
      expect(map['dimensions_m'], [0.9, 2.1]);
      expect(map['parent_wall_id'], 'surf_wall_01');
      expect(map['confidence'], 0.97);

      final fromMap = NativeOpeningScanModel.fromMap(map);
      expect(fromMap.openingId, 'opn_door_01');
      expect(fromMap.openingType, 'door');
      expect(fromMap.dimensions[1], 2.1);
    });

    test('NativeObjectScanModel serializes and deserializes correctly', () {
      final obj = NativeObjectScanModel(
        objectId: 'obj_table_01',
        category: 'table',
        label: 'Oak Dining Table',
        dimensionsM: [1.8, 0.9, 0.75],
        translation: [2.0, 1.5, 0.375],
        rotationDeg: 45.0,
        confidence: 0.95,
        provenance: 'HARDWARE_DEPTH',
      );

      final map = obj.toMap();
      expect(map['object_id'], 'obj_table_01');
      expect(map['category'], 'table');
      expect(map['label'], 'Oak Dining Table');
      expect(map['rotation_deg'], 45.0);
      expect(map['provenance'], 'HARDWARE_DEPTH');

      final fromMap = NativeObjectScanModel.fromMap(map);
      expect(fromMap.objectId, 'obj_table_01');
      expect(fromMap.label, 'Oak Dining Table');
      expect(fromMap.rotationDeg, 45.0);
    });

    test('NativeSpatialScanPayloadModel round-trip serialization', () {
      final payload = NativeSpatialScanPayloadModel(
        roomId: 'room_123',
        platform: 'apple_roomplan',
        deviceTier: 'TIER_1_LIDAR',
        surfaces: [
          NativeSurfaceScanModel(
            surfaceId: 'w1',
            category: 'wall',
            dimensionsM: [5.0, 2.8, 0.15],
          ),
        ],
        openings: [
          NativeOpeningScanModel(
            openingId: 'd1',
            category: 'door',
          ),
        ],
        objects: [
          NativeObjectScanModel(
            objectId: 't1',
            category: 'table',
          ),
        ],
        meshVerticesCount: 150000,
        sensorNotes: ['RoomPlan API active'],
      );

      final map = payload.toMap();
      expect(map['room_id'], 'room_123');
      expect(map['device_tier'], 'TIER_1_LIDAR');
      expect(map['mesh_vertices_count'], 150000);

      final fromMap = NativeSpatialScanPayloadModel.fromMap(map);
      expect(fromMap.roomId, 'room_123');
      expect(fromMap.framework, 'apple_roomplan');
      expect(fromMap.surfaces.length, 1);
      expect(fromMap.openings.length, 1);
      expect(fromMap.objects.length, 1);
      expect(fromMap.pointCloudCount, 150000);
    });

    test('NativeSpatialScanReportModel serializes and computes getters correctly', () {
      final report = NativeSpatialScanReportModel(
        scanId: 'spatial_scan_999',
        roomId: 'room_abc',
        platform: 'Apple RoomPlan',
        hardwareType: 'APPLE_LIDAR_ROOMPLAN',
        surfacesDetected: 6,
        openingsDetected: 2,
        objectsDetected: 3,
        confidenceScore: 0.985,
        measurementProvenance: 'LIDAR_NATIVE',
        rawScanRetained: true,
        createdAt: DateTime.utc(2026, 9, 28, 20, 30),
      );

      final map = report.toMap();
      expect(map['scan_id'], 'spatial_scan_999');
      expect(map['measurement_provenance'], 'LIDAR_NATIVE');
      expect(map['surfaces_detected'], 6);

      final fromMap = NativeSpatialScanReportModel.fromMap(map);
      expect(fromMap.scanId, 'spatial_scan_999');
      expect(fromMap.provenance, 'LIDAR_NATIVE');
      expect(fromMap.surfacesCount, 6);
      expect(fromMap.openingsCount, 2);
      expect(fromMap.objectsCount, 3);
      expect(fromMap.closedLoopVerified, isTrue);
      expect(fromMap.confidenceScore, 0.985);
    });
  });

  group('LiDARScanScreen Widget Tests', () {
    testWidgets('Renders Apple LiDAR hardware badge and controls in standby', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiDARScanScreen(
            roomId: 'room_lidar_test',
            roomName: 'Master Bedroom',
            deviceTier: 'TIER_1_LIDAR',
            autoFetch: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title & hardware badge
      expect(find.text('Master Bedroom • Spatial Scan'), findsOneWidget);
      expect(find.text('Apple RoomPlan LiDAR'), findsOneWidget);
      expect(find.text('EXACT'), findsOneWidget);
      expect(find.text('STANDBY'), findsOneWidget);
      expect(find.text('Start Spatial Scan'), findsOneWidget);

      // Ensure visible and tap start spatial scan
      await tester.ensureVisible(find.text('Start Spatial Scan'));
      await tester.tap(find.text('Start Spatial Scan'));
      await tester.pumpAndSettle();

      // Verify scanning state and detected counts
      expect(find.text('STREAMING MESH'), findsOneWidget);
      expect(find.text('6'), findsOneWidget); // 6 surfaces
      expect(find.text('2'), findsWidgets); // 2 openings & 2 objects
      expect(find.text('Rescan Room'), findsOneWidget);
    });

    testWidgets('Renders Android Hardware-Depth mode with existing report', (tester) async {
      final initialReport = NativeSpatialScanReportModel(
        scanId: 'rep_android_01',
        roomId: 'room_tof_test',
        platform: 'Android ARCore Depth',
        hardwareType: 'ANDROID_TOF_DEPTH',
        surfacesDetected: 4,
        openingsDetected: 1,
        objectsDetected: 2,
        confidenceScore: 0.96,
        measurementProvenance: 'HARDWARE_DEPTH',
        rawScanRetained: true,
        createdAt: DateTime.utc(2026, 9, 28, 20, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LiDARScanScreen(
            roomId: 'room_tof_test',
            roomName: 'Living Hall',
            deviceTier: 'TIER_2_AR_DEPTH',
            initialReport: initialReport,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Android badge
      expect(find.text('Living Hall • Spatial Scan'), findsOneWidget);
      expect(find.text('Android Hardware-Depth / ToF'), findsOneWidget);
      expect(find.text('HARDWARE_DEPTH'), findsOneWidget);
      expect(find.text('Canonical Spatial Report'), findsOneWidget);
      expect(find.text('Verified ✓'), findsOneWidget);
    });
  });
}
