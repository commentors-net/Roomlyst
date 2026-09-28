import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../domain/device_capability.dart';

class CapabilityService {
  static const MethodChannel _channel = MethodChannel('com.roomlyst.app/device_capabilities');

  // Development & testing mock profile override (Add-on Section 9)
  static DeviceCapabilityProfile? _mockProfile;

  static void setMockProfile(DeviceCapabilityProfile? profile) {
    _mockProfile = profile;
    debugPrint('[CapabilityService] Active profile override: ${profile?.deviceModel ?? "Live Detection"}');
  }

  static DeviceCapabilityProfile? get mockProfile => _mockProfile;

  static Future<DeviceCapabilityProfile> detectDeviceCapabilities() async {
    // 0. Development Mock Override
    if (_mockProfile != null) {
      return _mockProfile!;
    }

    try {
      // 1. Attempt query to native platform bridge (Swift / Kotlin)
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceCapabilities');
      if (result != null) {
        final casted = Map<String, dynamic>.from(result);
        return DeviceCapabilityProfile.fromMap(casted);
      }
    } on MissingPluginException {
      debugPrint('[CapabilityService] Native method channel not implemented on this host, falling back.');
    } catch (e) {
      debugPrint('[CapabilityService] Error querying native capabilities: $e');
    }

    // 2. Query backend capability evaluator as fallback
    try {
      String platformName = 'web';
      if (!kIsWeb) {
        if (Platform.isIOS) platformName = 'ios';
        if (Platform.isAndroid) platformName = 'android';
      }

      final serverRes = await ApiClient.get('/devices/capabilities?platform=$platformName');
      if (serverRes is Map<String, dynamic>) {
        return DeviceCapabilityProfile.fromMap(serverRes);
      }
    } catch (_) {}

    // 3. Safe Tier C default (Add-on Section 4: Ordinary phone is a core requirement)
    return MockCapabilityProfiles.androidBasicCameraOnly;
  }
}
