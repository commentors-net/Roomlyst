"""
Configuration Settings for Roomlyst API Service.
Uses pydantic-settings to load from environment variables and .env file.
"""

from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "Roomlyst API"
    VERSION: str = "0.2.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"

    # Database
    DATABASE_URL: str = "sqlite:///./roomlyst.db"

    # Security & JWT
    SECRET_KEY: str = "roomlyst-super-secret-dev-key-change-in-production-2026"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # Storage Backend: "local" or "s3"
    STORAGE_BACKEND: str = "local"
    LOCAL_STORAGE_PATH: str = "storage"
    S3_BUCKET_NAME: str = "roomlyst-media"
    S3_ENDPOINT_URL: Optional[str] = None
    S3_ACCESS_KEY: Optional[str] = None
    S3_SECRET_KEY: Optional[str] = None
    S3_REGION: str = "us-east-1"

    # Redis (For distributed task worker)
    REDIS_URL: str = "redis://localhost:6379/0"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
