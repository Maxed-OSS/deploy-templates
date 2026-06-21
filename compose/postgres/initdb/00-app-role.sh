#!/bin/sh
# Creates a least-privilege application role used by the API service.
#
# Run automatically by the postgres image on first boot (empty data dir).
# Credentials come from APP_DB_USER / APP_DB_PASSWORD env vars set in
# docker-compose.yml. This role is intentionally NOT a superuser - your
# application connects as this role so Row Level Security policies apply.
set -eu

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${APP_DB_USER}') THEN
    CREATE ROLE ${APP_DB_USER} LOGIN PASSWORD '${APP_DB_PASSWORD}';
  END IF;
END
\$\$;

GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${APP_DB_USER};
GRANT USAGE ON SCHEMA public TO ${APP_DB_USER};
-- Future tables created in this schema are usable by the app role.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO ${APP_DB_USER};

-- Make the app role name available to the SQL bootstrap that runs next, so
-- its grants target the correct role without hardcoding it.
ALTER DATABASE ${POSTGRES_DB} SET app.bootstrap_app_role = '${APP_DB_USER}';
SQL

echo "app role '${APP_DB_USER}' ready"
