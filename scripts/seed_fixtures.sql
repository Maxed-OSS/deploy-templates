-- ---------------------------------------------------------------------------
-- Synthetic demo fixtures (SAFE TO COMMIT - entirely made up).
-- ---------------------------------------------------------------------------
-- Loads two demo workspaces and a few notes so you can exercise the RLS
-- pattern end to end. Run after the stack is up:
--
--   docker compose exec -T db \
--     psql -U app -d workspace < scripts/seed_fixtures.sql
--
-- Then prove isolation (run as the app role):
--   SELECT set_config('app.workspace_id',
--     (SELECT id::text FROM workspaces WHERE name='Acme Demo Co'), false);
--   SELECT count(*) FROM notes;  -- only Acme's rows
-- ---------------------------------------------------------------------------

INSERT INTO workspaces (id, name) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Acme Demo Co'),
    ('22222222-2222-2222-2222-222222222222', 'Globex Sample LLC')
ON CONFLICT (id) DO NOTHING;

-- Notes are written with RLS active; set the workspace before each insert.
SELECT set_config('app.workspace_id', '11111111-1111-1111-1111-111111111111', false);
INSERT INTO notes (workspace_id, body) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Demo: Q1 close kickoff'),
    ('11111111-1111-1111-1111-111111111111', 'Demo: reconcile operating account');

SELECT set_config('app.workspace_id', '22222222-2222-2222-2222-222222222222', false);
INSERT INTO notes (workspace_id, body) VALUES
    ('22222222-2222-2222-2222-222222222222', 'Demo: onboard new vendor');
