"""Shared helpers for cross-database Alembic migrations (MySQL dev, PostgreSQL prod)."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect


def get_bind():
    return op.get_bind()


def is_postgresql() -> bool:
    return get_bind().dialect.name == "postgresql"


def is_mysql() -> bool:
    return get_bind().dialect.name == "mysql"


def bool_false_default():
    """Server default for Boolean columns (PostgreSQL rejects integer 0)."""
    return sa.false()


def bool_true_default():
    return sa.true()


def table_exists(name: str) -> bool:
    return name in inspect(get_bind()).get_table_names()


def column_names(table: str) -> set[str]:
    if not table_exists(table):
        return set()
    return {col["name"] for col in inspect(get_bind()).get_columns(table)}


def fk_name_for_column(table: str, column: str) -> str | None:
    for fk in inspect(get_bind()).get_foreign_keys(table):
        if column in fk.get("constrained_columns", []):
            return fk["name"]
    return None


def run_for_dialect(*, mysql_sql: str | None = None, pg_sql: str | None = None) -> None:
    if is_postgresql() and pg_sql:
        op.execute(pg_sql)
    elif is_mysql() and mysql_sql:
        op.execute(mysql_sql)


def pg_add_enum_value(type_name: str, value: str) -> None:
    """Add a value to a PostgreSQL enum type if it does not exist."""
    op.execute(
        f"ALTER TYPE {type_name} ADD VALUE IF NOT EXISTS '{value}'"
    )


def pg_rename_column(table: str, old_name: str, new_name: str) -> None:
    op.execute(
        f'ALTER TABLE {table} RENAME COLUMN {old_name} TO {new_name}'
    )


def quote_user_table() -> str:
    """Quote reserved table name ``user`` for PostgreSQL."""
    return '"user"' if is_postgresql() else "user"
