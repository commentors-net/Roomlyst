import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiClient {
  static const String tokenKey = 'roomlyst_jwt_token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  static Future<Map<String, String>> _buildHeaders() async {
    final token = await getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}$endpoint');
    final headers = await _buildHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}$endpoint');
    final headers = await _buildHeaders();
    final response = await http.post(url, headers: headers, body: jsonEncode(data));
    return _handleResponse(response);
  }

  static Future<dynamic> patch(String endpoint, dynamic data) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}$endpoint');
    final headers = await _buildHeaders();
    final response = await http.patch(url, headers: headers, body: jsonEncode(data));
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}$endpoint');
    final headers = await _buildHeaders();
    final response = await http.delete(url, headers: headers);
    return _handleResponse(response);
  }

  static Future<List<dynamic>> getScalePresets() async {
    final res = await get('/rooms/scale-presets');
    if (res is List<dynamic>) return res;
    return [];
  }

  static Future<dynamic> calibrateRoomScale({
    required String roomId,
    required String referenceType,
    required double targetRealValue,
    String referenceDimensionType = 'width',
    String? referenceEntityId,
    String? notes,
  }) async {
    return post('/rooms/$roomId/scale-calibration', {
      'reference_type': referenceType,
      'target_real_value': targetRealValue,
      'reference_dimension_type': referenceDimensionType,
      'reference_entity_id': referenceEntityId,
      'notes': notes,
    });
  }

  static Future<dynamic> verifyMeasurement({
    required String roomId,
    required String measurementId,
    double? verifiedValue,
  }) async {
    return post('/rooms/$roomId/measurements/$measurementId/verify', {
      'verified_value': verifiedValue,
    });
  }

  static Future<dynamic> getRoomFeasibility(String roomId) async {
    return get('/rooms/$roomId/feasibility');
  }

  static Future<dynamic> getBudgetBenchmarks() async {
    return get('/rooms/budget-benchmarks');
  }

  static Future<dynamic> calculateRoomBudget({
    required String roomId,
    required double totalBudget,
    String currency = 'MYR',
    String renovationTier = 'MODERATE',
    double contingencyPct = 10.0,
    bool includeTax = false,
    double? customTaxRate,
    Map<String, String>? actions,
  }) async {
    return post('/rooms/$roomId/budget', {
      'total_budget': totalBudget,
      'currency': currency,
      'renovation_tier': renovationTier,
      'contingency_pct': contingencyPct,
      'include_tax': includeTax,
      'custom_tax_rate': ?customTaxRate,
      'actions': ?actions,
    });
  }

  static Future<dynamic> getRoomBudget(String roomId) async {
    return get('/rooms/$roomId/budget');
  }

  static Future<dynamic> getBudgetScenarios({
    required String roomId,
    double totalBudget = 15000.0,
    String currency = 'MYR',
    double contingencyPct = 10.0,
    bool includeTax = false,
    double? customTaxRate,
  }) async {
    final queryParams = <String, String>{
      'total_budget': totalBudget.toString(),
      'currency': currency,
      'contingency_pct': contingencyPct.toString(),
      'include_tax': includeTax.toString(),
    };
    if (customTaxRate != null) {
      queryParams['custom_tax_rate'] = customTaxRate.toString();
    }
    final uri = Uri(path: '/rooms/$roomId/budget/scenarios', queryParameters: queryParams);
    return get(uri.toString());
  }

  static Future<dynamic> getRoomVersions(String roomId) async {
    return get('/rooms/$roomId/versions');
  }

  static Future<dynamic> getRoomVersion(String roomId, String versionId) async {
    return get('/rooms/$roomId/versions/$versionId');
  }

  static Future<dynamic> branchDesignVersion({
    required String roomId,
    required String parentVersionId,
    String? parentVariantId,
    String branchLabel = 'New Branch',
    List<String> styles = const ['Warm Modern Minimalist'],
    double budgetAmount = 15000.0,
    String budgetCurrency = 'MYR',
    String renovationTier = 'MODERATE',
    String? prompt,
  }) async {
    return post('/rooms/$roomId/versions/branch', {
      'parent_version_id': parentVersionId,
      'parent_variant_id': parentVariantId,
      'branch_label': branchLabel,
      'styles': styles,
      'goals': ['modernize', 'harmonize'],
      'budget_amount': budgetAmount,
      'budget_currency': budgetCurrency,
      'renovation_tier': renovationTier,
      'free_text_prompt': prompt,
    });
  }

  static Future<dynamic> toggleVariantFavorite({
    required String roomId,
    required String variantId,
    bool? isFavorite,
    String? notes,
  }) async {
    return post('/rooms/$roomId/variants/$variantId/favorite', {
      'is_favorite': isFavorite,
      'notes': notes,
    });
  }

  static Future<dynamic> getRoomFavorites(String roomId) async {
    return get('/rooms/$roomId/favorites');
  }

  static Future<dynamic> compareVariants({
    required String roomId,
    required String variantAId,
    required String variantBId,
  }) async {
    return get('/rooms/$roomId/variants/compare?variant_a_id=$variantAId&variant_b_id=$variantBId');
  }

  static Future<dynamic> uploadRoomPhoto({
    required Uint8List imageBytes,
    required String fileName,
    required String roomName,
    required String platform,
    required bool hasLiDAR,
    bool hasHardwareDepth = false,
    bool hasAR = false,
    bool hasARCoreDepth = false,
    String? scanMode,
  }) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}/rooms/upload-and-analyze');
    final request = http.MultipartRequest('POST', url);

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['room_name'] = roomName;
    request.fields['platform'] = platform;
    request.fields['has_lidar'] = hasLiDAR.toString();
    request.fields['has_hardware_depth'] = hasHardwareDepth.toString();
    request.fields['has_ar'] = hasAR.toString();
    request.fields['has_arcore_depth'] = hasARCoreDepth.toString();
    if (scanMode != null) {
      request.fields['scan_mode'] = scanMode;
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<dynamic> uploadMultiRoomPhotos({
    required List<List<int>> imageBytesList,
    required List<String> fileNames,
    List<String>? viewpointLabels,
    required String projectId,
    required String roomName,
    required String platform,
    required bool hasLiDAR,
    bool hasHardwareDepth = false,
    bool hasAR = false,
    bool hasARCoreDepth = false,
    String? scanMode,
  }) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}/rooms/multi-capture-and-analyze');
    final request = http.MultipartRequest('POST', url);

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['project_id'] = projectId;
    request.fields['room_name'] = roomName;
    request.fields['platform'] = platform;
    request.fields['has_lidar'] = hasLiDAR.toString();
    request.fields['has_hardware_depth'] = hasHardwareDepth.toString();
    request.fields['has_ar'] = hasAR.toString();
    request.fields['has_arcore_depth'] = hasARCoreDepth.toString();
    if (scanMode != null) {
      request.fields['scan_mode'] = scanMode;
    }
    if (viewpointLabels != null && viewpointLabels.isNotEmpty) {
      request.fields['viewpoint_labels'] = viewpointLabels.join(',');
    }

    for (int i = 0; i < imageBytesList.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          imageBytesList[i],
          filename: fileNames[i],
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<dynamic> initVideoScanSession({
    required String roomId,
    int? totalChunks,
    int? totalBytes,
    String videoFormat = 'mp4',
  }) async {
    final payload = <String, dynamic>{
      'room_id': roomId,
      'video_format': videoFormat,
    };
    if (totalChunks != null) payload['total_chunks'] = totalChunks;
    if (totalBytes != null) payload['total_bytes'] = totalBytes;
    return post('/scan/video/init', payload);
  }

  static Future<dynamic> uploadVideoChunk({
    required String sessionId,
    required int chunkIndex,
    required Uint8List chunkBytes,
    String filename = 'chunk.bin',
  }) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}/scan/video/chunk');
    final request = http.MultipartRequest('POST', url);

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['session_id'] = sessionId;
    request.fields['chunk_index'] = chunkIndex.toString();
    request.files.add(
      http.MultipartFile.fromBytes('chunk_data', chunkBytes, filename: filename),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<dynamic> completeVideoScanSession({
    required String sessionId,
  }) async {
    return post('/scan/video/complete', {
      'session_id': sessionId,
    });
  }

  static Future<dynamic> sampleAndAnalyzeVideo({
    required String roomId,
    required List<Uint8List> keyframeBytesList,
    required List<String> fileNames,
    double videoDurationSeconds = 0.0,
    double fps = 30.0,
  }) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}/scan/video/sample-and-analyze');
    final request = http.MultipartRequest('POST', url);

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['room_id'] = roomId;
    request.fields['video_duration_seconds'] = videoDurationSeconds.toString();
    request.fields['fps'] = fps.toString();

    for (int i = 0; i < keyframeBytesList.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes('files', keyframeBytesList[i], filename: fileNames[i]),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<dynamic> getVideoScanReport(String roomId) async {
    return get('/rooms/$roomId/video-scan-report');
  }

  static Future<dynamic> runSfmPipeline({
    required String roomId,
    List<Uint8List>? imageBytesList,
    List<String>? fileNames,
  }) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}/reconstruction/sfm-pipeline');
    final request = http.MultipartRequest('POST', url);

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['room_id'] = roomId;

    if (imageBytesList != null && fileNames != null) {
      for (int i = 0; i < imageBytesList.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes('files', imageBytesList[i], filename: fileNames[i]),
        );
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<dynamic> getReconstructionReport(String roomId) async {
    return get('/rooms/$roomId/reconstruction-report');
  }

  static Future<dynamic> getRoomPointCloud(String roomId) async {
    return get('/rooms/$roomId/point-cloud');
  }

  static Future<dynamic> getRoomSpatialPlanes(String roomId) async {
    return get('/rooms/$roomId/spatial-planes');
  }

  static Future<dynamic> ingestARMotionTelemetry({
    required String roomId,
    required List<Map<String, dynamic>> poses,
    List<Map<String, dynamic>>? imuSamples,
    Map<String, dynamic>? depthPayload,
    String deviceTier = 'TIER_3_AR_RGB',
  }) async {
    return post('/scan/ar-motion/ingest', {
      'room_id': roomId,
      'poses': poses,
      'imu_samples': ?imuSamples,
      'depth_payload': ?depthPayload,
      'device_tier': deviceTier,
    });
  }

  static Future<dynamic> fuseARMotionWithReconstruction({
    required String roomId,
    List<Map<String, dynamic>>? poses,
    List<Map<String, dynamic>>? imuSamples,
    Map<String, dynamic>? depthPayload,
    String deviceTier = 'TIER_3_AR_RGB',
  }) async {
    return post('/scan/ar-motion/fuse', {
      'room_id': roomId,
      'poses': ?poses,
      'imu_samples': ?imuSamples,
      'depth_payload': ?depthPayload,
      'device_tier': deviceTier,
    });
  }

  static Future<dynamic> getARScanReport(String roomId) async {
    return get('/rooms/$roomId/ar-report');
  }

  static Future<dynamic> normalizeNativeSpatialScan(Map<String, dynamic> payload) async {
    return post('/scan/native-spatial/normalize', payload);
  }

  static Future<dynamic> getNativeSpatialReport(String roomId) async {
    return get('/rooms/$roomId/native-spatial-report');
  }

  static Future<dynamic> getScanTelemetryBenchmarks() async {
    return get('/scan/orchestration/telemetry-benchmarks');
  }

  static Future<dynamic> evaluateScanRoute(Map<String, dynamic> deviceProfile) async {
    return post('/scan/orchestration/evaluate-route', deviceProfile);
  }

  static Future<dynamic> attachScanOrchestration(String roomId, Map<String, dynamic> deviceProfile) async {
    return post('/rooms/$roomId/scan-orchestration', deviceProfile);
  }

  static Future<dynamic> generateMaterialTakeoff({
    required String roomId,
    Map<String, double>? customWasteFactors,
  }) async {
    final payload = <String, dynamic>{};
    if (customWasteFactors != null) {
      payload['custom_waste_factors'] = customWasteFactors;
    }
    return post('/rooms/$roomId/material-takeoff', payload);
  }

  static Future<dynamic> getMaterialTakeoff(String roomId) async {
    return get('/rooms/$roomId/material-takeoff');
  }

  static Future<dynamic> verifyCriticalDimension({
    required String roomId,
    required String dimensionId,
    required double verifiedValue,
    String verifiedBy = 'Contractor',
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'dimension_id': dimensionId,
      'verified_value': verifiedValue,
      'verified_by': verifiedBy,
    };
    if (notes != null) {
      payload['notes'] = notes;
    }
    return post('/rooms/$roomId/material-takeoff/verify-dimension', payload);
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      String detail = 'Request failed with status: ${response.statusCode}';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson.containsKey('detail')) {
          detail = errJson['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }
  }
}
