"""Tests for the object-storage adapter (InMemory reference + Protocol)."""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from adapters.storage import InMemoryObjectStore, ObjectStore, S3Config, S3ObjectStore


def test_inmemory_put_get_roundtrip():
    store = InMemoryObjectStore()
    store.put("docs/a.txt", b"hello", content_type="text/plain")
    assert store.get("docs/a.txt") == b"hello"


def test_inmemory_exists():
    store = InMemoryObjectStore()
    assert not store.exists("missing")
    store.put("present", b"x")
    assert store.exists("present")


def test_inmemory_get_missing_raises_keyerror():
    store = InMemoryObjectStore()
    try:
        store.get("nope")
    except KeyError:
        pass
    else:  # pragma: no cover
        raise AssertionError("expected KeyError")


def test_inmemory_list_prefix_sorted():
    store = InMemoryObjectStore()
    store.put("a/2", b"")
    store.put("a/1", b"")
    store.put("b/1", b"")
    assert list(store.list("a/")) == ["a/1", "a/2"]


def test_inmemory_url():
    store = InMemoryObjectStore()
    assert store.url("k") == "memory://k"


def test_inmemory_satisfies_protocol():
    # runtime_checkable Protocol: the reference impl must satisfy it.
    assert isinstance(InMemoryObjectStore(), ObjectStore)


def test_s3_store_satisfies_protocol_without_boto3_import():
    # Constructing S3ObjectStore must not require boto3 (lazy import).
    store = S3ObjectStore(
        S3Config(
            endpoint_url="http://localhost:9000",
            bucket="b",
            access_key="k",
            secret_key="s",
        )
    )
    assert isinstance(store, ObjectStore)
    assert store.url("file.pdf") == "http://localhost:9000/b/file.pdf"
