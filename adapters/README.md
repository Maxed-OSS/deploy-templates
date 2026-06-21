# Adapters

These are **open interface contracts** (the "glue") for slotting your own
implementations into a workspace built on this stack. They are deliberately
small, dependency-light, and protocol-shaped - define the interface here, ship
your concrete implementation in your own application.

Two adapters are provided:

| Adapter | File | What it abstracts |
|---|---|---|
| Object storage | [`storage.py`](./storage.py) | Put/get/list documents on any S3-compatible store (MinIO, AWS S3, R2, GCS-S3). |
| Accounting export | [`accounting_export.py`](./accounting_export.py) | Emit standard accounting records (accounts, journal entries) to an external system or file in a vendor-neutral shape. |

## Why interfaces, not implementations?

Self-hosting means swapping pieces. By coding against these `Protocol`s your
application never hardcodes a vendor:

```python
from adapters.storage import ObjectStore

def save_receipt(store: ObjectStore, key: str, data: bytes) -> str:
    store.put(key, data, content_type="application/pdf")
    return store.url(key)
```

Pass a MinIO-backed store locally and an AWS-S3-backed store in production -
`save_receipt` doesn't change.

## The accounting export shape

`accounting_export.py` defines a neutral record format (a tiny chart-of-accounts
entry and a balanced journal entry with debit/credit lines). It is the same
double-entry shape every general ledger uses, so you can target QuickBooks,
Xero, ERPNext, a CSV, or a plain Postgres table behind one interface. The
included `CsvLedgerExporter` is a complete, working reference implementation.
