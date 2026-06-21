"""Object-storage adapter interface + an S3-compatible reference implementation.

The `ObjectStore` Protocol is the contract your application codes against. The
`S3ObjectStore` class is a complete, working implementation for any
S3-compatible backend (MinIO, AWS S3, Cloudflare R2, ...). Nothing here is
product-specific - it is the standard put/get/list surface for documents.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Protocol, runtime_checkable


@runtime_checkable
class ObjectStore(Protocol):
    """Minimal object-storage contract."""

    def put(self, key: str, data: bytes, *, content_type: str = "application/octet-stream") -> None:
        """Store ``data`` under ``key``."""
        ...

    def get(self, key: str) -> bytes:
        """Return the bytes stored under ``key``. Raise KeyError if absent."""
        ...

    def exists(self, key: str) -> bool:
        """Return True if an object exists under ``key``."""
        ...

    def list(self, prefix: str = "") -> Iterable[str]:
        """Yield keys under ``prefix``."""
        ...

    def url(self, key: str) -> str:
        """Return a stable address for ``key`` (not necessarily public)."""
        ...


@dataclass
class S3Config:
    endpoint_url: str
    bucket: str
    access_key: str
    secret_key: str
    region: str = "us-east-1"


class S3ObjectStore:
    """ObjectStore backed by any S3-compatible service via boto3.

    boto3 is imported lazily so this module stays importable (and testable
    against InMemoryObjectStore) without the dependency installed.
    """

    def __init__(self, config: S3Config) -> None:
        self._config = config
        self._client = None  # lazily created

    @property
    def client(self):  # noqa: ANN201 - boto3 client type is dynamic
        if self._client is None:
            import boto3  # local import keeps the module dependency-light

            self._client = boto3.client(
                "s3",
                endpoint_url=self._config.endpoint_url,
                aws_access_key_id=self._config.access_key,
                aws_secret_access_key=self._config.secret_key,
                region_name=self._config.region,
            )
        return self._client

    def put(self, key: str, data: bytes, *, content_type: str = "application/octet-stream") -> None:
        self.client.put_object(Bucket=self._config.bucket, Key=key, Body=data, ContentType=content_type)

    def get(self, key: str) -> bytes:
        try:
            resp = self.client.get_object(Bucket=self._config.bucket, Key=key)
        except self.client.exceptions.NoSuchKey as exc:  # pragma: no cover
            raise KeyError(key) from exc
        return resp["Body"].read()

    def exists(self, key: str) -> bool:
        try:
            self.client.head_object(Bucket=self._config.bucket, Key=key)
            return True
        except Exception:
            return False

    def list(self, prefix: str = "") -> Iterable[str]:
        paginator = self.client.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=self._config.bucket, Prefix=prefix):
            for obj in page.get("Contents", []):
                yield obj["Key"]

    def url(self, key: str) -> str:
        base = self._config.endpoint_url.rstrip("/")
        return f"{base}/{self._config.bucket}/{key}"


class InMemoryObjectStore:
    """Dependency-free ObjectStore for tests and local experimentation."""

    def __init__(self) -> None:
        self._data: dict[str, bytes] = {}

    def put(self, key: str, data: bytes, *, content_type: str = "application/octet-stream") -> None:
        self._data[key] = data

    def get(self, key: str) -> bytes:
        if key not in self._data:
            raise KeyError(key)
        return self._data[key]

    def exists(self, key: str) -> bool:
        return key in self._data

    def list(self, prefix: str = "") -> Iterable[str]:
        return [k for k in sorted(self._data) if k.startswith(prefix)]

    def url(self, key: str) -> str:
        return f"memory://{key}"
