// Global Application Configuration for Roomlyst Mobile.


class AppConfig {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS Simulator/Desktop, or LAN IP
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';
  static String baseUrl = defaultBaseUrl;

  static const String apiVersion = '/api/v1';

  static String get fullApiUrl => '$baseUrl$apiVersion';

  static const String appName = 'Roomlyst';
  static const String appTagline = 'AI-Powered Interior Design & Renovation';
}
