# deploy-templates

Infrastructure scaffolding to **self-host a compatible accounting workspace**.

This repository is the *commodity infrastructure* you stand up around an
accounting application: a local Docker stack (Postgres, Redis, S3-compatible
object storage, and a generic API placeholder), a provider-agnostic Terraform
module skeleton, Railway/Vercel deployment starters, environment templates, and
a small set of open adapter interfaces (the "glue") for storage and accounting
export.

It is **not** a product and contains no business logic. It gives you a clean,
reproducible foundation so you can drop your own application on top.

---

## What's in here

| Path | What it is |
|---|---|
| `docker-compose.yml` | One-command local stack: Postgres + Redis + MinIO + API placeholder. |
| `compose/postgres/initdb/` | First-boot scripts: a least-privilege app role + an **RLS-ready bootstrap** demonstrating row-scoped multi-tenancy. |
| `compose/api/` | A generic FastAPI placeholder that only proves the wiring (health of db/cache/storage). Replace it with your service. |
| `adapters/` | Open, vendor-neutral interfaces: an S3-compatible **object store** and a double-entry **accounting export**, each with a working reference implementation. |
| `terraform/` | A provider-agnostic **module skeleton** (Postgres + Redis + bucket) plus a runnable example that plans with no cloud credentials. |
| `starters/railway/` | Deploy the API to Railway with managed Postgres/Redis. |
| `starters/vercel/` | Host a front-end on Vercel that proxies `/api/*` to your backend. |
| `scripts/` | `up.sh`, `down.sh`, `validate.sh`, YAML lint, synthetic seed data. |
| `tests/` | Pytest suite (adapters + repo integrity + a public-safety gate). |

---

## Why

Self-hosting an accounting workspace means assembling the same boring pieces
every time: a relational database with tenant isolation, a cache, somewhere to
put documents, and a way to ship records to other accounting systems. This repo
makes those pieces reproducible and swappable:

- **Postgres with RLS from day one** - the included bootstrap shows the standard
  session-variable + Row Level Security pattern so every row is scoped to a
  workspace, fail-closed.
- **S3-compatible storage** - code against the `ObjectStore` interface and run
  MinIO locally, AWS S3 / R2 in production, with no code change.
- **Vendor-neutral accounting export** - emit standard double-entry records to a
  CSV, a database, or any accounting API behind one `LedgerExporter` interface.

---

## Install / prerequisites

- **Docker** with the Compose plugin (`docker compose`) for the local stack.
- **Python 3.10+** to run the tests and the YAML-lint fallback.
- **Terraform 1.3+** (optional) for the module example.

```bash
git clone <your-fork-url> deploy-templates
cd deploy-templates
cp .env.example .env        # edit secrets before using beyond your laptop
```

---

## Usage: one-command local bring-up

```bash
./scripts/up.sh
```

This copies `.env.example` to `.env` (first run only) and starts the stack
detached. Once healthy:

| Service | URL / address |
|---|---|
| API liveness | http://localhost:8000/healthz |
| API readiness (reports each dependency) | http://localhost:8000/readyz |
| MinIO console | http://localhost:9001 |
| Postgres | `localhost:5432` (db `workspace`, app role `app`) |
| Redis | `localhost:6379` |

Validate the compose config at any time:

```bash
./scripts/validate.sh        # docker compose config, or YAML lint if Docker is absent
```

Tear down:

```bash
./scripts/down.sh            # keep data
./scripts/down.sh --volumes  # wipe data
```

### Example: prove the RLS isolation

Load the **synthetic** demo fixtures (entirely made-up data), then confirm a
request only ever sees its own workspace's rows:

```bash
docker compose exec -T db psql -U app -d workspace < scripts/seed_fixtures.sql

docker compose exec -T db psql -U app -d workspace -c \
  "SELECT set_config('app.workspace_id',
       (SELECT id::text FROM workspaces WHERE name='Acme Demo Co'), false);
   SELECT count(*) AS visible_rows FROM notes;"
# -> only Acme's notes are visible; Globex's rows are filtered out by the policy.
```

---

## How the open adapters / spec slot in

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
- **Terraform** (`terraform/`): a module skeleton shaped for a real cloud
  provider; the example plans with zero credentials.

See each directory's README for steps.

---

## Tests

```bash
pip install -r requirements-dev.txt
pytest
```

The suite covers the adapters, validates the compose/Terraform/JSON configs, and
includes a **public-safety gate** that fails if any proprietary or secret
content ever lands in the repo.

---

## Scope (what this repo deliberately is not)

This is open **infrastructure glue only**. It intentionally contains no product
business logic, no proprietary application schema, no AI/ML pipeline, and no real
customer data - only synthetic fixtures. Build your application on top of it.

---

## License

[Apache-2.0](./LICENSE).
