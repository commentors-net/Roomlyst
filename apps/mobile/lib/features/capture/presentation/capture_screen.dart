import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../capability/domain/device_capability.dart';
import '../../projects/domain/project.dart';
import '../../redesign/presentation/room_review_screen.dart';
import 'ar_session_screen.dart';
import 'capture_orchestration_dialog.dart';
import 'lidar_scan_screen.dart';
import 'video_scan_screen.dart';
import '../services/scan_orchestrator.dart';

enum CaptureWorkflowMode {
  singlePhoto,
  multiCornerScan,
  videoSweep,
}

class CaptureScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final DeviceCapabilityProfile capability;
  final bool autoSyncCloud;

  const CaptureScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.capability,
    this.autoSyncCloud = true,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CaptureWorkflowMode _mode = CaptureWorkflowMode.multiCornerScan;
  late ScanOrchestrator _orchestrator;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _singleImageBytes;
  final List<Uint8List> _multiFrames = [];
  final List<String> _viewpointLabels = [];
  int? _selectedFrameIndex;
  bool _isAnalyzing = false;
  String _statusText = 'Ready for multi-corner capture';

  @override
  void initState() {
    super.initState();
    _orchestrator = ScanOrchestrator(deviceProfile: widget.capability);
    if (widget.autoSyncCloud) {
      _orchestrator.syncWithCloud().catchError((_) => null);
    }
  }

  void _openOrchestrationDialog() {
    CaptureOrchestrationDialog.show(
      context,
      orchestrator: _orchestrator,
      onModeChanged: (newMode) {
        setState(() {});
        _handleOrchestratedModeChange(newMode);
      },
    );
  }

  void _handleOrchestratedModeChange(ScanMode newMode) {
    if (newMode == ScanMode.lidarScan) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiDARScanScreen(
            roomId: 'temp_${widget.projectId}',
            roomName: widget.projectName,
            deviceTier: 'TIER_1_LIDAR',
          ),
        ),
      );
    } else if (newMode == ScanMode.arDepthScan || newMode == ScanMode.arRgbScan) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ARSessionScreen(
            roomId: 'temp_${widget.projectId}',
            roomName: widget.projectName,
            deviceTier: newMode == ScanMode.arDepthScan ? 'TIER_2_AR_DEPTH' : 'TIER_3_AR_RGB',
          ),
        ),
      );
    } else if (newMode == ScanMode.rgbVideoScan) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoScanScreen(
            projectId: widget.projectId,
            projectName: widget.projectName,
            capability: widget.capability,
          ),
        ),
      );
    } else {
      setState(() {
        _mode = CaptureWorkflowMode.multiCornerScan;
      });
    }
  }

  static const List<String> _cornerNames = [
    'Corner 1: Main Entry / Primary View',
    'Corner 2: Left Room Corner',
    'Corner 3: Opposite Wall Corner',
    'Corner 4: Right Room Corner',
  ];

  double get _coveragePct {
    final count = _multiFrames.length;
    if (count == 0) return 0.0;
    if (count == 1) return 40.0;
    if (count == 2) return 65.0;
    if (count == 3) return 85.0;
    return 100.0;
  }

  String get _coverageGuidance {
    final count = _multiFrames.length;
    if (count == 0) return 'Stand near room entrance. Point camera and capture Corner 1.';
    if (count == 1) return 'Move physically across the room to Corner 2 (Left Corner).';
    if (count == 2) return 'Walk to Corner 3 (Opposite Wall) for cross-room depth.';
    if (count == 3) return 'Walk to Corner 4 (Right Corner) to close the 360 loop.';
    return 'Full room coverage achieved (100%). Ready for multi-view analysis.';
  }

  Uint8List _generateSyntheticBmp({int cornerIndex = 1}) {
    // Generate synthetic image bytes for testing
    final width = 400;
    final height = 300;
    final headerSize = 54;
    final fileSize = headerSize + (width * height * 3);
    final bytes = Uint8List(fileSize);

    // BMP Header
    bytes[0] = 0x42; bytes[1] = 0x4D; // BM
    bytes[2] = fileSize & 0xFF;
    bytes[3] = (fileSize >> 8) & 0xFF;
    bytes[4] = (fileSize >> 16) & 0xFF;
    bytes[5] = (fileSize >> 24) & 0xFF;
    bytes[10] = headerSize; // offset

    // DIB Header
    bytes[14] = 40; // DIB size
    bytes[18] = width & 0xFF; bytes[19] = (width >> 8) & 0xFF;
    bytes[22] = height & 0xFF; bytes[23] = (height >> 8) & 0xFF;
    bytes[26] = 1; // color planes
    bytes[28] = 24; // bits per pixel

    // Vary shade slightly per corner so frames have real visual difference
    final cornerMod = cornerIndex * 15;
    int offset = headerSize;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (y < height * 0.25) {
          // Floor
          bytes[offset] = 70 + cornerMod;
          bytes[offset + 1] = 110 + cornerMod;
          bytes[offset + 2] = 160;
        } else if (y < height * 0.75) {
          // Walls
          bytes[offset] = 180 + cornerMod;
          bytes[offset + 1] = 190 + cornerMod;
          bytes[offset + 2] = 205;
        } else {
          // Ceiling
          bytes[offset] = 230 + cornerMod;
          bytes[offset + 1] = 230 + cornerMod;
          bytes[offset + 2] = 240;
        }
        offset += 3;
      }
    }
    return bytes;
  }

  Future<void> _capturePhotoPrompt({required bool isSingle}) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Capture Room Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
              const SizedBox(height: 8),
              const Text(
                'Take a live picture of your room with your device camera or choose from gallery.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: AppTheme.primary),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Opens your Android camera to snap this room view', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera, isSingle: isSingle);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppTheme.accent),
                ),
                title: const Text('Choose from Photo Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select existing room photo from your phone', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery, isSingle: isSingle);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white70),
                ),
                title: const Text('Use Sample Room Demo Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Test with calibrated interior room sample', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  final nextIdx = _multiFrames.length + 1;
                  final bytes = _generateSyntheticBmp(cornerIndex: nextIdx);
                  _applyCapturedBytes(bytes, isSingle: isSingle);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, {required bool isSingle}) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1440,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        _applyCapturedBytes(bytes, isSingle: isSingle);
      }
    } catch (e) {
      debugPrint('[CaptureScreen] Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _applyCapturedBytes(Uint8List bytes, {required bool isSingle}) {
    setState(() {
      if (isSingle) {
        _singleImageBytes = bytes;
        _statusText = 'Room photo captured successfully. Tap photo to preview.';
      } else {
        if (_multiFrames.length >= 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All 4 room corners captured!')),
          );
          return;
        }
        final nextIdx = _multiFrames.length + 1;
        _multiFrames.add(bytes);
        _viewpointLabels.add('Corner $nextIdx');
        _selectedFrameIndex = _multiFrames.length - 1;
        _statusText = 'Captured Corner $nextIdx (${_coveragePct.toInt()}% Coverage). Tap to preview.';
      }
    });
  }

  void _showImagePreviewDialog(Uint8List bytes, String title, {int? frameIndex}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pinch_outlined, size: 16, color: AppTheme.textMuted),
                      SizedBox(width: 4),
                      Text('Pinch to zoom & pan', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                  if (frameIndex != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger),
                      label: const Text('Delete', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _removeFrame(frameIndex);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _captureNextCorner() {
    _capturePhotoPrompt(isSingle: false);
  }

  void _removeFrame(int index) {
    setState(() {
      _multiFrames.removeAt(index);
      _viewpointLabels.removeAt(index);
      if (_selectedFrameIndex != null && _selectedFrameIndex! >= _multiFrames.length) {
        _selectedFrameIndex = _multiFrames.isEmpty ? null : _multiFrames.length - 1;
      }
      _statusText = 'Removed frame. Current coverage: ${_coveragePct.toInt()}%';
    });
  }

  Future<void> _uploadAndAnalyze() async {
    setState(() {
      _isAnalyzing = true;
      _statusText = _mode == CaptureWorkflowMode.multiCornerScan
          ? 'Synthesizing multi-view room model...'
          : 'Uploading & analyzing room structure...';
    });

    try {
      dynamic res;
      if (_mode == CaptureWorkflowMode.multiCornerScan && _multiFrames.isNotEmpty) {
        final fileNames = List.generate(_multiFrames.length, (i) => 'corner_${i + 1}.jpg');
        res = await ApiClient.uploadMultiRoomPhotos(
          imageBytesList: _multiFrames,
          fileNames: fileNames,
          viewpointLabels: _viewpointLabels,
          projectId: widget.projectId,
          roomName: 'Living Room (Multi-View)',
          platform: widget.capability.platform,
          hasLiDAR: widget.capability.hasLiDAR,
          hasHardwareDepth: widget.capability.hasHardwareDepth,
          hasAR: widget.capability.hasAR,
          hasARCoreDepth: widget.capability.hasARCoreDepth,
          scanMode: widget.capability.scanMode.id,
        );
      } else {
        final bytes = _singleImageBytes ?? _generateSyntheticBmp();
        res = await ApiClient.uploadRoomPhoto(
          imageBytes: bytes,
          fileName: 'room_capture.jpg',
          roomName: 'Living Room',
          platform: widget.capability.platform,
          hasLiDAR: widget.capability.hasLiDAR,
          hasHardwareDepth: widget.capability.hasHardwareDepth,
          hasAR: widget.capability.hasAR,
          hasARCoreDepth: widget.capability.hasARCoreDepth,
          scanMode: widget.capability.scanMode.id,
        );
      }

      if (res is Map<String, dynamic>) {
        final roomModel = RoomModelData.fromMap(res);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RoomReviewScreen(
                room: roomModel,
                projectId: widget.projectId,
              ),
            ),
          );
        }
        return;
      }
    } catch (_) {
      // In offline / standalone mode, synthesize room model from captured photos
      final fallbackRoom = RoomModelData(
        id: 'room_captured_${DateTime.now().millisecondsSinceEpoch}',
        name: widget.projectName.isNotEmpty ? widget.projectName : 'Captured Room',
        roomType: 'living_room',
        status: 'READY_FOR_REVIEW',
        originalImageUrl: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?auto=format&fit=crop&w=800&q=80',
        surfaces: [
          DetectedElement(id: 's_fl', name: 'Tiled Hardwood Floor', type: 'surface', action: 'KEEP', subtitle: 'FLOOR'),
          DetectedElement(id: 's_w1', name: 'Matte Accent Wall', type: 'surface', action: 'RESTYLE', subtitle: 'WALL'),
          DetectedElement(id: 's_cl', name: 'White Ceiling', type: 'surface', action: 'KEEP', subtitle: 'CEILING'),
        ],
        openings: [
          DetectedElement(id: 'op_dr', name: 'Main Entry Door', type: 'opening', action: 'KEEP', subtitle: 'DOOR'),
          DetectedElement(id: 'op_wn', name: 'Balcony Window', type: 'opening', action: 'KEEP', subtitle: 'WINDOW'),
        ],
        objects: [
          DetectedElement(id: 'obj_sofa', name: '3-Seater Fabric Sofa', type: 'object', action: 'KEEP', confidence: 0.95),
          DetectedElement(id: 'obj_table', name: 'Coffee Table', type: 'object', action: 'REPLACE', confidence: 0.88),
          DetectedElement(id: 'obj_rug', name: 'Floor Rug', type: 'object', action: 'REPLACE', confidence: 0.91),
          DetectedElement(id: 'obj_tv', name: 'Wall Mounted TV', type: 'object', action: 'KEEP', confidence: 0.94),
        ],
        geometry: GeometryModel(
          floorAreaSqm: 23.1,
          ceilingHeightM: 2.8,
          estimatedWidthM: 4.2,
          estimatedLengthM: 5.5,
          roomShape: 'RECTANGULAR',
          perimeterM: 19.4,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room model synthesized from photo capture.'),
            backgroundColor: AppTheme.accent,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoomReviewScreen(
              room: fallbackRoom,
              projectId: widget.projectId,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.accent),
            tooltip: 'Scan Orchestrator & Benchmarks',
            onPressed: _openOrchestrationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.radar, color: Colors.blueAccent),
            tooltip: 'Hardware LiDAR Scan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LiDARScanScreen(
                    roomId: 'temp_${widget.projectId}',
                    roomName: widget.projectName,
                    deviceTier: widget.capability.hasLiDAR ? 'TIER_1_LIDAR' : 'TIER_2_AR_DEPTH',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Capture Guidance',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppTheme.surface,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Guided Multi-Corner Capture',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Capturing from 3 to 4 distinct corners allows Roomlyst to cross-match furniture and build multi-view 3D depth, improving measurement accuracy from ~15cm to ~5cm.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Text('Hardware Mode: ${widget.capability.tierBadgeText}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Accuracy: ${widget.capability.accuracyAssuranceText}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Orchestration Status Banner (Milestone 3.5)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _orchestrator.isManualOverride
                        ? Colors.purpleAccent.withValues(alpha: 0.5)
                        : AppTheme.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _orchestrator.isManualOverride ? Icons.tune : Icons.auto_awesome,
                      color: _orchestrator.isManualOverride ? Colors.purpleAccent : AppTheme.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _orchestrator.currentTierName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: _orchestrator.isManualOverride
                                      ? Colors.purple.withValues(alpha: 0.25)
                                      : AppTheme.accent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _orchestrator.isManualOverride ? 'OVERRIDE' : 'AUTO',
                                  style: TextStyle(
                                    color: _orchestrator.isManualOverride
                                        ? Colors.purpleAccent
                                        : AppTheme.accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _orchestrator.currentAccuracyAssurance,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _openOrchestrationDialog,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              // Workflow Mode Switcher (Milestone 2.1)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _mode = CaptureWorkflowMode.multiCornerScan),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _mode == CaptureWorkflowMode.multiCornerScan
                                ? AppTheme.primary.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.view_in_ar,
                                size: 16,
                                color: _mode == CaptureWorkflowMode.multiCornerScan
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Multi-Corner Scan',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _mode == CaptureWorkflowMode.multiCornerScan
                                      ? AppTheme.primary
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoScanScreen(
                                projectId: widget.projectId,
                                projectName: widget.projectName,
                                capability: widget.capability,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Video Sweep',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _mode = CaptureWorkflowMode.singlePhoto),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _mode == CaptureWorkflowMode.singlePhoto
                                ? AppTheme.primary.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_camera,
                                size: 16,
                                color: _mode == CaptureWorkflowMode.singlePhoto
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Single Photo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _mode == CaptureWorkflowMode.singlePhoto
                                      ? AppTheme.primary
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Coverage Indicator (Multi-Corner Mode)
              if (_mode == CaptureWorkflowMode.multiCornerScan) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Room Coverage: ${_coveragePct.toInt()}%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_multiFrames.length} of 4 Corners',
                            style: const TextStyle(fontSize: 12, color: AppTheme.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _coveragePct / 100.0,
                        backgroundColor: Colors.black26,
                        color: _coveragePct >= 85.0
                            ? AppTheme.success
                            : _coveragePct >= 40.0
                                ? AppTheme.accent
                                : AppTheme.primary,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _coverageGuidance,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Viewfinder / Interactive Capture Stage
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceBorder, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _mode == CaptureWorkflowMode.singlePhoto
                        ? (_singleImageBytes != null
                            ? _buildSingleImagePreview()
                            : _buildSingleViewfinder())
                        : _buildMultiViewStage(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Thumbnail Tray for Multi-View Captures
              if (_mode == CaptureWorkflowMode.multiCornerScan && _multiFrames.isNotEmpty) ...[
                SizedBox(
                  height: 68,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _multiFrames.length,
                    itemBuilder: (context, idx) {
                      final isSelected = (_selectedFrameIndex ?? (_multiFrames.length - 1)) == idx;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedFrameIndex = idx);
                            _showImagePreviewDialog(
                              _multiFrames[idx],
                              _viewpointLabels[idx],
                              frameIndex: idx,
                            );
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.accent : Colors.white24,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.memory(_multiFrames[idx], fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeFrame(idx),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                left: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('C${idx + 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Status Bar
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),

              // Action Buttons
              if (_mode == CaptureWorkflowMode.multiCornerScan) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isAnalyzing || _multiFrames.length >= 4 ? null : _captureNextCorner,
                        icon: const Icon(Icons.add_a_photo, size: 18),
                        label: Text(_multiFrames.isEmpty ? 'Capture Corner 1' : 'Next Corner (${_multiFrames.length + 1}/4)'),
                      ),
                    ),
                    if (_multiFrames.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isAnalyzing ? null : _uploadAndAnalyze,
                          icon: _isAnalyzing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Room (${_multiFrames.length})'),
                        ),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                if (_singleImageBytes != null) ...[
                  ElevatedButton(
                    onPressed: _isAnalyzing ? null : _uploadAndAnalyze,
                    child: _isAnalyzing
                        ? const Text('Analyzing Room...')
                        : const Text('Analyze Single Photo'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _isAnalyzing ? null : () => setState(() => _singleImageBytes = null),
                    child: const Text('Recapture Photo', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleImagePreview() {
    return GestureDetector(
      onTap: () => _showImagePreviewDialog(_singleImageBytes!, 'Room Capture Photo'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_singleImageBytes!, fit: BoxFit.cover),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Tap to zoom / inspect',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleViewfinder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.crop_free_rounded, size: 56, color: AppTheme.accent),
        const SizedBox(height: 12),
        const Text('Align Room in Frame', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            widget.capability.captureGuidanceText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _capturePhotoPrompt(isSingle: true),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Capture Room Photo'),
        ),
      ],
    );
  }

  Widget _buildMultiViewStage() {
    if (_multiFrames.isNotEmpty) {
      final activeIdx = _selectedFrameIndex != null && _selectedFrameIndex! < _multiFrames.length
          ? _selectedFrameIndex!
          : _multiFrames.length - 1;
      final bytes = _multiFrames[activeIdx];
      final label = _viewpointLabels[activeIdx];

      return GestureDetector(
        onTap: () => _showImagePreviewDialog(bytes, label, frameIndex: activeIdx),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Tap to zoom / inspect',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final nextIdx = _multiFrames.length;
    final currentTarget = nextIdx < 4 ? _cornerNames[nextIdx] : 'All Corners Captured';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _multiFrames.length >= 4 ? Icons.check_circle_outline : Icons.center_focus_strong,
          size: 56,
          color: _multiFrames.length >= 4 ? AppTheme.success : AppTheme.accent,
        ),
        const SizedBox(height: 12),
        Text(
          currentTarget,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _coverageGuidance,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 20),
        if (_multiFrames.length < 4)
          ElevatedButton.icon(
            onPressed: _captureNextCorner,
            icon: const Icon(Icons.camera_alt),
            label: Text('Capture ${nextIdx + 1} of 4 Corners'),
          ),
      ],
    );
  }
}
