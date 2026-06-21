#!/usr/bin/env bash
# Validate the compose config. Uses `docker compose config` when Docker is
# available; otherwise falls back to a YAML-parse lint via Python (PyYAML).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Ensure variable interpolation has values; .env.example provides safe defaults.
ENV_FILE=".env"
[ -f "$ENV_FILE" ] || ENV_FILE=".env.example"

if docker compose version >/dev/null 2>&1; then
  echo "Validating with: docker compose config"
  docker compose --env-file "$ENV_FILE" config >/dev/null
  echo "OK: docker compose config is valid."
elif command -v docker-compose >/dev/null 2>&1; then
  echo "Validating with: docker-compose config"
  docker-compose --env-file "$ENV_FILE" config >/dev/null
  echo "OK: docker-compose config is valid."
else
  echo "Docker not available - falling back to YAML lint (PyYAML)."
  python3 scripts/lint_yaml.py docker-compose.yml
  echo "OK: YAML parses."
fi
