"""
Abstract Base Classes for AI and Computer Vision Pipelines in Roomlyst.
Adheres to ADR-003 and Blueprint Section 13.3.
"""

from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional
from PIL import Image
from pydantic import BaseModel, Field

from packages.room_model import (
    CanonicalRoomModel,
    DesignConstraint,
    DesignVariant,
    QualityReport,
    RoomObject,
    RoomOpening,
    RoomSurface,
)


class PipelineResult(BaseModel):
    """Metadata wrapper for all pipeline step outputs."""
    provider: str
    model_version: str
    latency_ms: float
    estimated_cost_usd: float = 0.0
    data: Any = None


class QualityCheckerBase(ABC):
    """Interface for capture quality verification."""

    @abstractmethod
    def validate_image(self, image: Image.Image) -> QualityReport:
        """Evaluates image for blur, lighting, and framing."""
        pass


class SegmentationProviderBase(ABC):
    """Interface for semantic and instance mask generation (e.g. SAM 2)."""

    @abstractmethod
    def segment_surfaces_and_objects(
        self, image: Image.Image, room_type: str = "living_room"
    ) -> PipelineResult:
        """Returns detected surfaces and objects with mask metadata."""
        pass


class DepthProviderBase(ABC):
    """Interface for monocular depth estimation (e.g. Depth Anything V2)."""

    @abstractmethod
    def estimate_depth(self, image: Image.Image) -> PipelineResult:
        """Returns relative or metric depth map representation."""
        pass


class ObjectDetectorBase(ABC):
    """Interface for indoor furniture and structural opening detection."""

    @abstractmethod
    def detect_objects(self, image: Image.Image) -> List[RoomObject]:
        """Detects major indoor furniture and items."""
        pass

    @abstractmethod
    def detect_openings(self, image: Image.Image) -> List[RoomOpening]:
        """Detects architectural openings (windows, doors)."""
        pass


class RedesignGeneratorBase(ABC):
    """Interface for structure-preserving generative redesign."""

    @abstractmethod
    def generate_redesigns(
        self,
        image: Image.Image,
        room_model: CanonicalRoomModel,
        constraints: DesignConstraint,
        count: int = 3,
    ) -> PipelineResult:
        """
        Generates design variants conforming to keep/replace masks,
        structural preservation, and user style choices.
        """
        pass
