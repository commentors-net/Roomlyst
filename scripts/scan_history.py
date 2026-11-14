#!/usr/bin/env python3
"""
Roomlyst Git History Secret Scanner.
Audits all commits in reachable git history for leaked credentials.
Adheres to AGENTS.md Section 9 (universal secret redaction in output).
"""

import subprocess
import re
import sys
from pathlib import Path

PATTERNS = [
    ("Private Key Block", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")),
    ("Hardcoded JWT Secret", re.compile(r"(?i)(?:SECRET_KEY|JWT_SECRET)\s*[:=]\s*['\"][a-zA-Z0-9_\-\.]{16,}['\"]")),
    ("OpenAI / Anthropic Token", re.compile(r"['\"](?:sk-[a-zA-Z0-9]{32,})['\"]")),
    ("Replicate Token", re.compile(r"['\"](?:r8_[a-zA-Z0-9]{32,})['\"]")),
    ("AWS Access Key ID", re.compile(r"['\"](?:AKIA[0-9A-Z]{16})['\"]")),
    ("Google API Key", re.compile(r"AIza[0-9A-Za-z-_]{35}")),
]

SAFE_TEMPLATES = [
    "change-this-to-a-secure-random-secret-key-in-production",
    "test-secret-key-roomlyst-2026",
    "test-secure-key-roomlyst-2026-xyz",
]

def scan_history():
    env = {"GIT_CONFIG_GLOBAL": "NUL", "GIT_CONFIG_SYSTEM": "NUL"}
    res = subprocess.run(["git", "rev-list", "--all"], capture_output=True, text=True, env=env)
    if res.returncode != 0:
        print(f"Error reading commits: {res.stderr}")
        sys.exit(1)

    commits = [c.strip() for c in res.stdout.strip().splitlines() if c.strip()]
    print(f"Total reachable commits in repository history: {len(commits)}")

    findings = []
    for c in commits:
        c_summary = subprocess.run(
            ["git", "log", "-1", "--oneline", c],
            capture_output=True,
            text=True,
            env=env
        ).stdout.strip()

        diff_res = subprocess.run(
            ["git", "show", "--format=", c],
            capture_output=True,
            text=True,
            env=env
        )

        for line_no, line in enumerate(diff_res.stdout.splitlines(), start=1):
            if not line.startswith("+") or line.startswith("+++"):
                continue

            # Skip allowlisted safe template strings
            if any(s in line for s in SAFE_TEMPLATES):
                continue

            for rule_name, pat in PATTERNS:
                m = pat.search(line)
                if m:
                    val = m.group(0)
                    findings.append({
                        "commit": c_summary,
                        "rule": rule_name,
                        "preview": f"[REDACTED_{rule_name.upper().replace(' ', '_')}_{len(val)}_CHARS]"
                    })

    print(f"Total secret pattern matches in Git history: {len(findings)}")
    seen = set()
    for f in findings:
        key = (f["commit"], f["rule"])
        if key not in seen:
            seen.add(key)
            print(f"  - {f['commit']} | {f['rule']} -> {f['preview']}")

    return findings

if __name__ == "__main__":
    scan_history()
