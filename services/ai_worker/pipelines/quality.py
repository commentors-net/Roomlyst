"""
Image Quality Checker Implementation.
Adheres to Blueprint Section 9 (Capture Quality Control) & Section 26 (Error Handling Philosophy).
"""

import time
import numpy as np
from PIL import Image
from packages.room_model import QualityReport
from .base import QualityCheckerBase


class ImageQualityChecker(QualityCheckerBase):
    """
    Validates indoor room photos for blur, exposure, and framing issues.
    Provides actionable, plain-English guidance to users when issues are detected.
    """

    def __init__(
        self,
        blur_threshold: float = 50.0,
        min_luminance: float = 35.0,
        max_luminance: float = 230.0,
        min_width: int = 400,
        min_height: int = 400,
    ):
        self.blur_threshold = blur_threshold
        self.min_luminance = min_luminance
        self.max_luminance = max_luminance
        self.min_width = min_width
        self.min_height = min_height

    def _calculate_laplacian_variance(self, gray_array: np.ndarray) -> float:
        """
        Calculates variance of Laplacian using discrete kernel approximation.
        High variance indicates sharp edges; low variance indicates blur.
        """
        # 3x3 Laplacian kernel
        # [0,  1, 0]
        # [1, -4, 1]
        # [0,  1, 0]
        padded = np.pad(gray_array, 1, mode="edge")
        laplacian = (
            padded[:-2, 1:-1]
            + padded[2:, 1:-1]
            + padded[1:-1, :-2]
            + padded[1:-1, 2:]
            - 4 * gray_array
        )
        return float(np.var(laplacian))

    def validate_image(self, image: Image.Image) -> QualityReport:
        width, height = image.size
        messages = []
        passed = True

        # Convert to grayscale numpy array for analysis
        gray_img = image.convert("L")
        gray_arr = np.array(gray_img, dtype=np.float32)

        # 1. Blur evaluation
        blur_score = self._calculate_laplacian_variance(gray_arr)
        is_blurry = blur_score < self.blur_threshold
        if is_blurry:
            passed = False
            messages.append(
                "Image appears blurry. Please hold your phone steady or ensure good lighting and recapture."
            )

        # 2. Exposure evaluation
        mean_lum = float(np.mean(gray_arr))
        is_under = mean_lum < self.min_luminance
        is_over = mean_lum > self.max_luminance

        if is_under:
            passed = False
            messages.append(
                "Image is too dark. Turn on room lights or open curtains to help the AI detect walls and furniture."
            )
        elif is_over:
            passed = False
            messages.append(
                "Image is overexposed or washed out by direct light. Try angling away from direct sun or glare."
            )

        # 3. Resolution check
        if width < self.min_width or height < self.min_height:
            passed = False
            messages.append(
                f"Resolution ({width}x{height}) is too low for accurate structural analysis. Minimum {self.min_width}x{self.min_height} required."
            )

        return QualityReport(
            passed=passed,
            blur_score=round(blur_score, 2),
            is_blurry=is_blurry,
            exposure_mean=round(mean_lum, 2),
            is_under_exposed=is_under,
            is_over_exposed=is_over,
            width_px=width,
            height_px=height,
            feedback_messages=messages,
        )
