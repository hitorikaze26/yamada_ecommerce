#!/usr/bin/env python3
"""Verify production environment variables and API health (Phase 0 checklist).

Usage:
  cd server
  set FLASK_APP=app:create_app
  python scripts/verify_production_env.py

Optional:
  set API_BASE_URL=https://your-api.up.railway.app
  set CORS_ORIGIN=https://your-app.vercel.app
  python scripts/verify_production_env.py
"""

from __future__ import annotations

import os
import re
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse, urlunparse

REQUIRED_PROD = (
    "FLASK_ENV",
    "DATABASE_URL",
    "SECRET_KEY",
    "JWT_SECRET_KEY",
)
RECOMMENDED_PROD = (
    "CORS_ORIGINS",
    "MAIL_BACKEND",
    "MAIL_USERNAME",
    "MAIL_PASSWORD",
    "SUPABASE_URL",
    "SUPABASE_SERVICE_KEY",
)


def _check_env() -> list[str]:
    errors: list[str] = []
    env = os.environ.get("FLASK_ENV", "development")
    print(f"FLASK_ENV={env}")

    if env == "production":
        for key in REQUIRED_PROD:
            if not os.environ.get(key):
                errors.append(f"Missing required: {key}")
        for key in RECOMMENDED_PROD:
            if not os.environ.get(key):
                print(f"  WARN: recommended not set: {key}")

        db_url = os.environ.get("DATABASE_URL", "")
        if db_url and "supabase.co" in db_url and ":6543" not in db_url:
            print(
                "  WARN: DATABASE_URL may be direct Postgres (:5432). "
                "Use Supabase transaction pooler :6543 for the app runtime."
            )

    cors = os.environ.get("CORS_ORIGINS", "")
    if cors:
        print(f"CORS_ORIGINS entries: {len(cors.split(','))}")
    else:
        print("  WARN: CORS_ORIGINS not set (defaults to localhost only)")

    return errors


def normalize_api_base(raw: str) -> str:
    """Normalize API_BASE_URL to https://host/api (never strip // from https://)."""
    value = raw.strip().rstrip("/")
    if not value:
        return value

    # Fix typo: https:/host -> https://host
    value = re.sub(r"^(https?):/([^/])", r"\1://\2", value, count=1)

    if not value.startswith(("http://", "https://")):
        value = f"https://{value}"

    parsed = urlparse(value)
    if not parsed.netloc:
        raise ValueError(f"Invalid API_BASE_URL (no host): {raw!r}")

    # Only remove a trailing /api path segment, not // in the scheme
    path = (parsed.path or "").rstrip("/")
    if path.endswith("/api"):
        path = path[: -len("/api")]
    path = f"{path}/api" if path else "/api"

    return urlunparse((parsed.scheme, parsed.netloc, path, "", "", ""))


def api_health_url(api_base: str) -> str:
    base = normalize_api_base(api_base)
    return f"{base}/health"


def api_login_url(api_base: str) -> str:
    base = normalize_api_base(api_base)
    origin = base[: -len("/api")]
    return f"{origin}/api/accounts/login"


def _check_health(api_base: str) -> list[str]:
    errors: list[str] = []
    try:
        health_url = api_health_url(api_base)
    except ValueError as exc:
        return [str(exc)]

    print(f"GET {health_url}")
    try:
        with urllib.request.urlopen(health_url, timeout=15) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            print(f"  status={resp.status} body={body[:200]}")
            if resp.status != 200:
                errors.append(f"Health check returned {resp.status}")
    except urllib.error.URLError as exc:
        errors.append(f"Health check failed: {exc}")
    return errors


def _check_cors_preflight(api_base: str, origin: str) -> list[str]:
    if not origin:
        print("Skip CORS preflight (set CORS_ORIGIN=https://your-app.vercel.app)")
        return []

    try:
        login_url = api_login_url(api_base)
    except ValueError as exc:
        return [str(exc)]

    print(f"OPTIONS {login_url} Origin={origin}")
    req = urllib.request.Request(
        login_url,
        method="OPTIONS",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "POST",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            allow_origin = resp.headers.get("Access-Control-Allow-Origin", "")
            allow_creds = resp.headers.get("Access-Control-Allow-Credentials", "")
            print(f"  Allow-Origin={allow_origin}")
            print(f"  Allow-Credentials={allow_creds}")
            if allow_creds.lower() != "true":
                return ["Access-Control-Allow-Credentials is not true"]
    except urllib.error.URLError as exc:
        return [f"CORS preflight failed: {exc}"]
    return []


def main() -> int:
    print("=== Yamada production env verification ===\n")
    errors = _check_env()

    api_base = os.environ.get("API_BASE_URL", "").strip()
    if api_base:
        try:
            normalized = normalize_api_base(api_base)
            if normalized != api_base.rstrip("/"):
                print(f"API base (normalized): {normalized}\n")
            errors.extend(_check_health(normalized))
            errors.extend(
                _check_cors_preflight(
                    normalized, os.environ.get("CORS_ORIGIN", "").strip()
                )
            )
        except ValueError as exc:
            errors.append(str(exc))
    else:
        print("\nSet API_BASE_URL to run remote health/CORS checks.")

    print()
    if errors:
        print("FAILED:")
        for err in errors:
            print(f"  - {err}")
        return 1
    print("OK — no blocking issues detected.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
