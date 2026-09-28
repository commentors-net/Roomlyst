import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../capability/domain/device_capability.dart';
import '../../projects/domain/project.dart';
import '../../redesign/presentation/room_review_screen.dart';

class VideoScanScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final DeviceCapabilityProfile capability;
  final String? roomId;

  const VideoScanScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.capability,
    this.roomId,
  });

  @override
  State<VideoScanScreen> createState() => _VideoScanScreenState();
}

class _VideoScanScreenState extends State<VideoScanScreen> {
  bool _isRecording = false;
  bool _isUploading = false;
  int _secondsRecorded = 0;
  Timer? _recordTimer;
  Timer? _motionTimer;

  // Live motion guidance parameters
  double _currentPanningSpeed = 12.0; // deg/sec (ideal is < 20 deg/sec)
  bool _isPanningTooFast = false;
  int _excessiveMotionWarnings = 0;
  double _motionStabilityScore = 0.94;

  // Keyframes sampled
  final List<Uint8List> _sampledKeyframes = [];
  final List<String> _keyframeLabels = [];
  final List<double> _keyframeSharpness = [];

  // Coverage tracker
  bool _coveredMainWall = false;
  bool _coveredLeftWall = false;
  bool _coveredFloor = false;
  bool _coveredCornerTransitions = false;
  bool _coveredRightWall = false;
  bool _coveredCeiling = false;

  double _uploadProgress = 0.0;
  String _statusMessage = 'Stand near room center and press Record Sweep to start guided scan.';

  @override
  void dispose() {
    _recordTimer?.cancel();
    _motionTimer?.cancel();
    super.dispose();
  }

  Uint8List _generateSyntheticBmp({int frameIdx = 0, bool blurry = false}) {
    final width = 320;
    final height = 240;
    final headerSize = 54;
    final fileSize = headerSize + (width * height * 3);
    final bytes = Uint8List(fileSize);

    // BMP Header
    bytes[0] = 0x42;
    bytes[1] = 0x4D;
    bytes[2] = fileSize & 0xFF;
    bytes[3] = (fileSize >> 8) & 0xFF;
    bytes[4] = (fileSize >> 16) & 0xFF;
    bytes[5] = (fileSize >> 24) & 0xFF;
    bytes[10] = headerSize;

    // DIB Header
    bytes[14] = 40;
    bytes[18] = width & 0xFF;
    bytes[19] = (width >> 8) & 0xFF;
    bytes[22] = height & 0xFF;
    bytes[23] = (height >> 8) & 0xFF;
    bytes[26] = 1;
    bytes[28] = 24;

    final sweepTint = (frameIdx * 18) % 80;
    int offset = headerSize;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (y < height * 0.3) {
          // Floor
          bytes[offset] = 80 + sweepTint;
          bytes[offset + 1] = 115 + sweepTint;
          bytes[offset + 2] = 150;
        } else if (y < height * 0.8) {
          // Wall
          bytes[offset] = 175 + sweepTint;
          bytes[offset + 1] = 185 + sweepTint;
          bytes[offset + 2] = 200;
        } else {
          // Ceiling
          bytes[offset] = 225 + (blurry ? 10 : 0);
          bytes[offset + 1] = 225;
          bytes[offset + 2] = 235;
        }
        offset += 3;
      }
    }
    return bytes;
  }

  void _startSweepRecording() {
    setState(() {
      _isRecording = true;
      _secondsRecorded = 0;
      _sampledKeyframes.clear();
      _keyframeLabels.clear();
      _keyframeSharpness.clear();
      _excessiveMotionWarnings = 0;
      _motionStabilityScore = 0.95;
      _coveredMainWall = true;
      _statusMessage = 'Sweeping smoothly... Maintain steady slow pan (< 20°/s).';
    });

    // Sample initial keyframe
    _sampleFrame('Main Wall View');

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsRecorded++;

        // Update coverage and sample keyframes based on sweep timeline
        if (_secondsRecorded == 3) {
          _coveredLeftWall = true;
          _sampleFrame('Left Wall Transition');
        } else if (_secondsRecorded == 6) {
          _coveredCornerTransitions = true;
          _coveredFloor = true;
          _sampleFrame('Corner 1 & Floor Sweep');
        } else if (_secondsRecorded == 9) {
          _coveredRightWall = true;
          _sampleFrame('Opposite Wall Sweep');
        } else if (_secondsRecorded == 12) {
          _coveredCeiling = true;
          _sampleFrame('Ceiling & 360 Loop Closure');
        }

        if (_secondsRecorded >= 15) {
          _stopSweepRecording();
        }
      });
    });

    // Simulate motion sensor telemetry
    _motionTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) return;
      setState(() {
        // Vary simulated panning speed
        if (_secondsRecorded == 4 || _secondsRecorded == 8) {
          _currentPanningSpeed = 24.5;
          _isPanningTooFast = true;
          _excessiveMotionWarnings++;
          _motionStabilityScore = (_motionStabilityScore - 0.03).clamp(0.5, 1.0);
          _statusMessage = '⚠️ Pan slower! High speed causes motion blur.';
        } else {
          _currentPanningSpeed = 12.0 + (_secondsRecorded % 3) * 2.2;
          _isPanningTooFast = false;
          _statusMessage = 'Optimal steady sweep. Scanning room features...';
        }
      });
    });
  }

  void _sampleFrame(String label) {
    final frame = _generateSyntheticBmp(
      frameIdx: _sampledKeyframes.length,
      blurry: _isPanningTooFast,
    );
    _sampledKeyframes.add(frame);
    _keyframeLabels.add(label);
    _keyframeSharpness.add(_isPanningTooFast ? 82.0 : 165.0);
  }

  void _stopSweepRecording() {
    _recordTimer?.cancel();
    _motionTimer?.cancel();
    setState(() {
      _isRecording = false;
      _currentPanningSpeed = 0.0;
      _isPanningTooFast = false;
      _statusMessage = 'Sweep complete! ${_sampledKeyframes.length} keyframes sampled. Ready for reconstruction.';
    });
  }

  double get _coverageProgress {
    int count = 0;
    if (_coveredMainWall) count++;
    if (_coveredLeftWall) count++;
    if (_coveredFloor) count++;
    if (_coveredCornerTransitions) count++;
    if (_coveredRightWall) count++;
    if (_coveredCeiling) count++;
    return count / 6.0;
  }

  Future<void> _processAndReconstruct() async {
    if (_sampledKeyframes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record a video sweep first.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
      _statusMessage = 'Initializing video scan session...';
    });

    try {
      final effectiveRoomId = widget.roomId ?? 'room_${widget.projectId}_vscan';
      final fileNames = List.generate(
        _sampledKeyframes.length,
        (i) => 'keyframe_${i + 1}.bmp',
      );

      // 1. Initialize chunked session
      final initRes = await ApiClient.initVideoScanSession(
        roomId: effectiveRoomId,
        totalChunks: 2,
        totalBytes: _sampledKeyframes.fold<int>(0, (sum, f) => sum + f.length),
        videoFormat: 'bmp_frames',
      );
      final sessionId = (initRes as Map<String, dynamic>)['session_id'] as String? ?? 'vscan_sess';

      setState(() {
        _uploadProgress = 0.35;
        _statusMessage = 'Uploading scan stream chunks...';
      });

      // 2. Upload representative chunk data
      await ApiClient.uploadVideoChunk(
        sessionId: sessionId,
        chunkIndex: 0,
        chunkBytes: _sampledKeyframes.first,
        filename: 'chunk_0.bmp',
      );

      setState(() {
        _uploadProgress = 0.65;
        _statusMessage = 'Analyzing motion stability & keyframe geometry...';
      });

      // 3. Multi-frame smart sampling and analysis
      final scanReport = await ApiClient.sampleAndAnalyzeVideo(
        roomId: effectiveRoomId,
        keyframeBytesList: _sampledKeyframes,
        fileNames: fileNames,
        videoDurationSeconds: _secondsRecorded > 0 ? _secondsRecorded.toDouble() : 15.0,
        fps: 30.0,
      );

      setState(() {
        _uploadProgress = 1.0;
        _statusMessage = 'Reconstruction sequence verified!';
      });

      // Also complete chunked session to finalize lifecycle
      await ApiClient.completeVideoScanSession(sessionId: sessionId);

      if (!mounted) return;

      final reportModel = VideoScanReportModel.fromMap(scanReport as Map<String, dynamic>);

      // Show completion summary dialog or navigate directly
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surface,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Reconstruction Suitable: ${reportModel.isSuitableForReconstruction ? "YES" : "NO"}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Quality Assessment: ${reportModel.qualityAssessment}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
              const SizedBox(height: 6),
              Text(
                'Sampled Keyframes: ${reportModel.keyframes.length} | Stability Score: ${(reportModel.metadata.motionStabilityScore * 100).toInt()}%',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text('Guidance Summary:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ...reportModel.guidanceNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $note', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.architecture),
                  label: const Text('Open Room Review'),
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    // Fetch or wrap room model
                    final roomModel = RoomModelData(
                      id: effectiveRoomId,
                      name: widget.projectName,
                      roomType: 'living_room',
                      status: 'READY_FOR_REVIEW',
                      videoScanReport: reportModel,
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomReviewScreen(
                          room: roomModel,
                          projectId: widget.projectId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing error: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.projectName} — Video Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Scanning Guidelines',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text('Non-LiDAR Video Sweep Tips'),
                  content: const Text(
                    '1. Hold phone at chest level and turn slowly from your hips.\n'
                    '2. Keep speed under 20° per second to avoid blur.\n'
                    '3. Keep floor boundaries and corners visible throughout sweep.\n'
                    '4. Close the loop by returning toward your starting angle.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Viewfinder & HUD Guidance Area
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isPanningTooFast ? AppTheme.danger : AppTheme.surfaceBorder,
                    width: _isPanningTooFast ? 3.0 : 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // Simulated Viewfinder Grid
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isRecording ? Icons.videocam : Icons.videocam_outlined,
                            size: 64,
                            color: _isRecording ? AppTheme.primary : AppTheme.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isRecording ? 'RECORDING SWEEP (${_secondsRecorded}s)' : 'READY TO RECORD',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Top HUD: Motion Stability & Panning Speed Gauge
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isPanningTooFast
                                  ? AppTheme.danger.withValues(alpha: 0.85)
                                  : Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isPanningTooFast ? AppTheme.danger : AppTheme.success,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isPanningTooFast ? Icons.speed : Icons.check_circle_outline,
                                  size: 16,
                                  color: _isPanningTooFast ? Colors.white : AppTheme.success,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Speed: ${_currentPanningSpeed.toStringAsFixed(1)}°/s',
                                  style: TextStyle(
                                    color: _isPanningTooFast ? Colors.white : AppTheme.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Stability: ${(_motionStabilityScore * 100).toInt()}%',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center Motion Warning Toast (Active when panning too fast)
                    if (_isPanningTooFast)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'SLOW DOWN! Pan slower to avoid blur',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Bottom HUD: Sampled frames counter
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_sampledKeyframes.length} Keyframes | Warnings: $_excessiveMotionWarnings',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Coverage Checklist & Progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Room Sweep Coverage',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        '${(_coverageProgress * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _coverageProgress,
                    backgroundColor: AppTheme.surfaceBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCoverageChip('Main Wall', _coveredMainWall),
                        _buildCoverageChip('Left Wall', _coveredLeftWall),
                        _buildCoverageChip('Floor Line', _coveredFloor),
                        _buildCoverageChip('Corners', _coveredCornerTransitions),
                        _buildCoverageChip('Right Wall', _coveredRightWall),
                        _buildCoverageChip('Ceiling Line', _coveredCeiling),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Sampled Keyframe Thumbnail Strip
            if (_sampledKeyframes.isNotEmpty)
              Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sampledKeyframes.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final sharpness = _keyframeSharpness[index];
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.surfaceBorder),
                            color: Colors.grey[850],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _sampledKeyframes[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Q: ${sharpness.toInt()}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: sharpness > 100 ? AppTheme.success : AppTheme.danger,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Live status message text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),

            // Upload Progress if active
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: LinearProgressIndicator(value: _uploadProgress),
              ),

            const Spacer(),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? AppTheme.danger : AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isUploading
                          ? null
                          : _isRecording
                              ? _stopSweepRecording
                              : _startSweepRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                      label: Text(_isRecording ? 'Stop Sweep' : 'Record Sweep'),
                    ),
                  ),
                  if (_sampledKeyframes.length >= 2) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppTheme.primary),
                        ),
                        onPressed: _isUploading ? null : _processAndReconstruct,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Reconstruct'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverageChip(String title, bool isCovered) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCovered
            ? AppTheme.success.withValues(alpha: 0.15)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCovered ? AppTheme.success : AppTheme.surfaceBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCovered ? Icons.check : Icons.circle_outlined,
            size: 12,
            color: isCovered ? AppTheme.success : AppTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCovered ? FontWeight.bold : FontWeight.normal,
              color: isCovered ? AppTheme.success : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
