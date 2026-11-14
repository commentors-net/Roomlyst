#!/usr/bin/env python3
"""
Roomlyst Local Secret Scanner (Prompt 13).
Zero-dependency script to audit workspace and staged git files for leaked credentials.
Adheres to AGENTS.md Section 9 secret management policy.
"""

import os
import re
import sys
from pathlib import Path

# Patterns to detect potential credentials
SECRET_PATTERNS = [
    ("Private Key Block", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")),
    ("Hardcoded JWT Secret", re.compile(r"""(?i)(?:SECRET_KEY|JWT_SECRET)\s*[:=]\s*['\"][a-zA-Z0-9_\-\.]{16,}['\"]""")),
    ("OpenAI / Anthropic Token", re.compile(r"""['\"](?:sk-[a-zA-Z0-9]{32,})['\"]""")),
    ("Replicate Token", re.compile(r"""['\"](?:r8_[a-zA-Z0-9]{32,})['\"]""")),
    ("AWS Access Key ID", re.compile(r"""['\"](?:AKIA[0-9A-Z]{16})['\"]""")),
    ("AWS Secret Key Assignment", re.compile(r"""(?i)(?:aws_secret_access_key|s3_secret_key)\s*[:=]\s*['\"][a-zA-Z0-9/+=]{40}['\"]""")),
]

# Allowlisted files and paths (matching .gitleaks.toml policy)
ALLOWLIST_PATHS = [
    Path("apps/mobile/android/app/google-services.json"),
    Path("tests/conftest.py"),
    Path("tests/test_secret_management.py"),
    Path("tests/test_prompt10_gateway_and_subpath.py"),
    Path("tests/test_privacy_and_security.py"),
    Path(".env.example"),
    Path(".gitleaks.toml"),
    Path("scripts/scan_secrets.py"),
]

# Allowlisted safe template placeholder strings
ALLOWLIST_STRINGS = [
    "change-this-to-a-secure-random-secret-key-in-production",
    "test-secret-key-roomlyst-2026",
    "test-secure-key-roomlyst-2026-xyz",
    "a-very-secure-random-secret-key-for-unit-testing-32chars",
    "docker-secret-file-content-32-chars-long!",
]

IGNORED_DIRS = {
    ".git",
    ".pytest_cache",
    ".dart_tool",
    "__pycache__",
    "node_modules",
    "venv",
    ".venv",
    "build",
    "dist",
    "storage",
    "12-evidence",
}


def is_allowlisted_path(rel_path: Path) -> bool:
    for allowed in ALLOWLIST_PATHS:
        if rel_path == allowed or allowed in rel_path.parents or rel_path.as_posix() == allowed.as_posix():
            return True
    return False


def scan_file(file_path: Path, repo_root: Path) -> list:
    rel_path = file_path.relative_to(repo_root)
    if is_allowlisted_path(rel_path):
        return []

    try:
        content = file_path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return []

    findings = []
    for line_no, line in enumerate(content.splitlines(), start=1):
        # Skip lines matching allowlisted test placeholders
        if any(safe_str in line for safe_str in ALLOWLIST_STRINGS):
            continue

        for rule_name, pattern in SECRET_PATTERNS:
            match = pattern.search(line)
            if match:
                # Redact matched text in console output per AGENTS.md policy
                findings.append({
                    "file": str(rel_path),
                    "line": line_no,
                    "rule": rule_name,
                    "preview": f"[REDACTED_SECRET_{len(match.group(0))}_CHARS]"
                })
    return findings


def main():
    repo_root = Path(__file__).resolve().parent.parent
    staged_only = "--staged" in sys.argv

    print("==================================================")
    print("Roomlyst Secret Scanner (Gitleaks Policy Auditor)")
    print(f"Scanning Root: {repo_root}")
    print("==================================================")

    all_findings = []
    scanned_count = 0

    for root, dirs, files in os.walk(repo_root):
        # Prune ignored directories
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS]

        for file_name in files:
            file_path = Path(root) / file_name
            # Skip media / binary files
            if file_path.suffix.lower() in {".png", ".jpg", ".jpeg", ".db", ".sqlite", ".ico", ".bin", ".ply"}:
                continue

            findings = scan_file(file_path, repo_root)
            if findings:
                all_findings.extend(findings)
            scanned_count += 1

    print(f"Total files scanned: {scanned_count}")

    if all_findings:
        print("\n[!] CRITICAL: Secret scanning detected potential leaked credentials:")
        for f in all_findings:
            print(f"  - {f['file']}:{f['line']} [{f['rule']}] -> {f['preview']}")
        print("\nAction required: Remove hardcoded secrets or update .gitleaks.toml allowlist if justified.")
        sys.exit(1)
    else:
        print("\n[+] PASS: No leaked secrets found. Repository complies with AGENTS.md Section 9.")
        sys.exit(0)


if __name__ == "__main__":
    main()
