import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

class ReconstructionViewerScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final MultiViewReconstructionReportModel? initialReport;

  const ReconstructionViewerScreen({
    super.key,
    required this.roomId,
    this.roomName = 'Room',
    this.initialReport,
  });

  @override
  State<ReconstructionViewerScreen> createState() => _ReconstructionViewerScreenState();
}

class _ReconstructionViewerScreenState extends State<ReconstructionViewerScreen> {
  MultiViewReconstructionReportModel? _report;
  bool _isLoading = false;
  String? _errorMessage;

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
      final report = await ProjectService.fetchReconstructionReport(widget.roomId);
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

  Future<void> _runReconstruction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await ProjectService.runSfmPipeline(roomId: widget.roomId);
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(
              '3D Reconstruction complete! ${report.pointCloud.vertexCount} points, ${report.extractedPlanes.length} planes fitted.',
            ),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.roomName} — 3D Reconstruction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh / Run SfM',
            onPressed: _isLoading ? null : _runReconstruction,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing multi-view reconstruction & RANSAC plane fitting...'),
                ],
              ),
            )
          : _errorMessage != null && _report == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.view_in_ar_outlined, size: 54, color: AppTheme.warning),
                        const SizedBox(height: 16),
                        const Text(
                          'No Reconstruction Available Yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _runReconstruction,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Run 3D SfM Reconstruction'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildReportContent(),
    );
  }

  Widget _buildReportContent() {
    if (_report == null) return const SizedBox.shrink();

    final r = _report!;
    final isTier1 = r.spatialConsistencyTier == 'TIER_1_CONSISTENT';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Consistency Tier Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isTier1 ? AppTheme.success.withAlpha(20) : AppTheme.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTier1 ? AppTheme.success.withAlpha(80) : AppTheme.warning.withAlpha(80),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isTier1 ? Icons.verified : Icons.analytics_outlined,
                  color: isTier1 ? AppTheme.success : AppTheme.warning,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.spatialConsistencyTier.replaceAll('_', ' '),
                        style: TextStyle(
                          color: isTier1 ? AppTheme.success : AppTheme.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Consistency: ${(r.consistencyScore * 100).toStringAsFixed(1)}% · Mean Reprojection: ${r.meanReprojectionErrorPx.toStringAsFixed(2)} px',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMain),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Point Cloud Metadata Card
          const Text(
            'Dense Point Cloud (SfM / MVS)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
          ),
          const SizedBox(height: 8),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_outlined, color: AppTheme.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${r.pointCloud.vertexCount} Vertices',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.pointCloud.format.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Density: ${r.pointCloud.pointDensityPtsPerSqm.toStringAsFixed(1)} pts/m²',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bounds: [${r.pointCloud.boundingBoxMin.map((v) => v.toStringAsFixed(1)).join(', ')}] to [${r.pointCloud.boundingBoxMax.map((v) => v.toStringAsFixed(1)).join(', ')}]',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                if (r.pointCloud.filePath.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Stored: ${r.pointCloud.filePath}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Spatial Planes Extracted (RANSAC)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Extracted Spatial Planes (RANSAC)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
              ),
              Text(
                '${r.extractedPlanes.length} Fitted',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...r.extractedPlanes.map(_buildPlaneCard),
          const SizedBox(height: 20),

          // Camera Trajectory / Poses
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated Camera Poses',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
              ),
              Text(
                '${r.cameraPoses.length} Keyframe Views',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...r.cameraPoses.map(_buildPoseCard),
          const SizedBox(height: 24),

          // Action button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Re-run Multi-View Reconstruction'),
              onPressed: _runReconstruction,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaneCard(SpatialPlaneModel plane) {
    IconData icon;
    Color color;

    if (plane.planeType == 'FLOOR') {
      icon = Icons.layers;
      color = AppTheme.primary;
    } else if (plane.planeType == 'CEILING') {
      icon = Icons.roofing;
      color = AppTheme.accent;
    } else {
      icon = Icons.crop_portrait;
      color = Colors.teal;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withAlpha(30),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plane.readableType,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '${plane.areaSqm.toStringAsFixed(1)} m²',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMain),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Inliers: ${plane.inlierCount} pts',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    if (plane.elevationM != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· Elev: ${plane.elevationM!.toStringAsFixed(2)} m',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      '· Conf: ${(plane.confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11, color: AppTheme.primary),
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

  Widget _buildPoseCard(CameraPoseModel pose) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.camera_alt_outlined, size: 16, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pose.viewId,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  'Yaw: ${pose.yawDeg.toStringAsFixed(1)}° · Pitch: ${pose.pitchDeg.toStringAsFixed(1)}° · Reproj: ${pose.reprojectionErrorPx.toStringAsFixed(2)} px',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '[${pose.position.map((v) => v.toStringAsFixed(1)).join(', ')}]',
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
