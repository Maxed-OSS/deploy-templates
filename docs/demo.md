# Demo: proving RLS tenant isolation

The headline guarantee of this starter is that **tenant A cannot read or write
tenant B's rows** — and that it's enforced by Postgres, not by application code
that has to remember a `WHERE` clause.

## Run it yourself (~10s)

```bash
./scripts/up.sh          # bring up Postgres + Redis + MinIO + API
./scripts/rls_demo.sh    # load synthetic fixtures and assert isolation
```

Expected output:

```
==> Loading synthetic demo fixtures (made-up data only)...
    fixtures loaded.

==> Running RLS isolation assertions as role 'app' (non-superuser)...
  PASS  Acme sees only Acme rows  (got: 2)
  PASS  Globex sees only Globex rows  (got: 1)
  PASS  No tenant set -> zero rows (fail-closed)  (got: 0)
  PASS  Acme cannot read Globex rows by id  (got: 0)
  PASS  Acme cannot write a Globex-tagged row  (got: rejected)

==> Result: 5 passed, 0 failed.
All RLS isolation guarantees hold: tenant A cannot read or write tenant B's rows.
```

The script exits non-zero if any guarantee fails, so it runs in CI as a
regression test.

## Recorded walkthrough

> **Placeholder — drop your own recording in here.**

A recorded run makes the guarantee tangible for readers who haven't cloned the
repo yet. Two common options:

### asciinema (terminal cast)

```bash
# record:
asciinema rec docs/rls_demo.cast -c "./scripts/rls_demo.sh"
# then upload and embed, or link the local cast:
```

[![asciicast](https://asciinema.org/a/REPLACE_WITH_CAST_ID.svg)](https://asciinema.org/a/REPLACE_WITH_CAST_ID)

### Animated GIF

Record the terminal (e.g. with [`vhs`](https://github.com/charmbracelet/vhs) or
[`asciinema` + `agg`](https://github.com/asciinema/agg)) and commit the result:

```
docs/rls_demo.gif
```

then reference it here:

```markdown
![RLS isolation demo](./rls_demo.gif)
```

Until a recording is committed, the script output above is the source of truth.

## What each assertion proves

| Assertion | Why it matters |
|---|---|
| Scoped to a tenant sees only its rows | The everyday read path is isolated. |
| No tenant set sees zero rows | **Fail-closed**: a forgotten scope leaks nothing, vs. the usual fail-open `WHERE tenant_id = ?`. |
| Cross-tenant read blocked by id | An attacker who knows another tenant's id still can't read it. |
| Cross-tenant write rejected | `WITH CHECK` stops rows being mis-tagged into another tenant. |

The policy and bootstrap live in
[`compose/postgres/initdb/10-rls-bootstrap.sql`](../compose/postgres/initdb/10-rls-bootstrap.sql).
