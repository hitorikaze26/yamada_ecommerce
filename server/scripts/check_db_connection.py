"""Quick database connectivity test before running flask db upgrade.

Usage (Supabase):
  $env:FLASK_ENV="production"
  $env:DATABASE_URL="postgresql://..."
  python scripts/check_db_connection.py
"""

from __future__ import annotations

import os
import socket
import sys
from pathlib import Path
from urllib.parse import quote_plus, urlparse, urlunparse

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / ".env")


def _mask_uri(uri: str) -> str:
    if "@" not in uri:
        return uri
    prefix, rest = uri.split("@", 1)
    if ":" in prefix:
        scheme, _ = prefix.rsplit(":", 1)
        return f"{scheme}:***@{rest}"
    return uri


def _host_has_ipv4(hostname: str) -> bool:
    try:
        socket.getaddrinfo(hostname, None, socket.AF_INET, socket.SOCK_STREAM)
        return True
    except socket.gaierror:
        return False


def _resolve_ipv4(hostname: str) -> str | None:
    try:
        infos = socket.getaddrinfo(hostname, None, socket.AF_INET, socket.SOCK_STREAM)
        return infos[0][4][0]
    except socket.gaierror:
        return None


def _project_ref_from_uri(uri: str) -> str | None:
    parsed = urlparse(uri)
    user = parsed.username or ""
    if user.startswith("postgres."):
        return user.split(".", 1)[1]
    host = parsed.hostname or ""
    if host.startswith("db.") and host.endswith(".supabase.co"):
        return host[3:].replace(".supabase.co", "")
    return None


def _supabase_candidate_urls(uri: str) -> list[tuple[str, str]]:
    """URLs to try, ordered for Windows / IPv4-only networks."""
    parsed = urlparse(uri)
    host = parsed.hostname or ""
    user = parsed.username or ""
    password = parsed.password or ""
    path = parsed.path or "/postgres"
    scheme = parsed.scheme if "+" in parsed.scheme else "postgresql+psycopg2"
    if not scheme.startswith("postgresql"):
        scheme = "postgresql+psycopg2"

    project_ref = _project_ref_from_uri(uri)
    candidates: list[tuple[str, str]] = []

    if password and project_ref:
        pooler_host = "aws-1-ap-northeast-1.pooler.supabase.com"
        pooler_user = f"postgres.{project_ref}"

        # Transaction pooler — IPv4, recommended for migrations + Railway
        txn_netloc = f"{pooler_user}:{quote_plus(password)}@{pooler_host}:6543"
        txn = urlunparse((scheme, txn_netloc, path, "", "sslmode=require", ""))
        candidates.append(("Transaction pooler IPv4 :6543 (use this on Windows)", txn))

        session_netloc = f"{pooler_user}:{quote_plus(password)}@{pooler_host}:5432"
        session = urlunparse((scheme, session_netloc, path, "", "sslmode=require", ""))
        candidates.append(("Session pooler IPv4 :5432", session))

    if "pooler.supabase.com" not in host:
        candidates.insert(0, ("Your current URL", uri))
    else:
        candidates.insert(0, ("Your current URL", uri))

    return candidates


def _try_psycopg2(uri: str, force_ipv4: bool = True) -> None:
    import psycopg2

    parsed = urlparse(uri)
    host = parsed.hostname
    if not host:
        raise ValueError("missing host")

    kwargs = {
        "host": host,
        "port": parsed.port or 5432,
        "user": parsed.username,
        "password": parsed.password,
        "dbname": (parsed.path or "/postgres").lstrip("/") or "postgres",
        "connect_timeout": 15,
        "sslmode": "require",
    }

    if force_ipv4:
        ipv4 = _resolve_ipv4(host)
        if ipv4:
            kwargs["hostaddr"] = ipv4

    conn = psycopg2.connect(**kwargs)
    cur = conn.cursor()
    cur.execute("SELECT 1")
    cur.close()
    conn.close()


def main() -> int:
    flask_env = os.environ.get("FLASK_ENV", "development")
    database_url = os.environ.get("DATABASE_URL", "")

    print(f"FLASK_ENV={flask_env}")
    if not database_url:
        print("ERROR: DATABASE_URL is not set in this shell.")
        return 1

    uri = database_url
    if not uri.startswith("postgresql"):
        from config import _normalize_database_url

        uri = _normalize_database_url(uri)

    parsed = urlparse(uri)
    direct_host = parsed.hostname or ""

    print(f"Target: {_mask_uri(uri)}")

    if direct_host.startswith("db.") and not _host_has_ipv4(direct_host):
        print(
            "\nNOTE: Supabase DIRECT host is IPv6-only on your project."
            "\n      Home/Windows networks often cannot reach it (timeout)."
            "\n      Use Transaction pooler (IPv4) on port 6543 instead.\n"
        )

    print("Connecting...", flush=True)

    for label, try_uri in _supabase_candidate_urls(uri):
        print(f"\n--- {label} ---")
        print(_mask_uri(try_uri))
        try:
            _try_psycopg2(try_uri, force_ipv4=True)
            print("\nSUCCESS")
            print("Set DATABASE_URL to:")
            print(f"  {try_uri}")
            print("\nThen run: flask db upgrade")
            return 0
        except Exception as exc:
            print(f"FAILED: {exc}")

    print("\nAll attempts failed.")
    print("\nSupabase checklist:")
    print("  1. Dashboard → Project Settings → Database → reset password if unsure")
    print("  2. URL-encode special characters in password (@ → %40)")
    print("  3. Use Transaction pooler URI (IPv4), port 6543:")
    print("     postgresql://postgres.<ref>:PASSWORD@aws-1-ap-northeast-1.pooler.supabase.com:6543/postgres")
    print("  4. Database → Network: allow your IP or disable IP restrictions")
    print("  5. Ensure project is not paused")
    print("  6. Optional paid add-on: IPv4 for direct connection")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
