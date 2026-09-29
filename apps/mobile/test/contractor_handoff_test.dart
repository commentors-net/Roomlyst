import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/contractor/presentation/contractor_handoff_screen.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  group('Milestone 6.2 — Contractor Handoff & BOQ Domain Models', () {
    test('TradeWorkPackageModel serializes and parses properly', () {
      final pkg = TradeWorkPackageModel(
        packageId: 'pkg_123',
        trade: 'CARPENTRY_JOINERY',
        title: 'Custom Joinery',
        description: 'Fabricate bespoke cabinetry',
        priority: 'HIGH',
        prerequisiteTrades: const ['MASONRY_TILING'],
        scopeItems: const ['Site measure', 'Install carcass', 'Fit doors'],
        safetyNotes: const ['Anchor to masonry walls'],
        estimatedDurationDays: 5,
      );

      final map = pkg.toMap();
      expect(map['trade'], 'CARPENTRY_JOINERY');
      expect(map['estimated_duration_days'], 5);

      final parsed = TradeWorkPackageModel.fromMap(map);
      expect(parsed.packageId, 'pkg_123');
      expect(parsed.scopeItems.length, 3);
      expect(parsed.prerequisiteTrades, contains('MASONRY_TILING'));
    });

    test('BillOfQuantitiesItemModel correctly computes waste margins and total costs', () {
      final boq = BillOfQuantitiesItemModel(
        itemId: 'boq_tile_01',
        trade: 'MASONRY_TILING',
        itemCode: 'TIL-01',
        description: '600x600 Rectified Porcelain Tiles',
        quantity: 20.0,
        unit: 'm2',
        wasteFactorPct: 10.0,
        totalQuantityWithWaste: 22.0,
        estimatedUnitRate: 135.0,
        estimatedMaterialTotal: 1870.0,
        estimatedLaborTotal: 1000.0,
        requiresSiteVerification: true,
      );

      expect(boq.totalEstimatedCost, 2870.0);
      expect(boq.totalQuantityWithWaste, greaterThan(boq.quantity));
      expect(boq.requiresSiteVerification, isTrue);

      final map = boq.toMap();
      final parsed = BillOfQuantitiesItemModel.fromMap(map);
      expect(parsed.itemCode, 'TIL-01');
      expect(parsed.totalEstimatedCost, 2870.0);
    });

    test('ContractorVerificationChecklistModel updates physical verification status cleanly', () {
      final chk = ContractorVerificationChecklistModel(
        checklistId: 'chk_span_01',
        dimensionLabel: 'Main Joinery Wall Span',
        dimensionType: 'Wall Span',
        dimensionValue: 4.80,
        unit: 'm',
        confidence: 0.78,
        source: 'ESTIMATED',
        isPhysicallyVerified: false,
        criticalForTrade: 'CARPENTRY_JOINERY',
      );

      expect(chk.isPhysicallyVerified, isFalse);

      final now = DateTime.now();
      final verified = chk.copyWith(
        isPhysicallyVerified: true,
        verifiedByName: 'Senior Joiner Wong',
        verifiedAt: now,
        notes: 'Laser verified at 4.81m',
      );

      expect(verified.isPhysicallyVerified, isTrue);
      expect(verified.verifiedByName, 'Senior Joiner Wong');
      expect(verified.verifiedAt, now);
      expect(verified.notes, 'Laser verified at 4.81m');
    });

    test('ContractorBidModel parses correctly and checks tender award status', () {
      final bid = ContractorBidModel(
        bidId: 'bid_apex_88',
        rfqId: 'rfq_tender_01',
        contractorId: 'c_apex',
        contractorName: 'Apex Builders Sdn Bhd',
        licenseNo: 'CIDB-G5-2024',
        contactEmail: 'tenders@apexbuilders.my',
        overallBidAmount: 14200.0,
        currency: 'MYR',
        estimatedLeadTimeDays: 12,
        validityDays: 30,
        status: 'SUBMITTED',
        statutoryComplianceAcknowledged: true,
        onSiteVerificationAcknowledged: true,
        submittedAt: DateTime.now(),
      );

      expect(bid.formattedBidAmount, contains('14200.00'));
      expect(bid.isAccepted, isFalse);

      final acceptedBid = ContractorBidModel.fromMap({
        ...bid.toMap(),
        'status': 'ACCEPTED',
      });
      expect(acceptedBid.isAccepted, isTrue);
    });

    test('ContractorProjectBriefModel parses and aggregates costs', () {
      final brief = ContractorProjectBriefModel(
        briefId: 'cbrief_test',
        projectId: 'proj_test',
        title: 'Contractor Tender Package',
        totalEstimatedMaterials: 7500.0,
        totalEstimatedLabor: 4500.0,
        totalEstimatedCost: 12000.0,
        confirmedMeasurementsCount: 3,
        unconfirmedMeasurementsCount: 1,
        currency: 'MYR',
        statutoryDisclaimer: 'Statutory verification notice',
        createdAt: DateTime.now(),
      );

      expect(brief.formattedTotalCost, contains('12000.00'));
      expect(brief.formattedMaterialCost, contains('7500.00'));
      expect(brief.formattedLaborCost, contains('4500.00'));
      expect(brief.unconfirmedMeasurementsCount, 1);
    });
  });

  group('Milestone 6.2 — ContractorHandoffScreen Widget Tests', () {
    testWidgets('ContractorHandoffScreen renders AppBar tabs properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ContractorHandoffScreen(
            projectId: 'proj_mock_01',
            projectName: 'Residence 88',
          ),
        ),
      );

      // Verify AppBar and Tab titles
      expect(find.text('Contractor Handoff & Tender'), findsOneWidget);
      expect(find.text('Scope & Packages'), findsOneWidget);
      expect(find.text('BOQ Takeoff'), findsOneWidget);
      expect(find.text('Verification Checklist'), findsOneWidget);
      expect(find.text('Tender & RFQs'), findsOneWidget);
    });
  });
}
