"""
Roomlyst AI Worker Pipelines.
"""

from .base import (
    DepthProviderBase,
    ObjectDetectorBase,
    QualityCheckerBase,
    RedesignGeneratorBase,
    SegmentationProviderBase,
)
from .quality import ImageQualityChecker
from .depth import LocalDepthEstimator
from .room_analyzer import RoomAnalyzer
from .multiview_analyzer import MultiViewRoomAnalyzer, MultiViewAssociator
from .generation import LocalRedesignGenerator
from .cloud_generation import CloudInpaintingProvider
from .mask_builder import MaskBuilder
from .scale_calibrator import ScaleCalibrator, ReferencePreset
from .feasibility_analyzer import GeometryAndFeasibilityAnalyzer
from .budget_estimator import BudgetIntelligenceEngine
from .variant_manager import VariantManager
from .video_scan_analyzer import VideoScanAnalyzer
from .reconstruction_pipeline import MultiViewReconstructor
from .ar_fusion_engine import ARMotionFusionEngine
from .native_spatial_normalizer import NativeSpatialNormalizer
from .material_estimator import MaterialEstimatorEngine, material_estimator

__all__ = [
    "DepthProviderBase",
    "ObjectDetectorBase",
    "QualityCheckerBase",
    "RedesignGeneratorBase",
    "SegmentationProviderBase",
    "ImageQualityChecker",
    "LocalDepthEstimator",
    "RoomAnalyzer",
    "MultiViewRoomAnalyzer",
    "MultiViewAssociator",
    "LocalRedesignGenerator",
    "CloudInpaintingProvider",
    "MaskBuilder",
    "ScaleCalibrator",
    "ReferencePreset",
    "GeometryAndFeasibilityAnalyzer",
    "BudgetIntelligenceEngine",
    "VariantManager",
    "VideoScanAnalyzer",
    "MultiViewReconstructor",
    "ARMotionFusionEngine",
    "NativeSpatialNormalizer",
    "MaterialEstimatorEngine",
    "material_estimator",
]
