import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

class ProjectExportDossierScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final ProfessionalExportDossierModel? initialDossier;

  const ProjectExportDossierScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.initialDossier,
  });

  @override
  State<ProjectExportDossierScreen> createState() => _ProjectExportDossierScreenState();
}

class _ProjectExportDossierScreenState extends State<ProjectExportDossierScreen> {
  ProfessionalExportDossierModel? _dossier;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialDossier != null) {
      _dossier = widget.initialDossier;
      _isLoading = false;
    } else {
      _loadDossier();
    }
  }

  Future<void> _loadDossier() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dossier = await ProjectService.getExportDossier(widget.projectId);
      if (mounted) {
        setState(() {
          _dossier = dossier;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showEditBrandingDialog() {
    if (_dossier == null) return;
    final current = _dossier!.branding;

    final firmController = TextEditingController(text: current.firmName);
    final taglineController = TextEditingController(text: current.tagline);
    final emailController = TextEditingController(text: current.contactEmail);
    final phoneController = TextEditingController(text: current.contactPhone ?? '');
    final licenseController = TextEditingController(text: current.licenseNumber ?? '');
    final disclaimerController = TextEditingController(text: current.customDisclaimer ?? '');
    String selectedPrimary = current.primaryColorHex;
    String selectedSecondary = current.secondaryColorHex;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Row(
            children: [
              Icon(Icons.palette_outlined, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Edit Studio Branding', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: firmController,
                    decoration: const InputDecoration(
                      labelText: 'Architecture / Interior Studio Name',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taglineController,
                    decoration: const InputDecoration(
                      labelText: 'Studio Tagline',
                      prefixIcon: Icon(Icons.short_text_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Practice License / Reg. No.',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Brand Primary Color', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['#2563EB', '#0F172A', '#0D9488', '#D97706', '#7C3AED'].map((hex) {
                      final isSel = selectedPrimary == hex;
                      return ChoiceChip(
                        label: Text(hex, style: const TextStyle(fontSize: 11)),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedPrimary = hex);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: disclaimerController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Custom Legal & Safety Disclaimer',
                      hintText: 'Enter contractual verification notices for tender package...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final updated = current.copyWith(
                  firmName: firmController.text.trim().isEmpty ? 'Roomlyst Studio Design' : firmController.text.trim(),
                  tagline: taglineController.text.trim(),
                  contactEmail: emailController.text.trim(),
                  contactPhone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  licenseNumber: licenseController.text.trim().isEmpty ? null : licenseController.text.trim(),
                  primaryColorHex: selectedPrimary,
                  secondaryColorHex: selectedSecondary,
                  customDisclaimer: disclaimerController.text.trim().isEmpty ? null : disclaimerController.text.trim(),
                );

                navigator.pop();
                try {
                  await ProjectService.updateProjectBranding(widget.projectId, updated);
                  await _loadDossier();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Studio branding profile updated')),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to update branding: $e')),
                  );
                }
              },
              child: const Text('Save Branding'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrintableReportDialog() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String html = _dossier?.printableHtml ?? '';

    if (html.isEmpty) {
      try {
        html = await ProjectService.getBrandedReportHtml(widget.projectId);
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to fetch HTML report: $e')),
        );
        return;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.print_outlined, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('${widget.projectName} Handover Report', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete standalone HTML document generated with embedded print CSS, practice branding, tabular measurement schedules, and sign-off blocks.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    html,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy HTML'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: html));
              Navigator.pop(ctx);
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Printable HTML report copied to clipboard!')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _exportJsonPackage() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final pkg = await ProjectService.getExportPackage(widget.projectId);
      final jsonStr = pkg.toString();
      Clipboard.setData(ClipboardData(text: jsonStr));
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Full project export package copied to clipboard!')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Export package failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.projectName} — Dossier')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _dossier == null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.projectName} — Dossier')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Unable to load export dossier',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadDossier,
              ),
            ],
          ),
        ),
      );
    }

    final dossier = _dossier!;
    final branding = dossier.branding;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${dossier.projectName} Dossier'),
          actions: [
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Studio Branding',
              onPressed: _showEditBrandingDialog,
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Printable HTML Report',
              onPressed: _showPrintableReportDialog,
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export Package',
              onPressed: _exportJsonPackage,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Executive Cover'),
              Tab(icon: Icon(Icons.straighten_outlined), text: 'Measurements'),
              Tab(icon: Icon(Icons.fact_check_outlined), text: 'Assumptions'),
              Tab(icon: Icon(Icons.assignment_turned_in_outlined), text: 'Contractor Handover'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Executive Cover & Room Sheets
            _buildExecutiveCoverTab(dossier, branding),

            // Tab 2: Tabular Measurement Schedule
            _buildMeasurementScheduleTab(dossier),

            // Tab 3: Architectural & Construction Assumptions
            _buildAssumptionsScheduleTab(dossier),

            // Tab 4: Contractor Handover & Sign-Off
            _buildContractorHandoverTab(dossier, branding),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Executive Cover
  // ---------------------------------------------------------------------------
  Widget _buildExecutiveCoverTab(ProfessionalExportDossierModel dossier, StudioBrandingModel branding) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Studio Practice Header Banner
        Card(
          color: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.primary, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branding.firmName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            branding.tagline,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit Branding', style: TextStyle(fontSize: 12)),
                      onPressed: _showEditBrandingDialog,
                    ),
                  ],
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (branding.licenseNumber != null)
                      _buildHeaderInfo(Icons.badge_outlined, 'License', branding.licenseNumber!),
                    _buildHeaderInfo(Icons.email_outlined, 'Contact', branding.contactEmail),
                    if (branding.contactPhone != null)
                      _buildHeaderInfo(Icons.phone_outlined, 'Phone', branding.contactPhone!),
                    _buildHeaderInfo(Icons.layers_outlined, 'Dossier Version', dossier.dossierVersion),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // KPI Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Scanned Rooms',
                dossier.totalRooms.toString(),
                Icons.meeting_room_outlined,
                AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Total Floor Area',
                '${dossier.totalFloorAreaSqm.toStringAsFixed(1)} m²',
                Icons.square_foot_outlined,
                AppTheme.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Estimated Budget',
                '${dossier.currency} ${dossier.totalEstimatedBudget.toStringAsFixed(0)}',
                Icons.monetization_on_outlined,
                AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Multi-Room Concept Sheets Section
        const Text(
          'Multi-Room Design Sheets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (dossier.roomSheets.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No room design sheets in this project.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            ),
          )
        else
          ...dossier.roomSheets.map((sheet) => _buildRoomSheetCard(sheet, dossier.currency)),
      ],
    );
  }

  Widget _buildHeaderInfo(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSheetCard(RoomSheetSummaryModel sheet, String currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.room_preferences_outlined, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      sheet.roomName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sheet.roomType.toUpperCase(),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sheet.approvalStatus == 'APPROVED'
                        ? AppTheme.success.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sheet.approvalStatus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: sheet.approvalStatus == 'APPROVED' ? AppTheme.success : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Selected Concept: ${sheet.selectedVariantStyle ?? "Warm Modern"} — ${sheet.selectedVariantTitle ?? "Variant 1"}',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSheetPill(Icons.square_foot, '${sheet.floorAreaSqm.toStringAsFixed(1)} m²'),
                const SizedBox(width: 8),
                _buildSheetPill(Icons.height, 'Ceiling ${sheet.ceilingHeightM.toStringAsFixed(1)}m'),
                const SizedBox(width: 8),
                _buildSheetPill(Icons.inventory_2_outlined, '${sheet.materialTakeoffItemCount} Takeoffs'),
                const SizedBox(width: 8),
                _buildSheetPill(Icons.shopping_bag_outlined, '${sheet.curatedProductCount} Products'),
                const Spacer(),
                Text(
                  '$currency ${sheet.estimatedBudget.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Tabular Measurement Schedule
  // ---------------------------------------------------------------------------
  Widget _buildMeasurementScheduleTab(ProfessionalExportDossierModel dossier) {
    final list = dossier.measurementSchedules;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Notice Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Schedule of Measurements indicates provenance and site verification requirements. Any dimension marked "Site Check Required" must be field-verified prior to fabrication.',
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (list.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No recorded room measurements.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            ),
          )
        else
          Card(
            color: AppTheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Room')),
                  DataColumn(label: Text('Entity')),
                  DataColumn(label: Text('Dimension')),
                  DataColumn(label: Text('Value')),
                  DataColumn(label: Text('Confidence')),
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('Verification State')),
                ],
                rows: list.map((item) {
                  final isVerified = item.verifiedByUser;
                  final badgeColor = isVerified
                      ? AppTheme.success
                      : (item.requiresSiteVerification ? Colors.orange : AppTheme.accent);

                  final badgeLabel = isVerified
                      ? 'Confirmed'
                      : (item.requiresSiteVerification ? 'Site Check Req.' : 'Approximate');

                  return DataRow(
                    cells: [
                      DataCell(Text(item.roomName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(item.entityLabel)),
                      DataCell(Text(item.dimensionType)),
                      DataCell(Text(
                        '${item.value.toStringAsFixed(2)} ${item.unit}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text('${(item.confidence * 100).toInt()}%')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(item.source, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                      )),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Architectural & Construction Assumptions
  // ---------------------------------------------------------------------------
  Widget _buildAssumptionsScheduleTab(ProfessionalExportDossierModel dossier) {
    final list = dossier.assumptionSchedules;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Architectural & Engineering Assumptions Schedule',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Consolidated schedule of technical assumptions regarding structural integrity, MEP circuits, waterproofing, and building management compliance.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 16),

        ...list.map((item) {
          final isHigh = item.riskLevel.toUpperCase() == 'HIGH';
          final isMedium = item.riskLevel.toUpperCase() == 'MEDIUM';
          final riskColor = isHigh ? AppTheme.danger : (isMedium ? Colors.orange : AppTheme.success);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(item.category),
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.category,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Text('— ${item.scope}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.riskLevel} RISK',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: riskColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.assumptionDescription,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.recommend_outlined, size: 16, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mandatory Recommendation: ${item.recommendation}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'STRUCTURAL':
        return Icons.foundation_outlined;
      case 'MEP_ELECTRICAL':
        return Icons.bolt_outlined;
      case 'MEP_PLUMBING':
        return Icons.plumbing_outlined;
      case 'WATERPROOFING':
        return Icons.water_drop_outlined;
      case 'SUBSTRATE':
        return Icons.layers_outlined;
      case 'PERMITTING':
        return Icons.gavel_outlined;
      default:
        return Icons.rule_outlined;
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Contractor Handover & Sign-Off
  // ---------------------------------------------------------------------------
  Widget _buildContractorHandoverTab(ProfessionalExportDossierModel dossier, StudioBrandingModel branding) {
    final steps = [
      '1. Site protection, edge guards & hoarding installation',
      '2. Controlled demolition and non-structural strip-out',
      '3. Concealed MEP rough-in (lighting loops, power drops, sanitary branches)',
      '4. Substrate leveling & 24h waterproofing ponding inspection',
      '5. Plasterboard partitions, skimming & ceiling grid installation',
      '6. Tile setting and architectural engineered timber flooring',
      '7. Custom joinery, architectural casework & fixed lighting installation',
      '8. Soft furnishings, touch-up painting & client handover inspection',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Suggested Execution Sequence
        const Text(
          'Contractor Execution & Staging Sequence',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Recommended critical path sequence for site mobilization and trade coordination.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: steps.map((step) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(step, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Legal & Regulatory Disclaimer Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Professional Regulatory & Safety Notice',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                branding.customDisclaimer ??
                    'This design handover dossier is prepared for client visualization and tender coordination. All structural, electrical, and plumbing works must be verified on-site by licensed trade contractors.',
                style: const TextStyle(fontSize: 12, color: Colors.amber, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Dual Signature Sign-Off Blocks
        Row(
          children: [
            Expanded(
              child: _buildSignatureBox(
                'Prepared By (Lead Designer)',
                branding.firmName,
                'Practice License: ${branding.licenseNumber ?? "Registered"}',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSignatureBox(
                'Accepted & Acknowledged By',
                dossier.clientName ?? 'Client Authorized Signatory',
                'Client Representative',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSignatureBox(String header, String name, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(header, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 28),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
