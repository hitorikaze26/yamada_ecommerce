"""Quick database connectivity test before running flask db upgrade.

Usage (Supabase):
  set FLASK_ENV=production
  set DATABASE_URL=postgresql://...
  python scripts/check_db_connection.py
"""

from __future__ import annotations

import sys
from pathlib import Path

# Allow running from server/ directory
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

from app import create_app
from app.models import db


def main() -> int:
    app = create_app()
    uri = app.config.get("SQLALCHEMY_DATABASE_URI") or ""
    if not uri:
        print("ERROR: No SQLALCHEMY_DATABASE_URI. Set DATABASE_URL (production) or DEV_DATABASE_URL.")
        return 1

    # Hide password in log
    safe = uri
    if "@" in safe:
        prefix, rest = safe.split("@", 1)
        if ":" in prefix:
            scheme, _ = prefix.rsplit(":", 1)
            safe = f"{scheme}:***@{rest}"

    print(f"FLASK_ENV={app.config.get('ENV', 'unknown')}")
    print(f"Target: {safe}")
    print("Connecting...", flush=True)

    with app.app_context():
        try:
            conn = db.engine.connect()
            from sqlalchemy import text

            conn.execute(text("SELECT 1"))
            conn.close()
        except Exception as exc:
            print(f"FAILED: {exc}")
            print(
                "\nTips:\n"
                "- Supabase: use URI from Dashboard → Database → Connection string\n"
                "- Add ?sslmode=require if not present\n"
                "- URL-encode special characters in the password\n"
                "- For migrations, prefer direct host (port 5432) over pooler\n"
            )
            return 1

    print("OK — database is reachable.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
