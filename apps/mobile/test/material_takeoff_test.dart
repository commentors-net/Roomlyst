// tests/material_takeoff_test.dart
// Milestone 4.1 – Material and Quantity Estimation
// Flutter unit and widget tests for material takeoff domain models and presentation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/renovation/presentation/material_takeoff_screen.dart';

void main() {
  group('CriticalDimensionVerificationModel', () {
    final sampleMap = {
      'dimension_id': 'dim_floor_area',
      'dimension_type': 'FLOOR_AREA',
      'label': 'Room Floor Footprint Area',
      'estimated_value': 20.0,
      'verified_value': 20.5,
      'unit': 'sqm',
      'confidence': 0.95,
      'uncertainty_margin_pct': 3.0,
      'verification_status': 'CONTRACTOR_VERIFIED',
      'verified_by': 'John Contractor',
      'verified_at': '2026-09-28T21:40:27Z',
      'notes': 'Checked with Leica Disto',
      'recommended_tool': 'Laser distance meter',
      'warning_note': 'Critical for flooring calculation',
    };

    test('fromMap parses all fields accurately', () {
      final dim = CriticalDimensionVerificationModel.fromMap(sampleMap);
      expect(dim.dimensionId, 'dim_floor_area');
      expect(dim.dimensionType, 'FLOOR_AREA');
      expect(dim.label, 'Room Floor Footprint Area');
      expect(dim.estimatedValue, 20.0);
      expect(dim.verifiedValue, 20.5);
      expect(dim.unit, 'sqm');
      expect(dim.confidence, 0.95);
      expect(dim.uncertaintyMarginPct, 3.0);
      expect(dim.verificationStatus, 'CONTRACTOR_VERIFIED');
      expect(dim.verifiedBy, 'John Contractor');
      expect(dim.notes, 'Checked with Leica Disto');
      expect(dim.isVerified, isTrue);
      expect(dim.statusLabel, 'Contractor Verified');
      expect(dim.displayValue, '20.50 sqm (Verified)');
    });

    test('unverified state displays tolerance bounds', () {
      final unverified = CriticalDimensionVerificationModel(
        dimensionId: 'dim_longest_wall',
        dimensionType: 'LONGEST_WALL',
        label: 'Primary Long Wall',
        estimatedValue: 5.0,
        unit: 'm',
        uncertaintyMarginPct: 5.0,
        verificationStatus: 'UNVERIFIED',
      );
      expect(unverified.isVerified, isFalse);
      expect(unverified.statusLabel, 'Unverified (Estimated)');
      expect(unverified.displayValue, '5.00 m (±5%)');
    });

    test('toMap serializes properly', () {
      final dim = CriticalDimensionVerificationModel.fromMap(sampleMap);
      final map = dim.toMap();
      expect(map['dimension_id'], 'dim_floor_area');
      expect(map['verified_value'], 20.5);
      expect(map['verification_status'], 'CONTRACTOR_VERIFIED');
    });
  });

  group('MaterialTakeoffItemModel', () {
    final sampleMap = {
      'item_id': 'item_floor_001',
      'category': 'FLOORING',
      'name': 'Hardwood Flooring',
      'description': 'Floor coverage with allowances',
      'net_quantity': 20.0,
      'unit': 'sqm',
      'waste_factor_pct': 10.0,
      'waste_quantity': 2.0,
      'gross_quantity': 22.0,
      'confidence_score': 0.92,
      'uncertainty_pct': 5.0,
      'min_recommended_quantity': 20.9,
      'max_recommended_quantity': 23.1,
      'packaging_spec': 'Cartons of 1.44 sqm',
      'estimated_packages': 16,
      'requires_contractor_verification': true,
    };

    test('fromMap parses fields and formatted getters', () {
      final item = MaterialTakeoffItemModel.fromMap(sampleMap);
      expect(item.itemId, 'item_floor_001');
      expect(item.category, 'FLOORING');
      expect(item.categoryDisplayName, 'Flooring');
      expect(item.netQuantity, 20.0);
      expect(item.grossQuantity, 22.0);
      expect(item.formattedGrossQuantity, '22.0 sqm');
      expect(item.formattedRange, '20.9 – 23.1 sqm');
      expect(item.estimatedPackages, 16);
      expect(item.requiresContractorVerification, isTrue);
    });

    test('toMap serializes accurately', () {
      final item = MaterialTakeoffItemModel.fromMap(sampleMap);
      final map = item.toMap();
      expect(map['item_id'], 'item_floor_001');
      expect(map['gross_quantity'], 22.0);
      expect(map['waste_factor_pct'], 10.0);
    });
  });

  group('MaterialTakeoffReportModel', () {
    final sampleReportMap = {
      'report_id': 'takeoff_test_01',
      'room_id': 'room_123',
      'gross_floor_area_sqm': 20.0,
      'net_wall_area_sqm': 38.0,
      'ceiling_area_sqm': 20.0,
      'baseboard_perimeter_m': 17.1,
      'openings_deducted_area_sqm': 3.33,
      'default_waste_factors': {
        'FLOORING': 10.0,
        'WALL_PAINT': 10.0,
      },
      'overall_confidence': 0.95,
      'accuracy_tier': 'EXACT',
      'items': [
        {
          'item_id': 'itm_fl',
          'category': 'FLOORING',
          'name': 'Hardwood Flooring',
          'net_quantity': 20.0,
          'unit': 'sqm',
          'waste_factor_pct': 10.0,
          'waste_quantity': 2.0,
          'gross_quantity': 22.0,
          'min_recommended_quantity': 21.34,
          'max_recommended_quantity': 22.66,
          'packaging_spec': 'Cartons of 1.44 sqm',
          'estimated_packages': 16,
          'requires_contractor_verification': true,
        },
        {
          'item_id': 'itm_pt',
          'category': 'WALL_PAINT',
          'name': 'Wall Paint',
          'net_quantity': 7.6,
          'unit': 'liters',
          'waste_factor_pct': 10.0,
          'waste_quantity': 0.76,
          'gross_quantity': 8.36,
          'min_recommended_quantity': 8.1,
          'max_recommended_quantity': 8.6,
          'packaging_spec': '2.5L Cans',
          'estimated_packages': 4,
          'requires_contractor_verification': false,
        },
      ],
      'critical_dimensions': [
        {
          'dimension_id': 'dim_fl',
          'dimension_type': 'FLOOR_AREA',
          'label': 'Room Floor Area',
          'estimated_value': 20.0,
          'verified_value': null,
          'unit': 'sqm',
          'verification_status': 'UNVERIFIED',
        },
        {
          'dimension_id': 'dim_wall',
          'dimension_type': 'LONGEST_WALL',
          'label': 'Longest Wall',
          'estimated_value': 5.0,
          'verified_value': 5.02,
          'unit': 'm',
          'verification_status': 'CONTRACTOR_VERIFIED',
        },
      ],
      'notes': ['Calculated with EXACT precision'],
    };

    test('fromMap parses report with verified metrics', () {
      final report = MaterialTakeoffReportModel.fromMap(sampleReportMap);
      expect(report.reportId, 'takeoff_test_01');
      expect(report.grossFloorAreaSqm, 20.0);
      expect(report.netWallAreaSqm, 38.0);
      expect(report.accuracyTier, 'EXACT');
      expect(report.items.length, 2);
      expect(report.criticalDimensions.length, 2);
      expect(report.unverifiedDimensionsCount, 1);
      expect(report.verifiedDimensionsCount, 1);
      expect(report.allDimensionsVerified, isFalse);
    });

    test('allDimensionsVerified is true when all verified', () {
      final report = MaterialTakeoffReportModel(
        reportId: 'rep_verified',
        roomId: 'room_1',
        grossFloorAreaSqm: 20.0,
        netWallAreaSqm: 38.0,
        ceilingAreaSqm: 20.0,
        baseboardPerimeterM: 17.0,
        openingsDeductedAreaSqm: 3.0,
        criticalDimensions: [
          CriticalDimensionVerificationModel(
            dimensionId: 'dim_1',
            dimensionType: 'FLOOR_AREA',
            label: 'Floor',
            estimatedValue: 20.0,
            verifiedValue: 20.1,
            verificationStatus: 'CONTRACTOR_VERIFIED',
          ),
        ],
      );
      expect(report.allDimensionsVerified, isTrue);
      expect(report.unverifiedDimensionsCount, 0);
      expect(report.verifiedDimensionsCount, 1);
    });
  });

  group('MaterialTakeoffScreen Widget Tests', () {
    final testReport = MaterialTakeoffReportModel(
      reportId: 'rep_ui_test',
      roomId: 'room_ui_01',
      grossFloorAreaSqm: 22.5,
      netWallAreaSqm: 42.0,
      ceilingAreaSqm: 22.5,
      baseboardPerimeterM: 18.2,
      openingsDeductedAreaSqm: 3.3,
      accuracyTier: 'EXACT',
      defaultWasteFactors: {'FLOORING': 10.0},
      items: [
        MaterialTakeoffItemModel(
          itemId: 'item_ui_fl',
          category: 'FLOORING',
          name: 'Engineered Wood Flooring',
          netQuantity: 22.5,
          unit: 'sqm',
          wasteFactorPct: 10.0,
          wasteQuantity: 2.25,
          grossQuantity: 24.75,
          minRecommendedQuantity: 24.0,
          maxRecommendedQuantity: 25.5,
          packagingSpec: 'Cartons of 1.44 sqm',
          estimatedPackages: 18,
          requiresContractorVerification: true,
        ),
      ],
      criticalDimensions: [
        CriticalDimensionVerificationModel(
          dimensionId: 'dim_ui_fl',
          dimensionType: 'FLOOR_AREA',
          label: 'Floor Footprint Area',
          estimatedValue: 22.5,
          unit: 'sqm',
          verificationStatus: 'UNVERIFIED',
          warningNote: 'Check subfloor before buying timber planks',
        ),
      ],
      notes: ['AI spatial measurement with LiDAR native precision.'],
    );

    testWidgets('renders surface metrics and material items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MaterialTakeoffScreen(
            roomId: 'room_ui_01',
            roomName: 'Living Room',
            initialReport: testReport,
          ),
        ),
      );

      // Verify header and metrics
      expect(find.text('Living Room Material Takeoff'), findsOneWidget);
      expect(find.text('Surface Quantity Takeoff'), findsOneWidget);
      expect(find.text('42.0 m²'), findsOneWidget); // Net Wall Area
      expect(find.text('22.5 m²'), findsNWidgets(2)); // Floor & Ceiling Area

      // Verify Critical Dimensions section
      expect(find.text('On-Site Physical Confirmation'), findsOneWidget);
      expect(find.text('Floor Footprint Area'), findsOneWidget);
      expect(find.text('1 Unverified'), findsOneWidget);

      // Verify Material Item Card
      expect(find.text('Engineered Wood Flooring'), findsOneWidget);
      expect(find.text('24.8 sqm'), findsOneWidget);
      expect(find.text('📦 18x Cartons of 1.44 sqm'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('tapping confirm opens verification bottom sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MaterialTakeoffScreen(
            roomId: 'room_ui_01',
            roomName: 'Living Room',
            initialReport: testReport,
          ),
        ),
      );

      // Tap confirm button
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Verify sheet title and inputs
      expect(find.text('Verify Floor Footprint Area'), findsOneWidget);
      expect(find.text('Confirm & Recalculate Quantities'), findsOneWidget);
    });
  });
}
