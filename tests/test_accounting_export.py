"""Tests for the vendor-neutral accounting-export adapter."""
from __future__ import annotations

import os
import sys
from datetime import date
from decimal import Decimal

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from adapters.accounting_export import (
    Account,
    CsvLedgerExporter,
    JournalEntry,
    JournalLine,
    LedgerExporter,
)


def _balanced_entry() -> JournalEntry:
    return JournalEntry(
        entry_date=date(2026, 1, 31),
        description="Record consulting revenue",
        lines=(
            JournalLine(account_code="1000", debit=Decimal("500.00"), memo="cash in"),
            JournalLine(account_code="4000", credit=Decimal("500.00"), memo="revenue"),
        ),
    )


def test_balanced_entry_validates():
    _balanced_entry().validate()  # should not raise


def test_unbalanced_entry_rejected():
    entry = JournalEntry(
        entry_date=date(2026, 1, 31),
        description="bad",
        lines=(
            JournalLine(account_code="1000", debit=Decimal("100")),
            JournalLine(account_code="4000", credit=Decimal("90")),
        ),
    )
    assert not entry.is_balanced()
    with pytest.raises(ValueError):
        entry.validate()


def test_line_cannot_be_debit_and_credit():
    entry = JournalEntry(
        entry_date=date(2026, 1, 31),
        description="bad",
        lines=(JournalLine(account_code="1000", debit=Decimal("10"), credit=Decimal("10")),),
    )
    with pytest.raises(ValueError):
        entry.validate()


def test_empty_entry_rejected():
    with pytest.raises(ValueError):
        JournalEntry(entry_date=date(2026, 1, 1), description="x", lines=()).validate()


def test_csv_exporter_accounts():
    exporter = CsvLedgerExporter()
    csv_out = exporter.export_accounts(
        [Account(code="1000", name="Cash", type="asset"), Account(code="4000", name="Revenue", type="revenue")]
    )
    lines = csv_out.strip().splitlines()
    assert lines[0] == "code,name,type"
    assert lines[1] == "1000,Cash,asset"
    assert lines[2] == "4000,Revenue,revenue"


def test_csv_exporter_entries():
    exporter = CsvLedgerExporter()
    csv_out = exporter.export_entries([_balanced_entry()])
    lines = csv_out.strip().splitlines()
    assert lines[0] == "date,description,account_code,debit,credit,memo"
    assert "2026-01-31,Record consulting revenue,1000,500.00,0.00,cash in" in csv_out
    assert "2026-01-31,Record consulting revenue,4000,0.00,500.00,revenue" in csv_out


def test_csv_exporter_rejects_unbalanced_on_export():
    exporter = CsvLedgerExporter()
    bad = JournalEntry(
        entry_date=date(2026, 1, 1),
        description="bad",
        lines=(JournalLine(account_code="1000", debit=Decimal("1")),),
    )
    with pytest.raises(ValueError):
        exporter.export_entries([bad])


def test_csv_exporter_satisfies_protocol():
    assert isinstance(CsvLedgerExporter(), LedgerExporter)
