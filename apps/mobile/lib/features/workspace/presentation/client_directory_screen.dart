import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

class ClientDirectoryScreen extends StatefulWidget {
  const ClientDirectoryScreen({super.key});

  @override
  State<ClientDirectoryScreen> createState() => _ClientDirectoryScreenState();
}

class _ClientDirectoryScreenState extends State<ClientDirectoryScreen> {
  List<ClientModel> _clients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final clients = await ProjectService.fetchClients(query: query);
      if (mounted) {
        setState(() {
          _clients = clients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load clients: $e')),
        );
      }
    }
  }

  void _openClientFormDialog({ClientModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final companyCtrl = TextEditingController(text: existing?.company ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final budgetCtrl = TextEditingController(
      text: existing?.budgetPreference != null ? existing!.budgetPreference!.toStringAsFixed(0) : '',
    );
    String currency = existing?.currency ?? 'MYR';
    final stylesCtrl = TextEditingController(
      text: existing?.preferredStyles.join(', ') ?? 'Modern Minimalist, Japandi',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(existing == null ? 'Add New Client' : 'Edit Client Profile'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Client Name *',
                      hintText: 'e.g. Sarah Jenkins',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'client@example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+60 12-345 6789',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: companyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Company / Firm (Optional)',
                      hintText: 'Jenkins Holdings',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: budgetCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Budget Preference',
                            hintText: '50000',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: currency,
                          dropdownColor: AppTheme.surface,
                          decoration: const InputDecoration(labelText: 'Currency'),
                          items: const [
                            DropdownMenuItem(value: 'MYR', child: Text('MYR')),
                            DropdownMenuItem(value: 'SGD', child: Text('SGD')),
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                            DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => currency = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stylesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Preferred Styles (comma-separated)',
                      hintText: 'Modern Minimalist, Japandi, Wabi-Sabi',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Client Brief / Notes',
                      hintText: 'Client prefers pet-friendly, scratch-resistant flooring...',
                    ),
                  ),
                ],
              ),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Client name is required')),
                  );
                  return;
                }

                final styles = stylesCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                final budget = double.tryParse(budgetCtrl.text.trim());

                Navigator.pop(ctx);

                try {
                  if (existing == null) {
                    await ProjectService.createClient(
                      name: name,
                      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      company: companyCtrl.text.trim().isEmpty ? null : companyCtrl.text.trim(),
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      budgetPreference: budget,
                      currency: currency,
                      preferredStyles: styles,
                    );
                  } else {
                    await ProjectService.updateClient(
                      existing.id,
                      name: name,
                      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      company: companyCtrl.text.trim().isEmpty ? null : companyCtrl.text.trim(),
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      budgetPreference: budget,
                      currency: currency,
                      preferredStyles: styles,
                    );
                  }
                  await _loadClients(query: _searchQuery.isEmpty ? null : _searchQuery);
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error saving client: $e')),
                    );
                  }
                }
              },
              child: Text(existing == null ? 'Create Client' : 'Update Client'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteClient(ClientModel client) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Client?'),
        content: Text(
          'Are you sure you want to delete client "${client.name}"?\n\nAssociated projects will NOT be deleted, but will become unassigned.',
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
                await ProjectService.deleteClient(client.id);
                await _loadClients(query: _searchQuery.isEmpty ? null : _searchQuery);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Client "${client.name}" removed.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to delete client: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add Client',
            onPressed: () => _openClientFormDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by client or company name...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadClients();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _loadClients(query: val.trim().isEmpty ? null : val.trim());
              },
            ),
          ),

          // Client List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _clients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? 'No clients added yet' : 'No clients found matching "$_searchQuery"',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _openClientFormDialog(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add First Client'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadClients(query: _searchQuery.isEmpty ? null : _searchQuery),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _clients.length,
                          itemBuilder: (context, index) {
                            final client = _clients[index];
                            return _buildClientCard(client);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(ClientModel client) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (client.company != null && client.company!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          client.company!,
                          style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
                  color: AppTheme.surface,
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openClientFormDialog(existing: client);
                    } else if (val == 'delete') {
                      _confirmDeleteClient(client);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                          SizedBox(width: 8),
                          Text('Delete Client', style: TextStyle(color: AppTheme.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contact Info
            if ((client.email != null && client.email!.isNotEmpty) ||
                (client.phone != null && client.phone!.isNotEmpty)) ...[
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (client.email != null && client.email!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email_outlined, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(client.email!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  if (client.phone != null && client.phone!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(client.phone!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Preferred Styles & Budget
            Row(
              children: [
                if (client.budgetPreference != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Budget: ${client.currency} ${client.budgetPreference!.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBorder,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${client.projectIds.length} Linked Project${client.projectIds.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            if (client.preferredStyles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: client.preferredStyles.map((style) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      style,
                      style: const TextStyle(color: AppTheme.accent, fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (client.notes != null && client.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                client.notes!,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
