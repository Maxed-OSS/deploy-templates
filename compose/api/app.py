"""Generic API placeholder for the deploy-templates stack.

This is intentionally NOT a product. It is the smallest possible service that
proves the surrounding infrastructure is wired correctly: it connects to
Postgres, Redis, and the S3-compatible object store and reports their health.

Replace this file (and the Dockerfile next to it) with your own application.
The only contracts the compose file relies on are:
  * the service listens on $APP_PORT (default 8000)
  * GET /healthz returns 200 when the app is up

Configuration is read entirely from environment variables (12-factor):
  DATABASE_URL, REDIS_URL, S3_ENDPOINT_URL, S3_BUCKET, S3_ACCESS_KEY,
  S3_SECRET_KEY, APP_PORT
"""
from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(
    title="deploy-templates API placeholder",
    description="Infra wiring check only. Replace with your own service.",
    version="0.1.0",
)


def _check_postgres() -> tuple[bool, str]:
    url = os.environ.get("DATABASE_URL")
    if not url:
        return False, "DATABASE_URL not set"
    try:
        import psycopg

        with psycopg.connect(url, connect_timeout=3) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return True, "ok"
    except Exception as exc:  # pragma: no cover - infra-dependent
        return False, f"{type(exc).__name__}: {exc}"


def _check_redis() -> tuple[bool, str]:
    url = os.environ.get("REDIS_URL")
    if not url:
        return False, "REDIS_URL not set"
    try:
        import redis

        client = redis.Redis.from_url(url, socket_connect_timeout=3)
        client.ping()
        return True, "ok"
    except Exception as exc:  # pragma: no cover - infra-dependent
        return False, f"{type(exc).__name__}: {exc}"


def _check_storage() -> tuple[bool, str]:
    endpoint = os.environ.get("S3_ENDPOINT_URL")
    bucket = os.environ.get("S3_BUCKET")
    if not endpoint or not bucket:
        return False, "S3_ENDPOINT_URL / S3_BUCKET not set"
    try:
        import boto3
        from botocore.config import Config

        client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=os.environ.get("S3_ACCESS_KEY"),
            aws_secret_access_key=os.environ.get("S3_SECRET_KEY"),
            config=Config(connect_timeout=3, retries={"max_attempts": 1}),
        )
        client.head_bucket(Bucket=bucket)
        return True, "ok"
    except Exception as exc:  # pragma: no cover - infra-dependent
        return False, f"{type(exc).__name__}: {exc}"


@app.get("/healthz")
def healthz() -> dict[str, str]:
    """Liveness: the process is up. Used by the container healthcheck."""
    return {"status": "ok"}


@app.get("/readyz")
def readyz() -> JSONResponse:
    """Readiness: dependencies are reachable. Reports each component."""
    checks = {
        "postgres": _check_postgres(),
        "redis": _check_redis(),
        "storage": _check_storage(),
    }
    components = {name: {"ok": ok, "detail": detail} for name, (ok, detail) in checks.items()}
    all_ok = all(ok for ok, _ in checks.values())
    return JSONResponse(
        status_code=200 if all_ok else 503,
        content={"ready": all_ok, "components": components},
    )


@app.get("/")
def root() -> dict[str, object]:
    return {
        "service": "deploy-templates API placeholder",
        "note": "Replace this with your own application.",
        "endpoints": ["/healthz", "/readyz"],
    }
