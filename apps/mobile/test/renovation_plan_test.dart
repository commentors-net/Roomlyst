import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/renovation/presentation/renovation_plan_screen.dart';

void main() {
  group('Milestone 4.4 Renovation Plan Domain Models', () {
    test('ExecutionPhaseModel parses from map correctly', () {
      final map = {
        'phase_number': 3,
        'title': 'Plumbing & Electrical Rough-Ins',
        'description': 'Route power circuits and plumbing lines.',
        'trades_involved': ['Electrician', 'Plumber'],
        'estimated_days': 4,
        'is_safety_critical': true,
        'regulatory_notice': 'Requires licensed authority testing prior to wall closure.',
      };

      final phase = ExecutionPhaseModel.fromMap(map);
      expect(phase.phaseNumber, 3);
      expect(phase.title, 'Plumbing & Electrical Rough-Ins');
      expect(phase.description, 'Route power circuits and plumbing lines.');
      expect(phase.tradesInvolved, ['Electrician', 'Plumber']);
      expect(phase.estimatedDays, 4);
      expect(phase.isSafetyCritical, isTrue);
      expect(phase.regulatoryNotice, contains('licensed authority'));

      final outMap = phase.toMap();
      expect(outMap['phase_number'], 3);
      expect(outMap['is_safety_critical'], isTrue);
    });

    test('PlanMeasurementItemModel distinguishes confirmed from estimated values', () {
      final confirmedMap = {
        'label': 'Main Wall Length',
        'value': 5.25,
        'unit': 'm',
        'source': 'LIDAR_NATIVE',
        'confidence': 0.98,
        'is_confirmed': true,
        'requires_manual_verification': false,
      };

      final confirmedItem = PlanMeasurementItemModel.fromMap(confirmedMap);
      expect(confirmedItem.label, 'Main Wall Length');
      expect(confirmedItem.value, 5.25);
      expect(confirmedItem.isConfirmed, isTrue);
      expect(confirmedItem.requiresManualVerification, isFalse);
      expect(confirmedItem.displayString, '5.25 m');

      final approxMap = {
        'label': 'Window Height',
        'value': 1.85,
        'unit': 'm',
        'source': 'MONOCULAR_DEPTH',
        'confidence': 0.72,
        'is_confirmed': false,
        'requires_manual_verification': true,
      };

      final approxItem = PlanMeasurementItemModel.fromMap(approxMap);
      expect(approxItem.label, 'Window Height');
      expect(approxItem.isConfirmed, isFalse);
      expect(approxItem.requiresManualVerification, isTrue);
      expect(approxItem.displayString, '1.85 m');
    });

    test('RenovationPlanVersionModel parses complete structured 13-section brief', () {
      final planMap = {
        'plan_id': 'plan_test_001',
        'version': 'v1',
        'created_at': '2026-09-28T14:30:00Z',
        'project_summary': {
          'budget_currency': 'MYR',
        },
        'selected_design': {
          'variant_id': 'var_japandi_01',
          'title': 'Japandi Serenity Living',
          'style': 'Japandi',
        },
        'budget_estimate': {
          'grand_total': 22500.0,
          'currency': 'MYR',
          'contingency_amount': 2250.0,
          'contingency_pct': 10.0,
          'subtotal_materials': 12000.0,
          'subtotal_labor': 8250.0,
          'tax_amount': 0.0,
          'tax_name': 'SST',
        },
        'measurement_confidence': {
          'overall_confidence': 0.92,
          'confirmed_measurements_count': 4,
          'unverified_measurements_count': 1,
          'measurements': [
            {
              'label': 'Room Width',
              'value': 4.0,
              'unit': 'm',
              'source': 'LIDAR_NATIVE',
              'confidence': 0.98,
              'is_confirmed': true,
              'requires_manual_verification': false,
            },
            {
              'label': 'Window Height',
              'value': 1.5,
              'unit': 'm',
              'source': 'MONOCULAR_DEPTH',
              'confidence': 0.75,
              'is_confirmed': false,
              'requires_manual_verification': true,
            },
          ],
        },
        'suggested_execution_sequence': [
          {
            'phase_number': 1,
            'title': 'Site Protection & Pre-Demolition',
            'description': 'Protect existing flooring and access corridors.',
            'trades_involved': ['General Labor'],
            'estimated_days': 1,
            'is_safety_critical': false,
          },
          {
            'phase_number': 3,
            'title': 'MEP Rough-in',
            'description': 'Concealed wiring and piping.',
            'trades_involved': ['Electrician'],
            'estimated_days': 3,
            'is_safety_critical': true,
            'regulatory_notice': 'Certified electrician required.',
          },
        ],
        'scope_of_work': [
          'Strip out existing damaged floor finish.',
          'Install engineered oak planks.',
          'Retain and protect structural doorway.',
        ],
        'existing_items_to_retain': [
          {
            'id': 'opn_door',
            'label': 'Main Entry Door',
            'action': 'KEEP',
            'rationale': 'Structural preservation',
          }
        ],
        'items_to_remove': [
          {
            'id': 'obj_carpet',
            'label': 'Old Wool Rug',
            'action': 'REMOVE',
            'rationale': 'Decommission',
          }
        ],
        'items_to_replace': [
          {
            'id': 'obj_sofa',
            'label': 'Living Room Sofa',
            'action': 'REPLACE',
            'rationale': 'Upgrade to low-profile seating',
          }
        ],
        'materials_and_quantities': {
          'accuracy_tier': 'EXACT',
          'items': [
            {
              'material_name': 'Engineered Oak Flooring',
              'category': 'FLOORING',
              'net_quantity': 20.0,
              'recommended_order_quantity': 22.0,
              'unit': 'sqm',
              'waste_factor_pct': 10.0,
              'package_spec': '2.2 sqm / box',
              'packages_needed': 10,
            }
          ],
        },
        'recommended_products': [
          {
            'id': 'prod_sofa_1',
            'name': 'Muji Low Bench Sofa',
            'brand': 'Muji',
            'category': 'SOFA',
            'price': 3499.0,
            'currency': 'MYR',
          }
        ],
        'assumptions': [
          'Subfloor is structurally sound and moisture-free.',
        ],
        'warnings_and_required_verifications': [
          'Window Height requires physical tape measure confirmation.',
        ],
        'export_markdown': '# Renovation Handover Brief v1\n\nRoomlyst Generated Plan.',
      };

      final plan = RenovationPlanVersionModel.fromMap(planMap);

      expect(plan.planId, 'plan_test_001');
      expect(plan.version, 'v1');
      expect(plan.selectedVariantTitle, 'Japandi Serenity Living');
      expect(plan.style, 'Japandi');
      expect(plan.currency, 'MYR');
      expect(plan.grandTotal, 22500.0);
      expect(plan.formattedGrandTotal, 'RM 22500');
      expect(plan.contingencyAmount, 2250.0);
      expect(plan.subtotalMaterials, 12000.0);
      expect(plan.subtotalLabor, 8250.0);
      expect(plan.confirmedCount, 4);
      expect(plan.unverifiedCount, 1);
      expect(plan.measurements.length, 2);
      expect(plan.measurements.first.isConfirmed, isTrue);
      expect(plan.measurements.last.requiresManualVerification, isTrue);
      expect(plan.executionPhases.length, 2);
      expect(plan.executionPhases.last.isSafetyCritical, isTrue);
      expect(plan.scopeOfWork.length, 3);
      expect(plan.itemsToRetain.length, 1);
      expect(plan.itemsToRemove.length, 1);
      expect(plan.itemsToReplace.length, 1);
      expect(plan.recommendedProducts.length, 1);
      expect(plan.assumptions.length, 1);
      expect(plan.warnings.length, 1);
      expect(plan.exportMarkdown, contains('# Renovation Handover Brief v1'));
    });
  });

  group('Milestone 4.4 RenovationPlanScreen Widget Tests', () {
    late RenovationPlanVersionModel mockPlan;

    setUp(() {
      mockPlan = RenovationPlanVersionModel(
        planId: 'plan_test_100',
        version: 'v1',
        createdAt: DateTime(2026, 9, 28, 14, 30),
        selectedVariantTitle: 'Warm Scandinavian Haven',
        style: 'Scandinavian',
        currency: 'MYR',
        grandTotal: 18500.0,
        subtotalMaterials: 10500.0,
        subtotalLabor: 6500.0,
        contingencyAmount: 1500.0,
        contingencyPct: 10.0,
        overallConfidence: 0.94,
        confirmedCount: 3,
        unverifiedCount: 1,
        scopeOfWork: [
          'Demolish damaged skirting boards.',
          'Install waterproof SPC vinyl planks.',
          'Paint north wall in textured sage green.',
        ],
        itemsToRetain: [
          {'label': 'Floor-to-Ceiling Casement Window', 'action': 'KEEP', 'rationale': 'Original fenestration'}
        ],
        itemsToRemove: [
          {'label': 'Damaged Laminate Flooring', 'action': 'REMOVE', 'rationale': 'Moisture damaged'}
        ],
        itemsToReplace: [
          {'label': 'Fabric Two-Seater Sofa', 'action': 'REPLACE', 'rationale': 'Worn fabric'}
        ],
        measurements: [
          PlanMeasurementItemModel(
            label: 'Room Length',
            value: 5.0,
            unit: 'm',
            source: 'LIDAR_NATIVE',
            confidence: 0.98,
            isConfirmed: true,
            requiresManualVerification: false,
          ),
          PlanMeasurementItemModel(
            label: 'Doorway Clearance',
            value: 0.85,
            unit: 'm',
            source: 'MONOCULAR_DEPTH',
            confidence: 0.74,
            isConfirmed: false,
            requiresManualVerification: true,
          ),
        ],
        executionPhases: [
          ExecutionPhaseModel(
            phaseNumber: 1,
            title: 'Site Preparation & Protection',
            description: 'Lay poly-sheeting across circulation corridors.',
            tradesInvolved: ['General Labor'],
            estimatedDays: 1,
            isSafetyCritical: false,
          ),
          ExecutionPhaseModel(
            phaseNumber: 3,
            title: 'Electrical & Plumbing Rough-in',
            description: 'Relocate power outlets for TV console.',
            tradesInvolved: ['Licensed Electrician'],
            estimatedDays: 2,
            isSafetyCritical: true,
            regulatoryNotice: 'Mandatory licensed electrician sign-off.',
          ),
        ],
        materialTakeoffSummary: {
          'items': [
            {
              'material_name': 'Waterproof SPC Vinyl Planks',
              'category': 'FLOORING',
              'recommended_order_quantity': 25.0,
              'unit': 'sqm',
              'waste_factor_pct': 10.0,
              'package_spec': '2.5 sqm / box',
              'packages_needed': 10,
            }
          ]
        },
        recommendedProducts: [
          {
            'name': 'Castlery Gable 3-Seater Sofa',
            'brand': 'Castlery',
            'category': 'SOFA',
            'price': 2899.0,
            'currency': 'MYR',
          }
        ],
        assumptions: [
          'Continuous 240V power and water available on site during renovation.'
        ],
        warnings: [
          'Doorway Clearance (0.85m) requires physical tape measure confirmation.'
        ],
        exportMarkdown: '# Contractor Renovation Brief v1\n\nRoomlyst Export Markdown.',
      );
    });

    testWidgets('RenovationPlanScreen renders version header and Tab 1 overview correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenovationPlanScreen(
            roomId: 'room_123',
            initialPlan: mockPlan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check App Bar
      expect(find.text('Renovation Plan & Brief'), findsOneWidget);

      // Check Version Selector and confirmed count
      expect(find.text('Plan Version:'), findsOneWidget);
      expect(find.text('3 Confirmed'), findsOneWidget);

      // Check Section 1 Design Summary
      expect(find.text('Warm Scandinavian Haven'), findsOneWidget);
      expect(find.text('Budget: RM 18500'), findsOneWidget);

      // Check Scope lines
      expect(find.text('Demolish damaged skirting boards.'), findsOneWidget);
      expect(find.text('Install waterproof SPC vinyl planks.'), findsOneWidget);

      // Check inventory retain/remove/replace
      expect(find.text('Floor-to-Ceiling Casement Window'), findsOneWidget);
      expect(find.text('Damaged Laminate Flooring'), findsOneWidget);
      expect(find.text('Fabric Two-Seater Sofa'), findsOneWidget);
    });

    testWidgets('RenovationPlanScreen switches to Takeoff & Cost tab correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenovationPlanScreen(
            roomId: 'room_123',
            initialPlan: mockPlan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Takeoff & Cost Tab
      await tester.tap(find.text('Takeoff & Cost'));
      await tester.pumpAndSettle();

      // Check Budget card
      expect(find.text('Budget Estimate & Splits'), findsOneWidget);
      expect(find.text('RM 18500'), findsOneWidget);
      expect(find.text('MYR 10500'), findsOneWidget); // Materials Subtotal
      expect(find.text('MYR 6500'), findsOneWidget);  // Labor Subtotal

      // Check Takeoff material
      expect(find.text('Waterproof SPC Vinyl Planks'), findsOneWidget);
      expect(find.text('25.0 sqm'), findsOneWidget);

      // Check recommended product
      expect(find.text('Castlery Gable 3-Seater Sofa'), findsOneWidget);
      expect(find.text('MYR 2899.0'), findsOneWidget);
    });

    testWidgets('RenovationPlanScreen switches to Sequence & Safety tab and displays statutory disclaimer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenovationPlanScreen(
            roomId: 'room_123',
            initialPlan: mockPlan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sequence & Safety Tab
      await tester.tap(find.text('Sequence & Safety'));
      await tester.pumpAndSettle();

      // Check statutory disclaimer card
      expect(find.text('Statutory Renovation Disclaimer'), findsOneWidget);
      expect(find.textContaining('professional structural, electrical, or plumbing'), findsOneWidget);

      // Check measurement confirmation badges
      expect(find.text('Room Length'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('Doorway Clearance'), findsOneWidget);
      expect(find.text('CHECK NEEDED'), findsOneWidget);

      // Check execution phases
      expect(find.text('Site Preparation & Protection'), findsOneWidget);
      expect(find.text('Electrical & Plumbing Rough-in'), findsOneWidget);
      expect(find.text('SAFETY CRITICAL'), findsOneWidget);
      expect(find.textContaining('Mandatory licensed electrician sign-off'), findsOneWidget);
    });

    testWidgets('RenovationPlanScreen opens export brief modal when export button tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenovationPlanScreen(
            roomId: 'room_123',
            initialPlan: mockPlan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Export Brief button
      await tester.tap(find.text('Export Brief'));
      await tester.pumpAndSettle();

      // Check Modal Title and content
      expect(find.text('Contractor Handover Brief'), findsOneWidget);
      expect(find.textContaining('Ready for Print/PDF'), findsOneWidget);
      expect(find.textContaining('# Contractor Renovation Brief v1'), findsOneWidget);
      expect(find.text('Copy Contractor Brief (Markdown)'), findsOneWidget);
    });
  });
}
