import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/login_screen.dart';
import '../../capability/domain/device_capability.dart';
import '../../capability/services/capability_service.dart';
import '../../capture/presentation/capture_screen.dart';
import '../domain/project.dart';
import '../services/project_service.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  List<ProjectModel> _projects = [];
  DeviceCapabilityProfile? _capabilities;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final caps = await CapabilityService.detectDeviceCapabilities();
    final projs = await ProjectService.fetchProjects();
    if (mounted) {
      setState(() {
        _capabilities = caps;
        _projects = projs;
        _isLoading = false;
      });
    }
  }

  void _showNewProjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Create New Project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Bangsar Penthouse',
            labelText: 'Project Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                final newProj = await ProjectService.createProject(controller.text.trim());
                setState(() => _projects.insert(0, newProj));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(ProjectModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Project?'),
        content: Text(
          'Are you sure you want to delete "${p.name}"? All associated rooms, scanned photos, and redesign variants will be permanently purged (Blueprint Section 23/49).',
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
              Navigator.pop(ctx);
              final success = await ProjectService.deleteProject(p.id);
              if (success && mounted) {
                setState(() => _projects.removeWhere((item) => item.id == p.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Project "${p.name}" and all room data securely purged.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDevCapabilitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hardware Simulation (Section 9)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select a device capability preset to test runtime adaptive degradation:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...MockCapabilityProfiles.allPresets.map((preset) {
              final DeviceCapabilityProfile? profile = preset['profile'] as DeviceCapabilityProfile?;
              final String name = preset['name'] as String;
              final bool isSelected = (profile == null && CapabilityService.mockProfile == null) ||
                  (profile != null && CapabilityService.mockProfile?.deviceModel == profile.deviceModel);

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                  size: 20,
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textMuted,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  CapabilityService.setMockProfile(profile);
                  await _loadData();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textMuted),
            onPressed: () async {
              await ApiClient.clearToken();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Device Capability Badge Card (Add-on Section 2, 7 & 9)
                  if (_capabilities != null) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showDevCapabilitySheet,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _capabilities!.hasLiDAR
                              ? AppTheme.success.withAlpha(20)
                              : AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _capabilities!.hasLiDAR
                                ? AppTheme.success.withAlpha(80)
                                : AppTheme.primary.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _capabilities!.hasLiDAR
                                  ? Icons.radar_rounded
                                  : Icons.camera_alt_outlined,
                              color: _capabilities!.hasLiDAR
                                  ? AppTheme.success
                                  : AppTheme.accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _capabilities!.tierBadgeText,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: _capabilities!.hasLiDAR
                                                ? AppTheme.success
                                                : AppTheme.accent,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.tune_rounded, size: 16, color: AppTheme.textMuted),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_capabilities!.deviceModel} · ${_capabilities!.userGuidancePrompt}',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Privacy Assurance Banner (Blueprint Section 23)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 18, color: AppTheme.success),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Privacy Protected: GPS & camera EXIF metadata stripped. Room photos are encrypted at rest.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Active Workspaces',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        onPressed: _showNewProjectDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Project'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Project Cards
                  ..._projects.map(
                    (p) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceBorder.withAlpha(60),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.weekend_outlined, color: AppTheme.accent),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        subtitle: Text(
                          'Currency: ${p.currency} · Status: ${p.status}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                              tooltip: 'Delete Project',
                              onPressed: () => _confirmDeleteProject(p),
                            ),
                            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CaptureScreen(
                                projectId: p.id,
                                projectName: p.name,
                                capability: _capabilities!,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () {
          final targetProjId = _projects.isNotEmpty ? _projects.first.id : 'proj_demo';
          final targetProjName = _projects.isNotEmpty ? _projects.first.name : 'Living Room Scan';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CaptureScreen(
                projectId: targetProjId,
                projectName: targetProjName,
                capability: _capabilities ?? MockCapabilityProfiles.androidBasicCameraOnly,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Capture Room'),
      ),
    );
  }
}
