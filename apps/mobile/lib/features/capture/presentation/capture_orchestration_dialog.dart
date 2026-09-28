import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../capability/domain/device_capability.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';
import '../services/scan_orchestrator.dart';

/// Modal dialog displaying multi-tier scan orchestration, telemetry benchmarks,
/// active mode diagnostics, and manual override controls.
/// Fulfills Milestone 3.5.
class CaptureOrchestrationDialog extends StatefulWidget {
  final ScanOrchestrator orchestrator;
  final ValueChanged<ScanMode> onModeChanged;
  final List<TierBenchmarkMetricsModel>? initialBenchmarks;

  const CaptureOrchestrationDialog({
    super.key,
    required this.orchestrator,
    required this.onModeChanged,
    this.initialBenchmarks,
  });

  static Future<void> show(
    BuildContext context, {
    required ScanOrchestrator orchestrator,
    required ValueChanged<ScanMode> onModeChanged,
    List<TierBenchmarkMetricsModel>? initialBenchmarks,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CaptureOrchestrationDialog(
        orchestrator: orchestrator,
        onModeChanged: onModeChanged,
        initialBenchmarks: initialBenchmarks,
      ),
    );
  }

  @override
  State<CaptureOrchestrationDialog> createState() => _CaptureOrchestrationDialogState();
}

class _CaptureOrchestrationDialogState extends State<CaptureOrchestrationDialog> {
  late ScanMode _selectedMode;
  List<TierBenchmarkMetricsModel> _benchmarks = [];
  bool _isLoadingBenchmarks = true;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.orchestrator.currentMode;
    if (widget.initialBenchmarks != null) {
      _benchmarks = widget.initialBenchmarks!;
      _isLoadingBenchmarks = false;
    } else {
      _loadBenchmarks();
    }
  }

  Future<void> _loadBenchmarks() async {
    if (widget.initialBenchmarks != null) {
      _benchmarks = widget.initialBenchmarks!;
      _isLoadingBenchmarks = false;
      return;
    }
    if (widget.orchestrator.evaluation != null &&
        widget.orchestrator.evaluation!.allTierBenchmarks.isNotEmpty) {
      _benchmarks = widget.orchestrator.evaluation!.allTierBenchmarks;
      _isLoadingBenchmarks = false;
      return;
    }
    try {
      final list = await ProjectService.fetchScanTelemetryBenchmarks();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _benchmarks = list;
          _isLoadingBenchmarks = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingBenchmarks = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orch = widget.orchestrator;
    final isOverride = _selectedMode != orch.recommendedMode;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.accent, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan Mode Orchestrator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Adaptive 5-tier pipeline with graceful degradation',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Scrollable body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Fallback degradation alert if any
                if (orch.fallbackReason != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Step-down Fallback Triggered',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                orch.fallbackReason!,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Current Active Mode Card
                _buildActiveCard(orch, isOverride),
                const SizedBox(height: 20),

                // Manual Override Switcher
                const Text(
                  'Select Capture Tier',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _buildTierOption(
                  ScanMode.lidarScan,
                  'Tier 1: Apple RoomPlan LiDAR',
                  'Sub-centimeter accuracy (< 1cm) with native laser meshing',
                  Icons.view_in_ar,
                  supported: orch.deviceProfile.hasLiDAR,
                ),
                _buildTierOption(
                  ScanMode.arDepthScan,
                  'Tier 2: Android ARCore Depth / ToF',
                  'ToF hardware depth (~2-3cm) with instant surface normal extraction',
                  Icons.sensors,
                  supported: orch.deviceProfile.hasHardwareDepth || orch.deviceProfile.hasARCoreDepth,
                ),
                _buildTierOption(
                  ScanMode.arRgbScan,
                  'Tier 3: ARKit / ARCore Motion Odometry',
                  'Visual-Inertial Odometry (~3-5cm) tracking room boundaries',
                  Icons.speed,
                  supported: orch.deviceProfile.hasAR,
                ),
                _buildTierOption(
                  ScanMode.rgbVideoScan,
                  'Tier 4: Guided Monocular Video Sweep',
                  'HD keyframe sweep with SfM 3D sparse-to-dense point cloud (~5-8cm)',
                  Icons.videocam,
                  supported: orch.deviceProfile.hasMotionSensors,
                ),
                _buildTierOption(
                  ScanMode.rgbPhotoScan,
                  'Tier 5: Multi-Corner Photo Capture',
                  'Multi-view corner photos with optional A4/door scale calibration (~12cm)',
                  Icons.camera_alt,
                  supported: true,
                ),

                const SizedBox(height: 24),

                // Comparative Telemetry Benchmarks Table
                const Text(
                  'Comparative Telemetry Benchmarks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Empirical accuracy, capture latency, and cloud compute cost by tier',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
                const SizedBox(height: 12),
                _buildBenchmarkMatrix(),
              ],
            ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                if (isOverride)
                  TextButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset to Auto'),
                    onPressed: () {
                      setState(() {
                        _selectedMode = orch.recommendedMode;
                      });
                      orch.resetToRecommended();
                      widget.onModeChanged(orch.recommendedMode);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    if (_selectedMode != orch.currentMode) {
                      orch.setManualMode(_selectedMode);
                      widget.onModeChanged(_selectedMode);
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isOverride ? 'Apply Manual Tier' : 'Confirm Optimal Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(ScanOrchestrator orch, bool isOverride) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverride ? Colors.purpleAccent.withValues(alpha: 0.5) : AppTheme.accent.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverride ? Colors.purple.withValues(alpha: 0.2) : AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOverride ? 'MANUAL OVERRIDE' : 'OPTIMAL SELECTION',
                  style: TextStyle(
                    color: isOverride ? Colors.purpleAccent : AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                orch.currentTierId,
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            orch.currentTierName,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.verified, color: AppTheme.accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  orch.currentAccuracyAssurance,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  orch.currentGuidancePrompt,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierOption(
    ScanMode mode,
    String title,
    String subtitle,
    IconData icon, {
    required bool supported,
  }) {
    final isSelected = _selectedMode == mode;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.surface : AppTheme.surface.withValues(alpha: 0.6),
        border: Border.all(
          color: isSelected ? AppTheme.accent : Colors.white12,
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
        },
        leading: Icon(icon, color: isSelected ? AppTheme.accent : Colors.white54),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (!supported)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Sensor Emulated',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
        ),
        trailing: Icon(
          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: isSelected ? AppTheme.accent : Colors.white38,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildBenchmarkMatrix() {
    if (_isLoadingBenchmarks) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (_benchmarks.isEmpty) {
      // Fallback local standard benchmarks
      return _buildStaticBenchmarkTable();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surface),
        dataRowColor: WidgetStateProperty.all(AppTheme.surface),
        columns: const [
          DataColumn(label: Text('Tier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Accuracy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Capture Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Compute Latency', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Cost', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
        rows: _benchmarks.map((b) {
          final isCurrent = b.scanMode == widget.orchestrator.currentMode.id;
          return DataRow(
            color: isCurrent ? WidgetStateProperty.all(AppTheme.accent.withValues(alpha: 0.12)) : null,
            cells: [
              DataCell(Text(b.tierIdLabel, style: TextStyle(color: isCurrent ? AppTheme.accent : Colors.white))),
              DataCell(Text('${b.typicalAccuracyCm} cm (${b.accuracyTier})', style: const TextStyle(color: Colors.white70))),
              DataCell(Text('${b.meanCaptureTimeSec.toInt()}s', style: const TextStyle(color: Colors.white70))),
              DataCell(Text('${b.meanProcessingTimeSec.toInt()}s', style: const TextStyle(color: Colors.white70))),
              DataCell(Text('\$${b.relativeComputeCostUsd.toStringAsFixed(3)}', style: const TextStyle(color: Colors.white70))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStaticBenchmarkTable() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _benchmarkRow('Tier 1 LiDAR', '< 1.0 cm', '15s capture', '\$0.005'),
          const Divider(color: Colors.white10),
          _benchmarkRow('Tier 2 AR Depth', '~2.5 cm', '20s capture', '\$0.010'),
          const Divider(color: Colors.white10),
          _benchmarkRow('Tier 3 AR RGB', '~4.5 cm', '25s capture', '\$0.015'),
          const Divider(color: Colors.white10),
          _benchmarkRow('Tier 4 Video Sweep', '~7.5 cm', '30s capture', '\$0.025'),
          const Divider(color: Colors.white10),
          _benchmarkRow('Tier 5 Multi-Photo', '~12.0 cm', '45s capture', '\$0.020'),
        ],
      ),
    );
  }

  Widget _benchmarkRow(String tier, String accuracy, String time, String cost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tier, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(accuracy, style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
          Text(time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(cost, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

extension on TierBenchmarkMetricsModel {
  String get tierIdLabel {
    switch (tierId) {
      case 'TIER_1_LIDAR':
        return 'T1 LiDAR';
      case 'TIER_2_AR_DEPTH':
        return 'T2 AR Depth';
      case 'TIER_3_AR_RGB':
        return 'T3 AR RGB';
      case 'TIER_4_VIDEO_SWEEP':
        return 'T4 Video';
      default:
        return 'T5 Photo';
    }
  }
}
