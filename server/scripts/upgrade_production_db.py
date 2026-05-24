#!/usr/bin/env python3
"""Apply pending Alembic migrations to the database in DATABASE_URL.

Use against Supabase Postgres (Railway production):

  cd server
  set DATABASE_URL=postgresql+psycopg2://...@....pooler.supabase.com:6543/postgres?sslmode=require
  set FLASK_ENV=production
  python scripts/upgrade_production_db.py

Uses Flask app context (required by migrations/env.py).
"""

from __future__ import annotations

import os
import sys

from alembic import command
from alembic.config import Config
from dotenv import load_dotenv


def main() -> int:
    server_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sys.path.insert(0, server_dir)

    load_dotenv(os.path.join(server_dir, ".env"))

    database_url = os.environ.get("DATABASE_URL", "").strip()
    if not database_url:
        print("ERROR: DATABASE_URL is not set.")
        print("Copy it from Railway → Variables (Supabase pooler :6543).")
        return 1

    os.environ["FLASK_ENV"] = os.environ.get("FLASK_ENV", "production")
    os.environ.setdefault("FLASK_APP", "app:create_app")

    host = database_url.split("@")[-1].split("/")[0] if "@" in database_url else "unknown"
    print(f"Target: {host}")
    print(f"FLASK_ENV={os.environ['FLASK_ENV']}\n")

    from app import create_app

    app = create_app()

    cfg = Config(os.path.join(server_dir, "migrations", "alembic.ini"))
    cfg.set_main_option("script_location", os.path.join(server_dir, "migrations"))

    with app.app_context():
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
