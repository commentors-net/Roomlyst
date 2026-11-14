"""
Roomlyst Security & Secret Management Verification Suite (Prompt 13).
Validates fail-closed secret architecture, placeholder guards,
Docker secret resolution, .gitignore coverage, and repository credential hygiene.
"""

import os
import re
import tempfile
from pathlib import Path
import pytest
from pydantic import ValidationError

from services.api.app.core.config import Settings


class TestSecretManagementFailClosed:
    """Verifies that the application fails closed when required credentials are missing."""

    def test_settings_fails_closed_when_secret_key_missing(self, monkeypatch):
        """Settings must raise an exception when SECRET_KEY is not provided."""
        monkeypatch.delenv("SECRET_KEY", raising=False)
        monkeypatch.delenv("SECRET_KEY_FILE", raising=False)

        with pytest.raises(ValidationError) as exc_info:
            Settings(_env_file=None)

        errors = str(exc_info.value)
        assert "Required secret 'SECRET_KEY' is missing" in errors

    def test_settings_rejects_insecure_placeholders(self, monkeypatch):
        """Settings must reject known insecure default keys."""
        for bad_key in ["changeme", "placeholder", "secret", "12345678", "password"]:
            monkeypatch.setenv("SECRET_KEY", bad_key)
            with pytest.raises(ValidationError) as exc_info:
                Settings(_env_file=None)
            assert "Insecure placeholder" in str(exc_info.value)

    def test_settings_rejects_short_secret_keys(self, monkeypatch):
        """Settings must reject keys shorter than 16 characters."""
        monkeypatch.setenv("SECRET_KEY", "short-key-1234")
        with pytest.raises(ValidationError) as exc_info:
            Settings(_env_file=None)
        assert "at least 16 characters" in str(exc_info.value)

    def test_settings_accepts_valid_secret_key(self, monkeypatch):
        """Settings must accept valid, non-trivial secret keys."""
        valid_key = "a-very-secure-random-secret-key-for-unit-testing-32chars"
        monkeypatch.setenv("SECRET_KEY", valid_key)
        s = Settings(_env_file=None)
        assert s.SECRET_KEY == valid_key

    def test_settings_resolves_secret_from_docker_secret_file(self, monkeypatch):
        """Settings must read secret from SECRET_KEY_FILE when provided."""
        valid_file_key = "docker-secret-file-content-32-chars-long!"
        with tempfile.NamedTemporaryFile("w", delete=False) as tf:
            tf.write(valid_file_key)
            tf_path = tf.name

        try:
            monkeypatch.delenv("SECRET_KEY", raising=False)
            monkeypatch.setenv("SECRET_KEY_FILE", tf_path)
            s = Settings(_env_file=None)
            assert s.SECRET_KEY == valid_file_key
        finally:
            if os.path.exists(tf_path):
                os.unlink(tf_path)


class TestRepositoryCredentialHygiene:
    """Verifies that no real secrets or un-ignored credentials exist in tracked files."""

    def test_env_example_has_no_real_secrets(self):
        """Ensure .env.example only contains template placeholders."""
        env_example = Path(".env.example")
        assert env_example.is_file(), ".env.example must exist"
        content = env_example.read_text(encoding="utf-8")

        # Must not contain real live keys
        assert "AIza" not in content
        assert "sk-" not in content
        assert "r8_" not in content
        assert "AKIA" not in content
        assert "BEGIN RSA PRIVATE KEY" not in content

    def test_gitignore_covers_sensitive_credential_patterns(self):
        """Ensure .gitignore excludes critical credential patterns."""
        gitignore = Path(".gitignore")
        assert gitignore.is_file()
        content = gitignore.read_text(encoding="utf-8")

        required_patterns = [
            ".env",
            "*.pem",
            "*.key",
            "*.keystore",
            "*.jks",
            "credentials.json",
            "google-services.json",
        ]
        for pattern in required_patterns:
            assert pattern in content, f".gitignore must contain {pattern}"

    def test_no_hardcoded_cloud_provider_keys_in_services(self):
        """Scan services/ directory for accidental hardcoded API tokens."""
        services_dir = Path("services")
        assert services_dir.is_dir()

        # Regular expressions for known secret formats
        patterns = {
            "OpenAI/Anthropic Key": re.compile(r"['\"](?:sk-[a-zA-Z0-9]{32,})['\"]"),
            "Replicate Token": re.compile(r"['\"](?:r8_[a-zA-Z0-9]{32,})['\"]"),
            "AWS Access Key": re.compile(r"['\"](?:AKIA[0-9A-Z]{16})['\"]"),
            "Private Key Block": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
        }

        violations = []
        for py_file in services_dir.rglob("*.py"):
            text = py_file.read_text(encoding="utf-8", errors="ignore")
            for label, pattern in patterns.items():
                if pattern.search(text):
                    violations.append(f"{py_file}: matches {label}")

        assert not violations, f"Hardcoded credentials found: {violations}"
