#!/usr/bin/env bash
# One-command local bring-up.
#   ./scripts/up.sh
# Copies .env.example -> .env on first run, then starts the stack detached.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -f .env ]; then
  echo "No .env found - creating one from .env.example (edit it for real secrets)."
  cp .env.example .env
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "ERROR: docker compose is not installed." >&2
  exit 1
fi

echo "Starting stack with: $COMPOSE up -d --build"
$COMPOSE up -d --build

echo
echo "Stack is starting. Useful endpoints once healthy:"
echo "  API health     : http://localhost:\${API_PORT:-8000}/healthz"
echo "  API readiness  : http://localhost:\${API_PORT:-8000}/readyz"
echo "  MinIO console  : http://localhost:\${MINIO_CONSOLE_PORT:-9001}"
echo "  Postgres       : localhost:\${POSTGRES_PORT:-5432}"
echo
echo "Prove tenant isolation once healthy:"
echo "  ./scripts/rls_demo.sh   # tenant A cannot read or write tenant B's rows"
echo
echo "Check status: $COMPOSE ps"
