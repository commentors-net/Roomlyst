import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/orchestration/presentation/ecosystem_orchestration_screen.dart';

void main() {
  group('Milestone 6.4 — Ecosystem Workflow Orchestration Domain Models', () {
    test('EcosystemRole enum maps codes and labels accurately', () {
      expect(EcosystemRole.homeowner.code, 'HOMEOWNER');
      expect(EcosystemRole.interiorDesigner.code, 'INTERIOR_DESIGNER');
      expect(EcosystemRole.contractor.code, 'CONTRACTOR');
      expect(EcosystemRole.merchantSeller.code, 'MERCHANT_SELLER');
      expect(EcosystemRole.propertyAgent.code, 'PROPERTY_AGENT');
      expect(EcosystemRole.studioAdmin.code, 'STUDIO_ADMIN');

      expect(EcosystemRole.fromCode('INTERIOR_DESIGNER'), EcosystemRole.interiorDesigner);
      expect(EcosystemRole.fromCode('CONTRACTOR'), EcosystemRole.contractor);
      expect(EcosystemRole.fromCode('UNKNOWN'), EcosystemRole.homeowner);
    });

    test('HandoffTransitionType and HandoffStatus map properly', () {
      expect(HandoffTransitionType.homeownerToDesigner.code, 'HOMEOWNER_TO_DESIGNER');
      expect(HandoffTransitionType.designerToContractor.code, 'DESIGNER_TO_CONTRACTOR');
      expect(HandoffTransitionType.designerToMerchant.code, 'DESIGNER_TO_MERCHANT');
      expect(HandoffTransitionType.designerToAgent.code, 'DESIGNER_TO_AGENT');

      expect(HandoffStatus.pendingAcceptance.code, 'PENDING_ACCEPTANCE');
      expect(HandoffStatus.active.code, 'ACTIVE');
      expect(HandoffStatus.completed.code, 'COMPLETED');
      expect(HandoffStatus.revoked.code, 'REVOKED');
    });

    test('EcosystemHandoffRecordModel serializes and deserializes properly', () {
      final handoff = EcosystemHandoffRecordModel(
        handoffId: 'hnd_test_01',
        projectId: 'proj_test_01',
        transitionType: HandoffTransitionType.designerToContractor,
        sourceActorId: 'des_elena',
        sourceRole: EcosystemRole.interiorDesigner,
        targetActorId: 'ctr_apex',
        targetRole: EcosystemRole.contractor,
        targetActorName: 'Apex Construction',
        status: HandoffStatus.pendingAcceptance,
        permittedScopes: ['view_tender_brief', 'view_boq', 'submit_bids'],
        transferredArtifactIds: ['brief_01'],
        notes: 'Please review and submit quotation.',
      );

      final map = handoff.toMap();
      expect(map['handoff_id'], 'hnd_test_01');
      expect(map['transition_type'], 'DESIGNER_TO_CONTRACTOR');
      expect(map['status'], 'PENDING_ACCEPTANCE');

      final parsed = EcosystemHandoffRecordModel.fromMap(map);
      expect(parsed.handoffId, 'hnd_test_01');
      expect(parsed.targetRole, EcosystemRole.contractor);
      expect(parsed.permittedScopes.length, 3);
      expect(parsed.notes, contains('submit quotation'));
    });

    test('EcosystemAuditEventModel captures audit actions and sensitivity', () {
      final audit = EcosystemAuditEventModel(
        eventId: 'aud_test_01',
        projectId: 'proj_test_01',
        actorId: 'des_elena',
        actorName: 'Elena Vance',
        actorRole: EcosystemRole.interiorDesigner,
        action: 'REVOKE_HANDOFF',
        resourceType: 'handoff',
        resourceId: 'hnd_test_01',
        isSensitive: true,
        metadata: {'reason': 'Scope update'},
      );

      final map = audit.toMap();
      expect(map['action'], 'REVOKE_HANDOFF');
      expect(map['is_sensitive'], isTrue);

      final parsed = EcosystemAuditEventModel.fromMap(map);
      expect(parsed.eventId, 'aud_test_01');
      expect(parsed.actorRole, EcosystemRole.interiorDesigner);
      expect(parsed.isSensitive, isTrue);
    });

    test('WorkflowOrchestrationSummaryModel aggregates 5-phase statuses and participants', () {
      final summary = WorkflowOrchestrationSummaryModel(
        projectId: 'proj_test_01',
        projectName: 'Skyline Penthouse',
        homeownerPhaseStatus: 'COMPLETED',
        designerPhaseStatus: 'COMPLETED',
        commercePhaseStatus: 'ACTIVE',
        contractorPhaseStatus: 'IN_PROGRESS',
        propertyStagingPhaseStatus: 'ACTIVE',
        totalActiveHandoffs: 3,
        totalParticipants: 5,
      );

      final map = summary.toMap();
      expect(map['homeowner_phase_status'], 'COMPLETED');
      expect(map['total_participants'], 5);

      final parsed = WorkflowOrchestrationSummaryModel.fromMap(map);
      expect(parsed.projectName, 'Skyline Penthouse');
      expect(parsed.contractorPhaseStatus, 'IN_PROGRESS');
      expect(parsed.totalActiveHandoffs, 3);
    });

    test('RoleScopedProjectViewModel tracks accessible and redacted fields for RBAC', () {
      final roleView = RoleScopedProjectViewModel(
        projectId: 'proj_test_01',
        role: EcosystemRole.contractor,
        projectName: 'Skyline Penthouse',
        accessibleSections: ['trade_work_packages', 'boq_with_wastage'],
        redactedFields: ['homeowner_billing_rate', 'designer_markups'],
        dataPayload: {'is_full_access': false},
      );

      final map = roleView.toMap();
      expect(map['role'], 'CONTRACTOR');
      expect(map['redacted_fields'], contains('designer_markups'));

      final parsed = RoleScopedProjectViewModel.fromMap(map);
      expect(parsed.role, EcosystemRole.contractor);
      expect(parsed.accessibleSections.length, 2);
      expect(parsed.redactedFields.length, 2);
    });
  });

  group('Milestone 6.4 — EcosystemOrchestrationScreen Widget Tests', () {
    testWidgets('EcosystemOrchestrationScreen renders 5-phase lifecycle and overview metrics', (tester) async {
      final sampleSummary = WorkflowOrchestrationSummaryModel(
        projectId: 'proj_widget_01',
        projectName: 'The Pavilion Suites',
        homeownerPhaseStatus: 'COMPLETED',
        designerPhaseStatus: 'ACTIVE',
        commercePhaseStatus: 'ACTIVE',
        contractorPhaseStatus: 'IN_PROGRESS',
        propertyStagingPhaseStatus: 'ACTIVE',
        totalActiveHandoffs: 2,
        totalParticipants: 4,
        handoffs: [
          EcosystemHandoffRecordModel(
            handoffId: 'hnd_01',
            projectId: 'proj_widget_01',
            transitionType: HandoffTransitionType.designerToContractor,
            sourceActorId: 'des_01',
            sourceRole: EcosystemRole.interiorDesigner,
            targetActorId: 'ctr_01',
            targetRole: EcosystemRole.contractor,
            targetActorName: 'Apex Construction',
            status: HandoffStatus.active,
            permittedScopes: ['view_boq', 'submit_bids'],
          ),
        ],
        recentAuditEvents: [
          EcosystemAuditEventModel(
            eventId: 'aud_01',
            projectId: 'proj_widget_01',
            actorId: 'des_01',
            actorName: 'Elena Vance',
            actorRole: EcosystemRole.interiorDesigner,
            action: 'INITIATE_HANDOFF',
            resourceType: 'handoff',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EcosystemOrchestrationScreen(
            projectId: 'proj_widget_01',
            projectName: 'The Pavilion Suites',
            initialSummary: sampleSummary,
          ),
        ),
      );

      await tester.pump();

      // Check AppBar and TabBar
      expect(find.text('Ecosystem Orchestrator'), findsOneWidget);
      expect(find.text('5-Phase Lifecycle'), findsOneWidget);
      expect(find.text('Role Permissions'), findsOneWidget);
      expect(find.text('Audit History'), findsOneWidget);

      // Check Overview Header
      expect(find.text('The Pavilion Suites'), findsWidgets);
      expect(find.text('PHASE 6 GOVERNED'), findsOneWidget);
      expect(find.text('Participants'), findsOneWidget);
      expect(find.text('Active Handoffs'), findsWidgets);

      // Check 5-Phase Stepper Cards
      expect(find.text('Homeowner Capture & Brief'), findsOneWidget);
      expect(find.text('Interior Designer Workspace'), findsOneWidget);
      expect(find.text('Merchant Commerce & Fit'), findsOneWidget);
      expect(find.text('Contractor Handoff & Tenders'), findsOneWidget);
      expect(find.text('Property Marketing & Staging'), findsOneWidget);

      // Check Handoff Card
      expect(find.text('Designer → Contractor'), findsOneWidget);
      expect(find.textContaining('Apex Construction'), findsWidgets);

      // Check Action Button
      expect(find.text('New Handoff'), findsOneWidget);
    });
  });
}
