"""
Monocular Depth Estimation Pipeline.
Adheres to Blueprint Section 13.1, 13.3, and ADR-003.
"""

import time
import numpy as np
from PIL import Image
from .base import DepthProviderBase, PipelineResult


class LocalDepthEstimator(DepthProviderBase):
    """
    Reference monocular depth estimator.
    Computes a depth gradient estimation representing the room perspective
    (foreground floor closer, ceiling/distant corners further) for local testing and CI.
    """

    def __init__(self, model_version: str = "depth-estimator-v1-ref"):
        self.model_version = model_version

    def estimate_depth(self, image: Image.Image) -> PipelineResult:
        start_time = time.time()
        w, h = image.size

        # Perspective room gradient simulation:
        # Lower center is closest (depth ~ 0.2), vanishing point around (0.5, 0.45) is furthest (depth ~ 0.95)
        y_coords, x_coords = np.mgrid[0:h, 0:w]
        norm_y = y_coords / float(h)
        norm_x = (x_coords - w / 2.0) / float(w)

        # Distance from approximate camera floor plane
        depth_array = 0.3 + 0.6 * (1.0 - norm_y) + 0.1 * np.abs(norm_x)
        depth_array = np.clip(depth_array, 0.0, 1.0)

        # Scale to 8-bit depth map visualization
        depth_uint8 = (depth_array * 255.0).astype(np.uint8)
        depth_image = Image.fromarray(depth_uint8, mode="L")

        latency_ms = (time.time() - start_time) * 1000.0

        return PipelineResult(
            provider="local-depth-estimator",
            model_version=self.model_version,
            latency_ms=round(latency_ms, 2),
            estimated_cost_usd=0.0001,
            data={
                "min_depth": float(np.min(depth_array)),
                "max_depth": float(np.max(depth_array)),
                "depth_image": depth_image,
            },
        )
