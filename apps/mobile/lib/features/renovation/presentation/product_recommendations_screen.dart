import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

/// Screen for exploring, filtering, and assigning curated furniture/decor
/// catalogue products with physical clearance and dimensional fit validation.
/// Fulfills Milestone 4.3 & Blueprint Section 41.
class ProductRecommendationsScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final ProductRecommendationReportModel? initialReport;
  final String initialStyle;
  final String initialTier;
  final String initialCurrency;

  const ProductRecommendationsScreen({
    super.key,
    required this.roomId,
    this.roomName = 'Room',
    this.initialReport,
    this.initialStyle = 'Warm Modern Minimalist',
    this.initialTier = 'MODERATE',
    this.initialCurrency = 'MYR',
  });

  @override
  State<ProductRecommendationsScreen> createState() => _ProductRecommendationsScreenState();
}

class _ProductRecommendationsScreenState extends State<ProductRecommendationsScreen> {
  bool _isLoading = false;
  ProductRecommendationReportModel? _report;
  late String _selectedStyle;
  late String _selectedTier;
  late String _selectedCurrency;
  String _selectedCategoryFilter = 'ALL';
  String _selectedFitFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _currencies = ['MYR', 'SGD', 'USD', 'EUR', 'GBP', 'AUD', 'CAD'];
  final List<Map<String, String>> _tiers = [
    {'key': 'ECONOMY', 'label': 'Economy'},
    {'key': 'MODERATE', 'label': 'Moderate'},
    {'key': 'PREMIUM', 'label': 'Premium'},
    {'key': 'LUXURY', 'label': 'Luxury'},
  ];

  final List<String> _styles = [
    'Warm Modern Minimalist',
    'Scandinavian',
    'Japandi',
    'Modern Luxury',
    'Industrial Modern',
    'Contemporary',
  ];

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    _selectedStyle = widget.initialStyle;
    _selectedTier = widget.initialTier;
    _selectedCurrency = widget.initialCurrency;

    if (_report == null) {
      _loadRecommendations();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final rep = await ProjectService.generateRoomRecommendations(
        roomId: widget.roomId,
        preferredStyle: _selectedStyle,
        preferredTier: _selectedTier,
        preferredCurrency: _selectedCurrency,
      );
      if (mounted) {
        setState(() {
          _report = rep;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load recommendations: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleAssigned(int index) {
    if (_report == null) return;
    final currentRec = _filteredRecommendations[index];
    final originalIndex = _report!.recommendations.indexWhere((r) => r.product.id == currentRec.product.id);
    if (originalIndex == -1) return;

    final updated = List<ProductRecommendationModel>.from(_report!.recommendations);
    updated[originalIndex] = currentRec.copyWith(isAssigned: !currentRec.isAssigned);

    setState(() {
      _report = ProductRecommendationReportModel(
        roomId: _report!.roomId,
        recommendations: updated,
        appliedStyle: _report!.appliedStyle,
        appliedTier: _report!.appliedTier,
        appliedCurrency: _report!.appliedCurrency,
        totalRecommendedSpend: _report!.totalRecommendedSpend,
        generatedAt: _report!.generatedAt,
      );
    });
  }

  List<ProductRecommendationModel> get _filteredRecommendations {
    if (_report == null) return [];
    var list = _report!.recommendations;

    // Filter by Category
    if (_selectedCategoryFilter != 'ALL') {
      list = list.where((r) => r.product.category.toUpperCase() == _selectedCategoryFilter.toUpperCase()).toList();
    }

    // Filter by Fit Status
    if (_selectedFitFilter != 'ALL') {
      list = list.where((r) => r.fitStatus.toUpperCase() == _selectedFitFilter.toUpperCase()).toList();
    }

    // Filter by search query
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) =>
          r.product.name.toLowerCase().contains(q) ||
          r.product.brand.toLowerCase().contains(q) ||
          (r.targetElementLabel?.toLowerCase().contains(q) ?? false) ||
          r.product.category.toLowerCase().contains(q)
      ).toList();
    }

    return list;
  }

  double get _assignedSpend {
    if (_report == null) return 0.0;
    return _report!.recommendations
        .where((r) => r.isAssigned)
        .fold(0.0, (sum, r) => sum + r.product.price);
  }

  int get _assignedCount {
    if (_report == null) return 0;
    return _report!.recommendations.where((r) => r.isAssigned).length;
  }

  Color _getFitStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PERFECT_FIT':
        return AppTheme.success;
      case 'TIGHT_FIT':
        return Colors.amber.shade700;
      case 'CLEARANCE_WARNING':
        return Colors.orange.shade800;
      case 'OVERSIZED':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }

  IconData _getFitStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PERFECT_FIT':
        return Icons.check_circle_outline;
      case 'TIGHT_FIT':
        return Icons.warning_amber_rounded;
      case 'CLEARANCE_WARNING':
        return Icons.height;
      case 'OVERSIZED':
        return Icons.highlight_off;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = _report != null && _report!.recommendations.isNotEmpty
        ? _report!.recommendations.first.product.formattedPrice.split(' ').first
        : 'RM';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Catalogue & Spatial Fit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.roomName} · $_selectedStyle',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filter & Preferences',
            onPressed: _showPreferencesModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerate',
            onPressed: _loadRecommendations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 16),
                  Text(
                    'Evaluating Spatial Clearance & Catalogue Fit...',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildSummaryHeader(currencySymbol),
                _buildSearchAndFilters(),
                Expanded(
                  child: _filteredRecommendations.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredRecommendations.length,
                          itemBuilder: (context, index) {
                            final rec = _filteredRecommendations[index];
                            return _buildProductCard(rec, index);
                          },
                        ),
                ),
                _buildAssignedBottomBar(currencySymbol),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader(String symbol) {
    final totalCount = _report?.recommendations.length ?? 0;
    final perfectCount = _report?.recommendations.where((r) => r.fitStatus == 'PERFECT_FIT').length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.primary.withAlpha(70)),
                      ),
                      child: Text(
                        _selectedTier,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalCount Curated Items',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$perfectCount of $totalCount items meet zero-collision circulation clearance.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Recommended Spend',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
                Text(
                  _report?.formattedSpend ?? '$symbol 0',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final categories = [
      'ALL',
      'SOFA',
      'COFFEE_TABLE',
      'TV_CONSOLE',
      'DINING_TABLE',
      'BED',
      'LIGHTING',
      'RUG',
      'ARMCHAIR',
    ];

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search products, brands, or target furniture...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),

          // Category Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategoryFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      cat.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : AppTheme.textMain,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedCategoryFilter = val ? cat : 'ALL';
                      });
                    },
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.background,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Fit Status Filter Row
          Row(
            children: [
              const Text(
                'Fit Filter: ',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              _buildFitFilterChip('ALL', 'All Fits'),
              const SizedBox(width: 4),
              _buildFitFilterChip('PERFECT_FIT', 'Perfect'),
              const SizedBox(width: 4),
              _buildFitFilterChip('TIGHT_FIT', 'Tight'),
              const SizedBox(width: 4),
              _buildFitFilterChip('CLEARANCE_WARNING', 'Warnings'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFitFilterChip(String key, String label) {
    final isSelected = _selectedFitFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFitFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductRecommendationModel rec, int index) {
    final prod = rec.product;
    final fitColor = _getFitStatusColor(rec.fitStatus);
    final fitIcon = _getFitStatusIcon(rec.fitStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rec.isAssigned ? AppTheme.primary : AppTheme.surfaceBorder,
          width: rec.isAssigned ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Target element mapping & match score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: const Border(bottom: BorderSide(color: AppTheme.surfaceBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      rec.targetElementLabel != null ? 'Replaces: ${rec.targetElementLabel}' : 'Room Placement',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 12, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${rec.matchPercentage}% Match',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Title & Brand
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prod.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${prod.brand} · ${prod.category.replaceAll('_', ' ')}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      prod.formattedPrice,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Spatial Clearance & Dimension Fit Banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fitColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: fitColor.withAlpha(70)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(fitIcon, size: 16, color: fitColor),
                          const SizedBox(width: 6),
                          Text(
                            rec.fitStatusLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: fitColor,
                            ),
                          ),
                          const Spacer(),
                          if (rec.dimensionVariancePct != 0.0)
                            Text(
                              'Variance: ${rec.dimensionVariancePct > 0 ? "+" : ""}${rec.dimensionVariancePct.toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 10, color: fitColor, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rec.fitNotes,
                        style: TextStyle(fontSize: 11, color: fitColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Dimension Comparison Box
                _buildDimensionComparisonWidget(rec),
                const SizedBox(height: 10),

                // Materials & Colors Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...prod.materials.map((m) => _buildSpecPill(m, Icons.category_outlined)),
                    ...prod.colors.map((c) => _buildSpecPill(c, Icons.palette_outlined)),
                  ],
                ),
                const SizedBox(height: 8),

                // Retailer, Lead Time, & Budget Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${prod.retailer} (${prod.leadTimeDays}d lead)',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    Text(
                      rec.budgetStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: rec.budgetStatus.contains('Over') ? AppTheme.danger : AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rec.isAssigned ? AppTheme.success : AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _toggleAssigned(index),
                        icon: Icon(
                          rec.isAssigned ? Icons.check : Icons.add,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          rec.isAssigned ? 'Assigned to Room' : 'Assign to Room',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showProductDetailsDialog(rec),
                      child: const Text('Specs', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionComparisonWidget(ProductRecommendationModel rec) {
    final prodDims = rec.product.dimensions;
    final targetW = rec.targetWidthM ?? prodDims.widthM;
    final targetD = rec.targetDepthM ?? prodDims.depthM;
    final targetH = rec.targetHeightM ?? prodDims.heightM;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dimensional Fit Evaluation',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Room Allocation', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    Text(
                      '${targetW.toStringAsFixed(2)}m (W) × ${targetD.toStringAsFixed(2)}m (D) × ${targetH.toStringAsFixed(2)}m (H)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Product Footprint', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    Text(
                      prodDims.formattedDimensions,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecPill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.surfaceBorder),
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

  Widget _buildAssignedBottomBar(String symbol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_assignedCount item${_assignedCount == 1 ? "" : "s"} assigned',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                Text(
                  '$symbol ${_assignedSpend.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _assignedCount > 0 ? _confirmAssignedProducts : null,
                icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                label: const Text(
                  'Confirm Spec Sheet',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAssignedProducts() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved $_assignedCount assigned product specs to room design specification.'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No Products Found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search keywords, category filter, or spatial fit criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedCategoryFilter = 'ALL';
                  _selectedFitFilter = 'ALL';
                });
              },
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetailsDialog(ProductRecommendationModel rec) {
    final prod = rec.product;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(prod.name, style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SKU: ${prod.sku}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Text(prod.description, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                const Text('Dimensions & Clearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(prod.dimensions.formattedDimensions, style: const TextStyle(fontSize: 12)),
                Text('Required Walkway Clearance: ${prod.requiredClearanceM}m', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                const Text('Pricing & Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Price: ${prod.formattedPrice}', style: const TextStyle(fontSize: 12)),
                Text('Retailer: ${prod.retailer}', style: const TextStyle(fontSize: 12)),
                Text('Lead Time: ${prod.leadTimeDays} business days', style: const TextStyle(fontSize: 12)),
                Text('Status: ${prod.availability}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPreferencesModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommendation Preferences',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Style Selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStyle,
                    decoration: const InputDecoration(labelText: 'Aesthetic Style'),
                    items: _styles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _selectedStyle = val);
                        setState(() => _selectedStyle = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Tier Selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTier,
                    decoration: const InputDecoration(labelText: 'Budget / Finish Tier'),
                    items: _tiers
                        .map((t) => DropdownMenuItem(value: t['key'], child: Text(t['label']!)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _selectedTier = val);
                        setState(() => _selectedTier = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Currency Selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCurrency,
                    decoration: const InputDecoration(labelText: 'Pricing Currency'),
                    items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _selectedCurrency = val);
                        setState(() => _selectedCurrency = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadRecommendations();
                      },
                      child: const Text('Apply & Re-Score Catalogue'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
