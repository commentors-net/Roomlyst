"""
Configuration Settings for Roomlyst API Service.
Uses pydantic-settings to load from environment variables and .env file.
Adheres to AGENTS.md Section 9: fail-closed secret architecture,
no hardcoded default credentials, and Docker secrets support.
"""

import os
from pathlib import Path
from typing import Optional
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "Roomlyst API"
    VERSION: str = "0.2.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"

    # Database
    DATABASE_URL: str = "sqlite:///./roomlyst.db"

    # Security & JWT - Fail-closed: No working default secret in source code
    SECRET_KEY: str = ""
    SECRET_KEY_FILE: Optional[str] = None
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

    # Cookie security
    COOKIE_SECURE: bool = False

    # Redis (For distributed task worker)
    REDIS_URL: str = "redis://localhost:6379/0"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @field_validator("SECRET_KEY", mode="before")
    @classmethod
    def validate_secret_key(cls, v: Optional[str]) -> str:
        """
        Ensures a valid SECRET_KEY is provided via environment, .env, or Docker secrets file.
        Fails closed with a clear error if missing or set to an insecure default.
        """
        key = v.strip() if (v and isinstance(v, str)) else None

        if not key:
            # Check SECRET_KEY_FILE environment variable or standard Docker secrets paths
            secret_file = os.getenv("SECRET_KEY_FILE")
            if not secret_file:
                for candidate in ("/run/secrets/roomlyst_secret_key", "/run/secrets/secret_key"):
                    if Path(candidate).is_file():
                        secret_file = candidate
                        break
            if secret_file and Path(secret_file).is_file():
                key = Path(secret_file).read_text(encoding="utf-8").strip()

        if not key:
            raise ValueError(
                "Required secret 'SECRET_KEY' is missing. Roomlyst requires a secure secret key "
                "provided via the SECRET_KEY environment variable, a .env file, or a Docker secret file "
                "(SECRET_KEY_FILE). No hardcoded default signing secrets are permitted (fail-closed architecture)."
            )

        insecure_prohibited = {
            "changeme",
            "placeholder",
            "secret",
            "12345678",
            "password",
        }
        if key.lower() in insecure_prohibited:
            raise ValueError(f"Insecure placeholder '{key}' is not permitted as SECRET_KEY.")

        if len(key) < 16:
            raise ValueError(f"SECRET_KEY must be at least 16 characters long (got {len(key)}).")

        return key


settings = Settings()
