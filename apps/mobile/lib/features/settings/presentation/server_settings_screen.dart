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

  // AI Evaluation Settings
  late String _selectedAiProvider;
  late TextEditingController _ollamaUrlController;
  late TextEditingController _aiModelController;
  bool _isTestingAi = false;
  String? _aiTestResult;
  bool _aiTestSuccess = false;
  List<String> _availableOllamaModels = [];

  @override
  void initState() {
    super.initState();
    _selectedType = AppConfig.serverType;
    final initialUrl = _selectedType == 'local' ? AppConfig.localUrl : AppConfig.webUrl;
    _urlController = TextEditingController(text: initialUrl);

    _selectedAiProvider = AppConfig.aiProvider;
    _ollamaUrlController = TextEditingController(text: AppConfig.ollamaUrl);
    _aiModelController = TextEditingController(text: AppConfig.aiModel);

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
    _ollamaUrlController.dispose();
    _aiModelController.dispose();
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

  Future<void> _testAiConnection() async {
    setState(() {
      _isTestingAi = true;
      _aiTestResult = null;
    });

    try {
      // First update backend with current chosen AI provider/url so status reflects it
      try {
        await ApiClient.updateAiConfig(
          provider: _selectedAiProvider,
          ollamaBaseUrl: _ollamaUrlController.text.trim(),
          model: _aiModelController.text.trim(),
        );
      } catch (_) {}

      final status = await ApiClient.getAiStatus();
      final ollamaReachable = status['ollama_reachable'] == true;
      final provider = status['provider'] ?? _selectedAiProvider;
      final activeModel = status['active_model'] ?? _aiModelController.text;
      final ollamaModels = (status['ollama_models'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      setState(() {
        _availableOllamaModels = ollamaModels;
        if (_selectedAiProvider == 'ollama') {
          if (ollamaReachable) {
            _aiTestSuccess = true;
            _aiTestResult = 'Ollama is online!\nActive Model: $activeModel\nAvailable: ${ollamaModels.join(', ')}';
          } else {
            _aiTestSuccess = false;
            _aiTestResult = 'Ollama at ${_ollamaUrlController.text.trim()} is unreachable.\nEnsure Ollama is running and accessible on your LAN.';
          }
        } else {
          _aiTestSuccess = true;
          _aiTestResult = 'Cloud Provider ($provider) configured.\nActive Model: $activeModel';
        }
      });
    } catch (e) {
      setState(() {
        _aiTestSuccess = false;
        _aiTestResult = 'AI Test Error: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) setState(() => _isTestingAi = false);
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

    await AppConfig.setAiConfig(
      provider: _selectedAiProvider,
      url: _ollamaUrlController.text.trim(),
      model: _aiModelController.text.trim(),
    );

    // Sync with backend if server is reachable
    try {
      await ApiClient.updateAiConfig(
        provider: _selectedAiProvider,
        ollamaBaseUrl: _ollamaUrlController.text.trim(),
        model: _aiModelController.text.trim(),
      );
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved successfully (Server: $rawUrl, AI: $_selectedAiProvider)'),
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
                  avatar: const Icon(Icons.dns, size: 14, color: AppTheme.accent),
                  label: const Text('Home Server (192.168.0.200:8000)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setState(() {
                      _urlController.text = 'http://192.168.0.200:8000';
                      _testResult = null;
                    });
                  },
                ),
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
          const SizedBox(height: 28),

          // AI Evaluation & LLM Provider Section
          const Divider(color: AppTheme.surfaceBorder),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Evaluation & LLM Engine',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedAiProvider.toUpperCase(),
                  style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Configure the model used for aesthetic room evaluation, structural feasibility critique, contractor risk warnings, and value ROI scoring.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Provider selector chips
          const Text('Select AI Engine Provider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Ollama (Local/LAN)'),
                selected: _selectedAiProvider == 'ollama',
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: _selectedAiProvider == 'ollama' ? Colors.white : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: _selectedAiProvider == 'ollama' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedAiProvider = 'ollama';
                      if (_aiModelController.text.isEmpty || _aiModelController.text.contains('gemini') || _aiModelController.text.contains('gpt') || _aiModelController.text.contains('claude')) {
                        _aiModelController.text = 'llama3.2:latest';
                      }
                      _aiTestResult = null;
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Google Gemini'),
                selected: _selectedAiProvider == 'gemini',
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: _selectedAiProvider == 'gemini' ? Colors.white : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: _selectedAiProvider == 'gemini' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedAiProvider = 'gemini';
                      _aiModelController.text = 'gemini-1.5-flash';
                      _aiTestResult = null;
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('OpenAI'),
                selected: _selectedAiProvider == 'openai',
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: _selectedAiProvider == 'openai' ? Colors.white : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: _selectedAiProvider == 'openai' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedAiProvider = 'openai';
                      _aiModelController.text = 'gpt-4o-mini';
                      _aiTestResult = null;
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Anthropic Claude'),
                selected: _selectedAiProvider == 'claude',
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: _selectedAiProvider == 'claude' ? Colors.white : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: _selectedAiProvider == 'claude' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedAiProvider = 'claude';
                      _aiModelController.text = 'claude-3-5-haiku-20241022';
                      _aiTestResult = null;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ollama URL field if Ollama chosen
          if (_selectedAiProvider == 'ollama') ...[
            const Text('Ollama Server URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent)),
            const SizedBox(height: 6),
            TextField(
              controller: _ollamaUrlController,
              decoration: InputDecoration(
                hintText: 'http://192.168.0.200:11434',
                prefixIcon: const Icon(Icons.memory, color: AppTheme.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _ollamaUrlController.clear(),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.dns, size: 13, color: AppTheme.accent),
                  label: const Text('192.168.0.200:11434', style: TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _ollamaUrlController.text = 'http://192.168.0.200:11434'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.laptop, size: 13, color: AppTheme.accent),
                  label: const Text('192.168.0.5:11434', style: TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _ollamaUrlController.text = 'http://192.168.0.5:11434'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.computer, size: 13, color: AppTheme.accent),
                  label: const Text('localhost:11434', style: TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _ollamaUrlController.text = 'http://127.0.0.1:11434'),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Model Name field
          const Text('Model Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent)),
          const SizedBox(height: 6),
          TextField(
            controller: _aiModelController,
            decoration: InputDecoration(
              hintText: _selectedAiProvider == 'ollama' ? 'llama3.2:latest' : 'Model Identifier',
              prefixIcon: const Icon(Icons.psychology_outlined, color: AppTheme.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_selectedAiProvider == 'ollama') ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: (_availableOllamaModels.isNotEmpty
                      ? _availableOllamaModels
                      : const ['llama3.2:latest', 'qwen2.5-coder:3b'])
                  .map((m) => ActionChip(
                        label: Text(m, style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _aiModelController.text = m),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),

          // Test AI Engine Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isTestingAi ? null : _testAiConnection,
            icon: _isTestingAi
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  )
                : const Icon(Icons.smart_toy_outlined, color: AppTheme.primary),
            label: Text(
              _isTestingAi ? 'Querying AI Engine...' : 'Test AI Engine Connection (/ai/status)',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 10),

          // AI Test Result Box
          if (_aiTestResult != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _aiTestSuccess ? AppTheme.success.withAlpha(20) : Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _aiTestSuccess ? AppTheme.success : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _aiTestSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _aiTestSuccess ? AppTheme.success : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _aiTestResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _aiTestSuccess ? AppTheme.success : Colors.redAccent,
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
