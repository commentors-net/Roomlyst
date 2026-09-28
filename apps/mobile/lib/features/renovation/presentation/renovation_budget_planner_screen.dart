import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

/// Screen for Renovation Budget Planning, Material vs Labor splits,
/// contingency reserve modeling, regional tax allowances, and 4-tier comparisons.
/// Fulfills Blueprint Section 34 & Milestone 4.2.
class RenovationBudgetPlannerScreen extends StatefulWidget {
  final String roomId;
  final BudgetPlanModel? initialBudgetPlan;

  const RenovationBudgetPlannerScreen({
    super.key,
    required this.roomId,
    this.initialBudgetPlan,
  });

  @override
  State<RenovationBudgetPlannerScreen> createState() => _RenovationBudgetPlannerScreenState();
}

class _RenovationBudgetPlannerScreenState extends State<RenovationBudgetPlannerScreen> {
  bool _isLoading = false;
  BudgetPlanModel? _plan;
  late double _targetBudget;
  late String _currency;
  late String _tier;
  late double _contingencyPct;
  late bool _includeTax;
  int _activeTabIndex = 0; // 0 = Trade Breakdown, 1 = Tier Scenarios
  final TextEditingController _budgetController = TextEditingController();

  final List<String> _currencies = ['MYR', 'SGD', 'USD', 'EUR', 'GBP', 'AUD', 'CAD'];
  final List<Map<String, String>> _tiers = [
    {'key': 'ECONOMY', 'label': 'Economy'},
    {'key': 'MODERATE', 'label': 'Moderate'},
    {'key': 'PREMIUM', 'label': 'Premium'},
    {'key': 'LUXURY', 'label': 'Luxury'},
  ];

  @override
  void initState() {
    super.initState();
    _plan = widget.initialBudgetPlan;
    _targetBudget = widget.initialBudgetPlan?.totalBudget ?? 20000.0;
    _currency = widget.initialBudgetPlan?.currency ?? 'MYR';
    _tier = widget.initialBudgetPlan?.renovationTier ?? 'MODERATE';
    _contingencyPct = widget.initialBudgetPlan?.contingencyPct ?? 10.0;
    _includeTax = (widget.initialBudgetPlan?.taxRatePct ?? 0.0) > 0.0;
    _budgetController.text = _targetBudget.toStringAsFixed(0);

    if (_plan == null) {
      _loadBudget();
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  String get _currencySymbol {
    switch (_currency.toUpperCase()) {
      case 'SGD':
        return 'S\$';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      case 'MYR':
      default:
        return 'RM';
    }
  }

  String get _regionalTaxLabel {
    switch (_currency.toUpperCase()) {
      case 'SGD':
        return 'GST (9.0%)';
      case 'EUR':
      case 'GBP':
        return 'VAT (20.0%)';
      case 'CAD':
        return 'GST/HST (13.0%)';
      case 'AUD':
        return 'GST (10.0%)';
      case 'USD':
        return 'Sales Tax (8.0%)';
      case 'MYR':
      default:
        return 'SST (8.0%)';
    }
  }

  Future<void> _loadBudget() async {
    setState(() => _isLoading = true);
    try {
      final plan = await ProjectService.calculateRoomBudget(
        roomId: widget.roomId,
        totalBudget: _targetBudget,
        currency: _currency,
        renovationTier: _tier,
        contingencyPct: _contingencyPct,
        includeTax: _includeTax,
      );
      if (mounted) {
        setState(() {
          _plan = plan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load renovation budget: $e')),
        );
      }
    }
  }

  Future<void> _recalculateBudget() async {
    final parsed = double.tryParse(_budgetController.text);
    if (parsed != null && parsed > 0) {
      _targetBudget = parsed;
    }
    await _loadBudget();
  }

  void _applyScenarioTier(String tierKey) {
    setState(() {
      _tier = tierKey;
      _activeTabIndex = 0;
    });
    _loadBudget();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Renovation Budget Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recalculate Budget',
            onPressed: _isLoading ? null : _recalculateBudget,
          ),
        ],
      ),
      body: _isLoading && _plan == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildControlsCard(),
                  const SizedBox(height: 16),
                  if (_plan != null) ...[
                    _buildFinancialSummaryBanner(),
                    const SizedBox(height: 16),
                    _buildMaterialLaborSplitBar(),
                    const SizedBox(height: 16),
                    _buildSegmentedTabSelector(),
                    const SizedBox(height: 16),
                    if (_activeTabIndex == 0) ...[
                      _buildTradeBreakdownSection(),
                      const SizedBox(height: 16),
                      if (_plan!.tradeoffs.isNotEmpty) ...[
                        _buildTradeoffsSection(),
                        const SizedBox(height: 16),
                      ],
                    ] else ...[
                      _buildTierScenariosSection(),
                      const SizedBox(height: 16),
                    ],
                    _buildDisclaimerCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 18, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Text(
                  'Budget Parameters & Constraints',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textMain),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _currency,
                  dropdownColor: AppTheme.surface,
                  underline: const SizedBox(),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accent),
                  items: _currencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _currency = val);
                      _recalculateBudget();
                    }
                  },
                ),
              ],
            ),
            const Divider(color: AppTheme.surfaceBorder, height: 20),
            // Target budget input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _budgetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Target Budget ($_currencySymbol)',
                      isDense: true,
                      prefixText: '$_currencySymbol ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _recalculateBudget(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    final curr = double.tryParse(_budgetController.text) ?? _targetBudget;
                    _budgetController.text = (curr + 1000).toStringAsFixed(0);
                    _recalculateBudget();
                  },
                  child: const Text('+1k'),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () {
                    final curr = double.tryParse(_budgetController.text) ?? _targetBudget;
                    if (curr > 1000) {
                      _budgetController.text = (curr - 1000).toStringAsFixed(0);
                      _recalculateBudget();
                    }
                  },
                  child: const Text('-1k'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Renovation Tier chips
            const Text(
              'Finishing Quality Tier',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _tiers.map((t) {
                final isSelected = _tier == t['key'];
                return ChoiceChip(
                  label: Text(t['label']!),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _tier = t['key']!);
                      _recalculateBudget();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Contingency slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Risk Contingency Reserve',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
                Text(
                  '${_contingencyPct.toStringAsFixed(0)}% ($_currencySymbol ${_plan != null ? _plan!.contingencyAmount.toStringAsFixed(0) : "0"})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent),
                ),
              ],
            ),
            Slider(
              value: _contingencyPct,
              min: 5.0,
              max: 25.0,
              divisions: 20,
              label: '${_contingencyPct.toStringAsFixed(0)}%',
              activeColor: AppTheme.primary,
              onChanged: (val) {
                setState(() => _contingencyPct = val);
              },
              onChangeEnd: (_) => _recalculateBudget(),
            ),
            // Regional tax toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Include Regional Regulatory Allowance: $_regionalTaxLabel',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
              ),
              subtitle: _includeTax && _plan != null
                  ? Text(
                      'Adds $_currencySymbol ${_plan!.taxAmount.toStringAsFixed(2)} based on statutory trade code',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    )
                  : null,
              value: _includeTax,
              activeTrackColor: AppTheme.primary,
              onChanged: (val) {
                setState(() => _includeTax = val);
                _recalculateBudget();
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.calculate, size: 18),
                label: Text(_isLoading ? 'Calculating...' : 'Recalculate Budget'),
                onPressed: _isLoading ? null : _recalculateBudget,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryBanner() {
    final p = _plan!;
    final isWithin = p.grandTotal <= p.totalBudget;
    final delta = (p.grandTotal - p.totalBudget).abs();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWithin ? const Color(0xFF0F2B1D) : const Color(0xFF2C1318),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWithin ? const Color(0x6610B981) : const Color(0x66EF4444),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grand Total (${p.renovationTier})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isWithin ? const Color(0x3310B981) : const Color(0x33EF4444),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isWithin ? 'WITHIN BUDGET' : 'OVER BUDGET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isWithin ? AppTheme.success : AppTheme.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_currencySymbol ${p.grandTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textMain),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isWithin ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 14,
                color: isWithin ? AppTheme.success : AppTheme.danger,
              ),
              const SizedBox(width: 4),
              Text(
                isWithin
                    ? '$_currencySymbol ${delta.toStringAsFixed(0)} under target budget'
                    : '$_currencySymbol ${delta.toStringAsFixed(0)} exceeds target budget',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isWithin ? AppTheme.success : AppTheme.danger,
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.surfaceBorder, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('Materials', '$_currencySymbol ${p.subtotalMaterials.toStringAsFixed(0)}'),
              _buildMiniMetric('Labor', '$_currencySymbol ${p.subtotalLabor.toStringAsFixed(0)}'),
              _buildMiniMetric('Contingency', '$_currencySymbol ${p.contingencyAmount.toStringAsFixed(0)}'),
              if (p.taxAmount > 0)
                _buildMiniMetric(p.taxName, '$_currencySymbol ${p.taxAmount.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
      ],
    );
  }

  Widget _buildMaterialLaborSplitBar() {
    final p = _plan!;
    final totalBase = p.subtotalMaterials + p.subtotalLabor;
    final matRatio = totalBase > 0 ? (p.subtotalMaterials / totalBase) : 0.5;
    final labRatio = totalBase > 0 ? (p.subtotalLabor / totalBase) : 0.5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Material vs Labor Distribution',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                ),
                Text(
                  '${(matRatio * 100).toStringAsFixed(0)}% Mat / ${(labRatio * 100).toStringAsFixed(0)}% Lab',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Flexible(
                    flex: (matRatio * 100).toInt(),
                    child: Container(height: 10, color: AppTheme.primary),
                  ),
                  Flexible(
                    flex: (labRatio * 100).toInt(),
                    child: Container(height: 10, color: const Color(0xFF06B6D4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Materials: $_currencySymbol ${p.subtotalMaterials.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF06B6D4), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Trade Labor: $_currencySymbol ${p.subtotalLabor.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTabIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 0 ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Trade Breakdown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _activeTabIndex == 0 ? Colors.white : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 1 ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  '4-Tier Comparison',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _activeTabIndex == 1 ? Colors.white : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeBreakdownSection() {
    final p = _plan!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trade Contractor & Material Line Items',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textMain),
        ),
        const SizedBox(height: 8),
        ...p.allocatedItems.map((item) => _buildTradeItemCard(item)),
      ],
    );
  }

  Widget _buildTradeItemCard(CategoryCostItemModel item) {
    final isOver = item.isOverBudget;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.categoryName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                      ),
                      if (item.tradeName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.tradeName!,
                          style: const TextStyle(fontSize: 11, color: AppTheme.accent),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '$_currencySymbol ${item.estimatedCost.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isOver ? Colors.amber : AppTheme.textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.quantity.toStringAsFixed(1)} ${item.unit} @ $_currencySymbol ${item.unitRate.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                if (item.materialCost > 0 || item.laborCost > 0)
                  Text(
                    'Mat: $_currencySymbol ${item.materialCost.toStringAsFixed(0)} | Lab: $_currencySymbol ${item.laborCost.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
              ],
            ),
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.notes!,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTradeoffsSection() {
    final p = _plan!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.recycling, size: 16, color: AppTheme.success),
                const SizedBox(width: 6),
                const Text(
                  'Keep-vs-Replace Trade-offs & Savings',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                ),
                const Spacer(),
                if (p.savingsFromKeptItems > 0)
                  Text(
                    '+$_currencySymbol ${p.savingsFromKeptItems.toStringAsFixed(0)} Saved',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.success),
                  ),
              ],
            ),
            const Divider(color: AppTheme.surfaceBorder, height: 16),
            ...p.tradeoffs.map((t) {
              final isKept = t.action.toLowerCase() == 'keep';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isKept ? const Color(0x2610B981) : const Color(0x262563EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.action.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isKept ? AppTheme.success : AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.elementLabel,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMain),
                      ),
                    ),
                    Text(
                      isKept
                          ? 'Saved $_currencySymbol ${t.savingsIfKept.toStringAsFixed(0)}'
                          : 'Est. $_currencySymbol ${t.replacementCostEstimate.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isKept ? AppTheme.success : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTierScenariosSection() {
    final scenarios = _plan?.scenarios ?? [];
    if (scenarios.isEmpty) {
      return const Center(child: Text('No scenario comparison data available.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Side-by-Side Finish Tier Scenarios',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textMain),
        ),
        const SizedBox(height: 8),
        ...scenarios.map((s) => _buildScenarioCard(s)),
      ],
    );
  }

  Widget _buildScenarioCard(BudgetScenarioComparisonModel s) {
    final isSelected = s.tier.toUpperCase() == _tier.toUpperCase();
    final isWithin = s.isWithinBudget;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s.tierName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textMain),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
                              child: const Text('CURRENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(s.description, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_currencySymbol ${s.grandTotalEstimated.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textMain),
                    ),
                    Text(
                      isWithin
                          ? 'Within budget'
                          : '+$_currencySymbol ${s.costDeltaVsBudget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isWithin ? AppTheme.success : AppTheme.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: AppTheme.surfaceBorder, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniMetric('Materials', '$_currencySymbol ${s.subtotalMaterials.toStringAsFixed(0)}'),
                _buildMiniMetric('Labor', '$_currencySymbol ${s.subtotalLabor.toStringAsFixed(0)}'),
                _buildMiniMetric('Contingency', '$_currencySymbol ${s.contingencyAmount.toStringAsFixed(0)}'),
                if (s.taxAmount > 0)
                  _buildMiniMetric('Tax', '$_currencySymbol ${s.taxAmount.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 12),
            if (!isSelected)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _applyScenarioTier(s.tier),
                  child: Text('Select ${s.tierName} Tier'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF231C0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x4DF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _plan?.disclaimer ??
                  'Indicative renovation estimate only based on regional material and work benchmarks. Does not constitute a formal contractor quote.',
              style: const TextStyle(fontSize: 10, color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }
}
