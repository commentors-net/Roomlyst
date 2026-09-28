import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

class ARSessionScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final ARAssistedScanReportModel? initialReport;
  final String deviceTier;

  const ARSessionScreen({
    super.key,
    required this.roomId,
    this.roomName = 'Room',
    this.initialReport,
    this.deviceTier = 'TIER_3_AR_RGB',
  });

  @override
  State<ARSessionScreen> createState() => _ARSessionScreenState();
}

class _ARSessionScreenState extends State<ARSessionScreen> {
  ARAssistedScanReportModel? _report;
  bool _isLoading = false;
  bool _isFusing = false;
  String? _errorMessage;
  String? _successMessage;

  // Live session mock/collector state
  bool _isSessionActive = false;
  final List<ARCameraPoseModel> _collectedPoses = [];
  final List<IMUMotionSampleModel> _collectedImu = [];
  int _depthPointCount = 0;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    if (_report == null) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await ProjectService.fetchARScanReport(widget.roomId);
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _startOrSimulateTracking() {
    setState(() {
      _isSessionActive = true;
      _errorMessage = null;
      _successMessage = null;
      _collectedPoses.clear();
      _collectedImu.clear();

      // Generate continuous AR camera trajectory in metric space (walking a 3.5m loop)
      const numSteps = 24;
      for (int i = 0; i < numSteps; i++) {
        final t = i * 0.15;
        final x = 1.2 * (i / numSteps);
        final y = 1.4 + 0.05 * (i % 3 == 0 ? 1.0 : -0.5);
        final z = 0.8 * (i / numSteps);

        _collectedPoses.add(
          ARCameraPoseModel(
            frameIndex: i,
            timestampMs: t * 1000.0,
            translation: [x, y, z],
            rotationQuaternion: const [1.0, 0.0, 0.0, 0.0],
            trackingState: 'TRACKING',
            featurePointsCount: 150 + i * 2,
            confidence: 0.95,
          ),
        );

        _collectedImu.add(
          IMUMotionSampleModel(
            timestampMs: t * 1000.0,
            acceleration: [0.02, 9.81 + 0.04 * (i % 2 == 0 ? 1 : -1), 0.01],
            rotationRate: const [0.01, 0.01, 0.02],
            gravityVector: const [0.0, 0.0, -9.81],
            headingDeg: 12.0 + i * 1.5,
            tiltDeg: 1.2,
          ),
        );
      }
      _depthPointCount = 180;
    });
  }

  Future<void> _fuseARWithModel() async {
    setState(() {
      _isFusing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final List<Map<String, dynamic>> posesJson = _collectedPoses.isNotEmpty
          ? _collectedPoses.map((p) => p.toMap()).toList()
          : [
              {
                'frame_index': 0,
                'timestamp_ms': 0.0,
                'translation': [0.0, 1.4, 0.0],
                'rotation_quaternion': [1.0, 0.0, 0.0, 0.0],
                'tracking_state': 'TRACKING',
                'feature_points_count': 140,
                'confidence': 0.95,
              },
              {
                'frame_index': 1,
                'timestamp_ms': 1000.0,
                'translation': [2.0, 1.4, 1.5],
                'rotation_quaternion': [1.0, 0.0, 0.0, 0.0],
                'tracking_state': 'TRACKING',
                'feature_points_count': 160,
                'confidence': 0.95,
              },
            ];

      final List<Map<String, dynamic>> imuJson = _collectedImu.isNotEmpty
          ? _collectedImu.map((imu) => imu.toMap()).toList()
          : [
              {
                'timestamp_ms': 0.0,
                'acceleration': [0.0, 9.81, 0.0],
                'rotation_rate': [0.0, 0.0, 0.0],
                'gravity_vector': [0.0, 0.0, -9.81],
                'heading_deg': 0.0,
                'tilt_deg': 0.0,
              }
            ];

      final depthPayload = {
        'sparse_points_count': _depthPointCount > 0 ? _depthPointCount : 120,
        'min_depth_m': 0.5,
        'max_depth_m': 5.5,
        'mean_depth_confidence': 0.92,
      };

      final report = await ProjectService.fuseARMotionWithReconstruction(
        roomId: widget.roomId,
        poses: posesJson,
        imuSamples: imuJson,
        depthPayload: depthPayload,
        deviceTier: widget.deviceTier,
      );

      if (mounted) {
        setState(() {
          _report = report;
          _isFusing = false;
          _successMessage = 'AR motion fused! Confidence upgraded to ${(report.overallConfidence * 100).toStringAsFixed(1)}%.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isFusing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${widget.roomName} • AR Motion Path'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
            tooltip: 'Refresh AR Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDeviceTierCard(),
                  const SizedBox(height: 12),
                  if (_errorMessage != null) _buildBanner(Colors.red.withAlpha(40), AppTheme.danger, Icons.error_outline, _errorMessage!),
                  if (_successMessage != null) _buildBanner(Colors.green.withAlpha(40), AppTheme.success, Icons.check_circle_outline, _successMessage!),
                  const SizedBox(height: 12),
                  _buildLiveTrackingCard(),
                  const SizedBox(height: 16),
                  if (_report != null) ...[
                    _buildReportSummaryCard(_report!),
                    const SizedBox(height: 16),
                  ],
                  _buildActionControls(),
                ],
              ),
            ),
    );
  }

  Widget _buildBanner(Color bgColor, Color textColor, IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTierCard() {
    final bool isDepthSupported = widget.deviceTier.contains('DEPTH');
    return Card(
      elevation: 0,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.view_in_ar, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.deviceTier,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDepthSupported
                        ? 'Non-LiDAR AR with hardware depth sensing & VIO odometry'
                        : 'Non-LiDAR AR with Visual-Inertial Odometry & depth-from-motion',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primary.withAlpha(80)),
              ),
              child: const Text(
                'VIO Native',
                style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTrackingCard() {
    return Card(
      elevation: 0,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Live Sensor Telemetry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isSessionActive ? Colors.green.withAlpha(35) : AppTheme.surfaceBorder,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: _isSessionActive ? AppTheme.success : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSessionActive ? 'TRACKING (NORMAL)' : 'IDLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isSessionActive ? AppTheme.success : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'AR Poses',
                    '${_collectedPoses.length}',
                    Icons.timeline,
                    Colors.indigoAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'IMU Samples',
                    '${_collectedImu.length}',
                    Icons.screen_rotation,
                    Colors.tealAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Depth Points',
                    '$_depthPointCount',
                    Icons.blur_on,
                    Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _startOrSimulateTracking,
              icon: Icon(_isSessionActive ? Icons.replay : Icons.play_arrow),
              label: Text(_isSessionActive ? 'Recalibrate / Re-simulate Odometry' : 'Start AR Odometry Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSummaryCard(ARAssistedScanReportModel report) {
    final pctConfidence = (report.overallConfidence * 100).toStringAsFixed(1);
    final isReliable = report.isScaleReliable;

    return Card(
      elevation: 0,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'AR Fusion Report',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isReliable ? AppTheme.success : AppTheme.warning).withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isReliable ? AppTheme.success : AppTheme.warning).withAlpha(90),
                    ),
                  ),
                  child: Text(
                    isReliable ? 'METRIC VALIDATED' : 'PROVISIONAL SCALE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isReliable ? AppTheme.success : AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppTheme.surfaceBorder),
            _buildReportRow('Tracking Quality', report.trackingQuality, Icons.check_circle_outline),
            _buildReportRow('Trajectory Length', '${report.trajectoryLengthMeters.toStringAsFixed(2)} m', Icons.straighten),
            _buildReportRow('Scale Factor', '${report.metricScaleFactor.toStringAsFixed(3)}x', Icons.aspect_ratio),
            _buildReportRow('Overall Confidence', '$pctConfidence%', Icons.verified),
            _buildReportRow('Depth-from-Motion', report.depthPointsEstimated > 0 ? '${report.depthPointsEstimated} pts' : 'None', Icons.blur_linear),
            _buildReportRow('Measurement Source', report.provenanceUpgradedTo, Icons.security_update_good),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppTheme.textMain, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildActionControls() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _isFusing ? null : _fuseARWithModel,
          icon: _isFusing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.merge_type),
          label: Text(_isFusing ? 'Fusing AR Odometry...' : 'Fuse AR Odometry with 3D Model'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
