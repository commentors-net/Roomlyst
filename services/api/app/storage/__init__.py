"""
Storage Package initialization with dynamic factory.
"""

from ..core.config import settings
from .base import StorageProviderBase
from .local import LocalStorageProvider
from .s3 import S3StorageProvider


def get_storage_provider() -> StorageProviderBase:
    """Returns configured storage provider according to environment settings."""
    if settings.STORAGE_BACKEND == "s3" and settings.S3_BUCKET_NAME:
        return S3StorageProvider(
            bucket_name=settings.S3_BUCKET_NAME,
            endpoint_url=settings.S3_ENDPOINT_URL,
            access_key=settings.S3_ACCESS_KEY,
            secret_key=settings.S3_SECRET_KEY,
            region=settings.S3_REGION,
        )
    return LocalStorageProvider(base_dir=settings.LOCAL_STORAGE_PATH, secret_key=settings.SECRET_KEY)


__all__ = ["StorageProviderBase", "LocalStorageProvider", "S3StorageProvider", "get_storage_provider"]
