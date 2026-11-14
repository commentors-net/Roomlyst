import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

class ClientPresentationScreen extends StatefulWidget {
  final String? projectId;
  final String? roomId;
  final String? roomName;
  final String? initialVariantId;
  final String? initialOriginalImageUrl;
  final String? initialVariantImageUrl;
  final String? reviewToken;
  final ReviewSessionModel? initialSession;

  const ClientPresentationScreen({
    super.key,
    this.projectId,
    this.roomId,
    this.roomName,
    this.initialVariantId,
    this.initialOriginalImageUrl,
    this.initialVariantImageUrl,
    this.reviewToken,
    this.initialSession,
  });

  @override
  State<ClientPresentationScreen> createState() => _ClientPresentationScreenState();
}

class _ClientPresentationScreenState extends State<ClientPresentationScreen> {
  bool _isLoading = true;
  ReviewSessionModel? _reviewSession;
  RoomModelData? _roomModel;
  List<DesignCommentModel> _comments = [];
  String _approvalStatus = 'PENDING_REVIEW';
  ApprovalRecordModel? _latestApproval;

  String? _selectedVariantId;
  String? _selectedVariantImageUrl;
  String? _selectedVariantStyle;
  String? _originalImageUrl;
  String _roomName = 'Room Design';
  String _projectName = 'Interior Workspace';

  String _viewMode = 'SPLIT'; // 'SPLIT', 'AFTER', 'BEFORE'
  double _splitPosition = 0.5; // 0.0 to 1.0 for before/after slider

  final TextEditingController _commentInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.roomName != null && widget.roomName!.isNotEmpty) {
      _roomName = widget.roomName!;
    }
    if (widget.initialOriginalImageUrl != null) {
      _originalImageUrl = AppConfig.resolveUrl(widget.initialOriginalImageUrl);
    }
    if (widget.initialVariantImageUrl != null) {
      _selectedVariantImageUrl = AppConfig.resolveUrl(widget.initialVariantImageUrl);
    }
    if (widget.initialVariantId != null) {
      _selectedVariantId = widget.initialVariantId;
    }
    if (widget.initialSession != null) {
      final s = widget.initialSession!;
      _reviewSession = s;
      _projectName = s.projectName;
      _roomName = s.roomName;
      _originalImageUrl = s.originalImageUrl;
      _selectedVariantId = s.selectedVariantId;
      _selectedVariantImageUrl = s.selectedVariantImageUrl;
      _selectedVariantStyle = s.selectedVariantStyle;
      _approvalStatus = s.approvalStatus;
      _latestApproval = s.latestApproval;
      _comments = s.comments;
      _isLoading = false;
    } else {
      _loadPresentationData();
    }
  }

  @override
  void dispose() {
    _commentInputController.dispose();
    super.dispose();
  }

  Future<void> _loadPresentationData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.reviewToken != null) {
        // Tokenized review session
        final session = await ProjectService.fetchReviewSession(widget.reviewToken!);
        if (mounted) {
          setState(() {
            _reviewSession = session;
            _projectName = session.projectName;
            _roomName = session.roomName;
            _originalImageUrl = session.originalImageUrl;
            _selectedVariantId = session.selectedVariantId;
            _selectedVariantImageUrl = session.selectedVariantImageUrl;
            _selectedVariantStyle = session.selectedVariantStyle;
            _approvalStatus = session.approvalStatus;
            _latestApproval = session.latestApproval;
            _comments = session.comments;
            _isLoading = false;
          });
        }
      } else if (widget.roomId != null) {
        // Logged-in designer session
        final roomData = await ProjectService.fetchRoomModel(widget.roomId!);
        final comments = await ProjectService.fetchComments(widget.roomId!);
        final approvalsData = await ProjectService.fetchApprovals(widget.roomId!);

        String? bestVariantId = widget.initialVariantId;
        String? bestVariantUrl;
        String? bestVariantStyle;

        if (roomData.redesignVariants.isNotEmpty) {
          final matched = widget.initialVariantId != null
              ? roomData.redesignVariants.firstWhere(
                  (v) => v.id == widget.initialVariantId,
                  orElse: () => roomData.redesignVariants.first,
                )
              : roomData.redesignVariants.first;
          bestVariantId = matched.id;
          bestVariantUrl = matched.displayImageUrl;
          bestVariantStyle = matched.style;
        } else if (roomData.originalImageUrl != null && roomData.originalImageUrl!.isNotEmpty) {
          bestVariantUrl = roomData.displayOriginalImageUrl ?? roomData.originalImageUrl;
          bestVariantStyle = 'Current Layout';
        }

        if (mounted) {
          setState(() {
            _roomModel = roomData;
            _roomName = roomData.name;
            _originalImageUrl = roomData.displayOriginalImageUrl ?? AppConfig.resolveUrl(roomData.originalImageUrl) ?? _originalImageUrl;
            _selectedVariantId = bestVariantId ?? _selectedVariantId;
            _selectedVariantImageUrl = AppConfig.resolveUrl(bestVariantUrl) ?? _selectedVariantImageUrl;
            _selectedVariantStyle = bestVariantStyle ?? _selectedVariantStyle;
            _comments = comments;
            _approvalStatus = approvalsData['current_status'] as String? ?? 'PENDING_REVIEW';
            if (approvalsData['latest_approval'] != null) {
              _latestApproval = ApprovalRecordModel.fromMap(
                approvalsData['latest_approval'] as Map<String, dynamic>,
              );
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load presentation: $e')),
        );
      }
    }
  }

  void _showAddCommentDialog({double? pinX, double? pinY}) {
    final textCtrl = TextEditingController();
    final authorCtrl = TextEditingController(text: 'Client Reviewer');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            Icon(pinX != null ? Icons.pin_drop : Icons.comment, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text(pinX != null ? 'Add Pinned Comment' : 'Add Comment'),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: authorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'e.g. Sarah Jenkins',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Comment / Annotation',
                  hintText: 'e.g. Can we change the wood stain to lighter oak?',
                ),
              ),
              if (pinX != null && pinY != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Pinned at (${(pinX * 100).toStringAsFixed(0)}%, ${(pinY * 100).toStringAsFixed(0)}%) on canvas',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = textCtrl.text.trim();
              if (text.isEmpty) return;
              final authorName = authorCtrl.text.trim().isEmpty ? 'Client' : authorCtrl.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);

              try {
                if (widget.reviewToken != null) {
                  final newCmt = await ProjectService.postReviewComment(
                    widget.reviewToken!,
                    authorId: 'usr_guest',
                    authorName: authorName,
                    text: text,
                    variantId: _selectedVariantId,
                    pinX: pinX,
                    pinY: pinY,
                  );
                  if (mounted) {
                    setState(() => _comments.add(newCmt));
                  }
                } else if (widget.roomId != null) {
                  final newCmt = await ProjectService.createComment(
                    widget.roomId!,
                    authorId: 'usr_designer',
                    authorName: authorName,
                    text: text,
                    variantId: _selectedVariantId,
                    pinX: pinX,
                    pinY: pinY,
                  );
                  if (mounted) {
                    setState(() => _comments.add(newCmt));
                  }
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Comment saved.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to post comment: $e')),
                );
              }
            },
            child: const Text('Post Comment'),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog({required bool isApproving}) {
    final notesCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'Client');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(isApproving ? 'Approve Design Concept?' : 'Request Design Changes'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isApproving
                    ? 'Confirming approval signals sign-off on this concept. The design team will proceed with tender/construction preparation.'
                    : 'Specify revision requirements for the design team:',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Approver Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isApproving ? 'Approval Notes (Optional)' : 'Required Revisions *',
                  hintText: isApproving
                      ? 'e.g. Design accepted for Phase 1.'
                      : 'e.g. Please replace carpet with vinyl plank and add pendant lamps.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproving ? AppTheme.success : AppTheme.warning,
              foregroundColor: isApproving ? Colors.white : Colors.black,
            ),
            onPressed: () async {
              final newStatus = isApproving ? 'APPROVED' : 'CHANGES_REQUESTED';
              final notes = notesCtrl.text.trim();
              final name = nameCtrl.text.trim().isEmpty ? 'Client' : nameCtrl.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);

              try {
                if (widget.reviewToken != null) {
                  final rec = await ProjectService.submitReviewDecision(
                    widget.reviewToken!,
                    status: newStatus,
                    decidedByName: name,
                    notes: notes.isEmpty ? null : notes,
                    variantId: _selectedVariantId,
                  );
                  if (mounted) {
                    setState(() {
                      _approvalStatus = rec.status;
                      _latestApproval = rec;
                    });
                  }
                } else if (widget.roomId != null) {
                  final rec = await ProjectService.submitApproval(
                    widget.roomId!,
                    status: newStatus,
                    decidedByName: name,
                    decidedByRole: 'LEAD_DESIGNER',
                    notes: notes.isEmpty ? null : notes,
                    variantId: _selectedVariantId,
                  );
                  if (mounted) {
                    setState(() {
                      _approvalStatus = rec.status;
                      _latestApproval = rec;
                    });
                  }
                }
                messenger.showSnackBar(
                  SnackBar(content: Text('Status updated to $newStatus')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to submit decision: $e')),
                );
              }
            },
            child: Text(isApproving ? 'Confirm Approval' : 'Submit Revisions'),
          ),
        ],
      ),
    );
  }

  void _showShareLinkDialog() async {
    final projId = widget.projectId ?? _reviewSession?.projectId;
    if (projId == null) return;

    String permission = 'CAN_APPROVE';
    int expiresIn = 14;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Row(
            children: [
              Icon(Icons.share, color: AppTheme.accent, size: 20),
              SizedBox(width: 8),
              Text('Share Client Review Link'),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Generate a secure, tokenized review link for client presentation without requiring full login.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: permission,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(labelText: 'Review Permission Tier'),
                  items: const [
                    DropdownMenuItem(value: 'CAN_VIEW', child: Text('View Only (Read-Only)')),
                    DropdownMenuItem(value: 'CAN_COMMENT', child: Text('View & Comment (Feedback)')),
                    DropdownMenuItem(value: 'CAN_APPROVE', child: Text('Full Review (Approve / Reject)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => permission = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: expiresIn,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(labelText: 'Link Expiration'),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('Expires in 3 Days')),
                    DropdownMenuItem(value: 7, child: Text('Expires in 7 Days')),
                    DropdownMenuItem(value: 14, child: Text('Expires in 14 Days')),
                    DropdownMenuItem(value: 30, child: Text('Expires in 30 Days')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => expiresIn = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  final link = await ProjectService.createShareLink(
                    projId,
                    roomId: widget.roomId,
                    permission: permission,
                    allowComments: permission != 'CAN_VIEW',
                    allowApprovals: permission == 'CAN_APPROVE',
                    expiresInDays: expiresIn,
                  );
                  final reviewUrl = 'https://app.roomlyst.com/review/${link.token}';
                  await Clipboard.setData(ClipboardData(text: reviewUrl));
                  messenger.showSnackBar(
                    SnackBar(content: Text('Review link copied to clipboard!\n$reviewUrl')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to generate link: $e')),
                  );
                }
              },
              child: const Text('Generate & Copy Link'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.forum_outlined, size: 20, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Design Annotations (${_comments.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AppTheme.surfaceBorder),
              Expanded(
                child: _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No annotations posted yet.\nTap anywhere on the canvas to place a pinned comment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, idx) {
                          final cmt = _comments[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: cmt.hasPin
                                    ? AppTheme.accent.withValues(alpha: 0.2)
                                    : AppTheme.surfaceBorder,
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: cmt.hasPin ? AppTheme.accent : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    cmt.authorName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceBorder,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      cmt.authorRole,
                                      style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (cmt.isResolved)
                                    const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(cmt.text, style: const TextStyle(fontSize: 12)),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  cmt.isResolved ? Icons.undo : Icons.check,
                                  size: 18,
                                  color: cmt.isResolved ? AppTheme.textMuted : AppTheme.success,
                                ),
                                tooltip: cmt.isResolved ? 'Reopen' : 'Resolve',
                                onPressed: () async {
                                  final newStatus = cmt.isResolved ? 'OPEN' : 'RESOLVED';
                                  await ProjectService.updateCommentStatus(cmt.commentId, newStatus);
                                  final updated = await ProjectService.fetchComments(widget.roomId ?? '');
                                  if (mounted) {
                                    setState(() => _comments = updated);
                                    setSheetState(() {});
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddCommentDialog();
                },
                icon: const Icon(Icons.add_comment, size: 16),
                label: const Text('Add General Comment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AppTheme.success;
      case 'CHANGES_REQUESTED':
        return AppTheme.warning;
      case 'REJECTED':
        return AppTheme.danger;
      default:
        return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_approvalStatus);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_roomName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_projectName, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          // Comments Drawer Trigger
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                tooltip: 'Annotations',
                onPressed: _showCommentsBottomSheet,
              ),
              if (_comments.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_comments.length}',
                      style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),

          // Share Presentation Link
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Presentation Link',
            onPressed: _showShareLinkDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Status & Style Banner with View Mode Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.surface,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _approvalStatus.replaceAll('_', ' '),
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_selectedVariantStyle != null)
                        Expanded(
                          child: Text(
                            'Style: $_selectedVariantStyle${_latestApproval?.decidedByName != null ? ' · Signed: ${_latestApproval!.decidedByName}' : ''}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else if (_latestApproval?.decidedByName != null)
                        Expanded(
                          child: Text(
                            'Signed: ${_latestApproval!.decidedByName}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        segments: const [
                          ButtonSegment(value: 'SPLIT', label: Text('Split')),
                          ButtonSegment(value: 'AFTER', label: Text('After')),
                          ButtonSegment(value: 'BEFORE', label: Text('Before')),
                        ],
                        selected: {_viewMode},
                        onSelectionChanged: (val) {
                          setState(() => _viewMode = val.first);
                        },
                      ),
                    ],
                  ),
                ),

                // Interactive Visual Canvas
                Expanded(
                  child: _buildPresentationCanvas(),
                ),

                // Concept Variant Selector Bar
                _buildVariantSelectorBar(),

                // Bottom Formal Approval Action Bar
                _buildApprovalActionBar(),
              ],
            ),
    );
  }

  Widget _buildCanvasImage(String? url, String fallbackLabel) {
    if (url == null || url.trim().isEmpty) {
      return _buildFallbackVisual(fallbackLabel);
    }
    final resolved = AppConfig.resolveUrl(url) ?? url;
    return Image.network(
      resolved,
      headers: ApiClient.authHeaders,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildFallbackVisual(fallbackLabel),
    );
  }

  Widget _buildPresentationCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        if (_viewMode == 'BEFORE') {
          return Center(
            child: SizedBox.expand(
              child: _buildCanvasImage(_originalImageUrl, 'Before (Original Scan)'),
            ),
          );
        }

        if (_viewMode == 'SPLIT') {
          // Before / After Comparison Split Slider
          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _splitPosition = (_splitPosition + details.primaryDelta! / width).clamp(0.05, 0.95);
              });
            },
            child: Stack(
              children: [
                // Background: Selected Variant Image (After)
                Positioned.fill(
                  child: _buildCanvasImage(_selectedVariantImageUrl, 'After Redesign'),
                ),

                // Clipped Foreground: Original Room Image (Before)
                Positioned.fill(
                  child: ClipRect(
                    clipper: _SplitClipper(_splitPosition),
                    child: _buildCanvasImage(_originalImageUrl, 'Before (Scan)'),
                  ),
                ),

                // Slider Divider Line
                Positioned(
                  left: width * _splitPosition - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: Colors.white,
                  ),
                ),

                // Slider Center Knob
                Positioned(
                  left: width * _splitPosition - 18,
                  top: height / 2 - 18,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.code, size: 20, color: Colors.black),
                  ),
                ),

                // Badges
                Positioned(
                  top: 12,
                  left: 12,
                  child: _buildCanvasBadge('BEFORE: ORIGINAL'),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildCanvasBadge('AFTER: REDESIGN'),
                ),
              ],
            ),
          );
        }

        // Pinned Annotation Canvas Mode
        return GestureDetector(
          onTapUp: (details) {
            final x = (details.localPosition.dx / width).clamp(0.0, 1.0);
            final y = (details.localPosition.dy / height).clamp(0.0, 1.0);
            _showAddCommentDialog(pinX: x, pinY: y);
          },
          child: Stack(
            children: [
              // Redesign Image Canvas
              Positioned.fill(
                child: _buildCanvasImage(_selectedVariantImageUrl, _selectedVariantStyle ?? 'Design Concept'),
              ),

              // Overlay Pinned Comment Markers
              ..._comments.asMap().entries.map((entry) {
                final idx = entry.key;
                final cmt = entry.value;
                if (!cmt.hasPin) return const SizedBox.shrink();

                final pinLeft = cmt.pinX! * width - 14;
                final pinTop = cmt.pinY! * height - 14;

                return Positioned(
                  left: pinLeft,
                  top: pinTop,
                  child: GestureDetector(
                    onTap: () {
                      _showCommentDetailDialog(cmt, idx + 1);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cmt.isResolved ? AppTheme.success : AppTheme.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Hint pill
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: const Text(
                      'Tap anywhere on the visual to drop a pinned comment pin',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCommentDetailDialog(DesignCommentModel cmt, int number) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.accent,
              child: Text('$number', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Text(cmt.authorName, style: const TextStyle(fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cmt.text, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              'Status: ${cmt.status} · Role: ${cmt.authorRole}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final newStatus = cmt.isResolved ? 'OPEN' : 'RESOLVED';
              await ProjectService.updateCommentStatus(cmt.commentId, newStatus);
              await _loadPresentationData();
            },
            child: Text(cmt.isResolved ? 'Reopen Comment' : 'Mark Resolved'),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFallbackVisual(String label) {
    return Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Future<void> _generateVariantsForPresentation() async {
    if (widget.roomId == null) return;
    setState(() => _isLoading = true);
    try {
      final variants = await ProjectService.generateRedesigns(
        roomId: widget.roomId!,
        styles: ['Warm Modern Minimalist', 'Japandi Clean Organic', 'Contemporary Scandinavian'],
        budgetAmount: 15000.0,
      );
      if (variants.isNotEmpty && mounted) {
        setState(() {
          _selectedVariantId = variants.first.id;
          _selectedVariantImageUrl = variants.first.imageUrl;
          _selectedVariantStyle = variants.first.style;
          if (_roomModel != null) {
            _roomModel = _roomModel!.copyWith(
              versions: [
                DesignVersionModel(
                  id: 'ver_${DateTime.now().millisecondsSinceEpoch}',
                  roomId: widget.roomId!,
                  versionNumber: 1,
                  variants: variants,
                ),
              ],
            );
          }
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${variants.length} redesign concepts generated!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate variants: $e')),
        );
      }
    }
  }

  Widget _buildVariantSelectorBar() {
    List<Map<String, dynamic>> variants = [];

    if (_reviewSession != null) {
      variants = _reviewSession!.availableVariants;
    } else if (_roomModel != null) {
      variants = _roomModel!.redesignVariants.map((v) {
        return {
          'variant_id': v.id,
          'style_name': v.style,
          'image_url': v.imageUrl,
          'estimated_cost': v.estimatedCost,
        };
      }).toList();
    }

    if (variants.isEmpty) {
      if (widget.roomId != null) {
        return Container(
          height: 56,
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'No redesign concepts yet',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _generateVariantsForPresentation,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Generate Redesigns', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      height: 60,
      color: AppTheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: variants.length,
        itemBuilder: (context, index) {
          final v = variants[index];
          final vId = v['variant_id'] as String? ?? '';
          final vStyle = v['style_name'] as String? ?? 'Concept ${index + 1}';
          final isSelected = vId == _selectedVariantId;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(vStyle),
              selected: isSelected,
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.surfaceBorder,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedVariantId = vId;
                    _selectedVariantImageUrl = v['image_url'] as String?;
                    _selectedVariantStyle = vStyle;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildApprovalActionBar() {
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
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.warning,
                  side: const BorderSide(color: AppTheme.warning),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _showApprovalDialog(isApproving: false),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Request Changes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _showApprovalDialog(isApproving: true),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Approve Concept'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitClipper extends CustomClipper<Rect> {
  final double split;
  _SplitClipper(this.split);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * split, size.height);
  }

  @override
  bool shouldReclip(_SplitClipper oldClipper) => oldClipper.split != split;
}
