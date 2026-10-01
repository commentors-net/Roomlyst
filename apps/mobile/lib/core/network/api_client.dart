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

  static const Duration defaultTimeout = Duration(milliseconds: 2500);

  static Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}$endpoint');
    final headers = await _buildHeaders();
    final response = await http.get(url, headers: headers).timeout(defaultTimeout);
    return _handleResponse(response);
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}$endpoint');
    final headers = await _buildHeaders();
    final response = await http.post(url, headers: headers, body: jsonEncode(data)).timeout(defaultTimeout);
    return _handleResponse(response);
  }

  static Future<dynamic> patch(String endpoint, dynamic data) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}$endpoint');
    final headers = await _buildHeaders();
    final response = await http.patch(url, headers: headers, body: jsonEncode(data)).timeout(defaultTimeout);
    return _handleResponse(response);
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}$endpoint');
    final headers = await _buildHeaders();
    final response = await http.put(url, headers: headers, body: jsonEncode(data)).timeout(defaultTimeout);
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}$endpoint');
    final headers = await _buildHeaders();
    final response = await http.delete(url, headers: headers).timeout(defaultTimeout);
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

    final streamedResponse = await request.send().timeout(const Duration(seconds: 4));
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

    final streamedResponse = await request.send().timeout(const Duration(seconds: 4));
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<dynamic> initVideoScanSession({
    required String roomId,
    int? totalChunks,
    int? totalBytes,
    String videoFormat = 'mp4',
    String? filename,
  }) async {
    final payload = <String, dynamic>{
      'room_id': roomId,
      'filename': filename ?? 'room_scan.$videoFormat',
      'total_chunks': totalChunks ?? 1,
      'file_size_bytes': totalBytes ?? 0,
    };
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
    String? roomId,
  }) async {
    final payload = <String, dynamic>{
      'session_id': sessionId,
    };
    if (roomId != null) {
      payload['room_id'] = roomId;
    }
    return post('/scan/video/complete', payload);
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

  static Future<dynamic> queryCatalogProducts({
    String? category,
    String? style,
    String? tier,
    String? currency,
    double? maxPrice,
    String? query,
    int limit = 50,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (style != null) params['style'] = style;
    if (tier != null) params['tier'] = tier;
    if (currency != null) params['currency'] = currency;
    if (maxPrice != null) params['max_price'] = maxPrice.toString();
    if (query != null && query.isNotEmpty) params['query'] = query;
    params['limit'] = limit.toString();

    final queryString = Uri(queryParameters: params).query;
    return get('/catalog/products?$queryString');
  }

  static Future<dynamic> getCatalogProduct(String productId) async {
    return get('/catalog/products/$productId');
  }

  static Future<dynamic> generateRoomRecommendations({
    required String roomId,
    String? preferredStyle,
    String? preferredTier,
    String? preferredCurrency,
    double? maxBudget,
  }) async {
    final payload = <String, dynamic>{};
    if (preferredStyle != null) payload['preferred_style'] = preferredStyle;
    if (preferredTier != null) payload['preferred_tier'] = preferredTier;
    if (preferredCurrency != null) payload['preferred_currency'] = preferredCurrency;
    if (maxBudget != null) payload['max_budget'] = maxBudget;
    return post('/rooms/$roomId/recommendations', payload);
  }

  static Future<dynamic> getRoomRecommendations(String roomId) async {
    return get('/rooms/$roomId/recommendations');
  }

  // Milestone 4.4: Renovation Plan API Methods
  static Future<dynamic> createRenovationPlan(
    String roomId, {
    String? selectedVariantId,
  }) async {
    final payload = <String, dynamic>{};
    if (selectedVariantId != null) {
      payload['selected_variant_id'] = selectedVariantId;
    }
    return post('/rooms/$roomId/renovation-plans', payload);
  }

  static Future<dynamic> getRoomRenovationPlans(String roomId) async {
    return get('/rooms/$roomId/renovation-plans');
  }

  static Future<dynamic> getRenovationPlan(String roomId, String planId) async {
    return get('/rooms/$roomId/renovation-plans/$planId');
  }

  static Future<dynamic> exportRenovationPlan(
    String roomId,
    String planId, {
    String format = 'markdown',
  }) async {
    return get('/rooms/$roomId/renovation-plans/$planId/export?format=$format');
  }

  // Milestone 5.1: Client & Workspace API Methods
  static Future<dynamic> createClient(Map<String, dynamic> data) async {
    return post('/clients', data);
  }

  static Future<dynamic> getClients({String? query}) async {
    final queryStr = (query != null && query.isNotEmpty) ? '?query=${Uri.encodeComponent(query)}' : '';
    return get('/clients$queryStr');
  }

  static Future<dynamic> getClient(String clientId) async {
    return get('/clients/$clientId');
  }

  static Future<dynamic> updateClient(String clientId, Map<String, dynamic> data) async {
    return put('/clients/$clientId', data);
  }

  static Future<dynamic> deleteClient(String clientId) async {
    return delete('/clients/$clientId');
  }

  static Future<dynamic> updateProject(String projectId, Map<String, dynamic> data) async {
    return put('/projects/$projectId', data);
  }

  static Future<dynamic> getProjectSummary(String projectId) async {
    return get('/projects/$projectId/summary');
  }

  static Future<dynamic> addProjectCollaborator(
    String projectId, {
    required String userId,
    required String role,
    String? email,
    String? name,
  }) async {
    return post('/projects/$projectId/collaborators', {
      'user_id': userId,
      'role': role,
      'email': email,
      'name': name,
    });
  }

  static Future<dynamic> getProjectCollaborators(String projectId) async {
    return get('/projects/$projectId/collaborators');
  }

  static Future<dynamic> removeProjectCollaborator(String projectId, String userId) async {
    return delete('/projects/$projectId/collaborators/$userId');
  }

  // Milestone 5.2: Collaboration, Approvals & Review
  static Future<dynamic> createComment(
    String roomId, {
    required String authorId,
    required String authorName,
    required String text,
    String authorRole = 'CLIENT',
    String? variantId,
    String? versionId,
    double? pinX,
    double? pinY,
    String? elementId,
    String? parentCommentId,
  }) async {
    final payload = <String, dynamic>{
      'author_id': authorId,
      'author_name': authorName,
      'author_role': authorRole,
      'text': text,
    };
    if (variantId != null) payload['variant_id'] = variantId;
    if (versionId != null) payload['version_id'] = versionId;
    if (pinX != null) payload['pin_x'] = pinX;
    if (pinY != null) payload['pin_y'] = pinY;
    if (elementId != null) payload['element_id'] = elementId;
    if (parentCommentId != null) payload['parent_comment_id'] = parentCommentId;

    return post('/rooms/$roomId/comments', payload);
  }

  static Future<dynamic> getComments(
    String roomId, {
    String? variantId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (variantId != null) params['variant_id'] = variantId;
    if (status != null) params['status'] = status;
    final query = params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
    return get('/rooms/$roomId/comments$query');
  }

  static Future<dynamic> updateCommentStatus(String commentId, String status) async {
    return patch('/comments/$commentId/status', {'status': status});
  }

  static Future<dynamic> deleteComment(String commentId) async {
    return delete('/comments/$commentId');
  }

  static Future<dynamic> submitApproval(
    String roomId, {
    required String status,
    String? decidedByName,
    String? decidedByRole,
    String? notes,
    String? versionId,
    String? variantId,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
    };
    if (decidedByName != null) payload['decided_by_name'] = decidedByName;
    if (decidedByRole != null) payload['decided_by_role'] = decidedByRole;
    if (notes != null) payload['notes'] = notes;
    if (versionId != null) payload['version_id'] = versionId;
    if (variantId != null) payload['variant_id'] = variantId;

    return post('/rooms/$roomId/approvals', payload);
  }

  static Future<dynamic> getApprovals(String roomId, {String? variantId}) async {
    final query = variantId != null ? '?variant_id=${Uri.encodeComponent(variantId)}' : '';
    return get('/rooms/$roomId/approvals$query');
  }

  static Future<dynamic> createShareLink(
    String projectId, {
    String? roomId,
    String createdBy = 'designer',
    String permission = 'CAN_COMMENT',
    bool allowComments = true,
    bool allowApprovals = false,
    int expiresInDays = 14,
  }) async {
    final payload = <String, dynamic>{
      'created_by': createdBy,
      'permission': permission,
      'allow_comments': allowComments,
      'allow_approvals': allowApprovals,
      'expires_in_days': expiresInDays,
    };
    if (roomId != null) payload['room_id'] = roomId;

    return post('/projects/$projectId/share-links', payload);
  }

  static Future<dynamic> getProjectShareLinks(String projectId) async {
    return get('/projects/$projectId/share-links');
  }

  static Future<dynamic> revokeShareLink(String linkId) async {
    return delete('/share-links/$linkId');
  }

  static Future<dynamic> getReviewSession(String token) async {
    return get('/review/$token');
  }

  static Future<dynamic> postReviewComment(
    String token, {
    required String authorId,
    required String authorName,
    required String text,
    String? variantId,
    double? pinX,
    double? pinY,
  }) async {
    final payload = <String, dynamic>{
      'author_id': authorId,
      'author_name': authorName,
      'author_role': 'CLIENT',
      'text': text,
    };
    if (variantId != null) payload['variant_id'] = variantId;
    if (pinX != null) payload['pin_x'] = pinX;
    if (pinY != null) payload['pin_y'] = pinY;

    return post('/review/$token/comments', payload);
  }

  static Future<dynamic> submitReviewDecision(
    String token, {
    required String status,
    String? decidedByName,
    String? notes,
    String? variantId,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
    };
    if (decidedByName != null) payload['decided_by_name'] = decidedByName;
    if (notes != null) payload['notes'] = notes;
    if (variantId != null) payload['variant_id'] = variantId;

    return post('/review/$token/decide', payload);
  }

  // Milestone 5.3: Professional Output & Branded Handover API Methods
  static Future<dynamic> getProjectBranding(String projectId) async {
    return get('/projects/$projectId/branding');
  }

  static Future<dynamic> updateProjectBranding(String projectId, Map<String, dynamic> data) async {
    return post('/projects/$projectId/branding', data);
  }

  static Future<dynamic> getExportDossier(String projectId) async {
    return get('/projects/$projectId/export-dossier');
  }

  static Future<dynamic> getExportPackage(String projectId) async {
    return get('/projects/$projectId/export-package');
  }

  static Future<String> getBrandedReportHtml(String projectId) async {
    try {
      final url = Uri.parse('${AppConfig.fullApiUrl}/projects/$projectId/branded-report');
      final headers = await _buildHeaders();
      final response = await http.get(url, headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      } else {
        throw Exception('Failed to load branded report: status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching branded report: $e');
    }
  }

  // Milestone 6.1: Furniture Seller & Commerce API Methods
  static Future<dynamic> createMerchant(Map<String, dynamic> data) async {
    return post('/merchants', data);
  }

  static Future<dynamic> getMerchants({String? country}) async {
    final queryStr = (country != null && country.isNotEmpty) ? '?country=${Uri.encodeComponent(country)}' : '';
    return get('/merchants$queryStr');
  }

  static Future<dynamic> getMerchantDetails(String merchantId) async {
    return get('/merchants/$merchantId');
  }

  static Future<dynamic> updateMerchant(String merchantId, Map<String, dynamic> data) async {
    return patch('/merchants/$merchantId', data);
  }

  static Future<dynamic> onboardMerchantProduct(String merchantId, Map<String, dynamic> data) async {
    return post('/merchants/$merchantId/products', data);
  }

  static Future<dynamic> getMerchantProducts(String merchantId) async {
    return get('/merchants/$merchantId/products');
  }

  static Future<dynamic> checkProductFit({
    required String productId,
    required String roomId,
    String? targetElementId,
  }) async {
    final payload = <String, dynamic>{
      'room_id': roomId,
    };
    if (targetElementId != null) {
      payload['target_element_id'] = targetElementId;
    }
    return post('/catalog/products/$productId/check-fit', payload);
  }

  static Future<dynamic> addProductPlacement(String roomId, Map<String, dynamic> data) async {
    return post('/rooms/$roomId/visualizations', data);
  }

  static Future<dynamic> getProductPlacements(String roomId) async {
    return get('/rooms/$roomId/visualizations');
  }

  static Future<dynamic> deleteProductPlacement(String roomId, String placementId) async {
    return delete('/rooms/$roomId/visualizations/$placementId');
  }

  static Future<dynamic> trackCommerceClick(Map<String, dynamic> data) async {
    return post('/commerce/track-click', data);
  }

  static Future<dynamic> getCommerceAttribution({String? projectId, String? merchantId}) async {
    final params = <String, String>{};
    if (projectId != null) params['project_id'] = projectId;
    if (merchantId != null) params['merchant_id'] = merchantId;
    final qs = Uri(queryParameters: params).query;
    return get('/commerce/attribution?$qs');
  }

  // ===========================================================================
  // Milestone 6.2: Contractor Handoff & Tender Bid Management
  // ===========================================================================
  static Future<dynamic> generateContractorBrief(
    String projectId, {
    String? roomId,
    String? siteAccessNotes,
  }) async {
    final payload = <String, dynamic>{};
    if (roomId != null) payload['room_id'] = roomId;
    if (siteAccessNotes != null) payload['site_access_notes'] = siteAccessNotes;
    return post('/projects/$projectId/contractor-brief', payload);
  }

  static Future<dynamic> getContractorBrief(String projectId) async {
    return get('/projects/$projectId/contractor-brief');
  }

  static Future<dynamic> getContractorBriefById(String briefId) async {
    return get('/contractor-briefs/$briefId');
  }

  static Future<String> getContractorBriefPrintableHtml(String briefId) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}/contractor-briefs/$briefId/printable');
    final headers = await _buildHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }
    throw Exception('Failed to load printable contractor brief: ${response.statusCode}');
  }

  static Future<dynamic> verifyChecklistItem(
    String briefId, {
    required String checklistId,
    String verifiedByName = 'Lead Contractor',
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'checklist_id': checklistId,
      'verified_by_name': verifiedByName,
    };
    if (notes != null) payload['notes'] = notes;
    return post('/contractor-briefs/$briefId/verify-item', payload);
  }

  static Future<dynamic> createContractorRFQ(
    String projectId, {
    required String title,
    required List<String> targetTrades,
    String? briefId,
    String? roomId,
    DateTime? submissionDeadline,
    List<String>? invitedContractors,
    String? legalTermsAndConditions,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'target_trades': targetTrades,
    };
    if (briefId != null) payload['brief_id'] = briefId;
    if (roomId != null) payload['room_id'] = roomId;
    if (submissionDeadline != null) payload['submission_deadline'] = submissionDeadline.toIso8601String();
    if (invitedContractors != null) payload['invited_contractors'] = invitedContractors;
    if (legalTermsAndConditions != null) payload['legal_terms_and_conditions'] = legalTermsAndConditions;
    return post('/projects/$projectId/rfqs', payload);
  }

  static Future<dynamic> listContractorRFQs(String projectId) async {
    return get('/projects/$projectId/rfqs');
  }

  static Future<dynamic> getContractorRFQ(String rfqId) async {
    return get('/rfqs/$rfqId');
  }

  static Future<dynamic> submitContractorBid(
    String rfqId,
    Map<String, dynamic> bidData,
  ) async {
    return post('/rfqs/$rfqId/bids', bidData);
  }

  static Future<dynamic> compareContractorBids(String rfqId) async {
    return get('/rfqs/$rfqId/compare');
  }

  static Future<dynamic> awardContractorBid(String rfqId, String bidId) async {
    return post('/rfqs/$rfqId/award/$bidId', {});
  }

  // Milestone 6.3: Property Agent & Virtual Staging API Methods
  static Future<dynamic> createPropertyListing(Map<String, dynamic> data) async {
    return post('/listings', data);
  }

  static Future<dynamic> listPropertyListings({String? agentLicense}) async {
    final queryStr = (agentLicense != null && agentLicense.isNotEmpty)
        ? '?agent_license=${Uri.encodeComponent(agentLicense)}'
        : '';
    return get('/listings$queryStr');
  }

  static Future<dynamic> getPropertyListing(String listingId) async {
    return get('/listings/$listingId');
  }

  static Future<dynamic> stageRoomForListing(String listingId, Map<String, dynamic> data) async {
    return post('/listings/$listingId/stage-room', data);
  }

  static Future<dynamic> getStagedRoomDisclosure(String listingId, String assetId) async {
    return get('/listings/$listingId/staged-rooms/$assetId/disclosure');
  }

  static Future<dynamic> exportListingPortalBundle(String listingId, {String portalTarget = 'propertyguru'}) async {
    return post('/listings/$listingId/export-portal-bundle', {'portal_target': portalTarget});
  }

  static Future<String> getPropertyMarketingFlyerHtml(String listingId) async {
    final url = Uri.parse('${AppConfig.fullApiUrl}/listings/$listingId/marketing-flyer');
    final headers = await _buildHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }
    throw Exception('Failed to load printable property marketing flyer: ${response.statusCode}');
  }

  // Milestone 6.4: Cross-Segment Workflow Orchestration API Methods
  static Future<dynamic> initiateHandoff(Map<String, dynamic> data) async {
    return post('/orchestration/handoffs', data);
  }

  static Future<dynamic> acceptHandoff(String handoffId, Map<String, dynamic> data) async {
    return post('/orchestration/handoffs/$handoffId/accept', data);
  }

  static Future<dynamic> completeHandoff(String handoffId) async {
    return post('/orchestration/handoffs/$handoffId/complete', {});
  }

  static Future<dynamic> revokeHandoff(String handoffId, {String? reason}) async {
    return post('/orchestration/handoffs/$handoffId/revoke', {'reason': reason ?? 'Access revoked'});
  }

  static Future<dynamic> listHandoffs({String? projectId, String? actorId}) async {
    final queryParams = <String>[];
    if (projectId != null && projectId.isNotEmpty) queryParams.add('project_id=${Uri.encodeComponent(projectId)}');
    if (actorId != null && actorId.isNotEmpty) queryParams.add('actor_id=${Uri.encodeComponent(actorId)}');
    final queryStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return get('/orchestration/handoffs$queryStr');
  }

  static Future<dynamic> getWorkflowOrchestrationSummary(String projectId) async {
    return get('/projects/$projectId/orchestration-summary');
  }

  static Future<dynamic> getProjectAuditLog(String projectId) async {
    return get('/projects/$projectId/audit-log');
  }

  static Future<dynamic> getRoleScopedProjectView(String projectId, String role) async {
    return get('/projects/$projectId/role-view?role=${Uri.encodeComponent(role)}');
  }

  static Future<dynamic> loginWithSocial({
    required String provider,
    required String email,
    String? name,
    String? idToken,
    String role = 'homeowner',
  }) async {
    final payload = <String, dynamic>{
      'provider': provider,
      'email': email,
      'role': role,
    };
    if (name != null) payload['name'] = name;
    if (idToken != null) payload['id_token'] = idToken;
    return post('/auth/social-login', payload);
  }

  // =====================================================================
  // AI Evaluation API Methods (Ollama, Gemini, OpenAI, Claude)
  // =====================================================================

  static Future<dynamic> getAiStatus() async {
    return get('/ai/status');
  }

  static Future<dynamic> updateAiConfig({
    String? provider,
    String? ollamaUrl,
    String? ollamaBaseUrl,
    String? defaultModel,
    String? model,
  }) async {
    final payload = <String, dynamic>{};
    final url = ollamaUrl ?? ollamaBaseUrl;
    final m = defaultModel ?? model;
    if (url != null) payload['ollama_url'] = url;
    if (m != null) payload['default_model'] = m;
    if (provider != null) payload['provider'] = provider;
    return post('/ai/config', payload);
  }

  static Future<dynamic> evaluateRoomAi(
    String roomId, {
    String? provider,
    String? model,
    String? selectedVariantId,
    String? customPrompt,
    String? prompt,
    String? ollamaUrl,
  }) async {
    final payload = <String, dynamic>{
      'provider': provider ?? AppConfig.aiProvider,
      'model': model ?? AppConfig.aiModel,
      'ollama_url': ollamaUrl ?? AppConfig.ollamaUrl,
    };
    if (selectedVariantId != null) payload['selected_variant_id'] = selectedVariantId;
    final effectivePrompt = customPrompt ?? prompt;
    if (effectivePrompt != null) payload['custom_prompt'] = effectivePrompt;
    return post('/rooms/$roomId/ai-evaluation', payload);
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
