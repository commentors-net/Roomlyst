import 'dart:typed_data';
import '../../../core/network/api_client.dart';
import '../domain/project.dart';

class ProjectService {
  static Future<List<ProjectModel>> fetchProjects() async {
    try {
      final res = await ApiClient.get('/projects');
      if (res is List) {
        return res.map((e) => ProjectModel.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    // Return sample project if API is offline
    return [
      ProjectModel(
        id: 'proj_demo_01',
        name: 'My Living Room Renovation',
        currency: 'MYR',
        status: 'ACTIVE',
      ),
    ];
  }

  static Future<ProjectModel> createProject(String name, {String currency = 'MYR'}) async {
    final res = await ApiClient.post('/projects', {'name': name, 'currency': currency});
    return ProjectModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<RoomModelData> fetchRoomModel(String roomId) async {
    final res = await ApiClient.get('/rooms/$roomId/model');
    return RoomModelData.fromMap(res as Map<String, dynamic>);
  }

  static Future<void> updateElementAction(String roomId, String elementId, String action) async {
    await ApiClient.patch(
      '/rooms/$roomId/elements/$elementId',
      {'action': action},
    );
  }

  static Future<List<RedesignVariantModel>> generateRedesigns({
    required String roomId,
    required List<String> styles,
    required double budgetAmount,
    String budgetCurrency = 'MYR',
    String renovationTier = 'MODERATE',
    String? prompt,
    String? parentVersionId,
    String? parentVariantId,
    String? branchLabel,
  }) async {
    final res = await ApiClient.post(
      '/rooms/$roomId/design-requests',
      {
        'styles': styles,
        'goals': ['modernize', 'harmonize'],
        'budget_amount': budgetAmount,
        'budget_currency': budgetCurrency,
        'renovation_tier': renovationTier,
        'free_text_prompt': prompt,
        'parent_version_id': parentVersionId,
        'parent_variant_id': parentVariantId,
        'branch_label': branchLabel,
      },
    );

    if (res is Map && res.containsKey('variants')) {
      final rawVariants = res['variants'] as List<dynamic>;
      return rawVariants.map((e) => RedesignVariantModel.fromMap(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<List<DesignVersionModel>> fetchRoomVersions(String roomId) async {
    final res = await ApiClient.getRoomVersions(roomId);
    if (res is List<dynamic>) {
      return res.map((e) => DesignVersionModel.fromMap(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<DesignVersionModel> branchDesignVersion({
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
    final res = await ApiClient.branchDesignVersion(
      roomId: roomId,
      parentVersionId: parentVersionId,
      parentVariantId: parentVariantId,
      branchLabel: branchLabel,
      styles: styles,
      budgetAmount: budgetAmount,
      budgetCurrency: budgetCurrency,
      renovationTier: renovationTier,
      prompt: prompt,
    );
    return DesignVersionModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<RedesignVariantModel> toggleVariantFavorite({
    required String roomId,
    required String variantId,
    bool? isFavorite,
    String? notes,
  }) async {
    final res = await ApiClient.toggleVariantFavorite(
      roomId: roomId,
      variantId: variantId,
      isFavorite: isFavorite,
      notes: notes,
    );
    return RedesignVariantModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<List<dynamic>> fetchRoomFavorites(String roomId) async {
    final res = await ApiClient.getRoomFavorites(roomId);
    if (res is List<dynamic>) return res;
    return [];
  }

  static Future<VariantComparisonModel> compareVariants({
    required String roomId,
    required String variantAId,
    required String variantBId,
  }) async {
    final res = await ApiClient.compareVariants(
      roomId: roomId,
      variantAId: variantAId,
      variantBId: variantBId,
    );
    return VariantComparisonModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<BudgetPlanModel> calculateRoomBudget({
    required String roomId,
    required double totalBudget,
    String currency = 'MYR',
    String renovationTier = 'MODERATE',
    double contingencyPct = 10.0,
    bool includeTax = false,
    double? customTaxRate,
    Map<String, String>? actions,
  }) async {
    final res = await ApiClient.calculateRoomBudget(
      roomId: roomId,
      totalBudget: totalBudget,
      currency: currency,
      renovationTier: renovationTier,
      contingencyPct: contingencyPct,
      includeTax: includeTax,
      customTaxRate: customTaxRate,
      actions: actions,
    );
    return BudgetPlanModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<BudgetPlanModel> fetchRoomBudget(String roomId) async {
    final res = await ApiClient.getRoomBudget(roomId);
    return BudgetPlanModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<List<BudgetScenarioComparisonModel>> fetchBudgetScenarios({
    required String roomId,
    double totalBudget = 15000.0,
    String currency = 'MYR',
    double contingencyPct = 10.0,
    bool includeTax = false,
    double? customTaxRate,
  }) async {
    final res = await ApiClient.getBudgetScenarios(
      roomId: roomId,
      totalBudget: totalBudget,
      currency: currency,
      contingencyPct: contingencyPct,
      includeTax: includeTax,
      customTaxRate: customTaxRate,
    );
    final rawList = (res as List<dynamic>?) ?? [];
    return rawList.map((e) => BudgetScenarioComparisonModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  static Future<bool> deleteProject(String projectId) async {
    try {
      await ApiClient.delete('/projects/$projectId');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> initVideoScanSession({
    required String roomId,
    int? totalChunks,
    int? totalBytes,
    String videoFormat = 'mp4',
  }) async {
    final res = await ApiClient.initVideoScanSession(
      roomId: roomId,
      totalChunks: totalChunks,
      totalBytes: totalBytes,
      videoFormat: videoFormat,
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> uploadVideoChunk({
    required String sessionId,
    required int chunkIndex,
    required Uint8List chunkBytes,
    String filename = 'chunk.bin',
  }) async {
    final res = await ApiClient.uploadVideoChunk(
      sessionId: sessionId,
      chunkIndex: chunkIndex,
      chunkBytes: chunkBytes,
      filename: filename,
    );
    return res as Map<String, dynamic>;
  }

  static Future<VideoScanReportModel> completeVideoScanSession({
    required String sessionId,
  }) async {
    final res = await ApiClient.completeVideoScanSession(sessionId: sessionId);
    final map = res as Map<String, dynamic>;
    if (map.containsKey('report')) {
      return VideoScanReportModel.fromMap(map['report'] as Map<String, dynamic>);
    }
    return VideoScanReportModel.fromMap(map);
  }

  static Future<VideoScanReportModel> sampleAndAnalyzeVideo({
    required String roomId,
    required List<Uint8List> keyframeBytesList,
    required List<String> fileNames,
    double videoDurationSeconds = 0.0,
    double fps = 30.0,
  }) async {
    final res = await ApiClient.sampleAndAnalyzeVideo(
      roomId: roomId,
      keyframeBytesList: keyframeBytesList,
      fileNames: fileNames,
      videoDurationSeconds: videoDurationSeconds,
      fps: fps,
    );
    return VideoScanReportModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<VideoScanReportModel> fetchVideoScanReport(String roomId) async {
    final res = await ApiClient.getVideoScanReport(roomId);
    return VideoScanReportModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<MultiViewReconstructionReportModel> runSfmPipeline({
    required String roomId,
    List<Uint8List>? imageBytesList,
    List<String>? fileNames,
  }) async {
    final res = await ApiClient.runSfmPipeline(
      roomId: roomId,
      imageBytesList: imageBytesList,
      fileNames: fileNames,
    );
    final map = res as Map<String, dynamic>;
    if (map.containsKey('report')) {
      return MultiViewReconstructionReportModel.fromMap(map['report'] as Map<String, dynamic>);
    }
    return MultiViewReconstructionReportModel.fromMap(map);
  }

  static Future<MultiViewReconstructionReportModel> fetchReconstructionReport(String roomId) async {
    final res = await ApiClient.getReconstructionReport(roomId);
    return MultiViewReconstructionReportModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<PointCloudMetadataModel> fetchRoomPointCloud(String roomId) async {
    final res = await ApiClient.getRoomPointCloud(roomId);
    return PointCloudMetadataModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<List<SpatialPlaneModel>> fetchRoomSpatialPlanes(String roomId) async {
    final res = await ApiClient.getRoomSpatialPlanes(roomId);
    final map = res as Map<String, dynamic>;
    final planes = (map['planes'] as List<dynamic>?) ?? [];
    return planes.map((e) => SpatialPlaneModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  static Future<dynamic> ingestARMotionTelemetry({
    required String roomId,
    required List<Map<String, dynamic>> poses,
    List<Map<String, dynamic>>? imuSamples,
    Map<String, dynamic>? depthPayload,
    String deviceTier = 'TIER_3_AR_RGB',
  }) async {
    return ApiClient.ingestARMotionTelemetry(
      roomId: roomId,
      poses: poses,
      imuSamples: imuSamples,
      depthPayload: depthPayload,
      deviceTier: deviceTier,
    );
  }

  static Future<ARAssistedScanReportModel> fuseARMotionWithReconstruction({
    required String roomId,
    List<Map<String, dynamic>>? poses,
    List<Map<String, dynamic>>? imuSamples,
    Map<String, dynamic>? depthPayload,
    String deviceTier = 'TIER_3_AR_RGB',
  }) async {
    final res = await ApiClient.fuseARMotionWithReconstruction(
      roomId: roomId,
      poses: poses,
      imuSamples: imuSamples,
      depthPayload: depthPayload,
      deviceTier: deviceTier,
    );
    final map = res as Map<String, dynamic>;
    if (map.containsKey('report')) {
      return ARAssistedScanReportModel.fromMap(map['report'] as Map<String, dynamic>);
    }
    return ARAssistedScanReportModel.fromMap(map);
  }

  static Future<ARAssistedScanReportModel> fetchARScanReport(String roomId) async {
    final res = await ApiClient.getARScanReport(roomId);
    return ARAssistedScanReportModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> normalizeNativeSpatialScan(NativeSpatialScanPayloadModel payload) async {
    final res = await ApiClient.normalizeNativeSpatialScan(payload.toMap());
    return res as Map<String, dynamic>;
  }

  static Future<NativeSpatialScanReportModel> fetchNativeSpatialReport(String roomId) async {
    final res = await ApiClient.getNativeSpatialReport(roomId);
    final map = res as Map<String, dynamic>;
    if (map.containsKey('report')) {
      return NativeSpatialScanReportModel.fromMap(map['report'] as Map<String, dynamic>);
    }
    return NativeSpatialScanReportModel.fromMap(map);
  }

  static Future<List<TierBenchmarkMetricsModel>> fetchScanTelemetryBenchmarks() async {
    final res = await ApiClient.getScanTelemetryBenchmarks();
    if (res is List) {
      return res.map((e) => TierBenchmarkMetricsModel.fromMap(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<ScanOrchestrationEvaluationModel> evaluateScanRoute(Map<String, dynamic> deviceProfile) async {
    final res = await ApiClient.evaluateScanRoute(deviceProfile);
    return ScanOrchestrationEvaluationModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<RoomModelData> attachScanOrchestration(String roomId, Map<String, dynamic> deviceProfile) async {
    final res = await ApiClient.attachScanOrchestration(roomId, deviceProfile);
    return RoomModelData.fromMap(res as Map<String, dynamic>);
  }

  static Future<MaterialTakeoffReportModel> fetchMaterialTakeoff(String roomId) async {
    final res = await ApiClient.getMaterialTakeoff(roomId);
    return MaterialTakeoffReportModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<MaterialTakeoffReportModel> calculateMaterialTakeoff({
    required String roomId,
    Map<String, double>? customWasteFactors,
  }) async {
    final res = await ApiClient.generateMaterialTakeoff(
      roomId: roomId,
      customWasteFactors: customWasteFactors,
    );
    return MaterialTakeoffReportModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<MaterialTakeoffReportModel> verifyTakeoffDimension({
    required String roomId,
    required String dimensionId,
    required double verifiedValue,
    String verifiedBy = 'Contractor',
    String? notes,
  }) async {
    final res = await ApiClient.verifyCriticalDimension(
      roomId: roomId,
      dimensionId: dimensionId,
      verifiedValue: verifiedValue,
      verifiedBy: verifiedBy,
      notes: notes,
    );
    final map = res as Map<String, dynamic>;
    if (map.containsKey('takeoff_report')) {
      return MaterialTakeoffReportModel.fromMap(map['takeoff_report'] as Map<String, dynamic>);
    }
    return MaterialTakeoffReportModel.fromMap(map);
  }
}


