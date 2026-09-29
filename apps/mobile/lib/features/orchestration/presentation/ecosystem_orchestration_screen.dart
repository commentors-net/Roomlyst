import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

/// Cross-Segment Ecosystem Workflow Orchestration & Governance Screen.
/// Fulfills Milestone 6.4, Blueprint Section 41 & Phase 6 Exit Gate.
class EcosystemOrchestrationScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final WorkflowOrchestrationSummaryModel? initialSummary;

  const EcosystemOrchestrationScreen({
    super.key,
    required this.projectId,
    this.projectName = 'Project Workspace',
    this.initialSummary,
  });

  @override
  State<EcosystemOrchestrationScreen> createState() => _EcosystemOrchestrationScreenState();
}

class _EcosystemOrchestrationScreenState extends State<EcosystemOrchestrationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  WorkflowOrchestrationSummaryModel? _summary;
  RoleScopedProjectViewModel? _roleView;
  EcosystemRole _selectedPreviewRole = EcosystemRole.contractor;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialSummary != null) {
      _summary = widget.initialSummary;
      _isLoading = false;
      _loadRoleScopedView(_selectedPreviewRole);
    } else {
      _loadOrchestrationData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrchestrationData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await ProjectService.fetchWorkflowOrchestrationSummary(widget.projectId);
      final rView = await ProjectService.fetchRoleScopedProjectView(widget.projectId, _selectedPreviewRole.code);
      setState(() {
        _summary = summary;
        _roleView = rView;
        _isLoading = false;
      });
    } catch (_) {
      // Fallback preview summary
      setState(() {
        _summary = _buildFallbackSummary();
        _roleView = _buildFallbackRoleView(_selectedPreviewRole);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoleScopedView(EcosystemRole role) async {
    try {
      final rView = await ProjectService.fetchRoleScopedProjectView(widget.projectId, role.code);
      setState(() {
        _selectedPreviewRole = role;
        _roleView = rView;
      });
    } catch (_) {
      setState(() {
        _selectedPreviewRole = role;
        _roleView = _buildFallbackRoleView(role);
      });
    }
  }

  WorkflowOrchestrationSummaryModel _buildFallbackSummary() {
    final h1 = EcosystemHandoffRecordModel(
      handoffId: 'hnd_mock_01',
      projectId: widget.projectId,
      transitionType: HandoffTransitionType.homeownerToDesigner,
      sourceActorId: 'usr_homeowner',
      sourceRole: EcosystemRole.homeowner,
      targetActorId: 'des_elena',
      targetRole: EcosystemRole.interiorDesigner,
      targetActorName: 'Elena Vance Architecture',
      status: HandoffStatus.active,
      permittedScopes: ['view_raw_scans', 'create_redesigns', 'edit_budget'],
      notes: 'Initial scan models and brief transferred.',
      createdAt: '2026-09-28T10:00:00Z',
      acceptedAt: '2026-09-28T11:30:00Z',
    );

    final h2 = EcosystemHandoffRecordModel(
      handoffId: 'hnd_mock_02',
      projectId: widget.projectId,
      transitionType: HandoffTransitionType.designerToContractor,
      sourceActorId: 'des_elena',
      sourceRole: EcosystemRole.interiorDesigner,
      targetActorId: 'ctr_apex',
      targetRole: EcosystemRole.contractor,
      targetActorName: 'Apex Build & Renovations',
      status: HandoffStatus.pendingAcceptance,
      permittedScopes: ['view_tender_brief', 'view_boq', 'submit_bids'],
      notes: 'RFQ tender for wet works and bespoke joinery.',
      createdAt: '2026-09-29T08:00:00Z',
    );

    final a1 = EcosystemAuditEventModel(
      eventId: 'aud_mock_01',
      projectId: widget.projectId,
      actorId: 'usr_homeowner',
      actorName: 'Homeowner',
      actorRole: EcosystemRole.homeowner,
      action: 'INITIATE_HANDOFF',
      resourceType: 'handoff',
      resourceId: 'hnd_mock_01',
      timestamp: '2026-09-28T10:00:00Z',
    );

    final a2 = EcosystemAuditEventModel(
      eventId: 'aud_mock_02',
      projectId: widget.projectId,
      actorId: 'des_elena',
      actorName: 'Elena Vance',
      actorRole: EcosystemRole.interiorDesigner,
      action: 'ACCEPT_HANDOFF',
      resourceType: 'handoff',
      resourceId: 'hnd_mock_01',
      timestamp: '2026-09-28T11:30:00Z',
    );

    return WorkflowOrchestrationSummaryModel(
      projectId: widget.projectId,
      projectName: widget.projectName,
      homeownerPhaseStatus: 'COMPLETED',
      designerPhaseStatus: 'ACTIVE',
      commercePhaseStatus: 'ACTIVE',
      contractorPhaseStatus: 'IN_PROGRESS',
      propertyStagingPhaseStatus: 'ACTIVE',
      totalActiveHandoffs: 1,
      totalParticipants: 3,
      handoffs: [h1, h2],
      recentAuditEvents: [a1, a2],
    );
  }

  RoleScopedProjectViewModel _buildFallbackRoleView(EcosystemRole role) {
    if (role == EcosystemRole.contractor) {
      return RoleScopedProjectViewModel(
        projectId: widget.projectId,
        role: role,
        projectName: widget.projectName,
        propertyAddress: '12 Jalan Ampang, Kuala Lumpur',
        accessibleSections: [
          'confirmed_and_estimated_measurements_checklist',
          'trade_work_packages',
          'bill_of_quantities_with_wastage',
          'site_access_rules_and_working_hours',
          'rfq_tender_specifications',
        ],
        redactedFields: [
          'homeowner_personal_phone',
          'homeowner_billing_rate',
          'designer_markups_and_commissions',
          'competitor_contractor_tender_bids',
        ],
      );
    } else if (role == EcosystemRole.merchantSeller) {
      return RoleScopedProjectViewModel(
        projectId: widget.projectId,
        role: role,
        projectName: widget.projectName,
        propertyAddress: 'Kuala Lumpur Central (Street Redacted)',
        accessibleSections: [
          'specified_catalog_products',
          'in_room_3d_furniture_placements',
          'spatial_fit_attestations',
          'affiliate_referral_tracking',
        ],
        redactedFields: [
          'full_architectural_floorplans',
          'contractor_tender_packages',
          'total_renovation_budget',
          'client_contact_details',
        ],
      );
    } else if (role == EcosystemRole.propertyAgent) {
      return RoleScopedProjectViewModel(
        projectId: widget.projectId,
        role: role,
        projectName: widget.projectName,
        propertyAddress: '12 Jalan Ampang, Kuala Lumpur',
        accessibleSections: [
          'virtually_staged_media_pairs',
          'reso_regulatory_disclosure_manifest',
          'printable_marketing_flyer_html',
          'cosmetic_renovation_potential_roi',
        ],
        redactedFields: [
          'subcontractor_unit_labor_rates',
          'internal_designer_cost_margins',
          'client_personal_identifiable_information',
        ],
      );
    } else {
      return RoleScopedProjectViewModel(
        projectId: widget.projectId,
        role: role,
        projectName: widget.projectName,
        propertyAddress: '12 Jalan Ampang, Kuala Lumpur',
        accessibleSections: [
          'all_spatial_scans',
          'design_versions_and_variants',
          'full_financial_budget',
          'client_confidential_brief',
          'merchant_placements_and_commissions',
          'contractor_briefs_and_tender_bids',
          'property_virtual_staging_and_flyers',
        ],
        redactedFields: [],
      );
    }
  }

  Future<void> _handleInitiateHandoff() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final targetNameController = TextEditingController(text: 'Apex Construction');
    final targetIdController = TextEditingController(text: 'ctr_apex_01');
    HandoffTransitionType transition = HandoffTransitionType.designerToContractor;
    EcosystemRole targetRole = EcosystemRole.contractor;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Initiate Ecosystem Handoff', style: TextStyle(color: AppTheme.textMain)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transition Type', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<HandoffTransitionType>(
                  initialValue: transition,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textMain),
                  items: HandoffTransitionType.values.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t.label));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        transition = val;
                        if (val == HandoffTransitionType.designerToContractor) {
                          targetRole = EcosystemRole.contractor;
                          targetNameController.text = 'Apex Construction';
                        } else if (val == HandoffTransitionType.designerToMerchant) {
                          targetRole = EcosystemRole.merchantSeller;
                          targetNameController.text = 'IKEA Business';
                        } else if (val == HandoffTransitionType.designerToAgent) {
                          targetRole = EcosystemRole.propertyAgent;
                          targetNameController.text = 'PropNex Realty';
                        } else {
                          targetRole = EcosystemRole.interiorDesigner;
                          targetNameController.text = 'Elena Vance Studio';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Participant Name', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: targetNameController,
                  style: const TextStyle(color: AppTheme.textMain),
                  decoration: const InputDecoration(hintText: 'e.g. Apex Construction'),
                ),
                const SizedBox(height: 16),
                const Text('Participant Actor ID', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: targetIdController,
                  style: const TextStyle(color: AppTheme.textMain),
                  decoration: const InputDecoration(hintText: 'e.g. ctr_apex_01'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Initiate Handoff')),
          ],
        ),
      ),
    );

    if (shouldCreate == true) {
      try {
        final newHandoff = await ProjectService.initiateEcosystemHandoff({
          'project_id': widget.projectId,
          'transition_type': transition.code,
          'source_actor_id': 'designer_current',
          'source_role': 'INTERIOR_DESIGNER',
          'target_actor_id': targetIdController.text.trim(),
          'target_role': targetRole.code,
          'target_actor_name': targetNameController.text.trim(),
          'permitted_scopes': ['view_workspace', 'read_specifications'],
        });

        setState(() {
          _summary?.handoffs.insert(0, newHandoff);
        });

        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Ecosystem handoff initiated with scoped permissions!'), backgroundColor: AppTheme.success),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Handoff initiation failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _handleAcceptHandoff(EcosystemHandoffRecordModel handoff) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ProjectService.acceptEcosystemHandoff(
        handoff.handoffId,
        {'actor_id': handoff.targetActorId, 'actor_name': handoff.targetActorName},
      );
      setState(() {
        final idx = _summary?.handoffs.indexWhere((h) => h.handoffId == handoff.handoffId) ?? -1;
        if (idx != -1) {
          _summary!.handoffs[idx] = updated;
        }
      });
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Handoff accepted. Scoped permissions activated!'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Accept failed: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final summary = _summary!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Ecosystem Orchestrator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _loadOrchestrationData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.linear_scale), text: '5-Phase Lifecycle'),
            Tab(icon: Icon(Icons.security), text: 'Role Permissions'),
            Tab(icon: Icon(Icons.history), text: 'Audit History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLifecycleTab(summary),
          _buildRolePermissionsTab(),
          _buildAuditHistoryTab(summary),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.swap_horiz_outlined),
        label: const Text('New Handoff'),
        onPressed: _handleInitiateHandoff,
      ),
    );
  }

  Widget _buildLifecycleTab(WorkflowOrchestrationSummaryModel summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Card
          _buildEcosystemOverviewCard(summary),
          const SizedBox(height: 20),

          // Stepper: 5 Phases
          const Text(
            'CROSS-SEGMENT PIPELINE PROGRESS',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.05),
          ),
          const SizedBox(height: 12),
          _buildPhaseStepCard(1, 'Homeowner Capture & Brief', 'Spatial scans, room brief, and design intentions', summary.homeownerPhaseStatus),
          _buildPhaseStepCard(2, 'Interior Designer Workspace', 'Geometric validation, versions, BOQ and specs', summary.designerPhaseStatus),
          _buildPhaseStepCard(3, 'Merchant Commerce & Fit', 'Catalog specification, in-room placement & fit verification', summary.commercePhaseStatus),
          _buildPhaseStepCard(4, 'Contractor Handoff & Tenders', 'Trade packages, verified checklist, RFQs and bidding', summary.contractorPhaseStatus),
          _buildPhaseStepCard(5, 'Property Marketing & Staging', 'Virtual staging, RESO portal bundle and disclosure controls', summary.propertyStagingPhaseStatus),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Handoffs', style: TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${summary.handoffs.length} total', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),

          if (summary.handoffs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('No cross-segment handoffs initiated yet.', style: TextStyle(color: AppTheme.textMuted))),
            )
          else
            ...summary.handoffs.map((h) => _buildHandoffCard(h)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEcosystemOverviewCard(WorkflowOrchestrationSummaryModel summary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                summary.projectName,
                style: const TextStyle(color: AppTheme.textMain, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withAlpha(35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('PHASE 6 GOVERNED', style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Multi-participant spatial architecture, commerce, and contractor ecosystem.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const Divider(color: AppTheme.surfaceBorder, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewMetric('Participants', '${summary.totalParticipants}', Icons.people_outline),
              _buildOverviewMetric('Active Handoffs', '${summary.totalActiveHandoffs}', Icons.swap_horiz),
              _buildOverviewMetric('Audit Events', '${summary.recentAuditEvents.length}', Icons.shield_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _buildPhaseStepCard(int step, String title, String subtitle, String status) {
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'COMPLETED':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle;
        break;
      case 'ACTIVE':
      case 'IN_PROGRESS':
        statusColor = AppTheme.accent;
        statusIcon = Icons.hourglass_top;
        break;
      default:
        statusColor = AppTheme.textMuted;
        statusIcon = Icons.radio_button_unchecked;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: status == 'ACTIVE' ? AppTheme.accent.withAlpha(100) : AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: statusColor.withAlpha(35),
            child: Text('$step', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Icon(statusIcon, color: statusColor, size: 18),
        ],
      ),
    );
  }

  Widget _buildHandoffCard(EcosystemHandoffRecordModel h) {
    Color statusColor;
    switch (h.status) {
      case HandoffStatus.active:
        statusColor = AppTheme.success;
        break;
      case HandoffStatus.completed:
        statusColor = AppTheme.accent;
        break;
      case HandoffStatus.revoked:
        statusColor = AppTheme.danger;
        break;
      default:
        statusColor = Colors.amber;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                h.transitionType.label,
                style: const TextStyle(color: AppTheme.textMain, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withAlpha(35), borderRadius: BorderRadius.circular(4)),
                child: Text(h.status.label, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Target: ${h.targetActorName ?? h.targetActorId} (${h.targetRole.label})',
            style: const TextStyle(color: AppTheme.accent, fontSize: 12),
          ),
          if (h.notes != null && h.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(h.notes!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: h.permittedScopes.map((s) {
              return Chip(
                label: Text(s, style: const TextStyle(fontSize: 10, color: AppTheme.textMain)),
                backgroundColor: AppTheme.background,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          if (h.status == HandoffStatus.pendingAcceptance) ...[
            const Divider(color: AppTheme.surfaceBorder, height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Accept & Activate Scoped Access'),
                onPressed: () => _handleAcceptHandoff(h),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRolePermissionsTab() {
    final rView = _roleView;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PREVIEW ROLE PERSPECTIVE (RBAC GOVERNANCE)',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.05),
          ),
          const SizedBox(height: 8),
          SegmentedButton<EcosystemRole>(
            segments: const [
              ButtonSegment(value: EcosystemRole.homeowner, label: Text('Owner', style: TextStyle(fontSize: 10))),
              ButtonSegment(value: EcosystemRole.interiorDesigner, label: Text('Designer', style: TextStyle(fontSize: 10))),
              ButtonSegment(value: EcosystemRole.contractor, label: Text('Contractor', style: TextStyle(fontSize: 10))),
              ButtonSegment(value: EcosystemRole.merchantSeller, label: Text('Merchant', style: TextStyle(fontSize: 10))),
              ButtonSegment(value: EcosystemRole.propertyAgent, label: Text('Agent', style: TextStyle(fontSize: 10))),
            ],
            selected: {_selectedPreviewRole},
            onSelectionChanged: (newSet) {
              _loadRoleScopedView(newSet.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primary;
                }
                return AppTheme.surface;
              }),
            ),
          ),
          const SizedBox(height: 16),

          if (rView != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: AppTheme.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Active Data Scope: ${rView.role.label}',
                        style: const TextStyle(color: AppTheme.textMain, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Property Address: ${rView.propertyAddress ?? "Confidential"}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Accessible Data
            const Text('Authorized Sections', style: TextStyle(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...rView.accessibleSections.map((sec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(sec.replaceAll('_', ' '), style: const TextStyle(color: AppTheme.textMain, fontSize: 12))),
                    ],
                  ),
                )),
            const SizedBox(height: 16),

            // Redacted Data
            if (rView.redactedFields.isNotEmpty) ...[
              const Text('Shielded / Redacted Fields (Privacy Enforced)', style: TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...rView.redactedFields.map((field) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: AppTheme.warning, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text(field.replaceAll('_', ' '), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                      ],
                    ),
                  )),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Full transparent access. No fields redacted for this role.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAuditHistoryTab(WorkflowOrchestrationSummaryModel summary) {
    final audits = summary.recentAuditEvents;

    if (audits.isEmpty) {
      return const Center(child: Text('No audit events logged yet.', style: TextStyle(color: AppTheme.textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: audits.length,
      itemBuilder: (context, index) {
        final a = audits[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: a.isSensitive ? AppTheme.danger.withAlpha(120) : AppTheme.surfaceBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                a.isSensitive ? Icons.warning_amber_rounded : Icons.history,
                color: a.isSensitive ? AppTheme.danger : AppTheme.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(a.action, style: const TextStyle(color: AppTheme.textMain, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(
                          a.actorRole.label,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Actor: ${a.actorName} (${a.actorId}) • Resource: ${a.resourceType}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
