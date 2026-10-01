import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/login_screen.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late String _selectedType;
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;
  String? _currentToken;

  @override
  void initState() {
    super.initState();
    _selectedType = AppConfig.serverType;
    final initialUrl = _selectedType == 'local' ? AppConfig.localUrl : AppConfig.webUrl;
    _urlController = TextEditingController(text: initialUrl);
    _checkCurrentSession();
  }

  Future<void> _checkCurrentSession() async {
    final token = await ApiClient.getToken();
    if (mounted) {
      setState(() => _currentToken = token);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      _urlController.text = type == 'local' ? AppConfig.localUrl : AppConfig.webUrl;
      _testResult = null;
    });
  }

  Future<void> _testConnection() async {
    final rawUrl = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (rawUrl.isEmpty) {
      setState(() {
        _testResult = 'Please enter a valid URL';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final healthUri = Uri.parse('$rawUrl/health');
      final response = await http.get(healthUri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final service = data['service'] ?? 'roomlyst-api';
        final status = data['status'] ?? 'healthy';
        setState(() {
          _testSuccess = true;
          _testResult = 'Connected successfully!\nService: $service • Status: $status';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = 'Server returned HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Connection failed: ${e.toString().replaceAll('Exception: ', '')}\n\nMake sure the server is running and your device is on the same network.';
      });
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    final rawUrl = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL cannot be empty')),
      );
      return;
    }

    await AppConfig.setServerConfig(
      type: _selectedType,
      url: rawUrl,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server configuration saved: $rawUrl'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server & App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.dns_rounded, color: AppTheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backend Endpoint Selection',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose whether the mobile app communicates with a local network server (LAN) or a remote cloud webserver.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Server Type Options
          const Text(
            'Target Server Type',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accent),
          ),
          const SizedBox(height: 10),

          // Local Network Card
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTypeChanged('local'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedType == 'local' ? AppTheme.primary : AppTheme.surfaceBorder,
                  width: _selectedType == 'local' ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedType == 'local' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _selectedType == 'local' ? AppTheme.primary : AppTheme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Local Network (LAN)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        SizedBox(height: 2),
                        Text(
                          'Connect to a computer running the backend on the same Wi-Fi network.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.wifi_rounded, color: AppTheme.accent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Webserver Card
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTypeChanged('web'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedType == 'web' ? AppTheme.primary : AppTheme.surfaceBorder,
                  width: _selectedType == 'web' ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedType == 'web' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _selectedType == 'web' ? AppTheme.primary : AppTheme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remote Webserver (Cloud)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        SizedBox(height: 2),
                        Text(
                          'Connect to a public cloud server or domain endpoint (HTTPS / HTTP).',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.cloud_outlined, color: AppTheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Server URL Input Field
          Text(
            _selectedType == 'local' ? 'Local Network URL' : 'Remote Webserver URL',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accent),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: _selectedType == 'local' ? 'http://192.168.0.5:8000' : 'https://api.roomlyst.com',
              prefixIcon: const Icon(Icons.link, color: AppTheme.primary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => _urlController.clear(),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) {
              if (_testResult != null) setState(() => _testResult = null);
            },
          ),
          const SizedBox(height: 10),

          // Preset Suggestion Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_selectedType == 'local') ...[
                ActionChip(
                  avatar: const Icon(Icons.laptop, size: 14, color: AppTheme.accent),
                  label: const Text('Host PC (192.168.0.5:8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _urlController.text = 'http://192.168.0.5:8000';
                      _testResult = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.phone_android, size: 14, color: AppTheme.accent),
                  label: const Text('Emulator (10.0.2.2:8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _urlController.text = 'http://10.0.2.2:8000';
                      _testResult = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.computer, size: 14, color: AppTheme.accent),
                  label: const Text('Localhost (127.0.0.1:8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _urlController.text = 'http://127.0.0.1:8000';
                      _testResult = null;
                    });
                  },
                ),
              ] else ...[
                ActionChip(
                  avatar: const Icon(Icons.cloud_done_outlined, size: 14, color: AppTheme.primary),
                  label: const Text('api.roomlyst.com', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _urlController.text = 'https://api.roomlyst.com';
                      _testResult = null;
                    });
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Test Connection Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppTheme.accent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isTesting ? null : _testConnection,
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                  )
                : const Icon(Icons.network_check_rounded, color: AppTheme.accent),
            label: Text(
              _isTesting ? 'Testing Connectivity...' : 'Test Connection (/health)',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.accent),
            ),
          ),
          const SizedBox(height: 12),

          // Diagnostic Test Result Card
          if (_testResult != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _testSuccess ? AppTheme.success.withAlpha(20) : Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _testSuccess ? AppTheme.success : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _testSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _testSuccess ? AppTheme.success : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _testSuccess ? AppTheme.success : Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Save & Apply Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            label: const Text(
              'Save & Apply Server Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),

          // Session Information & Sign Out
          const Divider(color: AppTheme.surfaceBorder),
          const SizedBox(height: 16),
          const Text(
            'Session & Authentication',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accent),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Row(
              children: [
                Icon(
                  _currentToken != null ? Icons.verified_user : Icons.no_accounts_outlined,
                  color: _currentToken != null ? AppTheme.success : AppTheme.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentToken != null ? 'Active Session Stored' : 'No Stored Session',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        _currentToken != null
                            ? 'Login persists automatically across app restarts.'
                            : 'Sign in to access your projects across devices.',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                if (_currentToken != null)
                  TextButton(
                    onPressed: () async {
                      await ApiClient.clearToken();
                      setState(() => _currentToken = null);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signed out successfully.')),
                        );
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
