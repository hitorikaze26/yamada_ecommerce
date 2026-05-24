"""Scan Alembic migrations for common PostgreSQL incompatibilities."""

from __future__ import annotations

import re
import sys
from pathlib import Path

VERSIONS_DIR = Path(__file__).resolve().parents[1] / "migrations" / "versions"


def _has_postgresql_guard(text: str) -> bool:
    return (
        "bind.dialect.name == 'postgresql'" in text
        or 'bind.dialect.name == "postgresql"' in text
        or "is_postgresql()" in text
        or "dialect_helpers" in text
    )


def _has_table_guard_before_get_columns(text: str, table: str) -> bool:
    """Rough check: table_exists or 'table' not in existing_tables before get_columns."""
    if f"get_columns('{table}')" not in text and f'get_columns("{table}")' not in text:
        return True
    if "table_exists" in text or "existing_tables" in text:
        return True
    return False


def scan_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    findings: list[str] = []
    pg_guard = _has_postgresql_guard(text)

    # Boolean + integer string defaults
    bool_default_bad = re.findall(
        r"sa\.Boolean\([^)]*\)[^,\n]*,[^;\n]*server_default=(?:sa\.text\([\"']0[\"']\)|[\"']0[\"']|[\"']1[\"'])",
        text,
    )
    if bool_default_bad and "bool_false_default" not in text and "bool_true_default" not in text:
        findings.append("Boolean column with integer server_default (use bool_false_default())")

    if re.search(r"MODIFY COLUMN", text) and not pg_guard:
        findings.append("MODIFY COLUMN without PostgreSQL dialect guard")

    if re.search(r"CHANGE COLUMN", text) and not pg_guard:
        findings.append("CHANGE COLUMN without PostgreSQL dialect guard")

    if re.search(r"drop_constraint\([^)]*_ibfk_", text):
        findings.append("hardcoded MySQL _ibfk_ constraint name")

    if re.search(r"drop_constraint\(\s*batch_op\.f\(['\"][^'\"]*_ibfk_", text):
        findings.append("drop_constraint via batch_op.f() with _ibfk_ name")

    if (
        "batch_alter_table" in text
        and "postgresql_using" in text
        and "alter_column" in text
        and not pg_guard
    ):
        findings.append("postgresql_using in batch_alter_table without dialect guard")

    if re.search(r"alter_column[\s\S]{0,400}mysql\.ENUM", text) and not pg_guard:
        findings.append("alter_column with mysql.ENUM without PostgreSQL guard")

    if "get_columns('buyer_profiles')" in text and not _has_table_guard_before_get_columns(
        text, "buyer_profiles"
    ):
        findings.append("get_columns('buyer_profiles') without table_exists guard")

    if re.search(r"UPDATE user SET", text) and "quote_user_table" not in text:
        findings.append('UPDATE user SET without quote_user_table() for PostgreSQL')

    if re.search(
        r"INSERT INTO[^;]+VALUES\s*\([^)]*\b1\s*,\s*1\b",
        text,
        re.IGNORECASE,
    ) and "true, true" not in text and not pg_guard:
        findings.append("INSERT may use 1 for boolean columns (needs PG true/false branch)")

    return findings


def main() -> int:
    print("=== Alembic PostgreSQL migration sanity check ===\n")
    total = 0
    for path in sorted(VERSIONS_DIR.glob("*.py")):
        findings = scan_file(path)
        if findings:
            total += len(findings)
            print(path.name)
            for item in findings:
                print(f"  - {item}")
            print()

    if total == 0:
        print("No issues found.")
        return 0

    print(f"Total findings: {total}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
