"""
S3-Compatible Object Storage Provider for Production & MinIO.
Compliant with Blueprint Section 20 & ADR-005.
"""

from typing import Optional
import boto3
from botocore.config import Config
from .base import StorageProviderBase


class S3StorageProvider(StorageProviderBase):
    def __init__(
        self,
        bucket_name: str,
        endpoint_url: Optional[str] = None,
        access_key: Optional[str] = None,
        secret_key: Optional[str] = None,
        region: str = "us-east-1",
    ):
        self.bucket_name = bucket_name
        self.client = boto3.client(
            "s3",
            endpoint_url=endpoint_url,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region,
            config=Config(signature_version="s3v4"),
        )

    def upload_file(self, key: str, data: bytes, content_type: str = "image/jpeg") -> str:
        self.client.put_object(
            Bucket=self.bucket_name,
            Key=key,
            Body=data,
            ContentType=content_type,
        )
        return key

    def get_signed_url(self, key: str, expires_in: int = 3600) -> str:
        """Generates a secure S3 pre-signed URL."""
        return self.client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self.bucket_name, "Key": key},
            ExpiresIn=expires_in,
        )

    def download_file(self, key: str) -> bytes:
        response = self.client.get_object(Bucket=self.bucket_name, Key=key)
        return response["Body"].read()

    def delete_file(self, key: str) -> bool:
        self.client.delete_object(Bucket=self.bucket_name, Key=key)
        return True
