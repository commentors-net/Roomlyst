"""
EXIF and Metadata Privacy Sanitizer for Roomlyst.
Adheres to Blueprint Section 23 (Privacy Requirements) & ADR-008:
- Strips unnecessary EXIF/GPS metadata from room photos prior to persistence or model ingestion.
- Normalizes orientation via exif_transpose before stripping EXIF tags.
- Verifies absence of sensitive geolocation data (GPSInfo 0x8825).
"""

import io
from typing import Dict, Any, Optional
from PIL import Image, ImageOps


GPS_IFD_TAG = 34853  # 0x8825 GPSInfo tag in EXIF standard


def has_exif_gps(image_bytes: bytes) -> bool:
    """
    Checks if image bytes contain sensitive GPS/geolocation EXIF tags.
    """
    try:
        with Image.open(io.BytesIO(image_bytes)) as img:
            exif = img.getexif()
            if not exif:
                return False
            # Check for GPS tag in primary EXIF or IFD
            if GPS_IFD_TAG in exif:
                return True
            # Also check get_ifd(GPS_IFD_TAG) if available in modern Pillow
            if hasattr(exif, "get_ifd"):
                gps_ifd = exif.get_ifd(GPS_IFD_TAG)
                if gps_ifd:
                    return True
            return False
    except Exception:
        return False


def sanitize_image(image_bytes: bytes) -> bytes:
    """
    Sanitizes image bytes by:
    1. Transposing pixels if an orientation tag is present (so the image does not rotate).
    2. Stripping ALL EXIF metadata including GPS coordinates, camera serial numbers, and timestamps.
    3. Re-encoding cleanly into JPEG or PNG.
    """
    with Image.open(io.BytesIO(image_bytes)) as img:
        # Preserve visual orientation before stripping EXIF
        transposed = ImageOps.exif_transpose(img)
        if transposed is None:
            transposed = img

        target_format = "PNG" if img.format == "PNG" else "JPEG"
        output_buffer = io.BytesIO()

        if target_format == "JPEG":
            # Convert RGBA to RGB for JPEG compatibility
            if transposed.mode in ("RGBA", "P"):
                transposed = transposed.convert("RGB")
            transposed.save(output_buffer, format="JPEG", quality=95, optimize=True)
        else:
            transposed.save(output_buffer, format="PNG", optimize=True)

        sanitized_bytes = output_buffer.getvalue()

    return sanitized_bytes


def inspect_image_privacy(image_bytes: bytes) -> Dict[str, Any]:
    """
    Returns an audit summary of image metadata privacy status.
    """
    with Image.open(io.BytesIO(image_bytes)) as img:
        exif = img.getexif()
        tag_count = len(exif) if exif else 0
        gps_present = has_exif_gps(image_bytes)

    return {
        "format": img.format,
        "size_bytes": len(image_bytes),
        "exif_tags_count": tag_count,
        "contains_gps": gps_present,
        "privacy_compliant": (not gps_present and tag_count == 0),
    }
