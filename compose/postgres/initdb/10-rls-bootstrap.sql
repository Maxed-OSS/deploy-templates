-- ---------------------------------------------------------------------------
-- RLS-ready bootstrap (generic demonstration)
-- ---------------------------------------------------------------------------
-- This file shows ONE common, well-documented Postgres pattern for building a
-- row-scoped multi-tenant application: a per-request session variable plus a
-- Row Level Security policy that filters every row to the active workspace.
--
-- It ships a deliberately generic `workspaces` table and a single example
-- `notes` table so the pattern is runnable and testable out of the box. There
-- is no application schema here - replace `notes` with your own tables and
-- copy the policy shape.
--
-- The contract your application code must honor:
--   At the start of each request/transaction, set the active workspace:
--       SELECT set_config('app.workspace_id', '<uuid>', true);
--   Then every query the app role runs only sees rows for that workspace.
-- ---------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

-- A workspace is the tenancy boundary (a firm, an org, a team - your call).
CREATE TABLE IF NOT EXISTS workspaces (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Example tenant-scoped table. Every row carries its workspace_id.
CREATE TABLE IF NOT EXISTS notes (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    body          text NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notes_workspace_id_idx ON notes (workspace_id);

-- Helper: read the active workspace from the session variable. Returns NULL
-- when unset (so a request that forgets to scope sees zero rows, fail-closed).
CREATE OR REPLACE FUNCTION current_workspace_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('app.workspace_id', true), '')::uuid;
$$;

-- Enable Row Level Security and FORCE it so even the table owner is filtered.
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes FORCE ROW LEVEL SECURITY;

-- One policy: a row is visible/writable only when it belongs to the active
-- workspace. USING covers reads/updates/deletes; WITH CHECK covers writes.
DROP POLICY IF EXISTS notes_workspace_isolation ON notes;
CREATE POLICY notes_workspace_isolation ON notes
    USING (workspace_id = current_workspace_id())
    WITH CHECK (workspace_id = current_workspace_id());

-- Grant the example table to the app role (default privileges cover future
-- tables, but this file runs in the same init pass so grant explicitly).
DO $$
DECLARE
    app_role text := current_setting('app.bootstrap_app_role', true);
BEGIN
    -- APP_DB_USER is exported by the init shell; fall back to 'app'.
    IF app_role IS NULL OR app_role = '' THEN
        app_role := 'app';
    END IF;
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON workspaces TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON notes TO %I', app_role);
END $$;
