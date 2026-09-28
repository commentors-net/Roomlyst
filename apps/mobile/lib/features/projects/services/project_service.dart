import 'dart:typed_data';
import '../../../core/network/api_client.dart';
import '../domain/project.dart';

class ProjectService {
  static Future<List<ProjectModel>> fetchProjects({String? clientId}) async {
    try {
      final endpoint = clientId != null ? '/projects?client_id=${Uri.encodeComponent(clientId)}' : '/projects';
      final res = await ApiClient.get(endpoint);
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

  static Future<ProjectModel> createProject(
    String name, {
    String currency = 'MYR',
    String? clientId,
    String? propertyAddress,
    String? designerNotes,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'currency': currency,
    };
    if (clientId != null) payload['client_id'] = clientId;
    if (propertyAddress != null) payload['property_address'] = propertyAddress;
    if (designerNotes != null) payload['designer_notes'] = designerNotes;

    final res = await ApiClient.post('/projects', payload);
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

  static Future<List<CatalogProductModel>> fetchCatalogProducts({
    String? category,
    String? style,
    String? tier,
    String? currency,
    double? maxPrice,
    String? query,
    int limit = 50,
  }) async {
    final res = await ApiClient.queryCatalogProducts(
      category: category,
      style: style,
      tier: tier,
      currency: currency,
      maxPrice: maxPrice,
      query: query,
      limit: limit,
    );
    if (res is List) {
      return res.map((e) => CatalogProductModel.fromMap(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<CatalogProductModel> fetchCatalogProduct(String productId) async {
    final res = await ApiClient.getCatalogProduct(productId);
    return CatalogProductModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<ProductRecommendationReportModel> generateRoomRecommendations({
    required String roomId,
    String? preferredStyle,
    String? preferredTier,
    String? preferredCurrency,
    double? maxBudget,
  }) async {
    final res = await ApiClient.generateRoomRecommendations(
      roomId: roomId,
      preferredStyle: preferredStyle,
      preferredTier: preferredTier,
      preferredCurrency: preferredCurrency,
      maxBudget: maxBudget,
    );
    return ProductRecommendationReportModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<ProductRecommendationReportModel> fetchRoomRecommendations(String roomId) async {
    final res = await ApiClient.getRoomRecommendations(roomId);
    return ProductRecommendationReportModel.fromMap(res as Map<String, dynamic>);
  }

  // Milestone 4.4: Renovation Plan Output Services
  static Future<RenovationPlanVersionModel> generateRenovationPlan({
    required String roomId,
    String? selectedVariantId,
  }) async {
    final res = await ApiClient.createRenovationPlan(
      roomId,
      selectedVariantId: selectedVariantId,
    );
    final map = res as Map<String, dynamic>;
    if (map.containsKey('plan')) {
      return RenovationPlanVersionModel.fromMap(map['plan'] as Map<String, dynamic>);
    }
    return RenovationPlanVersionModel.fromMap(map);
  }

  static Future<List<RenovationPlanVersionModel>> fetchRoomRenovationPlans(String roomId) async {
    final res = await ApiClient.getRoomRenovationPlans(roomId);
    final map = res as Map<String, dynamic>;
    final rawPlans = (map['plans'] as List<dynamic>?) ?? [];
    return rawPlans
        .map((e) => RenovationPlanVersionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<RenovationPlanVersionModel> fetchRenovationPlan({
    required String roomId,
    required String planId,
  }) async {
    final res = await ApiClient.getRenovationPlan(roomId, planId);
    final map = res as Map<String, dynamic>;
    if (map.containsKey('plan')) {
      return RenovationPlanVersionModel.fromMap(map['plan'] as Map<String, dynamic>);
    }
    return RenovationPlanVersionModel.fromMap(map);
  }

  static Future<Map<String, dynamic>> exportRenovationPlan({
    required String roomId,
    required String planId,
    String format = 'markdown',
  }) async {
    final res = await ApiClient.exportRenovationPlan(roomId, planId, format: format);
    return res as Map<String, dynamic>;
  }

  // Milestone 5.1: Client and Project Workspace Services
  static Future<ClientModel> createClient({
    required String name,
    String? email,
    String? phone,
    String? company,
    String? notes,
    double? budgetPreference,
    String currency = 'MYR',
    List<String>? preferredStyles,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'currency': currency,
    };
    if (email != null) payload['email'] = email;
    if (phone != null) payload['phone'] = phone;
    if (company != null) payload['company'] = company;
    if (notes != null) payload['notes'] = notes;
    if (budgetPreference != null) payload['budget_preference'] = budgetPreference;
    if (preferredStyles != null) payload['preferred_styles'] = preferredStyles;

    final res = await ApiClient.createClient(payload);
    return ClientModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<List<ClientModel>> fetchClients({String? query}) async {
    final res = await ApiClient.getClients(query: query);
    if (res is List) {
      return res.map((e) => ClientModel.fromMap(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<ClientModel> fetchClient(String clientId) async {
    final res = await ApiClient.getClient(clientId);
    return ClientModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<ClientModel> updateClient(
    String clientId, {
    String? name,
    String? email,
    String? phone,
    String? company,
    String? notes,
    double? budgetPreference,
    String? currency,
    List<String>? preferredStyles,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (email != null) payload['email'] = email;
    if (phone != null) payload['phone'] = phone;
    if (company != null) payload['company'] = company;
    if (notes != null) payload['notes'] = notes;
    if (budgetPreference != null) payload['budget_preference'] = budgetPreference;
    if (currency != null) payload['currency'] = currency;
    if (preferredStyles != null) payload['preferred_styles'] = preferredStyles;

    final res = await ApiClient.updateClient(clientId, payload);
    return ClientModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<void> deleteClient(String clientId) async {
    await ApiClient.deleteClient(clientId);
  }

  static Future<ProjectModel> updateProjectDetails(
    String projectId, {
    String? name,
    String? clientId,
    String? status,
    String? propertyAddress,
    String? designerNotes,
    String? targetCompletionDate,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (clientId != null) payload['client_id'] = clientId;
    if (status != null) payload['status'] = status;
    if (propertyAddress != null) payload['property_address'] = propertyAddress;
    if (designerNotes != null) payload['designer_notes'] = designerNotes;
    if (targetCompletionDate != null) payload['target_completion_date'] = targetCompletionDate;

    final res = await ApiClient.updateProject(projectId, payload);
    return ProjectModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<ProjectWorkspaceSummaryModel> fetchProjectSummary(String projectId) async {
    final res = await ApiClient.getProjectSummary(projectId);
    return ProjectWorkspaceSummaryModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<ProjectCollaboratorModel> addProjectCollaborator(
    String projectId, {
    required String userId,
    required String role,
    String? email,
    String? name,
  }) async {
    final res = await ApiClient.addProjectCollaborator(
      projectId,
      userId: userId,
      role: role,
      email: email,
      name: name,
    );
    return ProjectCollaboratorModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<List<ProjectCollaboratorModel>> fetchProjectCollaborators(String projectId) async {
    final res = await ApiClient.getProjectCollaborators(projectId);
    if (res is List) {
      return res.map((e) => ProjectCollaboratorModel.fromMap(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<void> removeProjectCollaborator(String projectId, String userId) async {
    await ApiClient.removeProjectCollaborator(projectId, userId);
  }

  // Milestone 5.2: Collaboration, Approvals & Review
  static Future<DesignCommentModel> createComment(
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
    final res = await ApiClient.createComment(
      roomId,
      authorId: authorId,
      authorName: authorName,
      text: text,
      authorRole: authorRole,
      variantId: variantId,
      versionId: versionId,
      pinX: pinX,
      pinY: pinY,
      elementId: elementId,
      parentCommentId: parentCommentId,
    );
    return DesignCommentModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<List<DesignCommentModel>> fetchComments(
    String roomId, {
    String? variantId,
    String? status,
  }) async {
    final res = await ApiClient.getComments(roomId, variantId: variantId, status: status);
    if (res is List) {
      return res.map((e) => DesignCommentModel.fromMap(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<DesignCommentModel> updateCommentStatus(String commentId, String status) async {
    final res = await ApiClient.updateCommentStatus(commentId, status);
    return DesignCommentModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<void> deleteComment(String commentId) async {
    await ApiClient.deleteComment(commentId);
  }

  static Future<ApprovalRecordModel> submitApproval(
    String roomId, {
    required String status,
    String? decidedByName,
    String? decidedByRole,
    String? notes,
    String? versionId,
    String? variantId,
  }) async {
    final res = await ApiClient.submitApproval(
      roomId,
      status: status,
      decidedByName: decidedByName,
      decidedByRole: decidedByRole,
      notes: notes,
      versionId: versionId,
      variantId: variantId,
    );
    return ApprovalRecordModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> fetchApprovals(String roomId, {String? variantId}) async {
    final res = await ApiClient.getApprovals(roomId, variantId: variantId);
    return res as Map<String, dynamic>;
  }

  static Future<ShareReviewLinkModel> createShareLink(
    String projectId, {
    String? roomId,
    String createdBy = 'designer',
    String permission = 'CAN_COMMENT',
    bool allowComments = true,
    bool allowApprovals = false,
    int expiresInDays = 14,
  }) async {
    final res = await ApiClient.createShareLink(
      projectId,
      roomId: roomId,
      createdBy: createdBy,
      permission: permission,
      allowComments: allowComments,
      allowApprovals: allowApprovals,
      expiresInDays: expiresInDays,
    );
    return ShareReviewLinkModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<List<ShareReviewLinkModel>> fetchProjectShareLinks(String projectId) async {
    final res = await ApiClient.getProjectShareLinks(projectId);
    if (res is List) {
      return res.map((e) => ShareReviewLinkModel.fromMap(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<void> revokeShareLink(String linkId) async {
    await ApiClient.revokeShareLink(linkId);
  }

  static Future<ReviewSessionModel> fetchReviewSession(String token) async {
    final res = await ApiClient.getReviewSession(token);
    return ReviewSessionModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<DesignCommentModel> postReviewComment(
    String token, {
    required String authorId,
    required String authorName,
    required String text,
    String? variantId,
    double? pinX,
    double? pinY,
  }) async {
    final res = await ApiClient.postReviewComment(
      token,
      authorId: authorId,
      authorName: authorName,
      text: text,
      variantId: variantId,
      pinX: pinX,
      pinY: pinY,
    );
    return DesignCommentModel.fromMap(res as Map<String, dynamic>);
  }

  static Future<ApprovalRecordModel> submitReviewDecision(
    String token, {
    required String status,
    String? decidedByName,
    String? notes,
    String? variantId,
  }) async {
    final res = await ApiClient.submitReviewDecision(
      token,
      status: status,
      decidedByName: decidedByName,
      notes: notes,
      variantId: variantId,
    );
    return ApprovalRecordModel.fromMap(res as Map<String, dynamic>);
  }
}


