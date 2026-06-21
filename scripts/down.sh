#!/usr/bin/env bash
# Tear down the stack. Pass --volumes to also delete data volumes.
#   ./scripts/down.sh            # stop containers, keep data
#   ./scripts/down.sh --volumes  # stop containers and wipe data
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "ERROR: docker compose is not installed." >&2
  exit 1
fi

if [ "${1:-}" = "--volumes" ]; then
  echo "Tearing down stack AND deleting data volumes."
  $COMPOSE down --volumes
else
  echo "Stopping stack (data volumes preserved). Use --volumes to wipe data."
  $COMPOSE down
fi
