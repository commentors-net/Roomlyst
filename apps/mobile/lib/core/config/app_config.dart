// Global Application Configuration for Roomlyst Mobile.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String keyServerType = 'roomlyst_server_type';
  static const String keyLocalUrl = 'roomlyst_local_url';
  static const String keyWebUrl = 'roomlyst_web_url';
  static const String keyActiveBaseUrl = 'roomlyst_active_base_url';

  // Presets
  static const String defaultLocalUrl = 'http://192.168.0.5:8000';
  static const String emulatorLocalUrl = 'http://10.0.2.2:8000';
  static const String defaultWebUrl = 'https://api.roomlyst.com';

  static String serverType = 'local'; // 'local' or 'web'
  static String localUrl = defaultLocalUrl;
  static String webUrl = defaultWebUrl;
  static String baseUrl = defaultLocalUrl;

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
    } catch (e) {
      debugPrint('AppConfig init error: $e');
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
}
