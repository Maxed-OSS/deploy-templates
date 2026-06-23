# deploy-templates

A developer starter kit for multi-tenant backends: a one-command local stack
(Postgres + Redis + S3-compatible storage + API) where **tenant isolation is
enforced by the database, not by hopeful application code**, plus open adapter
interfaces, deployment starters, and a registry-ready Terraform module.

Point it at your own service and you start from a foundation that already has the
hard parts solved: provable row-level tenant isolation, a vendor-neutral object
store and double-entry export, and a path to production on managed cloud. A
scripted demo proves that tenant A literally cannot read tenant B's rows, even
when the query "forgets" to filter.

```bash
git clone https://github.com/maxed-oss/deploy-templates
cd deploy-templates
./scripts/up.sh                 # one command: Postgres + Redis + S3 (MinIO) + API
./scripts/rls_demo.sh           # prove tenant A cannot read tenant B
```

[![ci](https://github.com/maxed-oss/deploy-templates/actions/workflows/ci.yml/badge.svg)](https://github.com/maxed-oss/deploy-templates/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)

> **Demo:** `./scripts/rls_demo.sh` runs in ~10s. A recorded walkthrough lives at
> [`docs/demo.md`](./docs/demo.md) (asciinema cast + GIF placeholder; drop your
> own recording in and the README link just works).

---

## Why this exists

Most "multi-tenant" apps enforce isolation with a `WHERE tenant_id = ?` that some
engineer has to remember on **every single query**. Forget it once, in a report,
a migration, a background job, or an ORM `.all()`, and one tenant sees another's
data. That is the classic SaaS data-leak.

This starter does it the way you can defend in a security review: **Postgres Row
Level Security (RLS) with `FORCE` enabled**, keyed off a per-request session
variable. The database itself refuses to return rows that don't belong to the
active tenant. Fail-closed: if a request forgets to set its tenant, it sees
**zero** rows, not everyone's.

Everything else in the repo is the scaffolding around that core: a cache,
S3-compatible object storage, deploy starters, a registry-ready Terraform
module, and open adapter interfaces for a reproducible workspace foundation.

---

## The headline: one command + a provable isolation guarantee

### 1. Bring the stack up

```bash
./scripts/up.sh
```

Copies `.env.example` → `.env` on first run, then starts everything detached.
Once healthy:

| Service | URL / address |
|---|---|
| API liveness | http://localhost:8000/healthz |
| API readiness (reports each dependency) | http://localhost:8000/readyz |
| MinIO console | http://localhost:9001 |
| Postgres | `localhost:5432` (db `workspace`, app role `app`) |
| Redis | `localhost:6379` |

### 2. Prove the RLS isolation

```bash
./scripts/rls_demo.sh
```

This script loads **synthetic** fixtures (two made-up tenants, "Acme Demo Co" and
"Globex Sample LLC"), then runs a sequence of assertions as the non-superuser
`app` role:

- Scoped to Acme → sees **only** Acme's rows.
- Scoped to Globex → sees **only** Globex's rows.
- **No tenant set** → sees **zero** rows (fail-closed).
- Attempts to read another tenant by guessing its `workspace_id` → **blocked** by
  the policy, even with the id in hand.
- Attempts to *write* a row tagged with another tenant's id → **rejected** by the
  `WITH CHECK` clause.

The script exits non-zero if any guarantee fails, so it doubles as a regression
test (it runs in CI). See [`docs/demo.md`](./docs/demo.md) for a recorded run.

---

## What's in here

| Path | What it is |
|---|---|
| `docker-compose.yml` | One-command local stack: Postgres + Redis + MinIO + API placeholder. |
| `compose/postgres/initdb/` | First-boot scripts: a least-privilege app role + an **RLS-ready bootstrap** demonstrating row-scoped multi-tenancy. |
| `compose/api/` | A generic FastAPI placeholder that only proves the wiring (health of db/cache/storage). Replace it with your service. |
| `scripts/rls_demo.sh` | The **RLS isolation proof**: tenant A cannot read tenant B. Runs in CI. |
| `adapters/` | Open, vendor-neutral interfaces: an S3-compatible **object store** and a double-entry **accounting export**, each with a working reference implementation. |
| `terraform/` | A **registry-ready** module (versions, variables, outputs, a real example) for a managed Postgres + Redis + bucket deployment. |
| `starters/railway/` | Deploy the API to Railway with managed Postgres/Redis. |
| `starters/vercel/` | Host a front-end on Vercel that proxies `/api/*` to your backend. |
| `scripts/` | `up.sh`, `down.sh`, `rls_demo.sh`, `validate.sh`, YAML lint, synthetic seed data. |
| `tests/` | Pytest suite (adapters + repo integrity + a public-safety gate). |

---

## How RLS multi-tenancy works here

Multi-tenancy is enforced in the database, not just the application:

1. The app connects as the **non-superuser** `app` role.
2. At the start of each request/transaction it sets the active workspace:
   `SELECT set_config('app.workspace_id', '<uuid>', true);`
3. Every tenant-scoped table has a policy: `workspace_id = current_workspace_id()`,
   with `WITH CHECK` so writes can't be mis-tagged.
4. If the variable is unset, `current_workspace_id()` returns `NULL` and the policy
   matches nothing: **fail-closed**.
5. `FORCE ROW LEVEL SECURITY` is enabled so even the table owner is filtered.

The bootstrap ships a generic `workspaces` table and an example `notes` table so
the pattern is runnable and testable out of the box. Replace `notes` with your own
tables and copy the policy shape; see
[`compose/postgres/initdb/10-rls-bootstrap.sql`](./compose/postgres/initdb/10-rls-bootstrap.sql).

---

## Install / prerequisites

- **Docker** with the Compose plugin (`docker compose`) for the local stack.
- **Python 3.10+** to run the tests and the YAML-lint fallback.
- **Terraform 1.3+** (optional) for the module example.

```bash
git clone https://github.com/maxed-oss/deploy-templates
cd deploy-templates
cp .env.example .env        # edit secrets before using beyond your laptop
```

Validate the compose config at any time:

```bash
./scripts/validate.sh        # docker compose config, or YAML lint if Docker is absent
```

Tear down:

```bash
./scripts/down.sh            # keep data
./scripts/down.sh --volumes  # wipe data
```

---

## How the open adapters slot in

Your application codes against the interfaces in [`adapters/`](./adapters), not
against a specific vendor.

```python
from adapters.storage import ObjectStore, S3ObjectStore, S3Config

def save_receipt(store: ObjectStore, key: str, pdf: bytes) -> str:
    store.put(key, pdf, content_type="application/pdf")
    return store.url(key)

# Local (MinIO) or production (S3/R2) - same call site:
store = S3ObjectStore(S3Config(
    endpoint_url="http://localhost:9000",
    bucket="workspace-documents",
    access_key="minioadmin",
    secret_key="minioadmin",
))
```

```python
from datetime import date
from decimal import Decimal
from adapters.accounting_export import (
    CsvLedgerExporter, JournalEntry, JournalLine,
)

entry = JournalEntry(
    entry_date=date(2026, 1, 31),
    description="Record consulting revenue",
    lines=(
        JournalLine(account_code="1000", debit=Decimal("500.00")),
        JournalLine(account_code="4000", credit=Decimal("500.00")),
    ),
)
print(CsvLedgerExporter().export_entries([entry]))
```

Swap `CsvLedgerExporter` for an implementation that targets QuickBooks, Xero,
ERPNext, or a Postgres table - the call site stays the same.

---

## Deploying

- **Railway** (`starters/railway/`): build the API image, attach managed
  Postgres + Redis, point storage env vars at any S3-compatible bucket.
- **Vercel** (`starters/vercel/`): serve a front-end and rewrite `/api/*` to your
  backend host.
- **Terraform** (`terraform/`): a registry-ready module shaped for a real cloud
  provider; the example plans with zero credentials.

See each directory's README for steps.

---

## Tests

```bash
pip install -r requirements-dev.txt
pytest
```

The suite covers the adapters, validates the compose/Terraform/JSON configs, and
includes a **public-safety gate** that fails if any proprietary or secret content
ever lands in the repo.

---

## Scope

This is a foundation for **your** application to build on: the multi-tenant data
layer, storage and accounting interfaces, and deployment plumbing that most
backends need and few enjoy writing. It deliberately ships no application
business logic and no real customer data (only synthetic fixtures) so you can
adopt the pieces you want and own everything above them.

---

## License

[Apache-2.0](./LICENSE).
