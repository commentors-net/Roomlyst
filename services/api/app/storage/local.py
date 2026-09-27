"""
Local Filesystem Storage Provider with Token-Signed URL Support.
Used for development, testing, and offline deployments.
"""

import hashlib
import hmac
import os
import time
from .base import StorageProviderBase


class LocalStorageProvider(StorageProviderBase):
    def __init__(self, base_dir: str = "storage", secret_key: str = "local-storage-secret"):
        self.base_dir = base_dir
        self.secret_key = secret_key
        os.makedirs(base_dir, exist_ok=True)

    def _resolve_path(self, key: str) -> str:
        # Sanitize key to prevent path traversal
        clean_key = os.path.normpath(key).lstrip("\\/.")
        return os.path.join(self.base_dir, clean_key)

    def upload_file(self, key: str, data: bytes, content_type: str = "image/jpeg") -> str:
        target_path = self._resolve_path(key)
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        with open(target_path, "wb") as f:
            f.write(data)
        return key

    def get_signed_url(self, key: str, expires_in: int = 3600) -> str:
        """
        Creates an expiring signed query string for local static asset serving.
        Protects raw user media from hotlinking without credentials.
        """
        expires_at = int(time.time()) + expires_in
        sig_payload = f"{key}:{expires_at}".encode("utf-8")
        signature = hmac.new(self.secret_key.encode("utf-8"), sig_payload, hashlib.sha256).hexdigest()[:16]
        return f"/storage/{key}?sig={signature}&exp={expires_at}"

    def download_file(self, key: str) -> bytes:
        target_path = self._resolve_path(key)
        if not os.path.exists(target_path):
            raise FileNotFoundError(f"Storage asset not found: {key}")
        with open(target_path, "rb") as f:
            return f.read()

    def delete_file(self, key: str) -> bool:
        target_path = self._resolve_path(key)
        if os.path.exists(target_path):
            os.remove(target_path)
            return True
        return False
