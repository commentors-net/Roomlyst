import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

class LiDARScanScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String deviceTier; // 'TIER_1_LIDAR' or 'TIER_2_AR_DEPTH'
  final NativeSpatialScanReportModel? initialReport;
  final bool autoFetch;

  const LiDARScanScreen({
    super.key,
    required this.roomId,
    this.roomName = 'Room',
    this.deviceTier = 'TIER_1_LIDAR',
    this.initialReport,
    this.autoFetch = true,
  });

  @override
  State<LiDARScanScreen> createState() => _LiDARScanScreenState();
}

class _LiDARScanScreenState extends State<LiDARScanScreen> {
  NativeSpatialScanReportModel? _report;
  bool _isLoading = false;
  bool _isProcessing = false;
  bool _isScanning = false;
  String? _errorMessage;
  String? _successMessage;

  // Live native scan state
  final List<NativeSurfaceScanModel> _surfaces = [];
  final List<NativeOpeningScanModel> _openings = [];
  final List<NativeObjectScanModel> _objects = [];
  int _pointMeshCount = 0;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    if (_report == null && widget.autoFetch) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await ProjectService.fetchNativeSpatialReport(widget.roomId);
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startOrSimulateScan() {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _successMessage = null;
      _surfaces.clear();
      _openings.clear();
      _objects.clear();

      final isAppleLidar = widget.deviceTier == 'TIER_1_LIDAR';
      final source = isAppleLidar ? 'LIDAR_NATIVE' : 'HARDWARE_DEPTH';

      // 4 primary walls
      _surfaces.add(
        NativeSurfaceScanModel(
          surfaceType: 'wall',
          dimensions: const [4.8, 2.7, 0.15],
          transformMatrix: const [
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            2.4, 0.0, 1.35, 1.0,
          ],
          confidence: 0.98,
          provenance: source,
        ),
      );
      _surfaces.add(
        NativeSurfaceScanModel(
          surfaceType: 'wall',
          dimensions: const [3.6, 2.7, 0.15],
          transformMatrix: const [
            0.0, 1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            4.8, 1.8, 1.35, 1.0,
          ],
          confidence: 0.97,
          provenance: source,
        ),
      );
      _surfaces.add(
        NativeSurfaceScanModel(
          surfaceType: 'wall',
          dimensions: const [4.8, 2.7, 0.15],
          transformMatrix: const [
            -1.0, 0.0, 0.0, 0.0,
            0.0, -1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            2.4, 3.6, 1.35, 1.0,
          ],
          confidence: 0.98,
          provenance: source,
        ),
      );
      _surfaces.add(
        NativeSurfaceScanModel(
          surfaceType: 'wall',
          dimensions: const [3.6, 2.7, 0.15],
          transformMatrix: const [
            0.0, -1.0, 0.0, 0.0,
            1.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 1.8, 1.35, 1.0,
          ],
          confidence: 0.96,
          provenance: source,
        ),
      );
      // Floor & ceiling
      _surfaces.add(
        NativeSurfaceScanModel(
          surfaceType: 'floor',
          dimensions: const [4.8, 3.6, 0.02],
          transformMatrix: const [
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            2.4, 1.8, 0.0, 1.0,
          ],
          confidence: 0.99,
          provenance: source,
        ),
      );
      _surfaces.add(
        NativeSurfaceScanModel(
          surfaceType: 'ceiling',
          dimensions: const [4.8, 3.6, 0.02],
          transformMatrix: const [
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            2.4, 1.8, 2.7, 1.0,
          ],
          confidence: 0.97,
          provenance: source,
        ),
      );

      // Openings (door & window)
      _openings.add(
        NativeOpeningScanModel(
          openingType: 'door',
          dimensions: const [0.9, 2.1, 0.15],
          transformMatrix: const [
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            1.0, 0.0, 1.05, 1.0,
          ],
          confidence: 0.98,
          provenance: source,
        ),
      );
      _openings.add(
        NativeOpeningScanModel(
          openingType: 'window',
          dimensions: const [1.5, 1.2, 0.15],
          transformMatrix: const [
            -1.0, 0.0, 0.0, 0.0,
            0.0, -1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            2.5, 3.6, 1.4, 1.0,
          ],
          confidence: 0.96,
          provenance: source,
        ),
      );

      // Objects (furniture)
      _objects.add(
        NativeObjectScanModel(
          category: 'table',
          label: 'Dining Table',
          dimensions: const [1.6, 0.9, 0.75],
          transformMatrix: const [
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            2.4, 1.8, 0.375, 1.0,
          ],
          confidence: 0.95,
          provenance: source,
        ),
      );
      _objects.add(
        NativeObjectScanModel(
          category: 'chair',
          label: 'Accent Chair',
          dimensions: const [0.7, 0.7, 0.85],
          transformMatrix: const [
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.8, 2.8, 0.425, 1.0,
          ],
          confidence: 0.93,
          provenance: source,
        ),
      );

      _pointMeshCount = 142500;
    });
  }

  Future<void> _normalizeAndSaveScan() async {
    if (_surfaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please perform or simulate a scan first.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final isAppleLidar = widget.deviceTier == 'TIER_1_LIDAR';
      final payload = NativeSpatialScanPayloadModel(
        roomId: widget.roomId,
        deviceTier: widget.deviceTier,
        framework: isAppleLidar ? 'Apple RoomPlan' : 'Android ARCore Depth',
        surfaces: _surfaces,
        openings: _openings,
        objects: _objects,
        pointCloudCount: _pointMeshCount,
      );

      final result = await ProjectService.normalizeNativeSpatialScan(payload);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isScanning = false;
          if (result.containsKey('report')) {
            _report = NativeSpatialScanReportModel.fromMap(result['report'] as Map<String, dynamic>);
          }
          _successMessage = 'Native spatial scan successfully normalized into Canonical Room Model!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApple = widget.deviceTier == 'TIER_1_LIDAR';
    final hardwareLabel = isApple ? 'Apple RoomPlan LiDAR' : 'Android Hardware-Depth / ToF';

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.roomName} • Spatial Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Report',
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHardwareBadge(hardwareLabel, isApple),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
                  if (_successMessage != null) _buildSuccessBanner(_successMessage!),
                  const SizedBox(height: 12),
                  _buildScanViewport(),
                  const SizedBox(height: 16),
                  _buildScanControls(),
                  const SizedBox(height: 24),
                  if (_report != null) _buildReportCard(_report!),
                ],
              ),
            ),
    );
  }

  Widget _buildHardwareBadge(String label, bool isLidar) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isLidar ? Colors.blue.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLidar ? Colors.blue.withValues(alpha: 0.3) : Colors.purple.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLidar ? Icons.radar : Icons.sensors,
            color: isLidar ? Colors.blue : Colors.purple,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  isLidar
                      ? 'Direct time-of-flight laser meshing • Sub-centimeter exact accuracy'
                      : 'Hardware-depth infrared ToF sensor • High-confidence metric scale',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'EXACT',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.green))),
        ],
      ),
    );
  }

  Widget _buildScanViewport() {
    return AspectRatio(
      aspectRatio: 1.33,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Stack(
          children: [
            // Mock wireframe top-down canvas
            Center(
              child: CustomPaint(
                size: const Size(260, 200),
                painter: _LiDARViewportPainter(
                  hasData: _surfaces.isNotEmpty || _report != null,
                ),
              ),
            ),
            // Live status overlay
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isScanning ? Colors.greenAccent : Colors.amberAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isScanning ? 'STREAMING MESH' : 'STANDBY',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricMetricItem('Surfaces', '${_surfaces.length}'),
                    _metricMetricItem('Openings', '${_openings.length}'),
                    _metricMetricItem('Objects', '${_objects.length}'),
                    _metricMetricItem('Points', _pointMeshCount > 0 ? '${(_pointMeshCount / 1000).toStringAsFixed(1)}k' : '0'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricMetricItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildScanControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _startOrSimulateScan,
                icon: const Icon(Icons.play_arrow),
                label: Text(_surfaces.isEmpty ? 'Start Spatial Scan' : 'Rescan Room'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_surfaces.isEmpty || _isProcessing) ? null : _normalizeAndSaveScan,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: const Text('Complete & Normalize'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard(NativeSpatialScanReportModel report) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Canonical Spatial Report',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    report.provenance,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Framework', report.framework),
            _infoRow('Device Tier', report.deviceTier),
            _infoRow('Surfaces Normalized', '${report.surfacesCount}'),
            _infoRow('Openings Identified', '${report.openingsCount}'),
            _infoRow('Objects Detected', '${report.objectsCount}'),
            _infoRow('Floor Area', '${report.floorAreaSqm.toStringAsFixed(2)} m²'),
            _infoRow('Perimeter', '${report.wallPerimeterM.toStringAsFixed(2)} m'),
            _infoRow('Ceiling Height', '${report.ceilingHeightM.toStringAsFixed(2)} m'),
            _infoRow('Mean Confidence', '${(report.confidenceScore * 100).toStringAsFixed(1)}%'),
            _infoRow('Closed Loop Closure', report.closedLoopVerified ? 'Verified ✓' : 'Unverified'),
            _infoRow('Scan Completed', report.scannedAt),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _LiDARViewportPainter extends CustomPainter {
  final bool hasData;

  _LiDARViewportPainter({required this.hasData});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    // Draw background spatial grid
    const step = 20.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (!hasData) return;

    // Draw normalized wall perimeter loop
    final wallPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final wallFillPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.75,
      height: size.height * 0.7,
    );

    canvas.drawRect(rect, wallFillPaint);
    canvas.drawRect(rect, wallPaint);

    // Draw door opening on bottom wall
    final openingPaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 4.0;
    canvas.drawLine(
      Offset(rect.left + rect.width * 0.2, rect.bottom),
      Offset(rect.left + rect.width * 0.45, rect.bottom),
      openingPaint,
    );

    // Draw window opening on top wall
    final windowPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 4.0;
    canvas.drawLine(
      Offset(rect.left + rect.width * 0.4, rect.top),
      Offset(rect.left + rect.width * 0.75, rect.top),
      windowPaint,
    );

    // Draw furniture object in center
    final objPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final objStroke = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final tableRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 60,
      height: 35,
    );
    canvas.drawRect(tableRect, objPaint);
    canvas.drawRect(tableRect, objStroke);
  }

  @override
  bool shouldRepaint(covariant _LiDARViewportPainter oldDelegate) {
    return oldDelegate.hasData != hasData;
  }
}
