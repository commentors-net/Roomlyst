import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/workspace/presentation/project_export_dossier_screen.dart';

void main() {
  group('Milestone 5.3 Professional Output & Studio Branding Models', () {
    test('StudioBrandingModel parses, mutates and serializes correctly', () {
      final map = {
        'firm_name': 'Atelier Peranakan & Partners',
        'tagline': 'Bespoke Architectural Interiors',
        'logo_url': 'https://assets.atelier.my/logo.png',
        'contact_email': 'contact@atelier.my',
        'contact_phone': '+60 3 2181 8888',
        'website': 'https://atelier.my',
        'license_number': 'PAM-AR-2026-9901',
        'primary_color_hex': '#0F172A',
        'secondary_color_hex': '#0D9488',
        'custom_disclaimer': 'All dimensions require on-site trade verification prior to fabrication.',
      };

      final branding = StudioBrandingModel.fromMap(map);
      expect(branding.firmName, 'Atelier Peranakan & Partners');
      expect(branding.tagline, 'Bespoke Architectural Interiors');
      expect(branding.logoUrl, 'https://assets.atelier.my/logo.png');
      expect(branding.licenseNumber, 'PAM-AR-2026-9901');
      expect(branding.primaryColorHex, '#0F172A');
      expect(branding.secondaryColorHex, '#0D9488');
      expect(branding.customDisclaimer, contains('on-site trade verification'));

      final updated = branding.copyWith(
        firmName: 'Atelier Peranakan International',
        primaryColorHex: '#2563EB',
      );
      expect(updated.firmName, 'Atelier Peranakan International');
      expect(updated.primaryColorHex, '#2563EB');
      expect(updated.licenseNumber, 'PAM-AR-2026-9901');

      final serialized = updated.toMap();
      expect(serialized['firm_name'], 'Atelier Peranakan International');
      expect(serialized['primary_color_hex'], '#2563EB');
    });

    test('MeasurementScheduleItemModel correctly identifies verification requirement', () {
      final unverifiedItem = MeasurementScheduleItemModel.fromMap({
        'room_id': 'room_01',
        'room_name': 'Living Room',
        'entity_label': 'Opening',
        'dimension_type': 'Clearance Height',
        'value': 2.45,
        'unit': 'm',
        'confidence': 0.78,
        'source': 'MONOCULAR_DEPTH',
        'verified_by_user': false,
        'requires_site_verification': true,
      });

      expect(unverifiedItem.requiresSiteVerification, isTrue);
      expect(unverifiedItem.verifiedByUser, isFalse);
      expect(unverifiedItem.confidence, 0.78);
      expect(unverifiedItem.dimensionType, 'Clearance Height');

      final verifiedItem = MeasurementScheduleItemModel.fromMap({
        'room_id': 'room_01',
        'room_name': 'Living Room',
        'entity_label': 'Wall Segment',
        'dimension_type': 'Length',
        'value': 6.20,
        'unit': 'm',
        'confidence': 0.99,
        'source': 'USER_CONFIRMED',
        'verified_by_user': true,
        'requires_site_verification': false,
      });

      expect(verifiedItem.requiresSiteVerification, isFalse);
      expect(verifiedItem.verifiedByUser, isTrue);
      expect(verifiedItem.value, 6.20);
    });

    test('AssumptionScheduleItemModel parses categories and risk levels correctly', () {
      final assumption = AssumptionScheduleItemModel.fromMap({
        'category': 'STRUCTURAL',
        'scope': 'Internal Demolition',
        'assumption_description': 'Internal partition wall is non-load-bearing.',
        'risk_level': 'HIGH',
        'recommendation': 'Engage licensed structural PE before removal.',
      });

      expect(assumption.category, 'STRUCTURAL');
      expect(assumption.scope, 'Internal Demolition');
      expect(assumption.riskLevel, 'HIGH');
      expect(assumption.recommendation, contains('structural PE'));

      final outMap = assumption.toMap();
      expect(outMap['category'], 'STRUCTURAL');
      expect(outMap['risk_level'], 'HIGH');
    });

    test('RoomSheetSummaryModel parses correctly', () {
      final sheet = RoomSheetSummaryModel.fromMap({
        'room_id': 'room_penthouse_01',
        'room_name': 'Grand Salon',
        'room_type': 'living_room',
        'floor_area_sqm': 48.5,
        'ceiling_height_m': 3.1,
        'selected_variant_id': 'var_01',
        'selected_variant_title': 'Warm Japandi',
        'selected_variant_style': 'Japandi',
        'estimated_budget': 65000.0,
        'material_takeoff_item_count': 12,
        'curated_product_count': 8,
        'approval_status': 'APPROVED',
        'execution_sequence_steps': [
          '1. Strip out',
          '2. MEP rough-in',
          '3. Finishes',
        ],
      });

      expect(sheet.roomName, 'Grand Salon');
      expect(sheet.floorAreaSqm, 48.5);
      expect(sheet.ceilingHeightM, 3.1);
      expect(sheet.estimatedBudget, 65000.0);
      expect(sheet.materialTakeoffItemCount, 12);
      expect(sheet.curatedProductCount, 8);
      expect(sheet.approvalStatus, 'APPROVED');
      expect(sheet.executionSequenceSteps.length, 3);
    });

    test('ProfessionalExportDossierModel aggregates multi-room project metrics', () {
      final dossier = ProfessionalExportDossierModel.fromMap({
        'dossier_id': 'dos_123',
        'project_id': 'proj_loft_01',
        'project_name': 'Bespoke Loft Handover',
        'status': 'CONCEPT_DESIGN',
        'client_name': 'Datin Grace Wong',
        'total_rooms': 2,
        'total_floor_area_sqm': 85.0,
        'total_estimated_budget': 120000.0,
        'currency': 'MYR',
        'branding': {
          'firm_name': 'Kuala Lumpur Design Practice',
          'license_number': 'PAM-2026-001',
        },
        'room_sheets': [
          {'room_id': 'r1', 'room_name': 'Salon', 'floor_area_sqm': 50.0},
          {'room_id': 'r2', 'room_name': 'Master Suite', 'floor_area_sqm': 35.0},
        ],
        'measurement_schedules': [
          {
            'room_id': 'r1',
            'room_name': 'Salon',
            'entity_label': 'Room',
            'dimension_type': 'Length',
            'value': 7.0,
            'confidence': 0.98,
            'source': 'LIDAR',
            'verified_by_user': true,
            'requires_site_verification': false,
          }
        ],
        'assumption_schedules': [
          {
            'category': 'WATERPROOFING',
            'scope': 'Wet area',
            'assumption_description': '2-coat PU membrane',
            'risk_level': 'HIGH',
            'recommendation': '24-hour ponding test',
          }
        ],
        'printable_html': '<html><body><h1>Bespoke Loft Handover</h1></body></html>',
      });

      expect(dossier.dossierId, 'dos_123');
      expect(dossier.projectName, 'Bespoke Loft Handover');
      expect(dossier.totalRooms, 2);
      expect(dossier.totalFloorAreaSqm, 85.0);
      expect(dossier.totalEstimatedBudget, 120000.0);
      expect(dossier.branding.firmName, 'Kuala Lumpur Design Practice');
      expect(dossier.roomSheets.length, 2);
      expect(dossier.measurementSchedules.length, 1);
      expect(dossier.assumptionSchedules.length, 1);
      expect(dossier.printableHtml, contains('Bespoke Loft Handover'));

      final outMap = dossier.toMap();
      expect(outMap['project_name'], 'Bespoke Loft Handover');
      expect(outMap['total_floor_area_sqm'], 85.0);
    });
  });

  group('Milestone 5.3 ProjectExportDossierScreen Widget Tests', () {
    testWidgets('renders ProjectExportDossierScreen with TabBar and basic scaffold', (tester) async {
      final mockDossier = ProfessionalExportDossierModel(
        dossierId: 'dos_test_01',
        projectId: 'proj_demo_01',
        projectName: 'Penthouse Renovation',
        status: 'CONCEPT_DESIGN',
        generatedAt: DateTime.now(),
        totalRooms: 1,
        totalFloorAreaSqm: 42.5,
        totalEstimatedBudget: 55000.0,
        currency: 'MYR',
        branding: const StudioBrandingModel(
          firmName: 'Aethelgard Studio',
          tagline: 'Modern Elegance',
          licenseNumber: 'PAM-2026-088',
        ),
        roomSheets: const [
          RoomSheetSummaryModel(
            roomId: 'r1',
            roomName: 'Living Room',
            floorAreaSqm: 42.5,
            estimatedBudget: 55000.0,
          ),
        ],
        measurementSchedules: const [
          MeasurementScheduleItemModel(
            roomId: 'r1',
            roomName: 'Living Room',
            entityLabel: 'Wall',
            dimensionType: 'Length',
            value: 6.5,
          ),
        ],
        assumptionSchedules: const [
          AssumptionScheduleItemModel(
            category: 'STRUCTURAL',
            scope: 'Drywall',
            assumptionDescription: 'Non-load bearing',
            recommendation: 'Site check',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectExportDossierScreen(
            projectId: 'proj_demo_01',
            projectName: 'Penthouse Renovation',
            initialDossier: mockDossier,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Penthouse Renovation Dossier'), findsOneWidget);

      // Verify Tab items are rendered
      expect(find.text('Executive Cover'), findsOneWidget);
      expect(find.text('Measurements'), findsOneWidget);
      expect(find.text('Assumptions'), findsOneWidget);
      expect(find.text('Contractor Handover'), findsOneWidget);

      // Verify studio branding banner
      expect(find.text('Aethelgard Studio'), findsOneWidget);
      expect(find.text('Modern Elegance'), findsOneWidget);
      expect(find.text('Edit Branding'), findsOneWidget);

      // Verify KPI metrics
      expect(find.text('42.5 m²'), findsWidgets);
      expect(find.text('MYR 55000'), findsWidgets);
    });
  });
}
