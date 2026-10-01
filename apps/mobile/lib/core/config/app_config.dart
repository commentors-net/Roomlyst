// Global Application Configuration for Roomlyst Mobile.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String keyServerType = 'roomlyst_server_type';
  static const String keyLocalUrl = 'roomlyst_local_url';
  static const String keyWebUrl = 'roomlyst_web_url';
  static const String keyActiveBaseUrl = 'roomlyst_active_base_url';

  static const String keyAiProvider = 'roomlyst_ai_provider';
  static const String keyOllamaUrl = 'roomlyst_ollama_url';
  static const String keyAiModel = 'roomlyst_ai_model';

  // Presets
  static const String defaultLocalUrl = 'http://192.168.0.5:8000';
  static const String defaultDockerUrl = 'http://192.168.0.200:8000';
  static const String emulatorLocalUrl = 'http://10.0.2.2:8000';
  static const String defaultWebUrl = 'https://api.roomlyst.com';

  static const String defaultOllamaUrl = 'http://192.168.0.200:11434';
  static const String defaultAiProvider = 'ollama';
  static const String defaultAiModel = 'llama3.2:latest';

  static String serverType = 'local'; // 'local' or 'web'
  static String localUrl = defaultLocalUrl;
  static String webUrl = defaultWebUrl;
  static String baseUrl = defaultLocalUrl;

  static String aiProvider = defaultAiProvider;
  static String ollamaUrl = defaultOllamaUrl;
  static String aiModel = defaultAiModel;

  static const String apiVersion = '/api/v1';

  static String get fullApiUrl => '$baseUrl$apiVersion';

  static const String appName = 'Roomlyst';
  static const String appTagline = 'AI-Powered Interior Design & Renovation';

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      serverType = prefs.getString(keyServerType) ?? 'local';
      localUrl = prefs.getString(keyLocalUrl) ?? defaultLocalUrl;
      webUrl = prefs.getString(keyWebUrl) ?? defaultWebUrl;
      baseUrl = prefs.getString(keyActiveBaseUrl) ?? (serverType == 'local' ? localUrl : webUrl);

      aiProvider = prefs.getString(keyAiProvider) ?? defaultAiProvider;
      ollamaUrl = prefs.getString(keyOllamaUrl) ?? defaultOllamaUrl;
      aiModel = prefs.getString(keyAiModel) ?? defaultAiModel;
    } catch (e) {
      debugPrint('AppConfig init error: $e');
    }
  }

  static Future<void> setAiConfig({
    required String provider,
    required String url,
    required String model,
  }) async {
    aiProvider = provider;
    ollamaUrl = url.trim();
    aiModel = model.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAiProvider, aiProvider);
      await prefs.setString(keyOllamaUrl, ollamaUrl);
      await prefs.setString(keyAiModel, aiModel);
    } catch (e) {
      debugPrint('setAiConfig error: $e');
    }
  }

  static Future<void> setServerConfig({
    required String type,
    required String url,
  }) async {
    serverType = type;
    baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (type == 'local') {
      localUrl = baseUrl;
    } else {
      webUrl = baseUrl;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyServerType, serverType);
      await prefs.setString(keyActiveBaseUrl, baseUrl);
      if (type == 'local') {
        await prefs.setString(keyLocalUrl, localUrl);
      } else {
        await prefs.setString(keyWebUrl, webUrl);
      }
    } catch (e) {
      debugPrint('AppConfig save error: $e');
    }
  }

  /// Resolves relative storage or API paths (e.g. `/storage/uploads/xyz.jpg`)
  /// to a full accessible URL pointing to the active backend.
  static String? resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('file://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '$baseUrl$trimmed';
    }
    return '$baseUrl/$trimmed';
  }
}
