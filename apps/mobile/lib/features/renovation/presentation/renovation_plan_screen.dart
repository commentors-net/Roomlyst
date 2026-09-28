import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

/// Screen for Renovation Plan Output & Contractor Handover Brief.
/// Fulfills Blueprint Section 41 & Milestone 4.4.
class RenovationPlanScreen extends StatefulWidget {
  final String roomId;
  final RenovationPlanVersionModel? initialPlan;
  final String? initialVariantId;

  const RenovationPlanScreen({
    super.key,
    required this.roomId,
    this.initialPlan,
    this.initialVariantId,
  });

  @override
  State<RenovationPlanScreen> createState() => _RenovationPlanScreenState();
}

class _RenovationPlanScreenState extends State<RenovationPlanScreen> {
  bool _isLoading = false;
  List<RenovationPlanVersionModel> _availablePlans = [];
  RenovationPlanVersionModel? _selectedPlan;
  int _activeTabIndex = 0; // 0: Overview & Scope, 1: Materials & Products, 2: Confidence & Sequence

  @override
  void initState() {
    super.initState();
    if (widget.initialPlan != null) {
      _selectedPlan = widget.initialPlan;
      _availablePlans = [widget.initialPlan!];
    }
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await ProjectService.fetchRoomRenovationPlans(widget.roomId);
      if (mounted) {
        setState(() {
          _availablePlans = plans;
          if (plans.isNotEmpty) {
            _selectedPlan = plans.last;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // If no plans exist yet, automatically synthesize v1
        if (_availablePlans.isEmpty) {
          _generateNewPlan();
        }
      }
    }
  }

  Future<void> _generateNewPlan() async {
    setState(() => _isLoading = true);
    try {
      final newPlan = await ProjectService.generateRenovationPlan(
        roomId: widget.roomId,
        selectedVariantId: widget.initialVariantId,
      );
      if (mounted) {
        setState(() {
          _availablePlans.add(newPlan);
          _selectedPlan = newPlan;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renovation Plan ${newPlan.version} generated successfully.'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate renovation plan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showExportDialog() {
    if (_selectedPlan == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExportModal(
        roomId: widget.roomId,
        plan: _selectedPlan!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Renovation Plan & Brief',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: 'Export Contractor Brief',
            onPressed: _selectedPlan != null ? _showExportDialog : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Regenerate Plan',
            onPressed: _isLoading ? null : _generateNewPlan,
          ),
        ],
      ),
      body: _isLoading && _selectedPlan == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _selectedPlan == null
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildVersionSelectorHeader(),
                    _buildTabBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildTabContent(),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _selectedPlan != null ? _buildBottomActionBar() : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'No Renovation Plan Generated Yet',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Consolidate your room geometry, chosen design, materials, and budget into an actionable contractor brief.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateNewPlan,
              icon: const Icon(Icons.bolt, color: Colors.black),
              label: const Text('Generate Plan v1', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionSelectorHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_toggle_off, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Plan Version:',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPlan?.version,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                isDense: true,
                items: _availablePlans.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.version,
                    child: Text('${p.version} (${p.createdAt != null ? "${p.createdAt!.month}/${p.createdAt!.day} ${p.createdAt!.hour}:${p.createdAt!.minute.toString().padLeft(2, '0')}" : "Latest"})'),
                  );
                }).toList(),
                onChanged: (newVer) {
                  if (newVer != null) {
                    final matched = _availablePlans.firstWhere((p) => p.version == newVer);
                    setState(() => _selectedPlan = matched);
                  }
                },
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: Colors.greenAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${_selectedPlan!.confirmedCount} Confirmed',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          _buildTabItem(0, 'Scope & Design', Icons.dashboard_outlined),
          _buildTabItem(1, 'Takeoff & Cost', Icons.pie_chart_outline),
          _buildTabItem(2, 'Sequence & Safety', Icons.timeline_outlined),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppTheme.primary : Colors.white60),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return _buildScopeAndDesignTab();
      case 1:
        return _buildTakeoffAndCostTab();
      case 2:
      default:
        return _buildSequenceAndSafetyTab();
    }
  }

  // ==========================================
  // TAB 1: Scope, Retain/Remove, Design
  // ==========================================
  Widget _buildScopeAndDesignTab() {
    final p = _selectedPlan!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Project & Design Summary
        _buildCard(
          title: '1. Selected Design & Room Summary',
          icon: Icons.palette_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.selectedVariantTitle ?? 'Modern Harmonized Scheme',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Style: ${p.style ?? "Contemporary"} · Plan Version: ${p.version}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary),
                    ),
                    child: Text(
                      'Budget: ${p.formattedGrandTotal}',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 8),
              // Measurement Confidence Summary
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: Colors.blueAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Overall Confidence: ${(p.overallConfidence * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '${p.unverifiedCount} item(s) require site check',
                    style: TextStyle(
                      color: p.unverifiedCount > 0 ? Colors.amberAccent : Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section 4: Scope of Work
        _buildCard(
          title: '2. Scope of Renovation Work',
          icon: Icons.assignment_turned_in_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.scopeOfWork.isEmpty)
                const Text('Standard interior refresh and layout restyling.', style: TextStyle(color: Colors.white70))
              else
                ...p.scopeOfWork.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Icon(Icons.arrow_right, color: AppTheme.primary, size: 18),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              s,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section 5 & 6: Existing Items to Retain vs Remove/Replace
        _buildCard(
          title: '3. Inventory Demolition & Preservation',
          icon: Icons.sync_alt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInventorySubSection(
                title: 'Retain & Protect (${p.itemsToRetain.length})',
                badgeColor: Colors.blueAccent,
                items: p.itemsToRetain,
                emptyText: 'No items designated to be retained.',
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 12),
              _buildInventorySubSection(
                title: 'Demolish / Strip Out (${p.itemsToRemove.length})',
                badgeColor: Colors.redAccent,
                items: p.itemsToRemove,
                emptyText: 'No items flagged for full removal.',
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 12),
              _buildInventorySubSection(
                title: 'Replace / Restyle (${p.itemsToReplace.length})',
                badgeColor: Colors.amberAccent,
                items: p.itemsToReplace,
                emptyText: 'No items flagged for replacement.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventorySubSection({
    required String title,
    required Color badgeColor,
    required List<Map<String, dynamic>> items,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(emptyText, style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
          )
        else
          ...items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['label']?.toString() ?? 'Unnamed item',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (item['rationale'] != null)
                            Text(
                              item['rationale'].toString(),
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['action']?.toString() ?? 'KEEP',
                        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  // ==========================================
  // TAB 2: Materials, Products & Cost
  // ==========================================
  Widget _buildTakeoffAndCostTab() {
    final p = _selectedPlan!;
    final takeoff = p.materialTakeoffSummary;
    final takeoffItems = (takeoff?['items'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Budget Breakdown Card
        _buildCard(
          title: 'Budget Estimate & Splits',
          icon: Icons.attach_money,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total Estimated:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    p.formattedGrandTotal,
                    style: const TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 8),
              _buildCostRow('Materials Subtotal', '${p.currency} ${p.subtotalMaterials.toStringAsFixed(0)}'),
              _buildCostRow('Labor Subtotal', '${p.currency} ${p.subtotalLabor.toStringAsFixed(0)}'),
              _buildCostRow('Contingency (${p.contingencyPct.toInt()}%)', '${p.currency} ${p.contingencyAmount.toStringAsFixed(0)}'),
              if (p.taxAmount > 0)
                _buildCostRow('${p.taxName} Tax', '${p.currency} ${p.taxAmount.toStringAsFixed(0)}'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Materials & Takeoff Summary
        _buildCard(
          title: 'Recommended Materials Takeoff',
          icon: Icons.inventory_2_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (takeoffItems.isEmpty)
                const Text('No material takeoff generated yet for this room.', style: TextStyle(color: Colors.white54, fontSize: 13))
              else
                ...takeoffItems.map((it) {
                  final m = it as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['material_name']?.toString() ?? 'Material',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Category: ${m['category']} · Waste Factor: ${m['waste_factor_pct']}%',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                              if (m['package_spec'] != null)
                                Text(
                                  'Spec: ${m['package_spec']} (${m['packages_needed']} cartons)',
                                  style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${m['recommended_order_quantity']} ${m['unit']}',
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text('Order Qty', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Product Recommendations Summary
        _buildCard(
          title: 'Selected / Recommended Products',
          icon: Icons.chair_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.recommendedProducts.isEmpty)
                const Text('No catalog products linked to this renovation plan.', style: TextStyle(color: Colors.white54, fontSize: 13))
              else
                ...p.recommendedProducts.map((prod) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prod['name']?.toString() ?? 'Product',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${prod['brand'] ?? ""} · ${prod['category'] ?? ""}',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${prod['currency'] ?? p.currency} ${prod['price'] ?? 0}',
                          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: Sequence, Confidence, Safety
  // ==========================================
  Widget _buildSequenceAndSafetyTab() {
    final p = _selectedPlan!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statutory Safety Warning Card
        _buildStatutoryNoticeCard(),

        const SizedBox(height: 16),

        // Section 10: Measurement Confidence & Demarcation
        _buildCard(
          title: 'Measurement Provenance & Verification',
          icon: Icons.straighten,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text('${p.confirmedCount}', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('Confirmed', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text('${p.unverifiedCount}', style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('Site Check Req.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Critical Measurements List:',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...p.measurements.map((m) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.label,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Source: ${m.source} · Confidence: ${(m.confidence * 100).toInt()}%',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              m.displayString,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: m.isConfirmed ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.isConfirmed ? 'CONFIRMED' : 'CHECK NEEDED',
                                style: TextStyle(
                                  color: m.isConfirmed ? Colors.greenAccent : Colors.amberAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section 13: Suggested Execution Sequence
        _buildCard(
          title: 'Suggested Renovation Sequence (Advisory)',
          icon: Icons.timeline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...p.executionPhases.map((phase) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: phase.isSafetyCritical ? Colors.redAccent.withValues(alpha: 0.2) : AppTheme.primary.withValues(alpha: 0.2),
                          border: Border.all(
                            color: phase.isSafetyCritical ? Colors.redAccent : AppTheme.primary,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${phase.phaseNumber}',
                          style: TextStyle(
                            color: phase.isSafetyCritical ? Colors.redAccent : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    phase.title,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                if (phase.isSafetyCritical)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SAFETY CRITICAL',
                                      style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phase.description,
                              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ...phase.tradesInvolved.map((trade) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF334155),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(trade, style: const TextStyle(color: Colors.white60, fontSize: 10)),
                                    )),
                                Text('· ~${phase.estimatedDays} day(s)', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                            if (phase.regulatoryNotice != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  '⚠ ${phase.regulatoryNotice}',
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section 11 & 12: Assumptions & Warnings
        _buildCard(
          title: 'Assumptions & Contractor Disclaimers',
          icon: Icons.gavel_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assumptions:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              ...p.assumptions.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('• $a', style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3)),
                  )),
              const SizedBox(height: 12),
              const Text('Required Site Verifications:', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              ...p.warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('⚠ $w', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, height: 1.3)),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatutoryNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statutory Renovation Disclaimer',
                  style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'This plan is an advisory consolidation of AI designs, estimated spatial geometry, and regional cost benchmarks. '
                  'It does NOT substitute for professional structural, electrical, or plumbing engineering approval. '
                  'All safety-critical trades must be certified by licensed professionals prior to execution.',
                  style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showExportDialog,
                icon: const Icon(Icons.description_outlined, color: Colors.white),
                label: const Text('Export Brief', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateNewPlan,
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('New Version', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal for previewing and copying the contractor-ready markdown export.
class _ExportModal extends StatefulWidget {
  final String roomId;
  final RenovationPlanVersionModel plan;

  const _ExportModal({
    required this.roomId,
    required this.plan,
  });

  @override
  State<_ExportModal> createState() => _ExportModalState();
}

class _ExportModalState extends State<_ExportModal> {
  bool _copied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.plan.exportMarkdown));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contractor Handover Brief',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Version: ${widget.plan.version} · Ready for Print/PDF',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.plan.exportMarkdown.isNotEmpty
                      ? widget.plan.exportMarkdown
                      : '# Renovation Plan ${widget.plan.version}\n\nNo formatted text generated.',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFE2E8F0),
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copyToClipboard,
              icon: Icon(_copied ? Icons.check : Icons.copy, color: Colors.black),
              label: Text(
                _copied ? 'Copied to Clipboard!' : 'Copy Contractor Brief (Markdown)',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _copied ? Colors.greenAccent : AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
