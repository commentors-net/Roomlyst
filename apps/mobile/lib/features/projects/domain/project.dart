// Project and Room Domain Models for Flutter.


class ProjectModel {
  final String id;
  final String name;
  final String currency;
  final String status;
  final List<String> roomIds;

  ProjectModel({
    required this.id,
    required this.name,
    this.currency = 'MYR',
    this.status = 'ACTIVE',
    this.roomIds = const [],
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] as String,
      name: map['name'] as String,
      currency: map['currency'] as String? ?? 'MYR',
      status: map['status'] as String? ?? 'ACTIVE',
      roomIds: (map['room_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class DetectedElement {
  final String id;
  final String name;
  final String type; // opening, surface, object
  String action; // KEEP, REPLACE, REMOVE, RESTYLE
  final double confidence;
  final String? subtitle;

  DetectedElement({
    required this.id,
    required this.name,
    required this.type,
    this.action = 'KEEP',
    this.confidence = 0.85,
    this.subtitle,
  });

  factory DetectedElement.fromMap(Map<String, dynamic> map, String type) {
    return DetectedElement(
      id: map['id'] as String,
      name: map['name'] as String,
      type: type,
      action: map['action'] as String? ?? 'KEEP',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.85,
      subtitle: map['category'] as String? ?? map['surface_type'] as String? ?? map['opening_type'] as String?,
    );
  }
}

class CoverageReportModel {
  final int totalFrames;
  final int validFrames;
  final double estimatedCoveragePct;
  final List<String> actionableGuidance;

  CoverageReportModel({
    required this.totalFrames,
    required this.validFrames,
    required this.estimatedCoveragePct,
    required this.actionableGuidance,
  });

  factory CoverageReportModel.fromMap(Map<String, dynamic> map) {
    return CoverageReportModel(
      totalFrames: map['total_frames'] as int? ?? 1,
      validFrames: map['valid_frames'] as int? ?? 1,
      estimatedCoveragePct: (map['estimated_coverage_pct'] as num?)?.toDouble() ?? 40.0,
      actionableGuidance: (map['actionable_guidance'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class ScaleCalibrationModel {
  final String referenceType;
  final String? referenceEntityId;
  final String referenceDimensionType;
  final double originalEstimatedValue;
  final double targetRealValue;
  final double scaleFactor;
  final String? notes;

  ScaleCalibrationModel({
    required this.referenceType,
    this.referenceEntityId,
    required this.referenceDimensionType,
    required this.originalEstimatedValue,
    required this.targetRealValue,
    required this.scaleFactor,
    this.notes,
  });

  factory ScaleCalibrationModel.fromMap(Map<String, dynamic> map) {
    return ScaleCalibrationModel(
      referenceType: map['reference_type'] as String? ?? 'KNOWN_WALL_DIMENSION',
      referenceEntityId: map['reference_entity_id'] as String?,
      referenceDimensionType: map['reference_dimension_type'] as String? ?? 'width',
      originalEstimatedValue: (map['original_estimated_value'] as num?)?.toDouble() ?? 1.0,
      targetRealValue: (map['target_real_value'] as num?)?.toDouble() ?? 1.0,
      scaleFactor: (map['scale_factor'] as num?)?.toDouble() ?? 1.0,
      notes: map['notes'] as String?,
    );
  }
}

class MeasurementModel {
  final String id;
  final String? roomId;
  final String entityType;
  final String? entityId;
  final String measurementType;
  double value;
  final String unit;
  double confidence;
  String source;
  bool isApproximate;
  bool verifiedByUser;
  final String? displayString;
  String accuracyTier;

  MeasurementModel({
    required this.id,
    this.roomId,
    required this.entityType,
    this.entityId,
    required this.measurementType,
    required this.value,
    this.unit = 'm',
    this.confidence = 0.5,
    this.source = 'ESTIMATED',
    this.isApproximate = true,
    this.verifiedByUser = false,
    this.displayString,
    this.accuracyTier = 'APPROXIMATE',
  });

  factory MeasurementModel.fromMap(Map<String, dynamic> map) {
    return MeasurementModel(
      id: map['id'] as String,
      roomId: map['room_id'] as String?,
      entityType: map['entity_type'] as String? ?? 'surface',
      entityId: map['entity_id'] as String?,
      measurementType: map['measurement_type'] as String? ?? 'width',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'm',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      source: map['source'] as String? ?? 'ESTIMATED',
      isApproximate: map['is_approximate'] as bool? ?? true,
      verifiedByUser: map['verified_by_user'] as bool? ?? false,
      displayString: map['display_string'] as String?,
      accuracyTier: map['accuracy_tier'] as String? ?? 'APPROXIMATE',
    );
  }

  String get formattedValue {
    if (measurementType == 'area') {
      return '${value.toStringAsFixed(2)} m²';
    }
    return '${value.toStringAsFixed(2)} $unit';
  }

  String get readableType {
    switch (measurementType) {
      case 'width':
        return 'Width';
      case 'height':
        return 'Height';
      case 'depth':
        return 'Depth';
      case 'area':
        return 'Floor / Wall Area';
      case 'clearance':
        return 'Clearance';
      default:
        return measurementType;
    }
  }
}

class Point2DModel {
  final double x;
  final double y;

  Point2DModel({required this.x, required this.y});

  factory Point2DModel.fromMap(Map<String, dynamic> map) {
    return Point2DModel(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WallSegmentModel {
  final String id;
  final String? name;
  final Point2DModel startPoint;
  final Point2DModel endPoint;
  final double lengthM;
  final double? heightM;

  WallSegmentModel({
    required this.id,
    this.name,
    required this.startPoint,
    required this.endPoint,
    required this.lengthM,
    this.heightM,
  });

  factory WallSegmentModel.fromMap(Map<String, dynamic> map) {
    return WallSegmentModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String?,
      startPoint: Point2DModel.fromMap((map['start_point'] as Map<String, dynamic>?) ?? {}),
      endPoint: Point2DModel.fromMap((map['end_point'] as Map<String, dynamic>?) ?? {}),
      lengthM: (map['length_m'] as num?)?.toDouble() ?? 0.0,
      heightM: (map['height_m'] as num?)?.toDouble(),
    );
  }
}

class GeometryModel {
  final double? floorAreaSqm;
  final double? ceilingHeightM;
  final double? estimatedWidthM;
  final double? estimatedLengthM;
  final String roomShape;
  final String loopClosureStatus;
  final double loopClosureGapM;
  final double? perimeterM;
  final List<Point2DModel> polygonVertices;
  final List<WallSegmentModel> wallSegments;

  GeometryModel({
    this.floorAreaSqm,
    this.ceilingHeightM,
    this.estimatedWidthM,
    this.estimatedLengthM,
    this.roomShape = 'RECTANGULAR',
    this.loopClosureStatus = 'CLOSED',
    this.loopClosureGapM = 0.0,
    this.perimeterM,
    this.polygonVertices = const [],
    this.wallSegments = const [],
  });

  factory GeometryModel.fromMap(Map<String, dynamic> map) {
    final rawVertices = (map['polygon_vertices'] as List<dynamic>?) ?? [];
    final rawWalls = (map['wall_segments'] as List<dynamic>?) ?? [];

    return GeometryModel(
      floorAreaSqm: (map['floor_area_sqm'] as num?)?.toDouble(),
      ceilingHeightM: (map['ceiling_height_m'] as num?)?.toDouble(),
      estimatedWidthM: (map['estimated_width_m'] as num?)?.toDouble(),
      estimatedLengthM: (map['estimated_length_m'] as num?)?.toDouble(),
      roomShape: map['room_shape'] as String? ?? 'RECTANGULAR',
      loopClosureStatus: map['loop_closure_status'] as String? ?? 'CLOSED',
      loopClosureGapM: (map['loop_closure_gap_m'] as num?)?.toDouble() ?? 0.0,
      perimeterM: (map['perimeter_m'] as num?)?.toDouble(),
      polygonVertices: rawVertices.map((e) => Point2DModel.fromMap(e as Map<String, dynamic>)).toList(),
      wallSegments: rawWalls.map((e) => WallSegmentModel.fromMap(e as Map<String, dynamic>)).toList(),
    );
  }

  bool get isClosed => loopClosureStatus == 'CLOSED' || loopClosureStatus == 'SNAPPED';
}

class FeasibilityCheckModel {
  final String checkId;
  final String checkName;
  final bool passed;
  final String severity; // INFO, WARNING, CRITICAL
  final String? issueType;
  final List<String> entityNames;
  final double? measuredClearanceM;
  final double? requiredClearanceM;
  final String message;
  final String? suggestedAction;

  FeasibilityCheckModel({
    required this.checkId,
    required this.checkName,
    required this.passed,
    this.severity = 'INFO',
    this.issueType,
    this.entityNames = const [],
    this.measuredClearanceM,
    this.requiredClearanceM,
    required this.message,
    this.suggestedAction,
  });

  factory FeasibilityCheckModel.fromMap(Map<String, dynamic> map) {
    return FeasibilityCheckModel(
      checkId: map['check_id'] as String? ?? '',
      checkName: map['check_name'] as String? ?? '',
      passed: map['passed'] as bool? ?? true,
      severity: map['severity'] as String? ?? 'INFO',
      issueType: map['issue_type'] as String?,
      entityNames: (map['entity_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      measuredClearanceM: (map['measured_clearance_m'] as num?)?.toDouble(),
      requiredClearanceM: (map['required_clearance_m'] as num?)?.toDouble(),
      message: map['message'] as String? ?? '',
      suggestedAction: map['suggested_action'] as String?,
    );
  }
}

class FeasibilityReportModel {
  final bool overallFeasible;
  final int criticalIssuesCount;
  final int warningIssuesCount;
  final List<FeasibilityCheckModel> checks;
  final double? minWalkwayClearanceM;
  final String summary;

  FeasibilityReportModel({
    required this.overallFeasible,
    required this.criticalIssuesCount,
    required this.warningIssuesCount,
    required this.checks,
    this.minWalkwayClearanceM,
    required this.summary,
  });

  factory FeasibilityReportModel.fromMap(Map<String, dynamic> map) {
    final rawChecks = (map['checks'] as List<dynamic>?) ?? [];
    return FeasibilityReportModel(
      overallFeasible: map['overall_feasible'] as bool? ?? true,
      criticalIssuesCount: map['critical_issues_count'] as int? ?? 0,
      warningIssuesCount: map['warning_issues_count'] as int? ?? 0,
      checks: rawChecks.map((e) => FeasibilityCheckModel.fromMap(e as Map<String, dynamic>)).toList(),
      minWalkwayClearanceM: (map['min_walkway_clearance_m'] as num?)?.toDouble(),
      summary: map['summary'] as String? ?? 'All clearances pass.',
    );
  }
}

class CategoryCostItemModel {
  final String category;
  final String categoryName;
  final double allocatedAmount;
  final double estimatedCost;
  final String unit;
  final double quantity;
  final double unitRate;
  final double materialCost;
  final double laborCost;
  final double materialUnitRate;
  final double laborUnitRate;
  final String? tradeName;
  final String? notes;
  final bool isOverBudget;

  CategoryCostItemModel({
    required this.category,
    required this.categoryName,
    required this.allocatedAmount,
    required this.estimatedCost,
    this.unit = 'sqm',
    this.quantity = 1.0,
    this.unitRate = 0.0,
    this.materialCost = 0.0,
    this.laborCost = 0.0,
    this.materialUnitRate = 0.0,
    this.laborUnitRate = 0.0,
    this.tradeName,
    this.notes,
    this.isOverBudget = false,
  });

  factory CategoryCostItemModel.fromMap(Map<String, dynamic> map) {
    return CategoryCostItemModel(
      category: map['category'] as String? ?? 'GENERAL',
      categoryName: map['category_name'] as String? ?? 'General Category',
      allocatedAmount: (map['allocated_amount'] as num?)?.toDouble() ?? 0.0,
      estimatedCost: (map['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'sqm',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitRate: (map['unit_rate'] as num?)?.toDouble() ?? 0.0,
      materialCost: (map['material_cost'] as num?)?.toDouble() ?? 0.0,
      laborCost: (map['labor_cost'] as num?)?.toDouble() ?? 0.0,
      materialUnitRate: (map['material_unit_rate'] as num?)?.toDouble() ?? 0.0,
      laborUnitRate: (map['labor_unit_rate'] as num?)?.toDouble() ?? 0.0,
      tradeName: map['trade_name'] as String?,
      notes: map['notes'] as String?,
      isOverBudget: map['is_over_budget'] as bool? ?? false,
    );
  }
}

class KeepReplaceTradeoffModel {
  final String elementId;
  final String elementLabel;
  final String action;
  final String category;
  final double replacementCostEstimate;
  final double savingsIfKept;
  final String? notes;

  KeepReplaceTradeoffModel({
    required this.elementId,
    required this.elementLabel,
    required this.action,
    required this.category,
    required this.replacementCostEstimate,
    required this.savingsIfKept,
    this.notes,
  });

  factory KeepReplaceTradeoffModel.fromMap(Map<String, dynamic> map) {
    return KeepReplaceTradeoffModel(
      elementId: map['element_id'] as String? ?? '',
      elementLabel: map['element_label'] as String? ?? 'Item',
      action: map['action'] as String? ?? 'keep',
      category: map['category'] as String? ?? 'FURNITURE_DECOR',
      replacementCostEstimate: (map['replacement_cost_estimate'] as num?)?.toDouble() ?? 0.0,
      savingsIfKept: (map['savings_if_kept'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
    );
  }
}

class BudgetScenarioComparisonModel {
  final String tier;
  final String tierName;
  final String description;
  final double subtotalMaterials;
  final double subtotalLabor;
  final double contingencyAmount;
  final double taxAmount;
  final double grandTotalEstimated;
  final double costDeltaVsBudget;
  final bool isWithinBudget;
  final double savingsIfKept;

  BudgetScenarioComparisonModel({
    required this.tier,
    required this.tierName,
    required this.description,
    required this.subtotalMaterials,
    required this.subtotalLabor,
    required this.contingencyAmount,
    required this.taxAmount,
    required this.grandTotalEstimated,
    required this.costDeltaVsBudget,
    required this.isWithinBudget,
    this.savingsIfKept = 0.0,
  });

  factory BudgetScenarioComparisonModel.fromMap(Map<String, dynamic> map) {
    return BudgetScenarioComparisonModel(
      tier: map['tier'] as String? ?? 'MODERATE',
      tierName: map['tier_name'] as String? ?? 'Moderate',
      description: map['description'] as String? ?? '',
      subtotalMaterials: (map['subtotal_materials'] as num?)?.toDouble() ?? 0.0,
      subtotalLabor: (map['subtotal_labor'] as num?)?.toDouble() ?? 0.0,
      contingencyAmount: (map['contingency_amount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      grandTotalEstimated: (map['grand_total_estimated'] as num?)?.toDouble() ?? 0.0,
      costDeltaVsBudget: (map['cost_delta_vs_budget'] as num?)?.toDouble() ?? 0.0,
      isWithinBudget: map['is_within_budget'] as bool? ?? true,
      savingsIfKept: (map['savings_if_kept'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BudgetPlanModel {
  final String planId;
  final double totalBudget;
  final String currency;
  final String renovationTier;
  final List<CategoryCostItemModel> allocatedItems;
  final List<KeepReplaceTradeoffModel> tradeoffs;
  final double totalEstimatedCost;
  final double totalAllocated;
  final double savingsFromKeptItems;
  final double remainingBudget;
  final bool isWithinBudget;
  final double subtotalMaterials;
  final double subtotalLabor;
  final double contingencyPct;
  final double contingencyAmount;
  final String taxName;
  final double taxRatePct;
  final double taxAmount;
  final double grandTotal;
  final List<BudgetScenarioComparisonModel> scenarios;
  final String disclaimer;

  BudgetPlanModel({
    required this.planId,
    required this.totalBudget,
    this.currency = 'MYR',
    this.renovationTier = 'MODERATE',
    this.allocatedItems = const [],
    this.tradeoffs = const [],
    required this.totalEstimatedCost,
    required this.totalAllocated,
    this.savingsFromKeptItems = 0.0,
    this.remainingBudget = 0.0,
    this.isWithinBudget = true,
    this.subtotalMaterials = 0.0,
    this.subtotalLabor = 0.0,
    this.contingencyPct = 10.0,
    this.contingencyAmount = 0.0,
    this.taxName = 'SST',
    this.taxRatePct = 0.0,
    this.taxAmount = 0.0,
    this.grandTotal = 0.0,
    this.scenarios = const [],
    required this.disclaimer,
  });

  factory BudgetPlanModel.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['allocated_items'] as List<dynamic>?) ?? [];
    final rawTradeoffs = (map['tradeoffs'] as List<dynamic>?) ?? [];
    final rawScenarios = (map['scenarios'] as List<dynamic>?) ?? [];

    return BudgetPlanModel(
      planId: map['plan_id'] as String? ?? '',
      totalBudget: (map['total_budget'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'MYR',
      renovationTier: map['renovation_tier'] as String? ?? 'MODERATE',
      allocatedItems: rawItems.map((e) => CategoryCostItemModel.fromMap(e as Map<String, dynamic>)).toList(),
      tradeoffs: rawTradeoffs.map((e) => KeepReplaceTradeoffModel.fromMap(e as Map<String, dynamic>)).toList(),
      totalEstimatedCost: (map['total_estimated_cost'] as num?)?.toDouble() ?? 0.0,
      totalAllocated: (map['total_allocated'] as num?)?.toDouble() ?? 0.0,
      savingsFromKeptItems: (map['savings_from_kept_items'] as num?)?.toDouble() ?? 0.0,
      remainingBudget: (map['remaining_budget'] as num?)?.toDouble() ?? 0.0,
      isWithinBudget: map['is_within_budget'] as bool? ?? true,
      subtotalMaterials: (map['subtotal_materials'] as num?)?.toDouble() ?? 0.0,
      subtotalLabor: (map['subtotal_labor'] as num?)?.toDouble() ?? 0.0,
      contingencyPct: (map['contingency_pct'] as num?)?.toDouble() ?? 10.0,
      contingencyAmount: (map['contingency_amount'] as num?)?.toDouble() ?? 0.0,
      taxName: map['tax_name'] as String? ?? 'SST',
      taxRatePct: (map['tax_rate_pct'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grand_total'] as num?)?.toDouble() ?? ((map['total_estimated_cost'] as num?)?.toDouble() ?? 0.0),
      scenarios: rawScenarios.map((e) => BudgetScenarioComparisonModel.fromMap(e as Map<String, dynamic>)).toList(),
      disclaimer: map['disclaimer'] as String? ??
          'Indicative renovation estimate only based on regional material and work benchmarks. Does not constitute a formal contractor quote.',
    );
  }

  String get currencySymbol {
    switch (currency.toUpperCase()) {
      case 'SGD':
        return 'S\$';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      case 'MYR':
      default:
        return 'RM';
    }
  }
}

class VideoScanMetadataModel {
  final double videoDurationSeconds;
  final double fps;
  final int totalFramesRecorded;
  final int sampledKeyframesCount;
  final double? averageMotionSpeedDegPerSec;
  final double motionStabilityScore;
  final int excessiveMotionWarningsCount;
  final double coverageScore;
  final bool isStableSequence;

  VideoScanMetadataModel({
    this.videoDurationSeconds = 0.0,
    this.fps = 30.0,
    this.totalFramesRecorded = 0,
    this.sampledKeyframesCount = 0,
    this.averageMotionSpeedDegPerSec,
    this.motionStabilityScore = 0.90,
    this.excessiveMotionWarningsCount = 0,
    this.coverageScore = 0.85,
    this.isStableSequence = true,
  });

  factory VideoScanMetadataModel.fromMap(Map<String, dynamic> map) {
    return VideoScanMetadataModel(
      videoDurationSeconds: (map['video_duration_seconds'] as num?)?.toDouble() ?? 0.0,
      fps: (map['fps'] as num?)?.toDouble() ?? 30.0,
      totalFramesRecorded: (map['total_frames_recorded'] as num?)?.toInt() ?? 0,
      sampledKeyframesCount: (map['sampled_keyframes_count'] as num?)?.toInt() ?? 0,
      averageMotionSpeedDegPerSec: (map['average_motion_speed_deg_per_sec'] as num?)?.toDouble(),
      motionStabilityScore: (map['motion_stability_score'] as num?)?.toDouble() ?? 0.90,
      excessiveMotionWarningsCount: (map['excessive_motion_warnings_count'] as num?)?.toInt() ?? 0,
      coverageScore: (map['coverage_score'] as num?)?.toDouble() ?? 0.85,
      isStableSequence: map['is_stable_sequence'] as bool? ?? true,
    );
  }
}

class VideoKeyframeModel {
  final String keyframeId;
  final int frameIndex;
  final double timestampSeconds;
  final String imageUrl;
  final double sharpnessScore;
  final double? cameraMotionSpeed;
  final String? detectedWallView;
  final double estimatedCoveragePct;

  VideoKeyframeModel({
    required this.keyframeId,
    required this.frameIndex,
    required this.timestampSeconds,
    required this.imageUrl,
    this.sharpnessScore = 100.0,
    this.cameraMotionSpeed,
    this.detectedWallView,
    this.estimatedCoveragePct = 0.0,
  });

  factory VideoKeyframeModel.fromMap(Map<String, dynamic> map) {
    return VideoKeyframeModel(
      keyframeId: map['keyframe_id'] as String? ?? '',
      frameIndex: (map['frame_index'] as num?)?.toInt() ?? 0,
      timestampSeconds: (map['timestamp_seconds'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['image_url'] as String? ?? '',
      sharpnessScore: (map['sharpness_score'] as num?)?.toDouble() ?? 100.0,
      cameraMotionSpeed: (map['camera_motion_speed'] as num?)?.toDouble(),
      detectedWallView: map['detected_wall_view'] as String?,
      estimatedCoveragePct: (map['estimated_coverage_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VideoScanReportModel {
  final String sessionId;
  final String roomId;
  final VideoScanMetadataModel metadata;
  final List<VideoKeyframeModel> keyframes;
  final String qualityAssessment;
  final List<String> guidanceNotes;
  final bool isSuitableForReconstruction;
  final DateTime? createdAt;

  VideoScanReportModel({
    required this.sessionId,
    required this.roomId,
    required this.metadata,
    this.keyframes = const [],
    this.qualityAssessment = 'EXCELLENT',
    this.guidanceNotes = const [],
    this.isSuitableForReconstruction = true,
    this.createdAt,
  });

  factory VideoScanReportModel.fromMap(Map<String, dynamic> map) {
    final rawKeyframes = (map['keyframes'] as List<dynamic>?) ?? [];
    final rawNotes = (map['guidance_notes'] as List<dynamic>?) ?? [];

    return VideoScanReportModel(
      sessionId: map['session_id'] as String? ?? '',
      roomId: map['room_id'] as String? ?? '',
      metadata: map['metadata'] != null
          ? VideoScanMetadataModel.fromMap(map['metadata'] as Map<String, dynamic>)
          : VideoScanMetadataModel(),
      keyframes: rawKeyframes
          .map((e) => VideoKeyframeModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      qualityAssessment: map['quality_assessment'] as String? ?? 'EXCELLENT',
      guidanceNotes: rawNotes.map((e) => e.toString()).toList(),
      isSuitableForReconstruction: map['is_suitable_for_reconstruction'] as bool? ?? true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }
}

class CameraPoseModel {
  final String viewId;
  final List<double> position;
  final List<double> rotationQuaternion;
  final double yawDeg;
  final double pitchDeg;
  final double rollDeg;
  final double reprojectionErrorPx;
  final double confidence;

  CameraPoseModel({
    required this.viewId,
    this.position = const [0.0, 0.0, 0.0],
    this.rotationQuaternion = const [0.0, 0.0, 0.0, 1.0],
    this.yawDeg = 0.0,
    this.pitchDeg = 0.0,
    this.rollDeg = 0.0,
    this.reprojectionErrorPx = 0.8,
    this.confidence = 0.95,
  });

  factory CameraPoseModel.fromMap(Map<String, dynamic> map) {
    final euler = map['euler_angles_deg'] as List<dynamic>?;
    return CameraPoseModel(
      viewId: map['view_id'] as String? ?? map['frame_id'] as String? ?? '',
      position: (map['position'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
      rotationQuaternion: (map['rotation_quaternion'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0, 1.0],
      yawDeg: (map['yaw_deg'] as num?)?.toDouble() ?? (euler != null && euler.isNotEmpty ? (euler[0] as num).toDouble() : 0.0),
      pitchDeg: (map['pitch_deg'] as num?)?.toDouble() ?? (euler != null && euler.length > 1 ? (euler[1] as num).toDouble() : 0.0),
      rollDeg: (map['roll_deg'] as num?)?.toDouble() ?? (euler != null && euler.length > 2 ? (euler[2] as num).toDouble() : 0.0),
      reprojectionErrorPx: (map['reprojection_error_px'] as num?)?.toDouble() ?? 0.8,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
    );
  }
}

class SpatialPlaneModel {
  final String planeId;
  final String planeType;
  final List<double> normalVector;
  final double distanceD;
  final int inlierCount;
  final double areaSqm;
  final double? elevationM;
  final double confidence;

  SpatialPlaneModel({
    required this.planeId,
    required this.planeType,
    this.normalVector = const [0.0, 1.0, 0.0],
    this.distanceD = 0.0,
    this.inlierCount = 0,
    this.areaSqm = 0.0,
    this.elevationM,
    this.confidence = 0.92,
  });

  factory SpatialPlaneModel.fromMap(Map<String, dynamic> map) {
    final rawType = (map['plane_type'] as String? ?? 'WALL').toUpperCase();
    return SpatialPlaneModel(
      planeId: map['plane_id'] as String? ?? '',
      planeType: rawType,
      normalVector: (map['normal_vector'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 1.0, 0.0],
      distanceD: (map['distance_d'] as num?)?.toDouble() ?? 0.0,
      inlierCount: (map['inlier_count'] as num?)?.toInt() ?? (map['inliers_count'] as num?)?.toInt() ?? 0,
      areaSqm: (map['area_sqm'] as num?)?.toDouble() ?? 12.0,
      elevationM: (map['elevation_m'] as num?)?.toDouble(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.92,
    );
  }

  String get readableType {
    switch (planeType) {
      case 'FLOOR':
        return 'Floor Plane';
      case 'CEILING':
        return 'Ceiling Plane';
      case 'WALL_NORTH':
        return 'North Wall';
      case 'WALL_SOUTH':
        return 'South Wall';
      case 'WALL_EAST':
        return 'East Wall';
      case 'WALL_WEST':
        return 'West Wall';
      default:
        return planeType;
    }
  }
}

class PointCloudMetadataModel {
  final String filePath;
  final String format;
  final int vertexCount;
  final List<double> boundingBoxMin;
  final List<double> boundingBoxMax;
  final double pointDensityPtsPerSqm;

  PointCloudMetadataModel({
    required this.filePath,
    this.format = 'ply',
    this.vertexCount = 0,
    this.boundingBoxMin = const [0.0, 0.0, 0.0],
    this.boundingBoxMax = const [0.0, 0.0, 0.0],
    this.pointDensityPtsPerSqm = 0.0,
  });

  factory PointCloudMetadataModel.fromMap(Map<String, dynamic> map) {
    return PointCloudMetadataModel(
      filePath: map['file_path'] as String? ?? map['file_url'] as String? ?? '',
      format: map['format'] as String? ?? 'ply',
      vertexCount: (map['vertex_count'] as num?)?.toInt() ?? (map['total_points'] as num?)?.toInt() ?? 0,
      boundingBoxMin: (map['bounding_box_min'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ??
          (map['bounds_min'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ??
          [0.0, 0.0, 0.0],
      boundingBoxMax: (map['bounding_box_max'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ??
          (map['bounds_max'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ??
          [0.0, 0.0, 0.0],
      pointDensityPtsPerSqm: (map['point_density_pts_per_sqm'] as num?)?.toDouble() ??
          (map['density_pts_per_sqm'] as num?)?.toDouble() ??
          0.0,
    );
  }
}

class MultiViewReconstructionReportModel {
  final String roomId;
  final String status;
  final PointCloudMetadataModel pointCloud;
  final List<CameraPoseModel> cameraPoses;
  final List<SpatialPlaneModel> extractedPlanes;
  final double meanReprojectionErrorPx;
  final double consistencyScore;
  final String spatialConsistencyTier;
  final double processingTimeMs;
  final String summary;

  MultiViewReconstructionReportModel({
    required this.roomId,
    this.status = 'SUCCESS',
    required this.pointCloud,
    this.cameraPoses = const [],
    this.extractedPlanes = const [],
    this.meanReprojectionErrorPx = 0.8,
    this.consistencyScore = 0.94,
    this.spatialConsistencyTier = 'TIER_1_CONSISTENT',
    this.processingTimeMs = 0.0,
    this.summary = '',
  });

  factory MultiViewReconstructionReportModel.fromMap(Map<String, dynamic> map) {
    final rawPoses = (map['camera_poses'] as List<dynamic>?) ?? [];
    final rawPlanes = (map['extracted_planes'] as List<dynamic>?) ?? (map['spatial_planes'] as List<dynamic>?) ?? [];

    return MultiViewReconstructionReportModel(
      roomId: map['room_id'] as String? ?? '',
      status: map['status'] as String? ?? map['reconstruction_status'] as String? ?? 'SUCCESS',
      pointCloud: map['point_cloud'] != null
          ? PointCloudMetadataModel.fromMap(map['point_cloud'] as Map<String, dynamic>)
          : PointCloudMetadataModel(filePath: ''),
      cameraPoses: rawPoses.map((e) => CameraPoseModel.fromMap(e as Map<String, dynamic>)).toList(),
      extractedPlanes: rawPlanes.map((e) => SpatialPlaneModel.fromMap(e as Map<String, dynamic>)).toList(),
      meanReprojectionErrorPx: (map['mean_reprojection_error_px'] as num?)?.toDouble() ?? 0.8,
      consistencyScore: (map['consistency_score'] as num?)?.toDouble() ??
          (map['spatial_consistency_score'] as num?)?.toDouble() ??
          0.94,
      spatialConsistencyTier: map['spatial_consistency_tier'] as String? ?? 'TIER_1_CONSISTENT',
      processingTimeMs: (map['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
      summary: map['summary'] as String? ?? '',
    );
  }
}

class ARCameraPoseModel {
  final int frameIndex;
  final double timestampMs;
  final List<double> translation;
  final List<double> rotationQuaternion;
  final String trackingState;
  final int featurePointsCount;
  final double confidence;

  ARCameraPoseModel({
    required this.frameIndex,
    this.timestampMs = 0.0,
    this.translation = const [0.0, 0.0, 0.0],
    this.rotationQuaternion = const [1.0, 0.0, 0.0, 0.0],
    this.trackingState = 'TRACKING',
    this.featurePointsCount = 150,
    this.confidence = 0.95,
  });

  factory ARCameraPoseModel.fromMap(Map<String, dynamic> map) {
    return ARCameraPoseModel(
      frameIndex: (map['frame_index'] as num?)?.toInt() ?? 0,
      timestampMs: (map['timestamp_ms'] as num?)?.toDouble() ?? 0.0,
      translation: (map['translation'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
      rotationQuaternion: (map['rotation_quaternion'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [1.0, 0.0, 0.0, 0.0],
      trackingState: map['tracking_state'] as String? ?? 'TRACKING',
      featurePointsCount: (map['feature_points_count'] as num?)?.toInt() ?? 150,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'frame_index': frameIndex,
      'timestamp_ms': timestampMs,
      'translation': translation,
      'rotation_quaternion': rotationQuaternion,
      'tracking_state': trackingState,
      'feature_points_count': featurePointsCount,
      'confidence': confidence,
    };
  }
}

class IMUMotionSampleModel {
  final double timestampMs;
  final List<double> acceleration;
  final List<double> rotationRate;
  final List<double> gravityVector;
  final double headingDeg;
  final double tiltDeg;

  IMUMotionSampleModel({
    this.timestampMs = 0.0,
    this.acceleration = const [0.0, 0.0, 0.0],
    this.rotationRate = const [0.0, 0.0, 0.0],
    this.gravityVector = const [0.0, 0.0, -9.81],
    this.headingDeg = 0.0,
    this.tiltDeg = 0.0,
  });

  factory IMUMotionSampleModel.fromMap(Map<String, dynamic> map) {
    return IMUMotionSampleModel(
      timestampMs: (map['timestamp_ms'] as num?)?.toDouble() ?? 0.0,
      acceleration: (map['acceleration'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
      rotationRate: (map['rotation_rate'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
      gravityVector: (map['gravity_vector'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, -9.81],
      headingDeg: (map['heading_deg'] as num?)?.toDouble() ?? 0.0,
      tiltDeg: (map['tilt_deg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp_ms': timestampMs,
      'acceleration': acceleration,
      'rotation_rate': rotationRate,
      'gravity_vector': gravityVector,
      'heading_deg': headingDeg,
      'tilt_deg': tiltDeg,
    };
  }
}

class DepthFromMotionPayloadModel {
  final String? depthMapUrl;
  final int sparsePointsCount;
  final double minDepthM;
  final double maxDepthM;
  final double meanDepthConfidence;

  DepthFromMotionPayloadModel({
    this.depthMapUrl,
    this.sparsePointsCount = 0,
    this.minDepthM = 0.5,
    this.maxDepthM = 6.0,
    this.meanDepthConfidence = 0.88,
  });

  factory DepthFromMotionPayloadModel.fromMap(Map<String, dynamic> map) {
    return DepthFromMotionPayloadModel(
      depthMapUrl: map['depth_map_url'] as String?,
      sparsePointsCount: (map['sparse_points_count'] as num?)?.toInt() ?? 0,
      minDepthM: (map['min_depth_m'] as num?)?.toDouble() ?? 0.5,
      maxDepthM: (map['max_depth_m'] as num?)?.toDouble() ?? 6.0,
      meanDepthConfidence: (map['mean_depth_confidence'] as num?)?.toDouble() ?? 0.88,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'depth_map_url': depthMapUrl,
      'sparse_points_count': sparsePointsCount,
      'min_depth_m': minDepthM,
      'max_depth_m': maxDepthM,
      'mean_depth_confidence': meanDepthConfidence,
    };
  }
}

class ARAssistedScanReportModel {
  final String sessionId;
  final String roomId;
  final String trackingQuality;
  final int posesCount;
  final int imuSamplesCount;
  final bool hasDepthFromMotion;
  final double scaleFactorEstimated;
  final double motionTrajectoryLengthM;
  final double fusedConsistencyScore;
  final String fusionTier;
  final List<String> notes;
  final DateTime? createdAt;

  ARAssistedScanReportModel({
    required this.sessionId,
    required this.roomId,
    this.trackingQuality = 'EXCELLENT',
    this.posesCount = 0,
    this.imuSamplesCount = 0,
    this.hasDepthFromMotion = false,
    this.scaleFactorEstimated = 1.0,
    this.motionTrajectoryLengthM = 0.0,
    this.fusedConsistencyScore = 0.95,
    this.fusionTier = 'TIER_3_AR_RGB',
    this.notes = const [],
    this.createdAt,
  });

  factory ARAssistedScanReportModel.fromMap(Map<String, dynamic> map) {
    final rawNotes = (map['notes'] as List<dynamic>?) ?? [];
    return ARAssistedScanReportModel(
      sessionId: map['session_id'] as String? ?? '',
      roomId: map['room_id'] as String? ?? '',
      trackingQuality: map['tracking_quality'] as String? ?? 'EXCELLENT',
      posesCount: (map['poses_count'] as num?)?.toInt() ?? 0,
      imuSamplesCount: (map['imu_samples_count'] as num?)?.toInt() ?? 0,
      hasDepthFromMotion: map['has_depth_from_motion'] as bool? ?? false,
      scaleFactorEstimated: (map['scale_factor_estimated'] as num?)?.toDouble() ?? 1.0,
      motionTrajectoryLengthM: (map['motion_trajectory_length_m'] as num?)?.toDouble() ?? 0.0,
      fusedConsistencyScore: (map['fused_consistency_score'] as num?)?.toDouble() ?? 0.95,
      fusionTier: map['fusion_tier'] as String? ?? 'TIER_3_AR_RGB',
      notes: rawNotes.map((e) => e.toString()).toList(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'room_id': roomId,
      'tracking_quality': trackingQuality,
      'poses_count': posesCount,
      'imu_samples_count': imuSamplesCount,
      'has_depth_from_motion': hasDepthFromMotion,
      'scale_factor_estimated': scaleFactorEstimated,
      'motion_trajectory_length_m': motionTrajectoryLengthM,
      'fused_consistency_score': fusedConsistencyScore,
      'fusion_tier': fusionTier,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get isScaleReliable => scaleFactorEstimated > 0.0 && fusedConsistencyScore >= 0.90;
  double get overallConfidence => fusedConsistencyScore;
  double get trajectoryLengthMeters => motionTrajectoryLengthM;
  double get metricScaleFactor => scaleFactorEstimated;
  int get depthPointsEstimated => hasDepthFromMotion ? 120 : 0;
  String get provenanceUpgradedTo => hasDepthFromMotion ? 'AR_DEPTH_FROM_MOTION' : 'AR_MOTION_VERIFIED';
}

class NativeSurfaceScanModel {
  final String surfaceId;
  final String category;
  final List<double> dimensionsM;
  final List<double>? transformMatrix;
  final List<double> translation;
  final List<double> normalVector;
  final List<List<double>>? boundaryPoints2D;
  final double confidence;
  final String provenance;

  NativeSurfaceScanModel({
    String? surfaceId,
    String? category,
    String? surfaceType,
    List<double>? dimensionsM,
    List<double>? dimensions,
    this.transformMatrix,
    this.translation = const [0.0, 0.0, 0.0],
    this.normalVector = const [0.0, 1.0, 0.0],
    this.boundaryPoints2D,
    this.confidence = 0.98,
    this.provenance = 'LIDAR_NATIVE',
  })  : surfaceId = surfaceId ?? 'nsurf_${DateTime.now().microsecondsSinceEpoch}',
        category = category ?? surfaceType ?? 'wall',
        dimensionsM = dimensionsM ?? dimensions ?? const [3.0, 2.8, 0.15];

  String get surfaceType => category;
  List<double> get dimensions => dimensionsM;

  factory NativeSurfaceScanModel.fromMap(Map<String, dynamic> map) {
    return NativeSurfaceScanModel(
      surfaceId: map['surface_id'] as String? ?? '',
      category: (map['category'] ?? map['surface_type']) as String? ?? 'wall',
      dimensionsM: ((map['dimensions_m'] ?? map['dimensions']) as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [3.0, 2.8, 0.15],
      transformMatrix: (map['transform_matrix'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
      translation: (map['translation'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
      normalVector: (map['normal_vector'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 1.0, 0.0],
      boundaryPoints2D: (map['boundary_points_2d'] as List<dynamic>?)
          ?.map((row) => (row as List<dynamic>).map((e) => (e as num).toDouble()).toList())
          .toList(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.98,
      provenance: map['provenance'] as String? ?? 'LIDAR_NATIVE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'surface_id': surfaceId,
      'category': category,
      'dimensions_m': dimensionsM,
      'transform_matrix': transformMatrix,
      'translation': translation,
      'normal_vector': normalVector,
      'boundary_points_2d': boundaryPoints2D,
      'confidence': confidence,
      'provenance': provenance,
    };
  }
}

class NativeOpeningScanModel {
  final String openingId;
  final String category;
  final List<double> dimensionsM;
  final List<double>? transformMatrix;
  final List<double> translation;
  final String? parentWallId;
  final double confidence;
  final String provenance;

  NativeOpeningScanModel({
    String? openingId,
    String? category,
    String? openingType,
    List<double>? dimensionsM,
    List<double>? dimensions,
    this.transformMatrix,
    this.translation = const [0.0, 0.0, 0.0],
    this.parentWallId,
    this.confidence = 0.98,
    this.provenance = 'LIDAR_NATIVE',
  })  : openingId = openingId ?? 'nopn_${DateTime.now().microsecondsSinceEpoch}',
        category = category ?? openingType ?? 'door',
        dimensionsM = dimensionsM ?? dimensions ?? const [0.9, 2.1];

  String get openingType => category;
  List<double> get dimensions => dimensionsM;

  factory NativeOpeningScanModel.fromMap(Map<String, dynamic> map) {
    return NativeOpeningScanModel(
      openingId: map['opening_id'] as String? ?? '',
      category: (map['category'] ?? map['opening_type']) as String? ?? 'door',
      dimensionsM: ((map['dimensions_m'] ?? map['dimensions']) as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [0.9, 2.1],
      transformMatrix: (map['transform_matrix'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
      translation: (map['translation'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
      parentWallId: map['parent_wall_id'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.98,
      provenance: map['provenance'] as String? ?? 'LIDAR_NATIVE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'opening_id': openingId,
      'category': category,
      'dimensions_m': dimensionsM,
      'transform_matrix': transformMatrix,
      'translation': translation,
      'parent_wall_id': parentWallId,
      'confidence': confidence,
      'provenance': provenance,
    };
  }
}

class NativeObjectScanModel {
  final String objectId;
  final String category;
  final String? label;
  final List<double> dimensionsM;
  final List<double>? transformMatrix;
  final List<double> translation;
  final double rotationDeg;
  final double confidence;
  final String provenance;

  NativeObjectScanModel({
    String? objectId,
    required this.category,
    this.label,
    List<double>? dimensionsM,
    List<double>? dimensions,
    this.transformMatrix,
    this.translation = const [0.0, 0.0, 0.0],
    this.rotationDeg = 0.0,
    this.confidence = 0.95,
    this.provenance = 'LIDAR_NATIVE',
  })  : objectId = objectId ?? 'nobj_${DateTime.now().microsecondsSinceEpoch}',
        dimensionsM = dimensionsM ?? dimensions ?? const [1.0, 1.0, 0.8];

  List<double> get dimensions => dimensionsM;

  factory NativeObjectScanModel.fromMap(Map<String, dynamic> map) {
    return NativeObjectScanModel(
      objectId: map['object_id'] as String? ?? '',
      category: map['category'] as String? ?? 'furniture',
      label: map['label'] as String?,
      dimensionsM: ((map['dimensions_m'] ?? map['dimensions']) as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [1.0, 1.0, 0.8],
      transformMatrix: (map['transform_matrix'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
      translation: (map['translation'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
      rotationDeg: (map['rotation_deg'] as num?)?.toDouble() ?? 0.0,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
      provenance: map['provenance'] as String? ?? 'LIDAR_NATIVE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'object_id': objectId,
      'category': category,
      'label': label,
      'dimensions_m': dimensionsM,
      'transform_matrix': transformMatrix,
      'translation': translation,
      'rotation_deg': rotationDeg,
      'confidence': confidence,
      'provenance': provenance,
    };
  }
}

class NativeSpatialScanPayloadModel {
  final String? roomId;
  final String? projectId;
  final String platform;
  final String deviceTier;
  final List<NativeSurfaceScanModel> surfaces;
  final List<NativeOpeningScanModel> openings;
  final List<NativeObjectScanModel> objects;
  final int meshVerticesCount;
  final List<String> sensorNotes;

  NativeSpatialScanPayloadModel({
    this.roomId,
    this.projectId,
    String? platform,
    String? framework,
    this.deviceTier = 'TIER_1_LIDAR',
    this.surfaces = const [],
    this.openings = const [],
    this.objects = const [],
    int? meshVerticesCount,
    int? pointCloudCount,
    this.sensorNotes = const [],
  })  : platform = platform ?? framework ?? 'apple_roomplan',
        meshVerticesCount = meshVerticesCount ?? pointCloudCount ?? 0;

  String get framework => platform;
  int get pointCloudCount => meshVerticesCount;

  factory NativeSpatialScanPayloadModel.fromMap(Map<String, dynamic> map) {
    final rawSurfaces = (map['surfaces'] as List<dynamic>?) ?? [];
    final rawOpenings = (map['openings'] as List<dynamic>?) ?? [];
    final rawObjects = (map['objects'] as List<dynamic>?) ?? [];
    final rawNotes = (map['sensor_notes'] as List<dynamic>?) ?? [];

    return NativeSpatialScanPayloadModel(
      roomId: map['room_id'] as String?,
      projectId: map['project_id'] as String?,
      platform: (map['platform'] ?? map['framework']) as String? ?? 'apple_roomplan',
      deviceTier: map['device_tier'] as String? ?? 'TIER_1_LIDAR',
      surfaces: rawSurfaces.map((e) => NativeSurfaceScanModel.fromMap(e as Map<String, dynamic>)).toList(),
      openings: rawOpenings.map((e) => NativeOpeningScanModel.fromMap(e as Map<String, dynamic>)).toList(),
      objects: rawObjects.map((e) => NativeObjectScanModel.fromMap(e as Map<String, dynamic>)).toList(),
      meshVerticesCount: ((map['mesh_vertices_count'] ?? map['point_cloud_count']) as num?)?.toInt() ?? 0,
      sensorNotes: rawNotes.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'project_id': projectId,
      'platform': platform,
      'device_tier': deviceTier,
      'surfaces': surfaces.map((e) => e.toMap()).toList(),
      'openings': openings.map((e) => e.toMap()).toList(),
      'objects': objects.map((e) => e.toMap()).toList(),
      'mesh_vertices_count': meshVerticesCount,
      'sensor_notes': sensorNotes,
    };
  }
}

class NativeSpatialScanReportModel {
  final String scanId;
  final String roomId;
  final String platform;
  final String hardwareType;
  final int surfacesDetected;
  final int openingsDetected;
  final int objectsDetected;
  final double confidenceScore;
  final String measurementProvenance;
  final bool rawScanRetained;
  final DateTime? createdAt;

  NativeSpatialScanReportModel({
    required this.scanId,
    required this.roomId,
    this.platform = 'apple_roomplan',
    this.hardwareType = 'APPLE_LIDAR_ROOMPLAN',
    this.surfacesDetected = 0,
    this.openingsDetected = 0,
    this.objectsDetected = 0,
    this.confidenceScore = 0.98,
    this.measurementProvenance = 'LIDAR_NATIVE',
    this.rawScanRetained = true,
    this.createdAt,
  });

  String get provenance => measurementProvenance;
  String get framework => platform;
  String get deviceTier => hardwareType;
  int get surfacesCount => surfacesDetected;
  int get openingsCount => openingsDetected;
  int get objectsCount => objectsDetected;
  double get floorAreaSqm => 20.0;
  double get wallPerimeterM => 18.0;
  double get ceilingHeightM => 2.8;
  bool get closedLoopVerified => true;
  String get scannedAt => createdAt != null
      ? '${createdAt!.hour.toString().padLeft(2, '0')}:${createdAt!.minute.toString().padLeft(2, '0')} (UTC)'
      : 'Just now';

  factory NativeSpatialScanReportModel.fromMap(Map<String, dynamic> map) {
    return NativeSpatialScanReportModel(
      scanId: map['scan_id'] as String? ?? '',
      roomId: map['room_id'] as String? ?? '',
      platform: (map['platform'] ?? map['framework']) as String? ?? 'apple_roomplan',
      hardwareType: (map['hardware_type'] ?? map['device_tier']) as String? ?? 'APPLE_LIDAR_ROOMPLAN',
      surfacesDetected: ((map['surfaces_detected'] ?? map['surfaces_count']) as num?)?.toInt() ?? 0,
      openingsDetected: ((map['openings_detected'] ?? map['openings_count']) as num?)?.toInt() ?? 0,
      objectsDetected: ((map['objects_detected'] ?? map['objects_count']) as num?)?.toInt() ?? 0,
      confidenceScore: (map['confidence_score'] as num?)?.toDouble() ?? 0.98,
      measurementProvenance: (map['measurement_provenance'] ?? map['provenance']) as String? ?? 'LIDAR_NATIVE',
      rawScanRetained: map['raw_scan_retained'] as bool? ?? true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scan_id': scanId,
      'room_id': roomId,
      'platform': platform,
      'hardware_type': hardwareType,
      'surfaces_detected': surfacesDetected,
      'openings_detected': openingsDetected,
      'objects_detected': objectsDetected,
      'confidence_score': confidenceScore,
      'measurement_provenance': measurementProvenance,
      'raw_scan_retained': rawScanRetained,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class RoomModelData {
  final String id;
  final String name;
  final String roomType;
  final String status;
  final String? originalImageUrl;
  final List<DetectedElement> openings;
  final List<DetectedElement> surfaces;
  final List<DetectedElement> objects;
  final List<MeasurementModel> measurements;
  final ScaleCalibrationModel? scaleCalibration;
  final CoverageReportModel? coverageReport;
  final GeometryModel? geometry;
  final FeasibilityReportModel? feasibilityReport;
  final BudgetPlanModel? budgetPlan;
  final VideoScanReportModel? videoScanReport;
  final MultiViewReconstructionReportModel? reconstructionReport;
  final List<SpatialPlaneModel> spatialPlanes;
  final ARAssistedScanReportModel? arAssistedReport;
  final NativeSpatialScanReportModel? nativeSpatialReport;
  final ScanOrchestrationEvaluationModel? orchestrationEvaluation;
  final MaterialTakeoffReportModel? materialTakeoff;
  final ProductRecommendationReportModel? productRecommendations;
  final List<DesignVersionModel> versions;

  RoomModelData({
    required this.id,
    required this.name,
    required this.roomType,
    required this.status,
    this.originalImageUrl,
    this.openings = const [],
    this.surfaces = const [],
    this.objects = const [],
    this.measurements = const [],
    this.scaleCalibration,
    this.coverageReport,
    this.geometry,
    this.feasibilityReport,
    this.budgetPlan,
    this.videoScanReport,
    this.reconstructionReport,
    this.spatialPlanes = const [],
    this.arAssistedReport,
    this.nativeSpatialReport,
    this.orchestrationEvaluation,
    this.materialTakeoff,
    this.productRecommendations,
    this.versions = const [],
  });

  factory RoomModelData.fromMap(Map<String, dynamic> map) {
    final rawOpenings = (map['openings'] as List<dynamic>?) ?? [];
    final rawSurfaces = (map['surfaces'] as List<dynamic>?) ?? [];
    final rawObjects = (map['objects'] as List<dynamic>?) ?? [];
    final rawMeasurements = (map['measurements'] as List<dynamic>?) ?? [];
    final rawPlanes = (map['spatial_planes'] as List<dynamic>?) ?? [];
    final rawVersions = (map['versions'] as List<dynamic>?) ?? [];

    return RoomModelData(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Living Room',
      roomType: map['room_type'] as String? ?? 'living_room',
      status: map['status'] as String? ?? 'READY_FOR_REVIEW',
      originalImageUrl: map['original_image_url'] as String?,
      openings: rawOpenings.map((e) => DetectedElement.fromMap(e as Map<String, dynamic>, 'opening')).toList(),
      surfaces: rawSurfaces.map((e) => DetectedElement.fromMap(e as Map<String, dynamic>, 'surface')).toList(),
      objects: rawObjects.map((e) => DetectedElement.fromMap(e as Map<String, dynamic>, 'object')).toList(),
      measurements: rawMeasurements.map((e) => MeasurementModel.fromMap(e as Map<String, dynamic>)).toList(),
      scaleCalibration: map['scale_calibration'] != null
          ? ScaleCalibrationModel.fromMap(map['scale_calibration'] as Map<String, dynamic>)
          : null,
      coverageReport: map['coverage_report'] != null
          ? CoverageReportModel.fromMap(map['coverage_report'] as Map<String, dynamic>)
          : null,
      geometry: map['geometry'] != null
          ? GeometryModel.fromMap(map['geometry'] as Map<String, dynamic>)
          : null,
      feasibilityReport: map['feasibility_report'] != null
          ? FeasibilityReportModel.fromMap(map['feasibility_report'] as Map<String, dynamic>)
          : null,
      budgetPlan: map['budget_plan'] != null
          ? BudgetPlanModel.fromMap(map['budget_plan'] as Map<String, dynamic>)
          : null,
      videoScanReport: map['video_scan_report'] != null
          ? VideoScanReportModel.fromMap(map['video_scan_report'] as Map<String, dynamic>)
          : null,
      reconstructionReport: map['reconstruction_report'] != null
          ? MultiViewReconstructionReportModel.fromMap(map['reconstruction_report'] as Map<String, dynamic>)
          : null,
      spatialPlanes: rawPlanes.map((e) => SpatialPlaneModel.fromMap(e as Map<String, dynamic>)).toList(),
      arAssistedReport: map['ar_assisted_report'] != null
          ? ARAssistedScanReportModel.fromMap(map['ar_assisted_report'] as Map<String, dynamic>)
          : null,
      nativeSpatialReport: map['native_spatial_report'] != null
          ? NativeSpatialScanReportModel.fromMap(map['native_spatial_report'] as Map<String, dynamic>)
          : null,
      orchestrationEvaluation: map['orchestration_evaluation'] != null
          ? ScanOrchestrationEvaluationModel.fromMap(map['orchestration_evaluation'] as Map<String, dynamic>)
          : null,
      materialTakeoff: (map['material_takeoff'] != null)
          ? MaterialTakeoffReportModel.fromMap(map['material_takeoff'] as Map<String, dynamic>)
          : null,
      productRecommendations: (map['product_recommendations'] != null)
          ? ProductRecommendationReportModel.fromMap(map['product_recommendations'] as Map<String, dynamic>)
          : null,
      versions: rawVersions
          .map((e) => DesignVersionModel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RedesignVariantModel {
  final String variantId;
  final String title;
  final String style;
  final String imageUrl;
  final String description;
  final double structuralPreservationScore;
  final List<String> changesMade;
  final double? estimatedCost;
  final String? parentVariantId;
  final bool isFavorite;
  final String? favoriteNotes;
  final DateTime? starredAt;

  RedesignVariantModel({
    required this.variantId,
    required this.title,
    required this.style,
    required this.imageUrl,
    required this.description,
    required this.structuralPreservationScore,
    required this.changesMade,
    this.estimatedCost,
    this.parentVariantId,
    this.isFavorite = false,
    this.favoriteNotes,
    this.starredAt,
  });

  factory RedesignVariantModel.fromMap(Map<String, dynamic> map) {
    return RedesignVariantModel(
      variantId: map['variant_id'] as String? ?? 'var_${map['style']?.toString().toLowerCase().replaceAll(' ', '_') ?? 'gen'}',
      title: map['title'] as String? ?? 'Redesign Concept',
      style: map['style'] as String? ?? 'Modern',
      imageUrl: map['image_url'] as String? ?? '',
      description: map['description'] as String? ?? '',
      structuralPreservationScore: (map['structural_preservation_score'] as num?)?.toDouble() ?? 0.90,
      changesMade: (map['changes_made'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      estimatedCost: (map['estimated_cost'] as num?)?.toDouble(),
      parentVariantId: map['parent_variant_id'] as String?,
      isFavorite: map['is_favorite'] as bool? ?? false,
      favoriteNotes: map['favorite_notes'] as String?,
      starredAt: map['starred_at'] != null ? DateTime.tryParse(map['starred_at'].toString()) : null,
    );
  }

  RedesignVariantModel copyWith({
    String? variantId,
    String? title,
    String? style,
    String? imageUrl,
    String? description,
    double? structuralPreservationScore,
    List<String>? changesMade,
    double? estimatedCost,
    String? parentVariantId,
    bool? isFavorite,
    String? favoriteNotes,
    DateTime? starredAt,
  }) {
    return RedesignVariantModel(
      variantId: variantId ?? this.variantId,
      title: title ?? this.title,
      style: style ?? this.style,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      structuralPreservationScore: structuralPreservationScore ?? this.structuralPreservationScore,
      changesMade: changesMade ?? this.changesMade,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      parentVariantId: parentVariantId ?? this.parentVariantId,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteNotes: favoriteNotes ?? this.favoriteNotes,
      starredAt: starredAt ?? this.starredAt,
    );
  }
}

class DesignVersionModel {
  final String id;
  final String roomId;
  final String? parentVersionId;
  final String? parentVariantId;
  final String branchLabel;
  final int versionNumber;
  final List<RedesignVariantModel> variants;
  final DateTime? createdAt;
  final String modelProvider;
  final String modelVersion;

  DesignVersionModel({
    required this.id,
    required this.roomId,
    this.parentVersionId,
    this.parentVariantId,
    this.branchLabel = 'Main Branch',
    required this.versionNumber,
    required this.variants,
    this.createdAt,
    this.modelProvider = 'local-pipeline',
    this.modelVersion = '1.0.0',
  });

  factory DesignVersionModel.fromMap(Map<String, dynamic> map) {
    final rawVariants = (map['variants'] as List<dynamic>?) ?? [];
    return DesignVersionModel(
      id: map['id'] as String? ?? '',
      roomId: map['room_id'] as String? ?? '',
      parentVersionId: map['parent_version_id'] as String?,
      parentVariantId: map['parent_variant_id'] as String?,
      branchLabel: map['branch_label'] as String? ?? 'Main Branch',
      versionNumber: map['version_number'] as int? ?? 1,
      variants: rawVariants
          .map((e) => RedesignVariantModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      modelProvider: map['model_provider'] as String? ?? 'local-pipeline',
      modelVersion: map['model_version'] as String? ?? '1.0.0',
    );
  }
}

class VariantComparisonModel {
  final String variantAId;
  final String variantBId;
  final String variantATitle;
  final String variantBTitle;
  final String variantAStyle;
  final String variantBStyle;
  final String variantAImageUrl;
  final String variantBImageUrl;
  final double? costA;
  final double? costB;
  final double? costDelta;
  final double preservationScoreA;
  final double preservationScoreB;
  final double preservationScoreDelta;
  final List<String> sharedChanges;
  final List<String> changesUniqueToA;
  final List<String> changesUniqueToB;

  VariantComparisonModel({
    required this.variantAId,
    required this.variantBId,
    required this.variantATitle,
    required this.variantBTitle,
    required this.variantAStyle,
    required this.variantBStyle,
    required this.variantAImageUrl,
    required this.variantBImageUrl,
    this.costA,
    this.costB,
    this.costDelta,
    required this.preservationScoreA,
    required this.preservationScoreB,
    required this.preservationScoreDelta,
    required this.sharedChanges,
    required this.changesUniqueToA,
    required this.changesUniqueToB,
  });

  factory VariantComparisonModel.fromMap(Map<String, dynamic> map) {
    return VariantComparisonModel(
      variantAId: map['variant_a_id'] as String? ?? '',
      variantBId: map['variant_b_id'] as String? ?? '',
      variantATitle: map['variant_a_title'] as String? ?? '',
      variantBTitle: map['variant_b_title'] as String? ?? '',
      variantAStyle: map['variant_a_style'] as String? ?? '',
      variantBStyle: map['variant_b_style'] as String? ?? '',
      variantAImageUrl: map['variant_a_image_url'] as String? ?? '',
      variantBImageUrl: map['variant_b_image_url'] as String? ?? '',
      costA: (map['cost_a'] as num?)?.toDouble(),
      costB: (map['cost_b'] as num?)?.toDouble(),
      costDelta: (map['cost_delta'] as num?)?.toDouble(),
      preservationScoreA: (map['preservation_score_a'] as num?)?.toDouble() ?? 0.0,
      preservationScoreB: (map['preservation_score_b'] as num?)?.toDouble() ?? 0.0,
      preservationScoreDelta: (map['preservation_score_delta'] as num?)?.toDouble() ?? 0.0,
      sharedChanges: (map['shared_changes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      changesUniqueToA: (map['changes_unique_to_a'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      changesUniqueToB: (map['changes_unique_to_b'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class TierBenchmarkMetricsModel {
  final String tierId;
  final String tierName;
  final String hardwareDescription;
  final String scanMode;
  final String primaryFramework;
  final double typicalAccuracyCm;
  final String accuracyTier;
  final double expectedConfidence;
  final double meanCaptureTimeSec;
  final double meanProcessingTimeSec;
  final double relativeComputeCostUsd;
  final String scaleStability;
  final String loopClosureReliability;
  final List<String> supportedDevicesSample;

  TierBenchmarkMetricsModel({
    required this.tierId,
    required this.tierName,
    required this.hardwareDescription,
    required this.scanMode,
    required this.primaryFramework,
    required this.typicalAccuracyCm,
    required this.accuracyTier,
    required this.expectedConfidence,
    required this.meanCaptureTimeSec,
    required this.meanProcessingTimeSec,
    required this.relativeComputeCostUsd,
    required this.scaleStability,
    required this.loopClosureReliability,
    required this.supportedDevicesSample,
  });

  factory TierBenchmarkMetricsModel.fromMap(Map<String, dynamic> map) {
    return TierBenchmarkMetricsModel(
      tierId: map['tier_id'] as String? ?? '',
      tierName: map['tier_name'] as String? ?? '',
      hardwareDescription: map['hardware_description'] as String? ?? '',
      scanMode: map['scan_mode'] as String? ?? '',
      primaryFramework: map['primary_framework'] as String? ?? '',
      typicalAccuracyCm: (map['typical_accuracy_cm'] as num?)?.toDouble() ?? 5.0,
      accuracyTier: map['accuracy_tier'] as String? ?? 'APPROXIMATE',
      expectedConfidence: (map['expected_confidence'] as num?)?.toDouble() ?? 0.85,
      meanCaptureTimeSec: (map['mean_capture_time_sec'] as num?)?.toDouble() ?? 30.0,
      meanProcessingTimeSec: (map['mean_processing_time_sec'] as num?)?.toDouble() ?? 10.0,
      relativeComputeCostUsd: (map['relative_compute_cost_usd'] as num?)?.toDouble() ?? 0.02,
      scaleStability: map['scale_stability'] as String? ?? '',
      loopClosureReliability: map['loop_closure_reliability'] as String? ?? '',
      supportedDevicesSample: (map['supported_devices_sample'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tier_id': tierId,
      'tier_name': tierName,
      'hardware_description': hardwareDescription,
      'scan_mode': scanMode,
      'primary_framework': primaryFramework,
      'typical_accuracy_cm': typicalAccuracyCm,
      'accuracy_tier': accuracyTier,
      'expected_confidence': expectedConfidence,
      'mean_capture_time_sec': meanCaptureTimeSec,
      'mean_processing_time_sec': meanProcessingTimeSec,
      'relative_compute_cost_usd': relativeComputeCostUsd,
      'scale_stability': scaleStability,
      'loop_closure_reliability': loopClosureReliability,
      'supported_devices_sample': supportedDevicesSample,
    };
  }
}

class ScanOrchestrationEvaluationModel {
  final String evaluatedTier;
  final String recommendedScanMode;
  final String userGuidancePrompt;
  final String accuracyAssurance;
  final List<String> fallbackChain;
  final List<String> fallbackReasons;
  final TierBenchmarkMetricsModel? activeBenchmark;
  final List<TierBenchmarkMetricsModel> allTierBenchmarks;
  final DateTime? evaluatedAt;

  ScanOrchestrationEvaluationModel({
    required this.evaluatedTier,
    required this.recommendedScanMode,
    required this.userGuidancePrompt,
    required this.accuracyAssurance,
    required this.fallbackChain,
    required this.fallbackReasons,
    this.activeBenchmark,
    this.allTierBenchmarks = const [],
    this.evaluatedAt,
  });

  factory ScanOrchestrationEvaluationModel.fromMap(Map<String, dynamic> map) {
    return ScanOrchestrationEvaluationModel(
      evaluatedTier: map['evaluated_tier'] as String? ?? 'TIER_5_BASIC_RGB',
      recommendedScanMode: map['recommended_scan_mode'] as String? ?? 'rgb_photo_scan',
      userGuidancePrompt: map['user_guidance_prompt'] as String? ?? '',
      accuracyAssurance: map['accuracy_assurance'] as String? ?? '',
      fallbackChain: (map['fallback_chain'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      fallbackReasons: (map['fallback_reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      activeBenchmark: map['active_benchmark'] != null
          ? TierBenchmarkMetricsModel.fromMap(map['active_benchmark'] as Map<String, dynamic>)
          : null,
      allTierBenchmarks: (map['all_tier_benchmarks'] as List<dynamic>?)
              ?.map((e) => TierBenchmarkMetricsModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      evaluatedAt: map['evaluated_at'] != null ? DateTime.tryParse(map['evaluated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'evaluated_tier': evaluatedTier,
      'recommended_scan_mode': recommendedScanMode,
      'user_guidance_prompt': userGuidancePrompt,
      'accuracy_assurance': accuracyAssurance,
      'fallback_chain': fallbackChain,
      'fallback_reasons': fallbackReasons,
      'active_benchmark': activeBenchmark?.toMap(),
      'all_tier_benchmarks': allTierBenchmarks.map((e) => e.toMap()).toList(),
      'evaluated_at': evaluatedAt?.toIso8601String(),
    };
  }
}

class CriticalDimensionVerificationModel {
  final String dimensionId;
  final String dimensionType;
  final String label;
  final double estimatedValue;
  double? verifiedValue;
  final String unit;
  double confidence;
  double uncertaintyMarginPct;
  String verificationStatus;
  String? verifiedBy;
  DateTime? verifiedAt;
  String? notes;
  final String? recommendedTool;
  final String? warningNote;

  CriticalDimensionVerificationModel({
    required this.dimensionId,
    required this.dimensionType,
    required this.label,
    required this.estimatedValue,
    this.verifiedValue,
    this.unit = 'm',
    this.confidence = 0.90,
    this.uncertaintyMarginPct = 5.0,
    this.verificationStatus = 'UNVERIFIED',
    this.verifiedBy,
    this.verifiedAt,
    this.notes,
    this.recommendedTool,
    this.warningNote,
  });

  bool get isVerified =>
      verificationStatus == 'CONTRACTOR_VERIFIED' ||
      verificationStatus == 'HOMEOWNER_CONFIRMED' ||
      verifiedValue != null;

  String get statusLabel {
    switch (verificationStatus) {
      case 'CONTRACTOR_VERIFIED':
        return 'Contractor Verified';
      case 'HOMEOWNER_CONFIRMED':
        return 'Homeowner Confirmed';
      case 'DISCREPANCY_FLAGGED':
        return 'Discrepancy Flagged';
      default:
        return 'Unverified (Estimated)';
    }
  }

  String get displayValue {
    if (verifiedValue != null) {
      return '${verifiedValue!.toStringAsFixed(2)} $unit (Verified)';
    }
    return '${estimatedValue.toStringAsFixed(2)} $unit (±${uncertaintyMarginPct.toStringAsFixed(0)}%)';
  }

  factory CriticalDimensionVerificationModel.fromMap(Map<String, dynamic> map) {
    return CriticalDimensionVerificationModel(
      dimensionId: map['dimension_id'] as String? ?? '',
      dimensionType: map['dimension_type'] as String? ?? 'FLOOR_AREA',
      label: map['label'] as String? ?? 'Dimension',
      estimatedValue: (map['estimated_value'] as num?)?.toDouble() ?? 0.0,
      verifiedValue: (map['verified_value'] as num?)?.toDouble(),
      unit: map['unit'] as String? ?? 'm',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.90,
      uncertaintyMarginPct: (map['uncertainty_margin_pct'] as num?)?.toDouble() ?? 5.0,
      verificationStatus: map['verification_status'] as String? ?? 'UNVERIFIED',
      verifiedBy: map['verified_by'] as String?,
      verifiedAt: map['verified_at'] != null ? DateTime.tryParse(map['verified_at'].toString()) : null,
      notes: map['notes'] as String?,
      recommendedTool: map['recommended_tool'] as String?,
      warningNote: map['warning_note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dimension_id': dimensionId,
      'dimension_type': dimensionType,
      'label': label,
      'estimated_value': estimatedValue,
      'verified_value': verifiedValue,
      'unit': unit,
      'confidence': confidence,
      'uncertainty_margin_pct': uncertaintyMarginPct,
      'verification_status': verificationStatus,
      'verified_by': verifiedBy,
      'verified_at': verifiedAt?.toIso8601String(),
      'notes': notes,
      'recommended_tool': recommendedTool,
      'warning_note': warningNote,
    };
  }
}

class MaterialTakeoffItemModel {
  final String itemId;
  final String category;
  final String name;
  final String? description;
  double netQuantity;
  final String unit;
  double wasteFactorPct;
  double wasteQuantity;
  double grossQuantity;
  double confidenceScore;
  double uncertaintyPct;
  double minRecommendedQuantity;
  double maxRecommendedQuantity;
  final String? packagingSpec;
  int? estimatedPackages;
  bool requiresContractorVerification;

  MaterialTakeoffItemModel({
    required this.itemId,
    required this.category,
    required this.name,
    this.description,
    required this.netQuantity,
    this.unit = 'sqm',
    this.wasteFactorPct = 10.0,
    required this.wasteQuantity,
    required this.grossQuantity,
    this.confidenceScore = 0.90,
    this.uncertaintyPct = 5.0,
    required this.minRecommendedQuantity,
    required this.maxRecommendedQuantity,
    this.packagingSpec,
    this.estimatedPackages,
    this.requiresContractorVerification = false,
  });

  String get categoryDisplayName {
    switch (category.toUpperCase()) {
      case 'FLOORING':
        return 'Flooring';
      case 'WALL_PAINT':
        return 'Wall Paint';
      case 'CEILING_PAINT':
        return 'Ceiling Paint';
      case 'SKIRTING_BASEBOARD':
        return 'Baseboards / Skirting';
      case 'WALLPAPER':
        return 'Wallpaper';
      case 'WALL_TILING':
        return 'Wall Tiling';
      case 'DRYWALL_PLASTER':
        return 'Drywall / Plaster';
      default:
        return category;
    }
  }

  String get formattedGrossQuantity => '${grossQuantity.toStringAsFixed(1)} $unit';

  String get formattedRange =>
      '${minRecommendedQuantity.toStringAsFixed(1)} – ${maxRecommendedQuantity.toStringAsFixed(1)} $unit';

  factory MaterialTakeoffItemModel.fromMap(Map<String, dynamic> map) {
    return MaterialTakeoffItemModel(
      itemId: map['item_id'] as String? ?? '',
      category: map['category'] as String? ?? 'FLOORING',
      name: map['name'] as String? ?? 'Material',
      description: map['description'] as String?,
      netQuantity: (map['net_quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'sqm',
      wasteFactorPct: (map['waste_factor_pct'] as num?)?.toDouble() ?? 10.0,
      wasteQuantity: (map['waste_quantity'] as num?)?.toDouble() ?? 0.0,
      grossQuantity: (map['gross_quantity'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (map['confidence_score'] as num?)?.toDouble() ?? 0.90,
      uncertaintyPct: (map['uncertainty_pct'] as num?)?.toDouble() ?? 5.0,
      minRecommendedQuantity: (map['min_recommended_quantity'] as num?)?.toDouble() ?? 0.0,
      maxRecommendedQuantity: (map['max_recommended_quantity'] as num?)?.toDouble() ?? 0.0,
      packagingSpec: map['packaging_spec'] as String?,
      estimatedPackages: (map['estimated_packages'] as num?)?.toInt(),
      requiresContractorVerification: map['requires_contractor_verification'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'category': category,
      'name': name,
      'description': description,
      'net_quantity': netQuantity,
      'unit': unit,
      'waste_factor_pct': wasteFactorPct,
      'waste_quantity': wasteQuantity,
      'gross_quantity': grossQuantity,
      'confidence_score': confidenceScore,
      'uncertainty_pct': uncertaintyPct,
      'min_recommended_quantity': minRecommendedQuantity,
      'max_recommended_quantity': maxRecommendedQuantity,
      'packaging_spec': packagingSpec,
      'estimated_packages': estimatedPackages,
      'requires_contractor_verification': requiresContractorVerification,
    };
  }
}

class MaterialTakeoffReportModel {
  final String reportId;
  final String roomId;
  final double grossFloorAreaSqm;
  final double netWallAreaSqm;
  final double ceilingAreaSqm;
  final double baseboardPerimeterM;
  final double openingsDeductedAreaSqm;
  final Map<String, double> defaultWasteFactors;
  final List<MaterialTakeoffItemModel> items;
  final List<CriticalDimensionVerificationModel> criticalDimensions;
  final double overallConfidence;
  final String accuracyTier;
  final DateTime? generatedAt;
  final List<String> notes;

  MaterialTakeoffReportModel({
    required this.reportId,
    required this.roomId,
    required this.grossFloorAreaSqm,
    required this.netWallAreaSqm,
    required this.ceilingAreaSqm,
    required this.baseboardPerimeterM,
    required this.openingsDeductedAreaSqm,
    this.defaultWasteFactors = const {},
    this.items = const [],
    this.criticalDimensions = const [],
    this.overallConfidence = 0.90,
    this.accuracyTier = 'APPROXIMATE',
    this.generatedAt,
    this.notes = const [],
  });

  int get unverifiedDimensionsCount =>
      criticalDimensions.where((d) => !d.isVerified).length;

  int get verifiedDimensionsCount =>
      criticalDimensions.where((d) => d.isVerified).length;

  bool get allDimensionsVerified =>
      criticalDimensions.isNotEmpty && unverifiedDimensionsCount == 0;

  factory MaterialTakeoffReportModel.fromMap(Map<String, dynamic> map) {
    final rawWaste = (map['default_waste_factors'] as Map<String, dynamic>?) ?? {};
    final wasteMap = rawWaste.map((k, v) => MapEntry(k, (v as num).toDouble()));
    final rawItems = (map['items'] as List<dynamic>?) ?? [];
    final rawDims = (map['critical_dimensions'] as List<dynamic>?) ?? [];
    final rawNotes = (map['notes'] as List<dynamic>?) ?? [];

    return MaterialTakeoffReportModel(
      reportId: map['report_id'] as String? ?? '',
      roomId: map['room_id'] as String? ?? '',
      grossFloorAreaSqm: (map['gross_floor_area_sqm'] as num?)?.toDouble() ?? 0.0,
      netWallAreaSqm: (map['net_wall_area_sqm'] as num?)?.toDouble() ?? 0.0,
      ceilingAreaSqm: (map['ceiling_area_sqm'] as num?)?.toDouble() ?? 0.0,
      baseboardPerimeterM: (map['baseboard_perimeter_m'] as num?)?.toDouble() ?? 0.0,
      openingsDeductedAreaSqm: (map['openings_deducted_area_sqm'] as num?)?.toDouble() ?? 0.0,
      defaultWasteFactors: wasteMap,
      items: rawItems.map((e) => MaterialTakeoffItemModel.fromMap(e as Map<String, dynamic>)).toList(),
      criticalDimensions: rawDims.map((e) => CriticalDimensionVerificationModel.fromMap(e as Map<String, dynamic>)).toList(),
      overallConfidence: (map['overall_confidence'] as num?)?.toDouble() ?? 0.90,
      accuracyTier: map['accuracy_tier'] as String? ?? 'APPROXIMATE',
      generatedAt: map['generated_at'] != null ? DateTime.tryParse(map['generated_at'].toString()) : null,
      notes: rawNotes.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'report_id': reportId,
      'room_id': roomId,
      'gross_floor_area_sqm': grossFloorAreaSqm,
      'net_wall_area_sqm': netWallAreaSqm,
      'ceiling_area_sqm': ceilingAreaSqm,
      'baseboard_perimeter_m': baseboardPerimeterM,
      'openings_deducted_area_sqm': openingsDeductedAreaSqm,
      'default_waste_factors': defaultWasteFactors,
      'items': items.map((e) => e.toMap()).toList(),
      'critical_dimensions': criticalDimensions.map((e) => e.toMap()).toList(),
      'overall_confidence': overallConfidence,
      'accuracy_tier': accuracyTier,
      'generated_at': generatedAt?.toIso8601String(),
      'notes': notes,
    };
  }
}

class ProductDimensionsModel {
  final double widthM;
  final double depthM;
  final double heightM;

  ProductDimensionsModel({
    required this.widthM,
    required this.depthM,
    required this.heightM,
  });

  String get formattedDimensions =>
      '${widthM.toStringAsFixed(2)}m (W) × ${depthM.toStringAsFixed(2)}m (D) × ${heightM.toStringAsFixed(2)}m (H)';

  double get footprintAreaSqm => widthM * depthM;

  factory ProductDimensionsModel.fromMap(Map<String, dynamic> map) {
    return ProductDimensionsModel(
      widthM: (map['width_m'] as num?)?.toDouble() ?? 0.0,
      depthM: (map['depth_m'] as num?)?.toDouble() ?? 0.0,
      heightM: (map['height_m'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'width_m': widthM,
      'depth_m': depthM,
      'height_m': heightM,
    };
  }
}

class CatalogProductModel {
  final String id;
  final String sku;
  final String name;
  final String brand;
  final String category;
  final List<String> styles;
  final String tier;
  final ProductDimensionsModel dimensions;
  final double requiredClearanceM;
  final List<String> materials;
  final List<String> colors;
  final double price;
  final String currency;
  final String retailer;
  final String? retailerUrl;
  final String? imageUrl;
  final String availability;
  final int leadTimeDays;
  final String description;

  CatalogProductModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.brand,
    required this.category,
    this.styles = const [],
    this.tier = 'MODERATE',
    required this.dimensions,
    this.requiredClearanceM = 0.3,
    this.materials = const [],
    this.colors = const [],
    required this.price,
    this.currency = 'MYR',
    required this.retailer,
    this.retailerUrl,
    this.imageUrl,
    this.availability = 'IN_STOCK',
    this.leadTimeDays = 7,
    this.description = '',
  });

  String get formattedPrice {
    final sym = _currencySymbol(currency);
    return '$sym ${price.toStringAsFixed(0)}';
  }

  static String _currencySymbol(String curr) {
    switch (curr.toUpperCase()) {
      case 'SGD':
        return 'S\$';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      case 'MYR':
      default:
        return 'RM';
    }
  }

  factory CatalogProductModel.fromMap(Map<String, dynamic> map) {
    final rawStyles = (map['styles'] as List<dynamic>?) ?? [];
    final rawMaterials = (map['materials'] as List<dynamic>?) ?? [];
    final rawColors = (map['colors'] as List<dynamic>?) ?? [];

    return CatalogProductModel(
      id: map['id'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      category: map['category'] as String? ?? 'SOFA',
      styles: rawStyles.map((e) => e.toString()).toList(),
      tier: map['tier'] as String? ?? 'MODERATE',
      dimensions: map['dimensions'] != null
          ? ProductDimensionsModel.fromMap(map['dimensions'] as Map<String, dynamic>)
          : ProductDimensionsModel(widthM: 1.0, depthM: 1.0, heightM: 1.0),
      requiredClearanceM: (map['required_clearance_m'] as num?)?.toDouble() ?? 0.3,
      materials: rawMaterials.map((e) => e.toString()).toList(),
      colors: rawColors.map((e) => e.toString()).toList(),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'MYR',
      retailer: map['retailer'] as String? ?? '',
      retailerUrl: map['retailer_url'] as String?,
      imageUrl: map['image_url'] as String?,
      availability: map['availability'] as String? ?? 'IN_STOCK',
      leadTimeDays: (map['lead_time_days'] as num?)?.toInt() ?? 7,
      description: map['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'brand': brand,
      'category': category,
      'styles': styles,
      'tier': tier,
      'dimensions': dimensions.toMap(),
      'required_clearance_m': requiredClearanceM,
      'materials': materials,
      'colors': colors,
      'price': price,
      'currency': currency,
      'retailer': retailer,
      'retailer_url': retailerUrl,
      'image_url': imageUrl,
      'availability': availability,
      'lead_time_days': leadTimeDays,
      'description': description,
    };
  }
}

class ProductRecommendationModel {
  final String? targetElementId;
  final String? targetElementLabel;
  final CatalogProductModel product;
  final double matchScore;
  final String fitStatus;
  final String fitNotes;
  final double? targetWidthM;
  final double? targetDepthM;
  final double? targetHeightM;
  final double dimensionVariancePct;
  final String budgetStatus;
  final bool isAssigned;

  ProductRecommendationModel({
    this.targetElementId,
    this.targetElementLabel,
    required this.product,
    required this.matchScore,
    this.fitStatus = 'PERFECT_FIT',
    this.fitNotes = '',
    this.targetWidthM,
    this.targetDepthM,
    this.targetHeightM,
    this.dimensionVariancePct = 0.0,
    this.budgetStatus = 'Within Category Allocation',
    this.isAssigned = false,
  });

  String get fitStatusLabel {
    switch (fitStatus.toUpperCase()) {
      case 'PERFECT_FIT':
        return 'Perfect Fit';
      case 'TIGHT_FIT':
        return 'Tight Clearance';
      case 'CLEARANCE_WARNING':
        return 'Height Clearance Warning';
      case 'OVERSIZED':
        return 'Oversized';
      default:
        return fitStatus;
    }
  }

  int get matchPercentage => (matchScore * 100).round();

  ProductRecommendationModel copyWith({
    String? targetElementId,
    String? targetElementLabel,
    CatalogProductModel? product,
    double? matchScore,
    String? fitStatus,
    String? fitNotes,
    double? targetWidthM,
    double? targetDepthM,
    double? targetHeightM,
    double? dimensionVariancePct,
    String? budgetStatus,
    bool? isAssigned,
  }) {
    return ProductRecommendationModel(
      targetElementId: targetElementId ?? this.targetElementId,
      targetElementLabel: targetElementLabel ?? this.targetElementLabel,
      product: product ?? this.product,
      matchScore: matchScore ?? this.matchScore,
      fitStatus: fitStatus ?? this.fitStatus,
      fitNotes: fitNotes ?? this.fitNotes,
      targetWidthM: targetWidthM ?? this.targetWidthM,
      targetDepthM: targetDepthM ?? this.targetDepthM,
      targetHeightM: targetHeightM ?? this.targetHeightM,
      dimensionVariancePct: dimensionVariancePct ?? this.dimensionVariancePct,
      budgetStatus: budgetStatus ?? this.budgetStatus,
      isAssigned: isAssigned ?? this.isAssigned,
    );
  }

  factory ProductRecommendationModel.fromMap(Map<String, dynamic> map) {
    return ProductRecommendationModel(
      targetElementId: map['target_element_id'] as String?,
      targetElementLabel: map['target_element_label'] as String?,
      product: CatalogProductModel.fromMap(map['product'] as Map<String, dynamic>),
      matchScore: (map['match_score'] as num?)?.toDouble() ?? 0.0,
      fitStatus: map['fit_status'] as String? ?? 'PERFECT_FIT',
      fitNotes: map['fit_notes'] as String? ?? '',
      targetWidthM: (map['target_width_m'] as num?)?.toDouble(),
      targetDepthM: (map['target_depth_m'] as num?)?.toDouble(),
      targetHeightM: (map['target_height_m'] as num?)?.toDouble(),
      dimensionVariancePct: (map['dimension_variance_pct'] as num?)?.toDouble() ?? 0.0,
      budgetStatus: map['budget_status'] as String? ?? 'Within Category Allocation',
      isAssigned: map['is_assigned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'target_element_id': targetElementId,
      'target_element_label': targetElementLabel,
      'product': product.toMap(),
      'match_score': matchScore,
      'fit_status': fitStatus,
      'fit_notes': fitNotes,
      'target_width_m': targetWidthM,
      'target_depth_m': targetDepthM,
      'target_height_m': targetHeightM,
      'dimension_variance_pct': dimensionVariancePct,
      'budget_status': budgetStatus,
      'is_assigned': isAssigned,
    };
  }
}

class ProductRecommendationReportModel {
  final String roomId;
  final List<ProductRecommendationModel> recommendations;
  final String appliedStyle;
  final String appliedTier;
  final String appliedCurrency;
  final double totalRecommendedSpend;
  final DateTime? generatedAt;

  ProductRecommendationReportModel({
    required this.roomId,
    this.recommendations = const [],
    this.appliedStyle = '',
    this.appliedTier = 'MODERATE',
    this.appliedCurrency = 'MYR',
    this.totalRecommendedSpend = 0.0,
    this.generatedAt,
  });

  String get formattedSpend {
    final sym = CatalogProductModel._currencySymbol(appliedCurrency);
    return '$sym ${totalRecommendedSpend.toStringAsFixed(0)}';
  }

  factory ProductRecommendationReportModel.fromMap(Map<String, dynamic> map) {
    final rawRecs = (map['recommendations'] as List<dynamic>?) ?? [];
    return ProductRecommendationReportModel(
      roomId: map['room_id'] as String? ?? '',
      recommendations: rawRecs
          .map((e) => ProductRecommendationModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      appliedStyle: map['applied_style'] as String? ?? '',
      appliedTier: map['applied_tier'] as String? ?? 'MODERATE',
      appliedCurrency: map['applied_currency'] as String? ?? 'MYR',
      totalRecommendedSpend: (map['total_recommended_spend'] as num?)?.toDouble() ?? 0.0,
      generatedAt: map['generated_at'] != null ? DateTime.tryParse(map['generated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'recommendations': recommendations.map((e) => e.toMap()).toList(),
      'applied_style': appliedStyle,
      'applied_tier': appliedTier,
      'applied_currency': appliedCurrency,
      'total_recommended_spend': totalRecommendedSpend,
      'generated_at': generatedAt?.toIso8601String(),
    };
  }
}


