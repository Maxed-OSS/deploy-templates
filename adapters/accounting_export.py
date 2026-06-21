"""Vendor-neutral accounting-export adapter.

Defines a tiny, standard double-entry record shape (chart-of-accounts entries
and balanced journal entries) plus a `LedgerExporter` interface and a complete
CSV reference implementation. This is the ordinary general-ledger shape used by
every accounting system; it lets an application target QuickBooks, Xero,
ERPNext, a CSV, or a Postgres table behind one stable contract.

There is nothing proprietary here: it is the commodity export format.
"""
from __future__ import annotations

import csv
import io
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal
from typing import Protocol, Sequence, runtime_checkable


@dataclass(frozen=True)
class Account:
    """A chart-of-accounts entry."""

    code: str            # e.g. "1000"
    name: str            # e.g. "Cash"
    type: str            # asset | liability | equity | revenue | expense


@dataclass(frozen=True)
class JournalLine:
    """One side of a journal entry. Exactly one of debit/credit is non-zero."""

    account_code: str
    debit: Decimal = Decimal("0")
    credit: Decimal = Decimal("0")
    memo: str = ""


@dataclass(frozen=True)
class JournalEntry:
    """A balanced double-entry transaction."""

    entry_date: date
    description: str
    lines: Sequence[JournalLine] = field(default_factory=tuple)

    def is_balanced(self) -> bool:
        debits = sum((ln.debit for ln in self.lines), Decimal("0"))
        credits = sum((ln.credit for ln in self.lines), Decimal("0"))
        return debits == credits

    def validate(self) -> None:
        if not self.lines:
            raise ValueError("journal entry has no lines")
        for ln in self.lines:
            if ln.debit < 0 or ln.credit < 0:
                raise ValueError("debit/credit amounts must be non-negative")
            if ln.debit > 0 and ln.credit > 0:
                raise ValueError("a line cannot be both a debit and a credit")
            if ln.debit == 0 and ln.credit == 0:
                raise ValueError("a line must have a non-zero debit or credit")
        if not self.is_balanced():
            raise ValueError("journal entry does not balance (debits != credits)")


@runtime_checkable
class LedgerExporter(Protocol):
    """Contract for emitting accounting records to an external destination."""

    def export_accounts(self, accounts: Sequence[Account]) -> str:
        """Persist/emit the chart of accounts; return a destination reference."""
        ...

    def export_entries(self, entries: Sequence[JournalEntry]) -> str:
        """Persist/emit journal entries; return a destination reference."""
        ...


class CsvLedgerExporter:
    """Reference LedgerExporter that renders records to CSV strings.

    Useful on its own (import into any tool that reads CSV) and as a template
    for writing exporters that target a real accounting API.
    """

    def export_accounts(self, accounts: Sequence[Account]) -> str:
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["code", "name", "type"])
        for acc in accounts:
            writer.writerow([acc.code, acc.name, acc.type])
        return buf.getvalue()

    def export_entries(self, entries: Sequence[JournalEntry]) -> str:
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["date", "description", "account_code", "debit", "credit", "memo"])
        for entry in entries:
            entry.validate()
            for ln in entry.lines:
                writer.writerow(
                    [
                        entry.entry_date.isoformat(),
                        entry.description,
                        ln.account_code,
                        f"{ln.debit:.2f}",
                        f"{ln.credit:.2f}",
                        ln.memo,
                    ]
                )
        return buf.getvalue()
