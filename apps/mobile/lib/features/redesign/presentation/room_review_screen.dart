import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';
import 'design_results_screen.dart';
import 'element_correction_screen.dart';
import '../../capture/presentation/reconstruction_viewer_screen.dart';
import '../../capture/presentation/ar_session_screen.dart';
import '../../capture/presentation/lidar_scan_screen.dart';
import '../../renovation/presentation/material_takeoff_screen.dart';
import '../../renovation/presentation/renovation_budget_planner_screen.dart';
import '../../renovation/presentation/product_recommendations_screen.dart';

class RoomReviewScreen extends StatefulWidget {
  final RoomModelData room;
  final String projectId;

  const RoomReviewScreen({
    super.key,
    required this.room,
    required this.projectId,
  });

  @override
  State<RoomReviewScreen> createState() => _RoomReviewScreenState();
}

class _RoomReviewScreenState extends State<RoomReviewScreen> {
  late RoomModelData _currentRoom;
  String _selectedStyle = 'Warm Modern Minimalist';
  String _selectedCurrency = 'MYR';
  String _selectedTier = 'MODERATE';
  final _budgetController = TextEditingController(text: '15000');
  final _promptController = TextEditingController(text: 'Keep sofa and windows. Change floor to oak.');
  bool _isGenerating = false;
  bool _isCalibrating = false;
  bool _isCalculatingBudget = false;
  bool _isReconstructing = false;
  BudgetPlanModel? _budgetPlan;
  ProductRecommendationReportModel? _productRecommendations;

  final List<String> _styles = [
    'Warm Modern Minimalist',
    'Japandi Clean Organic',
    'Contemporary Scandinavian',
    'Modern Industrial Loft',
  ];

  final List<Map<String, String>> _currencies = [
    {'code': 'MYR', 'symbol': 'RM', 'name': 'MYR (RM)'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'SGD (S\$)'},
    {'code': 'USD', 'symbol': '\$', 'name': 'USD (\$)'},
    {'code': 'EUR', 'symbol': '€', 'name': 'EUR (€)'},
    {'code': 'GBP', 'symbol': '£', 'name': 'GBP (£)'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'AUD (A\$)'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'CAD (C\$)'},
  ];

  final List<String> _tiers = ['ECONOMY', 'MODERATE', 'PREMIUM', 'LUXURY'];

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
    _budgetPlan = widget.room.budgetPlan;
    _productRecommendations = widget.room.productRecommendations;
    if (_budgetPlan != null) {
      _selectedCurrency = _budgetPlan!.currency;
      _selectedTier = _budgetPlan!.renovationTier;
      _budgetController.text = _budgetPlan!.totalBudget.toStringAsFixed(0);
    }
  }

  Future<void> _recalculateBudget() async {
    setState(() => _isCalculatingBudget = true);
    try {
      final totalBudget = double.tryParse(_budgetController.text) ?? 15000.0;
      final plan = await ProjectService.calculateRoomBudget(
        roomId: _currentRoom.id,
        totalBudget: totalBudget,
        currency: _selectedCurrency,
        renovationTier: _selectedTier,
      );
      setState(() {
        _budgetPlan = plan;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Renovation budget plan updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budget error: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculatingBudget = false);
    }
  }

  Future<void> _generateRedesigns() async {
    setState(() => _isGenerating = true);
    try {
      final variants = await ProjectService.generateRedesigns(
        roomId: _currentRoom.id,
        styles: [_selectedStyle],
        budgetAmount: double.tryParse(_budgetController.text) ?? 15000.0,
        budgetCurrency: _selectedCurrency,
        renovationTier: _selectedTier,
        prompt: _promptController.text,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DesignResultsScreen(
              variants: variants,
              roomName: _currentRoom.name,
              roomId: _currentRoom.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation error: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _runReconstruction() async {
    setState(() => _isReconstructing = true);
    try {
      final report = await ProjectService.runSfmPipeline(roomId: _currentRoom.id);
      final updatedRoom = await ProjectService.fetchRoomModel(_currentRoom.id);
      if (mounted) {
        setState(() {
          _currentRoom = updatedRoom;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(
              '3D SfM Reconstruction complete! ${report.pointCloud.vertexCount} vertices, ${report.extractedPlanes.length} spatial planes aligned.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Reconstruction failed: ${e.toString().replaceAll("Exception: ", "")}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReconstructing = false);
    }
  }

  void _showCalibrationBottomSheet() {
    String selectedPreset = 'KNOWN_WALL_DIMENSION';
    String dimensionType = 'width';
    final valController = TextEditingController(text: '3.80');

    final presets = [
      {'id': 'KNOWN_WALL_DIMENSION', 'name': 'Known Wall Dimension', 'val': '3.80', 'type': 'width'},
      {'id': 'STANDARD_DOOR_HEIGHT', 'name': 'Standard Door Height (2.10m)', 'val': '2.10', 'type': 'height'},
      {'id': 'A4_PAPER', 'name': 'A4 Paper (29.7cm)', 'val': '0.297', 'type': 'width'},
      {'id': 'FLOOR_TILE_60', 'name': 'Floor Tile 60x60cm', 'val': '0.60', 'type': 'width'},
      {'id': 'FLOOR_TILE_30', 'name': 'Floor Tile 30x30cm', 'val': '0.30', 'type': 'width'},
      {'id': 'CREDIT_CARD', 'name': 'Credit Card (8.56cm)', 'val': '0.086', 'type': 'width'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Calibrate Room Scale',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textMain),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'Select a known reference object or wall measurement to proportionally calibrate room geometry.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reference Object Preset',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.accent),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPreset,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: presets.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['id'],
                        child: Text(p['name']!, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final found = presets.firstWhere((p) => p['id'] == val);
                        setModalState(() {
                          selectedPreset = val;
                          valController.text = found['val']!;
                          dimensionType = found['type']!;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: valController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Actual Dimension (meters)',
                      suffixText: 'm',
                      helperText: selectedPreset == 'A4_PAPER'
                          ? 'Place an A4 sheet on the floor or wall'
                          : selectedPreset == 'STANDARD_DOOR_HEIGHT'
                              ? 'Standard residential door frame is ~2.10m'
                              : 'Real tape measurement of wall width or item',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCalibrating
                          ? null
                          : () async {
                              final targetVal = double.tryParse(valController.text);
                              if (targetVal == null || targetVal <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid positive dimension')),
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              await _performCalibration(selectedPreset, targetVal, dimensionType);
                            },
                      child: const Text('Apply Calibration & Rescale'),
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

  Future<void> _performCalibration(String preset, double targetVal, String dimType) async {
    setState(() => _isCalibrating = true);
    try {
      final res = await ApiClient.calibrateRoomScale(
        roomId: _currentRoom.id,
        referenceType: preset,
        targetRealValue: targetVal,
        referenceDimensionType: dimType,
      );
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _currentRoom = RoomModelData.fromMap(res);
        });
        final factor = _currentRoom.scaleCalibration?.scaleFactor ?? 1.0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Room calibrated! Rescaled by ${factor.toStringAsFixed(3)}x. Provenance upgraded to REFERENCE_SCALED.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Scale calibration failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalibrating = false);
    }
  }

  void _showVerifyMeasurementDialog(MeasurementModel meas) {
    final ctrl = TextEditingController(text: meas.value.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Verify ${meas.readableType}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current estimated value: ${meas.formattedValue} (${meas.source})',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Verified Value (${meas.unit})',
                suffixText: meas.unit,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val == null || val <= 0) return;
              Navigator.pop(ctx);
              try {
                await ApiClient.verifyMeasurement(
                  roomId: _currentRoom.id,
                  measurementId: meas.id,
                  verifiedValue: val,
                );
                setState(() {
                  meas.value = val;
                  meas.verifiedByUser = true;
                  meas.source = 'USER_VERIFIED';
                  meas.accuracyTier = 'EXACT';
                  meas.isApproximate = false;
                  meas.confidence = 1.0;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.success,
                      content: Text('${meas.readableType} verified as ${meas.formattedValue}!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Verification error: $e')),
                  );
                }
              }
            },
            child: const Text('Confirm Measurement'),
          ),
        ],
      ),
    );
  }

  Widget _buildElementRow(DetectedElement elem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  elem.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (elem.subtitle != null)
                  Text(
                    '${elem.subtitle} · ${(elem.confidence * 100).toInt()}% conf.',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: elem.action,
            underline: const SizedBox(),
            dropdownColor: AppTheme.surface,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent),
            items: const [
              DropdownMenuItem(value: 'KEEP', child: Text('Keep (Anchor)')),
              DropdownMenuItem(value: 'REPLACE', child: Text('Replace')),
              DropdownMenuItem(value: 'REMOVE', child: Text('Remove')),
              DropdownMenuItem(value: 'RESTYLE', child: Text('Restyle')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => elem.action = val);
                ProjectService.updateElementAction(_currentRoom.id, elem.id, val);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementRow(MeasurementModel meas) {
    final isVerified = meas.verifiedByUser;
    final isExact = meas.accuracyTier == 'EXACT';

    Color badgeColor = AppTheme.warning;
    if (isVerified) {
      badgeColor = AppTheme.success;
    } else if (meas.source == 'REFERENCE_SCALED') {
      badgeColor = AppTheme.accent;
    } else if (meas.source == 'LIDAR_VERIFIED') {
      badgeColor = Colors.purpleAccent;
    } else if (meas.source == 'MULTIVIEW_RECONSTRUCTION') {
      badgeColor = AppTheme.primary;
    } else if (meas.source == 'AR_MOTION_VERIFIED' || meas.source == 'AR_DEPTH_FROM_MOTION') {
      badgeColor = Colors.teal;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isVerified ? AppTheme.success.withAlpha(80) : AppTheme.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      meas.readableType,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor.withAlpha(90), width: 0.8),
                      ),
                      child: Text(
                        meas.source,
                        style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isExact) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'EXACT',
                          style: TextStyle(color: AppTheme.success, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  meas.formattedValue,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMain,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 32),
              side: BorderSide(
                color: isVerified ? AppTheme.success : AppTheme.surfaceBorder,
              ),
            ),
            onPressed: () => _showVerifyMeasurementDialog(meas),
            icon: Icon(
              isVerified ? Icons.check_circle : Icons.tune,
              size: 14,
              color: isVerified ? AppTheme.success : AppTheme.accent,
            ),
            label: Text(
              isVerified ? 'Verified' : 'Verify',
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

  Widget _buildScaleCalibrationBanner() {
    final calib = _currentRoom.scaleCalibration;
    final isCalibrated = calib != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCalibrated ? AppTheme.success.withAlpha(20) : AppTheme.warning.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCalibrated ? AppTheme.success.withAlpha(60) : AppTheme.warning.withAlpha(60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCalibrated ? Icons.verified_outlined : Icons.straighten_outlined,
                color: isCalibrated ? AppTheme.success : AppTheme.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCalibrated
                      ? 'Scale Calibrated (${calib.scaleFactor.toStringAsFixed(3)}x)'
                      : 'Approximate Dimensions',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isCalibrated ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(50, 30),
                ),
                onPressed: _showCalibrationBottomSheet,
                icon: const Icon(Icons.aspect_ratio, size: 14, color: AppTheme.accent),
                label: Text(
                  isCalibrated ? 'Recalibrate' : 'Calibrate Scale',
                  style: const TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isCalibrated
                ? 'Calibrated using ${calib.referenceType.replaceAll('_', ' ')}. Dimensions and areas are scaled with high geometric consistency.'
                : 'Measurements are AI estimations. Use an A4 paper, standard door height, or known wall length to calibrate.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildGeometryAndFeasibilitySection() {
    final geom = _currentRoom.geometry;
    final report = _currentRoom.feasibilityReport;

    final isLoopClosed = geom?.isClosed ?? true;
    final shapeName = geom?.roomShape.replaceAll('_', ' ') ?? 'RECTANGULAR';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Row(
                children: [
                  const Icon(Icons.architecture_outlined, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Geometry & Shape ($shapeName)',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isLoopClosed ? AppTheme.success : AppTheme.warning).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isLoopClosed ? AppTheme.success : AppTheme.warning).withAlpha(90),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isLoopClosed ? 'LOOP CLOSED' : 'LOOP UNCLOSED',
                  style: TextStyle(
                    color: isLoopClosed ? AppTheme.success : AppTheme.warning,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (geom != null && geom.perimeterM != null) ...[
            const SizedBox(height: 6),
            Text(
              'Perimeter: ${geom.perimeterM!.toStringAsFixed(2)}m · Walls: ${geom.wallSegments.length} segments · Vertices: ${geom.polygonVertices.length}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: AppTheme.surfaceBorder, height: 1),
          const SizedBox(height: 12),

          // Feasibility & Clearance Checks
          Row(
            children: [
              Icon(
                report?.overallFeasible == false ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: report?.overallFeasible == false ? AppTheme.warning : AppTheme.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  report?.overallFeasible == false
                      ? 'Feasibility Warnings (${report?.warningIssuesCount ?? 0} warning, ${report?.criticalIssuesCount ?? 0} critical)'
                      : 'Physical Clearances Pass',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: report?.overallFeasible == false ? AppTheme.warning : AppTheme.success,
                  ),
                ),
              ),
              if (report?.minWalkwayClearanceM != null)
                Text(
                  'Min Walkway: ${report!.minWalkwayClearanceM!.toStringAsFixed(2)}m',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            report?.summary ?? 'Automated clearance checks between doors, furniture, and walkways.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          if (report != null && report.checks.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...report.checks.take(4).map((chk) {
              final isCrit = chk.severity == 'CRITICAL';
              final isWarn = chk.severity == 'WARNING';
              final color = isCrit ? AppTheme.danger : (isWarn ? AppTheme.warning : AppTheme.success);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      chk.passed ? Icons.check : (isCrit ? Icons.error_outline : Icons.info_outline),
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chk.message,
                            style: TextStyle(fontSize: 11, color: chk.passed ? AppTheme.textMain : color),
                          ),
                          if (chk.suggestedAction != null)
                            Text(
                              'Action: ${chk.suggestedAction!}',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildReconstructionSection() {
    final report = _currentRoom.reconstructionReport;
    final planes = _currentRoom.spatialPlanes.isNotEmpty
        ? _currentRoom.spatialPlanes
        : (report?.extractedPlanes ?? []);
    final hasReconstruction = report != null || planes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              const Row(
                children: [
                  Icon(Icons.view_in_ar, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Multi-View 3D Reconstruction',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                  ),
                ],
              ),
              if (hasReconstruction)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primary.withAlpha(90), width: 0.8),
                  ),
                  child: Text(
                    report?.spatialConsistencyTier.replaceAll('_', ' ') ?? 'TIER 1 CONSISTENT',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasReconstruction) ...[
            Text(
              'Dense point cloud: ${report?.pointCloud.vertexCount ?? 2000}+ vertices · ${planes.length} architectural planes fitted (RANSAC).',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.explore_outlined, size: 16),
                label: const Text('View 3D Point Cloud & Extracted Planes', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReconstructionViewerScreen(
                        roomId: _currentRoom.id,
                        roomName: _currentRoom.name,
                        initialReport: report,
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            const Text(
              'Perform multi-view camera-pose estimation & SfM point cloud reconstruction to upgrade monocular dimensions with spatial consistency.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  backgroundColor: AppTheme.surfaceBorder,
                  foregroundColor: AppTheme.primary,
                ),
                icon: _isReconstructing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_outlined, size: 16),
                label: Text(
                  _isReconstructing ? 'Reconstructing 3D Room...' : 'Run Multi-View SfM Pipeline',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: _isReconstructing ? null : _runReconstruction,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildARAssistedSection() {
    final arReport = _currentRoom.arAssistedReport;
    final hasReport = arReport != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Row(
                children: [
                  Icon(Icons.track_changes, color: Colors.teal.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'AR Non-LiDAR Motion Fusion',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                  ),
                ],
              ),
              if (hasReport)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.teal.withAlpha(90), width: 0.8),
                  ),
                  child: Text(
                    arReport.isScaleReliable ? 'METRIC VALIDATED' : 'PROVISIONAL',
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasReport) ...[
            Text(
              'VIO Trajectory: ${arReport.trajectoryLengthMeters.toStringAsFixed(2)}m · Scale: ${arReport.metricScaleFactor.toStringAsFixed(3)}x · ${(arReport.overallConfidence * 100).toStringAsFixed(1)}% confidence.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Text(
              'Use ARCore / ARKit Visual-Inertial Odometry and depth-from-motion to scale and verify 3D reconstructions without LiDAR hardware.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.explore_outlined, size: 16),
              label: Text(
                hasReport ? 'View AR Motion Telemetry & Recalibrate' : 'Open AR Odometry & Motion Studio',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ARSessionScreen(
                      roomId: _currentRoom.id,
                      roomName: _currentRoom.name,
                      initialReport: arReport,
                    ),
                  ),
                );
                // Reload room model if possible
                try {
                  final updatedRoom = await ProjectService.fetchRoomModel(_currentRoom.id);
                  if (mounted) {
                    setState(() => _currentRoom = updatedRoom);
                  }
                } catch (_) {}
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeSpatialSection() {
    final spatialReport = _currentRoom.nativeSpatialReport;
    final hasReport = spatialReport != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Row(
                children: [
                  Icon(Icons.radar, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Hardware LiDAR & Native Spatial Mesh',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                  ),
                ],
              ),
              if (hasReport)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withAlpha(90), width: 0.8),
                  ),
                  child: Text(
                    spatialReport.provenance,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasReport) ...[
            Text(
              '${spatialReport.framework} · ${spatialReport.surfacesCount} surfaces · ${spatialReport.openingsCount} openings · ${spatialReport.objectsCount} objects · ${(spatialReport.confidenceScore * 100).toStringAsFixed(0)}% confidence (Exact sub-cm scale).',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Text(
              'Capture sub-centimeter exact room models with native Apple RoomPlan (LiDAR) or Android ToF hardware depth, bypassing optical scale ambiguities.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.radar_outlined, size: 16),
              label: Text(
                hasReport ? 'View Native Spatial Scan / Rescan' : 'Open Hardware LiDAR & Depth Scanner',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiDARScanScreen(
                      roomId: _currentRoom.id,
                      roomName: _currentRoom.name,
                      initialReport: spatialReport,
                    ),
                  ),
                );
                try {
                  final updatedRoom = await ProjectService.fetchRoomModel(_currentRoom.id);
                  if (mounted) {
                    setState(() => _currentRoom = updatedRoom);
                  }
                } catch (_) {}
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSection() {
    final currencyObj = _currencies.firstWhere(
      (c) => c['code'] == _selectedCurrency,
      orElse: () => {'code': 'MYR', 'symbol': 'RM', 'name': 'MYR (RM)'},
    );
    final symbol = currencyObj['symbol'] ?? 'RM';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: AppTheme.accent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Budget Intelligence',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              if (_budgetPlan != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _budgetPlan!.isWithinBudget ? AppTheme.primary.withAlpha(40) : Colors.red.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _budgetPlan!.isWithinBudget ? AppTheme.primary : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _budgetPlan!.isWithinBudget ? 'WITHIN BUDGET' : 'OVER BUDGET',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _budgetPlan!.isWithinBudget ? AppTheme.primary : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Currency & Tier Selectors
          Row(
            children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: _currencies.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['code'],
                      child: Text(c['name']!, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCurrency = val);
                      _recalculateBudget();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedTier,
                  decoration: const InputDecoration(
                    labelText: 'Finish Tier',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: _tiers.map((t) {
                    return DropdownMenuItem<String>(
                      value: t,
                      child: Text(t, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedTier = val);
                      _recalculateBudget();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Budget Input + Recalculate Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Renovation Budget Target',
                    prefixText: '$symbol ',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  backgroundColor: AppTheme.surfaceBorder,
                  foregroundColor: AppTheme.accent,
                ),
                onPressed: _isCalculatingBudget ? null : _recalculateBudget,
                icon: _isCalculatingBudget
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.calculate_outlined, size: 16),
                label: const Text('Calculate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Budget Breakdown Display
          if (_budgetPlan != null) ...[
            // Total & Kept Savings Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBorder.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Estimated Cost:',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      Text(
                        '$symbol ${_budgetPlan!.totalEstimatedCost.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _budgetPlan!.isWithinBudget ? AppTheme.textMain : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Remaining Buffer:',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      Text(
                        '$symbol ${_budgetPlan!.remainingBudget.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _budgetPlan!.remainingBudget >= 0 ? AppTheme.primary : Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  if (_budgetPlan!.savingsFromKeptItems > 0) ...[
                    const Divider(height: 12, color: AppTheme.surfaceBorder),
                    Row(
                      children: [
                        const Icon(Icons.savings_outlined, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '+$symbol ${_budgetPlan!.savingsFromKeptItems.toStringAsFixed(0)} saved by keeping items',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Category Cost Breakdown
            const Text(
              'Category Allocations',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent),
            ),
            const SizedBox(height: 6),
            ..._budgetPlan!.allocatedItems.map((item) {
              final double ratio = item.allocatedAmount > 0
                  ? (item.estimatedCost / item.allocatedAmount).clamp(0.0, 1.0)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.categoryName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(
                          '$symbol ${item.estimatedCost.toStringAsFixed(0)} / $symbol ${item.allocatedAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isOverBudget ? Colors.red : AppTheme.textMuted,
                            fontWeight: item.isOverBudget ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 4,
                        backgroundColor: AppTheme.surfaceBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          item.isOverBudget ? Colors.red : AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),

            // Keep vs Replace Trade-offs
            if (_budgetPlan!.tradeoffs.isNotEmpty) ...[
              const Text(
                'Keep-vs-Replace Trade-offs',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent),
              ),
              const SizedBox(height: 6),
              ..._budgetPlan!.tradeoffs.take(4).map((t) {
                final isKept = t.action == 'keep';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        isKept ? Icons.check_circle_outline : Icons.change_circle_outlined,
                        size: 14,
                        color: isKept ? AppTheme.primary : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          t.elementLabel,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        isKept
                            ? 'Saved $symbol ${t.savingsIfKept.toStringAsFixed(0)}'
                            : 'Est. $symbol ${t.replacementCostEstimate.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isKept ? AppTheme.primary : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],

            // Indicative Disclaimer Container (Blueprint Section 34)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withAlpha(60)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _budgetPlan!.disclaimer,
                      style: const TextStyle(fontSize: 10, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calculate_outlined, size: 16),
                label: const Text('Open Detailed Renovation Planner', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RenovationBudgetPlannerScreen(
                        roomId: widget.room.id,
                        initialBudgetPlan: _budgetPlan,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaterialTakeoffSection() {
    final takeoff = _currentRoom.materialTakeoff;
    final isExact = takeoff?.accuracyTier == 'EXACT';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: AppTheme.accent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Material & Quantity Takeoff',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (isExact ? AppTheme.success : AppTheme.warning).withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isExact ? 'EXACT (±3-8%)' : 'APPROXIMATE (±12-18%)',
                  style: TextStyle(
                    color: isExact ? AppTheme.success : AppTheme.warning,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            takeoff != null
                ? 'Surface-area bill of materials: ${takeoff.items.length} categories computed with packaging allowances.'
                : 'Automated surface quantities for flooring, wall paint, baseboards, and tiles with configurable waste factors.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          if (takeoff != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Floor: ${takeoff.grossFloorAreaSqm.toStringAsFixed(1)} m²',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Walls: ${takeoff.netWallAreaSqm.toStringAsFixed(1)} m²',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Trim: ${takeoff.baseboardPerimeterM.toStringAsFixed(1)} m',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accent),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MaterialTakeoffScreen(
                      roomId: _currentRoom.id,
                      roomName: _currentRoom.name,
                      initialReport: _currentRoom.materialTakeoff,
                    ),
                  ),
                );
                try {
                  final refreshed = await ProjectService.fetchRoomModel(_currentRoom.id);
                  if (mounted) setState(() => _currentRoom = refreshed);
                } catch (_) {}
              },
              icon: const Icon(Icons.calculate_outlined, size: 16, color: AppTheme.accent),
              label: const Text(
                'Open Material Takeoff & Waste Allowances',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRecommendationsSection() {
    final recs = _productRecommendations ?? _currentRoom.productRecommendations;
    final totalRecs = recs?.recommendations.length ?? 0;
    final perfectRecs = recs?.recommendations.where((r) => r.fitStatus == 'PERFECT_FIT').length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              const Row(
                children: [
                  Icon(Icons.chair_outlined, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Curated Product Catalogue',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                  ),
                ],
              ),
              if (recs != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.success.withAlpha(90), width: 0.8),
                  ),
                  child: Text(
                    '$perfectRecs PERFECT FIT',
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recs != null
                ? 'Curated items: $totalRecs verified products across ${_selectedTier.toLowerCase()} tier with physical clearance validation.'
                : 'Automated furniture & decor recommendations matching replaced elements, budget tier, and room geometry.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          if (recs != null && recs.recommendations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Catalogue Spend: ${recs.formattedSpend}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                  ),
                ),
                Text(
                  'Style: ${recs.appliedStyle}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductRecommendationsScreen(
                      roomId: _currentRoom.id,
                      roomName: _currentRoom.name,
                      initialReport: recs,
                      initialStyle: _selectedStyle,
                      initialTier: _selectedTier,
                      initialCurrency: _selectedCurrency,
                    ),
                  ),
                );
                try {
                  final refreshed = await ProjectService.fetchRoomModel(_currentRoom.id);
                  if (mounted) {
                    setState(() {
                      _currentRoom = refreshed;
                      _productRecommendations = refreshed.productRecommendations;
                    });
                  }
                } catch (_) {}
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 16, color: AppTheme.primary),
              label: const Text(
                'Open Product Catalogue & Spatial Fit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Room Understanding'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final updated = await Navigator.push<RoomModelData>(
                context,
                MaterialPageRoute(
                  builder: (_) => ElementCorrectionScreen(room: _currentRoom),
                ),
              );
              if (updated != null && mounted) {
                setState(() {
                  _currentRoom = updated;
                });
              }
            },
            icon: const Icon(Icons.edit_note, size: 18, color: AppTheme.accent),
            label: const Text('Correct AI', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spatial Measurements & Scale Calibration Section
            const Text(
              'Spatial Measurements & Scale',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
            ),
            const SizedBox(height: 8),
            _buildScaleCalibrationBanner(),
            if (_currentRoom.measurements.isNotEmpty) ...[
              ..._currentRoom.measurements.map(_buildMeasurementRow),
              const SizedBox(height: 16),
            ],

            // Geometry and Feasibility Intelligence Section
            const Text(
              'Spatial Geometry & Feasibility',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
            ),
            const SizedBox(height: 8),
            _buildGeometryAndFeasibilitySection(),

            // Multi-View 3D Reconstruction Section
            _buildReconstructionSection(),

            // AR Non-LiDAR Motion Fusion Section (Milestone 3.3)
            _buildARAssistedSection(),

            // Native Spatial & LiDAR Scanning Section (Milestone 3.4)
            _buildNativeSpatialSection(),

            // Structural Anchors Section
            const Text(
              'Architectural Openings (Preserved)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
            ),
            const SizedBox(height: 8),
            ..._currentRoom.openings.map(_buildElementRow),
            const SizedBox(height: 16),

            // Surfaces Section
            const Text(
              'Surfaces & Finishes',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
            ),
            const SizedBox(height: 8),
            ..._currentRoom.surfaces.map(_buildElementRow),
            const SizedBox(height: 16),

            // Furniture Section
            const Text(
              'Detected Furniture & Items',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
            ),
            const SizedBox(height: 8),
            ..._currentRoom.objects.map(_buildElementRow),
            const SizedBox(height: 24),

            // Renovation Budget & Trade-Offs Section (Milestone 2.4 & 4.2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Renovation Budget & Trade-Offs',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RenovationBudgetPlannerScreen(
                          roomId: widget.room.id,
                          initialBudgetPlan: _budgetPlan,
                        ),
                      ),
                    );
                  },
                  child: const Text('Detailed Planner', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBudgetSection(),
            const SizedBox(height: 16),

            // Material and Quantity Estimation Section (Milestone 4.1)
            const Text(
              'Material & Quantity Estimation',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
            ),
            const SizedBox(height: 8),
            _buildMaterialTakeoffSection(),
            const SizedBox(height: 16),

            // Product & Catalogue Recommendations Section (Milestone 4.3)
            const Text(
              'Curated Products & Spatial Fit',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
            ),
            const SizedBox(height: 8),
            _buildProductRecommendationsSection(),
            const SizedBox(height: 24),

            const Divider(color: AppTheme.surfaceBorder),
            const SizedBox(height: 16),

            // Style Preference Selector
            const Text(
              'Select Target Aesthetic Style',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _styles.map((style) {
                final isSelected = _selectedStyle == style;
                return ChoiceChip(
                  label: Text(style),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedStyle = style);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Free-Text Instruction
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Specific Goals & Instructions',
                hintText: 'e.g. Keep sofa. Modernize lighting and flooring.',
              ),
            ),
            const SizedBox(height: 28),

            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateRedesigns,
                child: _isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Synthesizing 3 Redesigns...'),
                        ],
                      )
                    : const Text('Generate 3 Structurally Preserved Concepts'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

