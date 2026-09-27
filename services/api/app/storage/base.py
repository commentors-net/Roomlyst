"""
Abstract Base Class for Object Storage Providers.
Fulfills Blueprint Section 20 & ADR-005.
"""

from abc import ABC, abstractmethod


class StorageProviderBase(ABC):
    """Unified interface for private, signed media storage."""

    @abstractmethod
    def upload_file(self, key: str, data: bytes, content_type: str = "image/jpeg") -> str:
        """Stores file bytes under key and returns access reference."""
        pass

    @abstractmethod
    def get_signed_url(self, key: str, expires_in: int = 3600) -> str:
        """Generates a time-limited signed URL for private access."""
        pass

    @abstractmethod
    def download_file(self, key: str) -> bytes:
        """Retrieves raw bytes from storage."""
        pass

    @abstractmethod
    def delete_file(self, key: str) -> bool:
        """Deletes file from storage."""
        pass
