#!/usr/bin/env bash
# ===========================================================================
# RLS isolation proof: tenant A cannot read (or write) tenant B's rows.
# ===========================================================================
# Loads the SYNTHETIC demo fixtures (two made-up tenants) and then runs a
# sequence of assertions AS THE NON-SUPERUSER `app` role to demonstrate that
# Postgres Row Level Security enforces tenant isolation in the database:
#
#   * scoped to a tenant  -> sees ONLY that tenant's rows
#   * no tenant set        -> sees ZERO rows (fail-closed)
#   * cross-tenant read    -> blocked even when you know the other id
#   * cross-tenant write   -> rejected by the WITH CHECK clause
#
# Exit code is non-zero if ANY guarantee fails, so this doubles as a
# regression test and runs in CI.
#
#   ./scripts/rls_demo.sh
# ===========================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# --- pick the compose command ----------------------------------------------
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "ERROR: docker compose is not installed; cannot run the live RLS demo." >&2
  echo "Bring the stack up first with ./scripts/up.sh" >&2
  exit 1
fi

APP_DB_USER="${APP_DB_USER:-app}"
POSTGRES_DB="${POSTGRES_DB:-workspace}"

ACME="11111111-1111-1111-1111-111111111111"
GLOBEX="22222222-2222-2222-2222-222222222222"

# psql helper: run SQL as the non-superuser app role, quiet, tuples-only.
psql_app() {
  $COMPOSE exec -T db psql -v ON_ERROR_STOP=1 -qtA \
    -U "$APP_DB_USER" -d "$POSTGRES_DB" -c "$1"
}

pass=0
fail=0
check() {
  # check "<label>" "<actual>" "<expected>"
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS  $label  (got: $actual)"
    pass=$((pass + 1))
  else
    echo "  FAIL  $label  (expected: $expected, got: $actual)" >&2
    fail=$((fail + 1))
  fi
}

echo "==> Loading synthetic demo fixtures (made-up data only)..."
$COMPOSE exec -T db psql -v ON_ERROR_STOP=1 -q \
  -U "$APP_DB_USER" -d "$POSTGRES_DB" < scripts/seed_fixtures.sql >/dev/null
echo "    fixtures loaded."
echo

echo "==> Running RLS isolation assertions as role '$APP_DB_USER' (non-superuser)..."

# 1) Scoped to Acme: sees only Acme's notes (2 rows in the fixtures).
acme_count=$(psql_app \
  "SELECT set_config('app.workspace_id','$ACME',false); SELECT count(*) FROM notes;" \
  | tail -n1)
check "Acme sees only Acme rows" "$acme_count" "2"

# 2) Scoped to Globex: sees only Globex's notes (1 row in the fixtures).
globex_count=$(psql_app \
  "SELECT set_config('app.workspace_id','$GLOBEX',false); SELECT count(*) FROM notes;" \
  | tail -n1)
check "Globex sees only Globex rows" "$globex_count" "1"

# 3) Fail-closed: no tenant set -> zero rows visible.
unset_count=$(psql_app \
  "SELECT set_config('app.workspace_id','',false); SELECT count(*) FROM notes;" \
  | tail -n1)
check "No tenant set -> zero rows (fail-closed)" "$unset_count" "0"

# 4) Cross-tenant read blocked: scoped to Acme, explicitly filter for Globex's
#    workspace_id. Even though we know the id, the policy hides those rows.
cross_read=$(psql_app \
  "SELECT set_config('app.workspace_id','$ACME',false); SELECT count(*) FROM notes WHERE workspace_id='$GLOBEX';" \
  | tail -n1)
check "Acme cannot read Globex rows by id" "$cross_read" "0"

# 5) Cross-tenant write rejected: scoped to Acme, try to INSERT a row tagged
#    as Globex. The WITH CHECK clause must reject it.
if psql_app \
  "SELECT set_config('app.workspace_id','$ACME',false); INSERT INTO notes (workspace_id, body) VALUES ('$GLOBEX','cross-tenant write attempt');" \
  >/dev/null 2>&1; then
  cross_write="allowed"
else
  cross_write="rejected"
fi
check "Acme cannot write a Globex-tagged row" "$cross_write" "rejected"

echo
echo "==> Result: $pass passed, $fail failed."
if [ "$fail" -ne 0 ]; then
  echo "RLS isolation is NOT holding. See failures above." >&2
  exit 1
fi
echo "All RLS isolation guarantees hold: tenant A cannot read or write tenant B's rows."
