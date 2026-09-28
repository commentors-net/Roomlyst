import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

class MaterialTakeoffScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final MaterialTakeoffReportModel? initialReport;

  const MaterialTakeoffScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.initialReport,
  });

  @override
  State<MaterialTakeoffScreen> createState() => _MaterialTakeoffScreenState();
}

class _MaterialTakeoffScreenState extends State<MaterialTakeoffScreen> {
  MaterialTakeoffReportModel? _report;
  bool _isLoading = false;
  bool _isSaving = false;
  final Map<String, double> _wasteFactors = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialReport != null) {
      _report = widget.initialReport;
      _initWasteFactors();
    } else {
      _loadTakeoff();
    }
  }

  void _initWasteFactors() {
    if (_report != null) {
      for (final item in _report!.items) {
        _wasteFactors[item.category] = item.wasteFactorPct;
      }
    }
  }

  Future<void> _loadTakeoff() async {
    setState(() => _isLoading = true);
    try {
      final rep = await ProjectService.fetchMaterialTakeoff(widget.roomId);
      if (mounted) {
        setState(() {
          _report = rep;
          _initWasteFactors();
        });
      }
    } catch (_) {
      // If none generated yet, compute standard takeoff
      await _recomputeTakeoff();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recomputeTakeoff() async {
    setState(() => _isSaving = true);
    try {
      final rep = await ProjectService.calculateMaterialTakeoff(
        roomId: widget.roomId,
        customWasteFactors: _wasteFactors.isNotEmpty ? _wasteFactors : null,
      );
      if (mounted) {
        setState(() {
          _report = rep;
          _initWasteFactors();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Material takeoff recalculated successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Failed to calculate material takeoff: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showVerifyDialog(CriticalDimensionVerificationModel dim) async {
    final valController = TextEditingController(
      text: (dim.verifiedValue ?? dim.estimatedValue).toStringAsFixed(2),
    );
    final surveyorController = TextEditingController(text: dim.verifiedBy ?? 'Site Contractor');
    final notesController = TextEditingController(text: dim.notes ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verify ${dim.label}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI Estimated: ${dim.estimatedValue.toStringAsFixed(2)} ${dim.unit} (±${dim.uncertaintyMarginPct.toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              if (dim.warningNote != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.warning.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.warning, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dim.warningNote!,
                          style: const TextStyle(fontSize: 11, color: AppTheme.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: valController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Physical On-Site Measurement (${dim.unit})',
                  suffixText: dim.unit,
                  helperText: dim.recommendedTool != null ? 'Tool: ${dim.recommendedTool}' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: surveyorController,
                decoration: const InputDecoration(
                  labelText: 'Surveyor / Verified By',
                  hintText: 'e.g. Master Flooring Contractor / Homeowner',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Site Inspection Notes (Optional)',
                  hintText: 'e.g. Uneven subfloor along north wall',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final val = double.tryParse(valController.text);
                    if (val == null || val <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid positive dimension')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _submitVerification(
                      dimensionId: dim.dimensionId,
                      verifiedValue: val,
                      verifiedBy: surveyorController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                  },
                  child: const Text('Confirm & Recalculate Quantities'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitVerification({
    required String dimensionId,
    required double verifiedValue,
    required String verifiedBy,
    String? notes,
  }) async {
    setState(() => _isSaving = true);
    try {
      final rep = await ProjectService.verifyTakeoffDimension(
        roomId: widget.roomId,
        dimensionId: dimensionId,
        verifiedValue: verifiedValue,
        verifiedBy: verifiedBy.isNotEmpty ? verifiedBy : 'Contractor',
        notes: notes,
      );
      if (mounted) {
        setState(() {
          _report = rep;
          _initWasteFactors();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Physical dimension verified! Material takeoff recalculated.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Verification update failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.roomName} Material Takeoff'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.accent),
              tooltip: 'Recalculate Takeoff',
              onPressed: _recomputeTakeoff,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _report == null
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calculate_outlined, size: 54, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No Material Takeoff Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
          ),
          const SizedBox(height: 8),
          const Text(
            'Compute surface-area derived materials with confidence bounds.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _recomputeTakeoff,
            child: const Text('Calculate Takeoff Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final rep = _report!;
    final isExact = rep.accuracyTier == 'EXACT';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Spatial Surface Overview Card
          _buildSurfaceMetricsOverview(rep, isExact),
          const SizedBox(height: 20),

          // 2. Critical Dimension Verification Checklist Card
          _buildCriticalDimensionsCard(rep),
          const SizedBox(height: 20),

          // 3. Materials & Quantities Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Materials & Allowances',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
              Text(
                '${rep.items.length} Categories',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Material Takeoff Items List
          ...rep.items.map((item) => _buildMaterialItemCard(item)),

          const SizedBox(height: 16),

          // 5. Update / Recalculate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _recomputeTakeoff,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Apply Custom Waste Allowances & Recalculate'),
            ),
          ),
          const SizedBox(height: 20),

          // 6. Architectural Disclaimers & Notes
          _buildDisclaimerSection(rep),
        ],
      ),
    );
  }

  Widget _buildSurfaceMetricsOverview(MaterialTakeoffReportModel rep, bool isExact) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Row(
                children: [
                  Icon(Icons.straighten, color: AppTheme.accent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Surface Quantity Takeoff',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isExact ? AppTheme.success : AppTheme.warning).withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isExact ? AppTheme.success : AppTheme.warning).withAlpha(80),
                  ),
                ),
                child: Text(
                  isExact ? 'EXACT (±3-8%)' : 'APPROXIMATE (±12-18%)',
                  style: TextStyle(
                    color: isExact ? AppTheme.success : AppTheme.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Net Wall Area',
                  '${rep.netWallAreaSqm.toStringAsFixed(1)} m²',
                  'After openings',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Floor Footprint',
                  '${rep.grossFloorAreaSqm.toStringAsFixed(1)} m²',
                  'Subfloor net',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Ceiling Area',
                  '${rep.ceilingAreaSqm.toStringAsFixed(1)} m²',
                  'Overhead flat',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Baseboard Run',
                  '${rep.baseboardPerimeterM.toStringAsFixed(1)} m',
                  'Net of thresholds',
                ),
              ),
            ],
          ),
          if (rep.openingsDeductedAreaSqm > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Structural deductions: ${rep.openingsDeductedAreaSqm.toStringAsFixed(2)} m² deducted across windows & doors.',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String subtitle) {
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
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildCriticalDimensionsCard(MaterialTakeoffReportModel rep) {
    final dims = rep.criticalDimensions;
    final unverifiedCount = rep.unverifiedDimensionsCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unverifiedCount > 0 ? AppTheme.warning.withAlpha(80) : AppTheme.success.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    unverifiedCount > 0 ? Icons.rule_folder_outlined : Icons.verified_user_outlined,
                    color: unverifiedCount > 0 ? AppTheme.warning : AppTheme.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'On-Site Physical Confirmation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (unverifiedCount > 0 ? AppTheme.warning : AppTheme.success).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  unverifiedCount > 0 ? '$unverifiedCount Unverified' : 'All Verified',
                  style: TextStyle(
                    color: unverifiedCount > 0 ? AppTheme.warning : AppTheme.success,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Physical cross-check with measuring tape or laser meter ensures precise order packages without shortages or excess.',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          ...dims.map((dim) => _buildCriticalDimensionRow(dim)),
        ],
      ),
    );
  }

  Widget _buildCriticalDimensionRow(CriticalDimensionVerificationModel dim) {
    final isVerified = dim.isVerified;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVerified ? AppTheme.success.withAlpha(60) : AppTheme.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 16,
            color: isVerified ? AppTheme.success : AppTheme.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dim.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMain,
                  ),
                ),
                Text(
                  dim.displayValue,
                  style: TextStyle(
                    fontSize: 11,
                    color: isVerified ? AppTheme.success : AppTheme.textMuted,
                  ),
                ),
                if (isVerified && dim.verifiedBy != null)
                  Text(
                    'Confirmed by: ${dim.verifiedBy}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 30),
              side: BorderSide(
                color: isVerified ? AppTheme.success : AppTheme.accent,
              ),
            ),
            onPressed: () => _showVerifyDialog(dim),
            child: Text(
              isVerified ? 'Edit' : 'Confirm',
              style: TextStyle(
                fontSize: 11,
                color: isVerified ? AppTheme.success : AppTheme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialItemCard(MaterialTakeoffItemModel item) {
    final currentWaste = _wasteFactors[item.category] ?? item.wasteFactorPct;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    Text(
                      item.categoryDisplayName,
                      style: const TextStyle(fontSize: 11, color: AppTheme.accent),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.formattedGrossQuantity,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                  Text(
                    'Net: ${item.netQuantity.toStringAsFixed(1)} ${item.unit}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          if (item.description != null) ...[
            const SizedBox(height: 6),
            Text(
              item.description!,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          // Waste factor slider
          Row(
            children: [
              Text(
                'Waste Factor Allowance: ${currentWaste.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMain),
              ),
              const Spacer(),
              Text(
                '+${item.wasteQuantity.toStringAsFixed(1)} ${item.unit}',
                style: const TextStyle(fontSize: 11, color: AppTheme.warning),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: currentWaste.clamp(5.0, 30.0),
              min: 5.0,
              max: 30.0,
              divisions: 25,
              activeColor: AppTheme.accent,
              inactiveColor: AppTheme.surfaceBorder,
              onChanged: (val) {
                setState(() {
                  _wasteFactors[item.category] = val;
                });
              },
            ),
          ),
          const SizedBox(height: 6),
          // Packaging & Uncertainty Bounds
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.packagingSpec != null)
                  Expanded(
                    child: Text(
                      '📦 ${item.estimatedPackages ?? 1}x ${item.packagingSpec}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMain),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  'Range: ${item.formattedRange}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (item.requiresContractorVerification) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 12, color: AppTheme.warning),
                const SizedBox(width: 4),
                const Text(
                  'Requires contractor verification before custom finish ordering.',
                  style: TextStyle(fontSize: 10, color: AppTheme.warning),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimerSection(MaterialTakeoffReportModel rep) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes, size: 16, color: AppTheme.textMuted),
              SizedBox(width: 6),
              Text(
                'Estimation Notes & Disclaimers',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMain),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...rep.notes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $note',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              )),
          const SizedBox(height: 6),
          const Text(
            'Roomlyst quantity models compute theoretical surface areas with configurable waste allowances. Actual on-site consumption may vary based on installer cutting patterns, subfloor conditions, and pattern repeat drops.',
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
