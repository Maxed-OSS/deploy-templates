# Architecture

A one-page tour of how the pieces fit together.

```
                       +-------------------+
                       |   Front-end       |   (Vercel starter, optional)
                       |   /api/* -> API   |
                       +---------+---------+
                                 |
                                 v
+--------------------------------------------------------------+
|                          API service                         |
|   (compose/api: generic placeholder you replace)             |
|                                                              |
|   reads config from env: DATABASE_URL, REDIS_URL,            |
|   S3_ENDPOINT_URL, S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY   |
+------+------------------+------------------------+-----------+
       |                  |                        |
       v                  v                        v
+-------------+    +--------------+        +------------------+
|  Postgres   |    |   Redis      |        |  MinIO (S3 API)  |
|  + RLS      |    |  cache/queue |        |  object storage  |
+-------------+    +--------------+        +------------------+
```

## Components

- **Postgres** is the system of record. On first boot, the scripts in
  `compose/postgres/initdb/` create a least-privilege `app` role and install an
  RLS-ready bootstrap (`workspaces` + an example `notes` table with a Row Level
  Security policy keyed off the `app.workspace_id` session variable).

- **Redis** is the cache and queue substrate. Nothing here depends on a specific
  queue library; point your worker at `REDIS_URL`.

- **MinIO** provides the S3 API locally. The `storage-init` job creates the
  default bucket on startup. In production, swap MinIO for AWS S3 / R2 / GCS-S3
  by changing only the storage env vars.

- **API placeholder** is a generic FastAPI app that proves the wiring. It exposes
  `/healthz` (liveness) and `/readyz` (checks each dependency). Replace it.

## The RLS contract

Multi-tenancy is enforced in the database, not just the application:

1. The app connects as the non-superuser `app` role.
2. At the start of each request/transaction it sets the active workspace:
   `SELECT set_config('app.workspace_id', '<uuid>', true);`
3. Every tenant-scoped table has a policy: `workspace_id = current_workspace_id()`.
4. If the variable is unset, `current_workspace_id()` returns NULL and the policy
   matches nothing - fail-closed.

`FORCE ROW LEVEL SECURITY` is enabled so even the table owner is filtered.

## The adapter boundary

The application never imports a cloud SDK directly. It depends on the
`Protocol`s in `adapters/`:

- `ObjectStore` - put/get/list/url for documents (S3ObjectStore reference impl).
- `LedgerExporter` - emit standard double-entry records (CsvLedgerExporter
  reference impl).

This keeps vendor choices at the edges and the core code portable.

## What is intentionally out of scope

This repo is infrastructure glue. It contains no product features, no
proprietary schema, no AI/ML pipeline, and no real data - only synthetic
fixtures. Everything domain-specific lives in your own application that runs on
top of this foundation.
