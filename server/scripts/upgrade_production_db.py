#!/usr/bin/env python3
"""Apply pending Alembic migrations to the database in DATABASE_URL.

Use on Railway (Supabase Postgres) when pre-deploy migration did not run:

  cd server
  set DATABASE_URL=postgresql://...
  set FLASK_APP=app:create_app
  set FLASK_ENV=production
  python scripts/upgrade_production_db.py

Prints current revision before/after upgrade.
"""

from __future__ import annotations

import os
import sys

from alembic import command
from alembic.config import Config
from dotenv import load_dotenv


def main() -> int:
    server_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    load_dotenv(os.path.join(server_dir, ".env"))

    database_url = os.environ.get("DATABASE_URL", "").strip()
    if not database_url:
        print("ERROR: DATABASE_URL is not set.")
        return 1

    os.environ.setdefault("FLASK_APP", "app:create_app")
    os.environ.setdefault("FLASK_ENV", "production")

    cfg = Config(os.path.join(server_dir, "migrations", "alembic.ini"))
    cfg.set_main_option("script_location", os.path.join(server_dir, "migrations"))
    cfg.set_main_option("sqlalchemy.url", database_url.replace("%", "%%"))

    print(f"Database host: {database_url.split('@')[-1].split('/')[0] if '@' in database_url else 'unknown'}")
    print("Current revision:")
    command.current(cfg, verbose=True)
    print("\nUpgrading to head...")
    command.upgrade(cfg, "head")
    print("\nAfter upgrade:")
    command.current(cfg, verbose=True)
    print("\nDone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
