"""Repo-integrity + public-safety tests.

These ensure (1) the compose file and key configs parse, and (2) the repo never
ships proprietary / secret content. The safety test is a hard gate: it scans
every committed text file for forbidden terms (data-moat, model-distillation,
partner names) and fails loudly if any appear.
"""
from __future__ import annotations

import json
import os
import re

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _text_files() -> list[str]:
    skip_dirs = {".git", "node_modules", ".terraform", "__pycache__", ".pytest_cache"}
    out: list[str] = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for fn in filenames:
            path = os.path.join(dirpath, fn)
            # Skip this test file itself (it necessarily names the terms).
            if os.path.abspath(path) == os.path.abspath(__file__):
                continue
            out.append(path)
    return out


def test_compose_parses():
    with open(os.path.join(ROOT, "docker-compose.yml"), encoding="utf-8") as fh:
        doc = yaml.safe_load(fh)
    assert "services" in doc
    for svc in ("db", "cache", "storage", "api"):
        assert svc in doc["services"], f"missing service: {svc}"


def test_compose_services_have_healthchecks_where_expected():
    with open(os.path.join(ROOT, "docker-compose.yml"), encoding="utf-8") as fh:
        doc = yaml.safe_load(fh)
    for svc in ("db", "cache", "storage", "api"):
        assert "healthcheck" in doc["services"][svc], f"{svc} missing healthcheck"


def test_env_example_has_no_real_secrets():
    with open(os.path.join(ROOT, ".env.example"), encoding="utf-8") as fh:
        content = fh.read()
    # Placeholders only: each secret default must be an obvious change-me value.
    for line in content.splitlines():
        if line.startswith(("POSTGRES_PASSWORD=", "APP_DB_PASSWORD=", "MINIO_ROOT_PASSWORD=")):
            value = line.split("=", 1)[1]
            assert "change-me" in value, f"non-placeholder secret in .env.example: {line}"


def test_railway_json_valid():
    with open(os.path.join(ROOT, "starters", "railway", "railway.json"), encoding="utf-8") as fh:
        json.load(fh)


def test_vercel_json_valid():
    with open(os.path.join(ROOT, "starters", "vercel", "vercel.json"), encoding="utf-8") as fh:
        json.load(fh)


# --- Public-safety gate ----------------------------------------------------
# Forbidden terms that would leak proprietary strategy or secret architecture.
# Word-boundary regexes keep them from matching innocuous substrings.
FORBIDDEN_PATTERNS = [
    r"\bparallel[- ]?write\b",
    r"\bshadow ledger\b",
    r"\bsecond ledger\b",
    r"\bowned ledger\b",
    r"\bowned books\b",
    r"\bdata[- ]?moat\b",
    r"\bdistillation\b",
    r"\bteacher model\b",
    r"\bstudent model\b",
    r"\bLoRA\b",
    r"\binference[_ ]?traces\b",
    r"\bde-?id(?:entification)? patent\b",
    r"\bsignalstore\b",
    r"\bintegrus\b",
    r"\bmaxed\b",
    r"\bqwen\b",
    r"\bDGX\b",
    r"\bSpark\b",
]


def test_no_forbidden_terms_anywhere():
    compiled = [(p, re.compile(p, re.IGNORECASE)) for p in FORBIDDEN_PATTERNS]
    violations: list[str] = []
    for path in _text_files():
        try:
            with open(path, "r", encoding="utf-8") as fh:
                text = fh.read()
        except (UnicodeDecodeError, OSError):
            continue  # binary or unreadable; nothing textual to leak
        for pattern, rx in compiled:
            if rx.search(text):
                rel = os.path.relpath(path, ROOT)
                violations.append(f"{rel}: matched /{pattern}/")
    assert not violations, "forbidden terms found:\n" + "\n".join(violations)
