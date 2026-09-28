import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';
import 'client_directory_screen.dart';
import 'client_presentation_screen.dart';

class ProjectWorkspaceScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  ProjectWorkspaceSummaryModel? _summary;
  bool _isLoading = true;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _targetDateController = TextEditingController();
  bool _isSavingNotes = false;

  static const List<String> _validStatuses = [
    'DRAFT',
    'BRIEFING',
    'CONCEPT_DESIGN',
    'CLIENT_REVIEW',
    'TENDER_READY',
    'IN_CONSTRUCTION',
    'COMPLETED',
    'ARCHIVED',
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _addressController.dispose();
    _targetDateController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() => _isLoading = true);
    try {
      final summary = await ProjectService.fetchProjectSummary(widget.projectId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _notesController.text = summary.designerNotes ?? '';
          _addressController.text = summary.propertyAddress ?? '';
          _targetDateController.text = summary.targetCompletionDate ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load workspace: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await ProjectService.updateProjectDetails(
        widget.projectId,
        status: newStatus,
      );
      await _loadWorkspace();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workspace status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _saveMetadataAndNotes() async {
    setState(() => _isSavingNotes = true);
    try {
      await ProjectService.updateProjectDetails(
        widget.projectId,
        designerNotes: _notesController.text.trim(),
        propertyAddress: _addressController.text.trim(),
        targetCompletionDate: _targetDateController.text.trim(),
      );
      if (mounted) {
        setState(() => _isSavingNotes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Designer notes and project metadata saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingNotes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save notes: $e')),
        );
      }
    }
  }

  void _showAssignClientDialog() async {
    List<ClientModel> clients = [];
    try {
      clients = await ProjectService.fetchClients();
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Assign Client'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (clients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No clients registered. Create a client profile first in Client Directory.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                )
              else
                ...clients.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.company ?? c.email ?? 'No details', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    trailing: _summary?.client?.id == c.id
                        ? const Icon(Icons.check, color: AppTheme.accent)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ProjectService.updateProjectDetails(
                        widget.projectId,
                        clientId: c.id,
                      );
                      await _loadWorkspace();
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (_summary?.client != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ProjectService.updateProjectDetails(
                  widget.projectId,
                  clientId: '',
                );
                await _loadWorkspace();
              },
              child: const Text('Unassign Client', style: TextStyle(color: AppTheme.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  void _showInviteCollaboratorDialog() {
    final userIdCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String role = 'COLLABORATOR';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Invite Collaborator'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'User ID *',
                    hintText: 'e.g. user_collab_99',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'designer@firm.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Alex Rivera',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(labelText: 'Collaborator Role'),
                  items: const [
                    DropdownMenuItem(value: 'LEAD_DESIGNER', child: Text('Lead Designer')),
                    DropdownMenuItem(value: 'COLLABORATOR', child: Text('Collaborator')),
                    DropdownMenuItem(value: 'VIEWER_CLIENT', child: Text('Viewer / Client')),
                    DropdownMenuItem(value: 'OWNER', child: Text('Co-Owner')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => role = val);
                    }
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
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final userId = userIdCtrl.text.trim();
                if (userId.isEmpty) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('User ID is required')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ProjectService.addProjectCollaborator(
                    widget.projectId,
                    userId: userId,
                    role: role,
                    email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                  );
                  await _loadWorkspace();
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Invited $userId as $role')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Failed to invite collaborator: $e')),
                    );
                  }
                }
              },
              child: const Text('Invite'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveCollaborator(ProjectCollaboratorModel collab) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Remove Collaborator?'),
        content: Text(
          'Remove "${collab.name ?? collab.email ?? collab.userId}" (${collab.role}) from this project workspace?',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await ProjectService.removeProjectCollaborator(widget.projectId, collab.userId);
                await _loadWorkspace();
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Removed ${collab.userId}')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to remove collaborator: $e')),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return AppTheme.textMuted;
      case 'BRIEFING':
        return AppTheme.accent;
      case 'CONCEPT_DESIGN':
        return AppTheme.primary;
      case 'CLIENT_REVIEW':
        return AppTheme.warning;
      case 'TENDER_READY':
        return Colors.purpleAccent;
      case 'IN_CONSTRUCTION':
        return Colors.amber;
      case 'COMPLETED':
        return AppTheme.success;
      case 'ARCHIVED':
        return Colors.blueGrey;
      default:
        return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Client Directory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientDirectoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkspace,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
              ? const Center(child: Text('Workspace not found'))
              : RefreshIndicator(
                  onRefresh: _loadWorkspace,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header & Lifecycle Status Card
                      _buildLifecycleHeaderCard(),
                      const SizedBox(height: 16),

                      // Client Information Card
                      _buildClientCard(),
                      const SizedBox(height: 16),

                      // Multi-Room Roll-Up Summary Metrics
                      _buildRollUpMetrics(),
                      const SizedBox(height: 20),

                      // Room Breakdown Section
                      _buildRoomBreakdownSection(),
                      const SizedBox(height: 20),

                      // Team Collaborators Section
                      _buildCollaboratorsSection(),
                      const SizedBox(height: 20),

                      // Designer Scratchpad & Metadata Section
                      _buildDesignerScratchpadSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLifecycleHeaderCard() {
    final statusColor = _getStatusColor(_summary!.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Workspace',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _summary!.projectName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _validStatuses.contains(_summary!.status) ? _summary!.status : 'DRAFT',
                      dropdownColor: AppTheme.surface,
                      icon: Icon(Icons.arrow_drop_down, color: statusColor, size: 20),
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      onChanged: (val) {
                        if (val != null && val != _summary!.status) {
                          _updateStatus(val);
                        }
                      },
                      items: _validStatuses.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.replaceAll('_', ' ')),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            if (_summary!.propertyAddress != null && _summary!.propertyAddress!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _summary!.propertyAddress!,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (_summary!.targetCompletionDate != null && _summary!.targetCompletionDate!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Target Completion: ${_summary!.targetCompletionDate}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard() {
    final client = _summary!.client;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_pin_outlined, size: 18, color: AppTheme.accent),
                    SizedBox(width: 8),
                    Text('Client Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showAssignClientDialog,
                  icon: Icon(client == null ? Icons.add : Icons.sync, size: 16),
                  label: Text(client == null ? 'Assign Client' : 'Change'),
                ),
              ],
            ),
            const Divider(color: AppTheme.surfaceBorder, height: 16),
            if (client == null)
              const Text(
                'No client linked to this workspace. Link a client to track budget preferences, styles, and briefings.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              )
            else ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        if (client.company != null && client.company!.isNotEmpty)
                          Text(
                            client.company!,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (client.budgetPreference != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Budget: ${client.currency} ${client.budgetPreference!.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              if ((client.email != null && client.email!.isNotEmpty) ||
                  (client.phone != null && client.phone!.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (client.email != null && client.email!.isNotEmpty)
                      Expanded(
                        child: Text(
                          'Email: ${client.email}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (client.phone != null && client.phone!.isNotEmpty)
                      Text(
                        'Tel: ${client.phone}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRollUpMetrics() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Rooms',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_summary!.totalRooms}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_summary!.totalFloorAreaSqm.toStringAsFixed(1)} m² floor area',
                  style: const TextStyle(color: AppTheme.accent, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cumulative Budget',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_summary!.currency} ${_summary!.totalEstimatedBudget.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.success),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Across all rooms',
                  style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomBreakdownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Multi-Room Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '${_summary!.rooms.length} Rooms Scanned',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_summary!.rooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: const Center(
              child: Text(
                'No rooms created in this workspace yet.\nCapture rooms to see floor area and budget roll-ups.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ..._summary!.rooms.map((room) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientPresentationScreen(
                        projectId: widget.projectId,
                        roomId: room.roomId,
                        roomName: room.roomName,
                      ),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.meeting_room_outlined, color: AppTheme.accent, size: 20),
                ),
                title: Text(
                  room.roomName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      'Type: ${room.roomType} · ${room.floorAreaSqm != null ? '${room.floorAreaSqm!.toStringAsFixed(1)} m²' : 'Area unmeasured'}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    if (room.latestPlanVersion != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Latest Plan: ${room.latestPlanVersion}',
                          style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_summary!.currency} ${room.estimatedBudget.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${room.versionCount} designs',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.slideshow_rounded, color: AppTheme.primary, size: 22),
                      tooltip: 'Client Review & Presentation',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientPresentationScreen(
                              projectId: widget.projectId,
                              roomId: room.roomId,
                              roomName: room.roomName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCollaboratorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Team Collaborators & Roles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: _showInviteCollaboratorDialog,
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Invite Member'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._summary!.collaborators.map((collab) {
          final isOwner = collab.role == 'OWNER';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: isOwner
                    ? AppTheme.primary.withValues(alpha: 0.25)
                    : AppTheme.surfaceBorder,
                child: Icon(
                  isOwner ? Icons.star : Icons.person,
                  size: 16,
                  color: isOwner ? AppTheme.accent : AppTheme.textMuted,
                ),
              ),
              title: Text(
                collab.name ?? collab.email ?? collab.userId,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'ID: ${collab.userId}${collab.email != null ? ' · ${collab.email}' : ''}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOwner
                          ? AppTheme.primary.withValues(alpha: 0.2)
                          : AppTheme.surfaceBorder,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOwner ? AppTheme.primary : AppTheme.surfaceBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      collab.role.replaceAll('_', ' '),
                      style: TextStyle(
                        color: isOwner ? AppTheme.accent : AppTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isOwner) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
                      tooltip: 'Remove collaborator',
                      onPressed: () => _confirmRemoveCollaborator(collab),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDesignerScratchpadSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note, size: 20, color: AppTheme.accent),
                SizedBox(width: 8),
                Text(
                  'Designer Notes & Scratchpad',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Shared workspace briefing, design intentions, and contractor guidelines:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter project-wide designer notes, client stipulations, or subcontractor instructions...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Property Address',
                      hintText: 'e.g. Unit 14-B, Residensi Solaris Dutamas',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _targetDateController,
                    decoration: const InputDecoration(
                      labelText: 'Target Date',
                      hintText: 'e.g. 2026-12-15',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isSavingNotes ? null : _saveMetadataAndNotes,
                icon: _isSavingNotes
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save Workspace Notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
