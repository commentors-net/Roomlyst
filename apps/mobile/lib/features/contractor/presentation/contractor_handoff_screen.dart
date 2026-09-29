import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roomlyst/core/theme/app_theme.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/projects/services/project_service.dart';

/// Interactive Contractor Handoff & Tender Bid Management Screen.
/// Fulfills Milestone 6.2 & Blueprint Section 41.
class ContractorHandoffScreen extends StatefulWidget {
  final String projectId;
  final String? roomId;
  final String projectName;

  const ContractorHandoffScreen({
    super.key,
    required this.projectId,
    this.roomId,
    this.projectName = 'Project Workspace',
  });

  @override
  State<ContractorHandoffScreen> createState() => _ContractorHandoffScreenState();
}

class _ContractorHandoffScreenState extends State<ContractorHandoffScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ContractorProjectBriefModel? _brief;
  List<ContractorQuoteRequestModel> _rfqs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadContractorData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContractorData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final brief = await ProjectService.generateContractorBrief(
        widget.projectId,
        roomId: widget.roomId,
      );
      final rfqs = await ProjectService.fetchContractorRFQs(widget.projectId);

      setState(() {
        _brief = brief;
        _rfqs = rfqs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyChecklistItem(ContractorVerificationChecklistModel item) async {
    final nameCtrl = TextEditingController(text: 'Lead Contractor');
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Dimension on Site'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.dimensionLabel} (${item.dimensionValue} ${item.unit})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Statutory requirement: Trade contractors must physically verify site dimensions before procuring materials.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Verifier Name / Contractor License',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Site Notes (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Confirm Physical Verification'),
          ),
        ],
      ),
    );

    if (confirmed == true && _brief != null) {
      try {
        final verified = await ProjectService.verifyChecklistItem(
          _brief!.briefId,
          checklistId: item.checklistId,
          verifiedByName: nameCtrl.text.trim().isEmpty ? 'Lead Contractor' : nameCtrl.text.trim(),
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );

        setState(() {
          final updatedList = _brief!.verificationChecklist.map((c) {
            if (c.checklistId == verified.checklistId) {
              return verified;
            }
            return c;
          }).toList();

          final confCount = updatedList.where((c) => c.isPhysicallyVerified).length;
          final unconfCount = updatedList.length - confCount;

          _brief = ContractorProjectBriefModel(
            briefId: _brief!.briefId,
            projectId: _brief!.projectId,
            roomId: _brief!.roomId,
            title: _brief!.title,
            projectSummary: _brief!.projectSummary,
            propertyAddress: _brief!.propertyAddress,
            siteAccessNotes: _brief!.siteAccessNotes,
            workPackages: _brief!.workPackages,
            boqItems: _brief!.boqItems,
            verificationChecklist: updatedList,
            confirmedMeasurementsCount: confCount,
            unconfirmedMeasurementsCount: unconfCount,
            totalEstimatedMaterials: _brief!.totalEstimatedMaterials,
            totalEstimatedLabor: _brief!.totalEstimatedLabor,
            totalEstimatedCost: _brief!.totalEstimatedCost,
            currency: _brief!.currency,
            statutoryDisclaimer: _brief!.statutoryDisclaimer,
            createdAt: _brief!.createdAt,
            printableHtml: _brief!.printableHtml,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verified "${item.dimensionLabel}" on site!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showIssueRFQDialog() async {
    final titleCtrl = TextEditingController(text: 'Tender — ${_brief?.title ?? "Renovation"}');
    final selectedTrades = <String>{'CARPENTRY_JOINERY', 'MASONRY_TILING', 'ELECTRICAL_LIGHTING'};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Issue Contractor Tender RFQ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tender Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Target Trade Disciplines:', style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 6,
                  children: [
                    'DEMOLITION_PREP',
                    'MASONRY_TILING',
                    'CARPENTRY_JOINERY',
                    'ELECTRICAL_LIGHTING',
                    'PAINTING_PLASTERING',
                  ].map((trade) {
                    final isSel = selectedTrades.contains(trade);
                    return FilterChip(
                      label: Text(trade.replaceAll('_', ' ')),
                      selected: isSel,
                      onSelected: (val) {
                        setDlgState(() {
                          if (val) {
                            selectedTrades.add(trade);
                          } else {
                            selectedTrades.remove(trade);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Invited Contractors: Apex Builders, Straits Craft Carpentry, VoltSmart Electrical',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  final newRfq = await ProjectService.createContractorRFQ(
                    widget.projectId,
                    title: titleCtrl.text.trim().isEmpty ? 'Contractor Tender' : titleCtrl.text.trim(),
                    targetTrades: selectedTrades.toList(),
                    briefId: _brief?.briefId,
                    roomId: widget.roomId,
                  );
                  setState(() {
                    _rfqs.insert(0, newRfq);
                  });
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Issued Request for Quotation (RFQ) to invited contractors!')),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to issue RFQ: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Issue Tender'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSampleBid(ContractorQuoteRequestModel rfq) async {
    final amountCtrl = TextEditingController(text: '13800.00');
    final contractorCtrl = TextEditingController(text: 'Apex Builders Sdn Bhd');
    final licenseCtrl = TextEditingController(text: 'CIDB-G5-2024-8899');
    bool acknowledgeStatutory = true;
    bool acknowledgeSiteVerify = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Submit Contractor Tender Bid'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: contractorCtrl,
                  decoration: const InputDecoration(labelText: 'Contractor Company Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: licenseCtrl,
                  decoration: const InputDecoration(labelText: 'CIDB / Trade License No.', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Overall Bid Sum (MYR)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acknowledgeStatutory,
                  onChanged: (v) => setDlgState(() => acknowledgeStatutory = v ?? true),
                  title: const Text('I confirm valid public liability insurance and statutory licensing', style: TextStyle(fontSize: 12)),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acknowledgeSiteVerify,
                  onChanged: (v) => setDlgState(() => acknowledgeSiteVerify = v ?? true),
                  title: const Text('I agree to physically field-verify all site dimensions prior to fabrication', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 13800.0;
                Navigator.pop(ctx);
                try {
                  final bid = await ProjectService.submitContractorBid(
                    rfq.rfqId,
                    {
                      'contractor_id': 'c_apex_${DateTime.now().millisecondsSinceEpoch}',
                      'contractor_name': contractorCtrl.text.trim(),
                      'license_no': licenseCtrl.text.trim(),
                      'contact_email': 'tender@apexbuilders.my',
                      'overall_bid_amount': amt,
                      'trade_specialties': ['MASONRY_TILING', 'CARPENTRY_JOINERY'],
                      'statutory_compliance_acknowledged': acknowledgeStatutory,
                      'on_site_verification_acknowledged': acknowledgeSiteVerify,
                    },
                  );

                  setState(() {
                    final idx = _rfqs.indexWhere((r) => r.rfqId == rfq.rfqId);
                    if (idx != -1) {
                      final updatedBids = List<ContractorBidModel>.from(_rfqs[idx].bids)..add(bid);
                      _rfqs[idx] = ContractorQuoteRequestModel(
                        rfqId: _rfqs[idx].rfqId,
                        projectId: _rfqs[idx].projectId,
                        roomId: _rfqs[idx].roomId,
                        briefId: _rfqs[idx].briefId,
                        title: _rfqs[idx].title,
                        targetTrades: _rfqs[idx].targetTrades,
                        submissionDeadline: _rfqs[idx].submissionDeadline,
                        status: _rfqs[idx].status,
                        invitedContractors: _rfqs[idx].invitedContractors,
                        bids: updatedBids,
                        awardedBidId: _rfqs[idx].awardedBidId,
                        legalTermsAndConditions: _rfqs[idx].legalTermsAndConditions,
                        createdAt: _rfqs[idx].createdAt,
                      );
                    }
                  });

                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Quotation submitted by ${bid.contractorName}!')),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Submit Tender'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBidComparisonModal(String rfqId) async {
    try {
      final summary = await ProjectService.compareContractorBids(rfqId);

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              controller: scrollCtrl,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tender Bid Comparison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text('Benchmark Estimate: ${summary.currency} ${summary.roomlystEstimatedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(summary.comparisonNotes, style: const TextStyle(fontSize: 13, color: Colors.blue)),
                ),
                const SizedBox(height: 16),
                const Text('Submitted Quotations (Ranked by Cost):', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...summary.bidsRanked.map((b) {
                  final varPct = (b['variance_from_estimate_pct'] as num?)?.toDouble() ?? 0.0;
                  final isRec = b['bid_id'] == summary.recommendedBidId;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isRec ? Colors.green.withValues(alpha: 0.06) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isRec ? Colors.green : Colors.grey.withValues(alpha: 0.3)),
                    ),
                    child: ListTile(
                      title: Row(
                        children: [
                          Text(b['contractor_name'] as String? ?? 'Contractor', style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (isRec) ...[
                            const SizedBox(width: 8),
                            const Chip(
                              label: Text('LOWEST BID', style: TextStyle(fontSize: 10, color: Colors.green)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('License: ${b['license_no']} | Lead Time: ${b['lead_time_days']} days'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('MYR ${(b['overall_bid_amount'] as num?)?.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${varPct >= 0 ? '+' : ''}$varPct% vs est',
                              style: TextStyle(fontSize: 11, color: varPct <= 0 ? Colors.green : Colors.orange)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to compare bids: $e')));
      }
    }
  }

  Future<void> _showPrintableDialog() async {
    if (_brief == null) return;
    try {
      final html = await ProjectService.fetchContractorBriefPrintableHtml(_brief!.briefId);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Printable Tender Document'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                html,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy HTML to Clipboard'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: html));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contractor Brief HTML copied to clipboard!')),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading print document: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contractor Handoff & Tender'),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Export Printable Brief',
            onPressed: _showPrintableDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadContractorData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Scope & Packages', icon: Icon(Icons.handyman_outlined, size: 18)),
            Tab(text: 'BOQ Takeoff', icon: Icon(Icons.format_list_numbered, size: 18)),
            Tab(text: 'Verification Checklist', icon: Icon(Icons.check_circle_outline, size: 18)),
            Tab(text: 'Tender & RFQs', icon: Icon(Icons.request_quote_outlined, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text('Error: $_errorMessage', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadContractorData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildScopeTab(),
                    _buildBOQTab(),
                    _buildVerificationTab(),
                    _buildTenderTab(),
                  ],
                ),
    );
  }

  Widget _buildScopeTab() {
    final brief = _brief!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatutoryNoticeCard(brief.statutoryDisclaimer),
        const SizedBox(height: 12),
        _buildKPIHeader(brief),
        const SizedBox(height: 16),
        const Text('Trade Execution Packages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...brief.workPackages.map((pkg) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.construction, color: AppTheme.primary, size: 20),
                ),
                title: Text(pkg.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text('${pkg.trade} | Est: ${pkg.estimatedDurationDays} Days | Priority: ${pkg.priority}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pkg.description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 10),
                        const Text('Scope Items:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ...pkg.scopeItems.map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(child: Text(s, style: const TextStyle(fontSize: 13))),
                                ],
                              ),
                            )),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Safety Notes: ${pkg.safetyNotes.join(", ")}',
                                    style: const TextStyle(fontSize: 12, color: Colors.orange)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildBOQTab() {
    final brief = _brief!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildKPIHeader(brief),
        const SizedBox(height: 16),
        const Text('Bill of Quantities (BOQ) with Wastage Margins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...brief.boqItems.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(item.itemCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        Text('${brief.currency} ${item.totalEstimatedCost.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Net Qty: ${item.quantity} ${item.unit} | Waste: +${item.wasteFactorPct}%',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const Spacer(),
                        Text('Gross: ${item.totalQuantityWithWaste} ${item.unit}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Materials: ${brief.currency} ${item.estimatedMaterialTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        Text('Labor: ${brief.currency} ${item.estimatedLaborTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildVerificationTab() {
    final brief = _brief!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatutoryNoticeCard(
          'CRITICAL: Any measurement marked "REQUIRES ON-SITE VERIFICATION" is an AI or optical estimate. '
          'Contractors must physically measure on site prior to cutting or fabrication.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('${brief.confirmedMeasurementsCount}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    const Text('Confirmed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                Column(
                  children: [
                    Text('${brief.unconfirmedMeasurementsCount}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const Text('Field Check Needed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Critical Measurement Checklist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...brief.verificationChecklist.map((item) {
          final isConf = item.isPhysicallyVerified;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: isConf ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.4)),
            ),
            child: ListTile(
              leading: Icon(
                isConf ? Icons.check_circle : Icons.warning_amber_rounded,
                color: isConf ? Colors.green : Colors.orange,
              ),
              title: Text(item.dimensionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${item.dimensionValue} ${item.unit} | Source: ${item.source} (${(item.confidence * 100).toInt()}% conf)\n'
                'Critical for: ${item.criticalForTrade}${item.verifiedByName != null ? "\nVerified by: ${item.verifiedByName}" : ""}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: isConf
                  ? const Chip(
                      label: Text('CONFIRMED', style: TextStyle(fontSize: 10, color: Colors.green)),
                      visualDensity: VisualDensity.compact,
                    )
                  : ElevatedButton(
                      onPressed: () => _verifyChecklistItem(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Verify', style: TextStyle(fontSize: 12)),
                    ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTenderTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Contractor Tenders & RFQs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Issue RFQ'),
              onPressed: _showIssueRFQDialog,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_rfqs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Icon(Icons.request_quote_outlined, size: 40, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('No tender quote requests issued yet.'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _showIssueRFQDialog, child: const Text('Issue First RFQ')),
                ],
              ),
            ),
          )
        else
          ..._rfqs.map((rfq) {
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(rfq.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        Chip(
                          label: Text(rfq.status, style: TextStyle(fontSize: 11, color: rfq.isAwarded ? Colors.green : Colors.blue)),
                          backgroundColor: (rfq.isAwarded ? Colors.green : Colors.blue).withValues(alpha: 0.1),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Trades: ${rfq.targetTrades.join(", ")}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('Deadline: ${rfq.submissionDeadline.toLocal().toString().split(" ")[0]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('${rfq.bids.length} Bids Received', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.compare_arrows, size: 16),
                          label: const Text('Compare Bids'),
                          onPressed: () => _showBidComparisonModal(rfq.rfqId),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('Simulate Bid'),
                          onPressed: () => _submitSampleBid(rfq),
                          style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    if (rfq.bids.isNotEmpty) ...[
                      const Divider(height: 20),
                      ...rfq.bids.map((b) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(b.contractorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('License: ${b.licenseNo} | Lead Time: ${b.estimatedLeadTimeDays}d'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(b.formattedBidAmount, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(b.status, style: TextStyle(fontSize: 10, color: b.isAccepted ? Colors.green : Colors.grey)),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStatutoryNoticeCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIHeader(ContractorProjectBriefModel brief) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(brief.formattedTotalCost, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Est Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            Container(height: 24, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
            Column(
              children: [
                Text(brief.formattedMaterialCost, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Materials', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            Container(height: 24, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
            Column(
              children: [
                Text(brief.formattedLaborCost, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Labor', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
