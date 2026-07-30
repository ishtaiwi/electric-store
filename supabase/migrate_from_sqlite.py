#!/usr/bin/env python3
"""
Migrate Electrical Store SQLite (d.db) → Supabase PostgreSQL.

Modes:
  1) Export SQL dump (default, no credentials needed):
       python migrate_from_sqlite.py --db ../d.db --out data_export.sql

  2) Upload directly to Supabase (needs service_role key):
       python migrate_from_sqlite.py --db ../d.db --upload \\
         --url https://xxxx.supabase.co --key YOUR_SERVICE_ROLE_KEY

Prerequisites:
  - Run supabase/schema.sql in the SQL Editor first
  - pip install -r requirements.txt
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

# FK-safe order for INSERT / UPSERT
TABLES: list[str] = [
    "users",
    "suppliers",
    "customers",
    "products",
    "invoices",
    "sales",
    "customer_payments",
    "discounts",
    "inventory_adjustments",
    "cancelled_sales",
    "expenses",
    "additional_income",
    "budget",
    "store_settings",
    "price_lists",
    "price_list_items",
    "supplier_attachments",
    "supplier_invoices",
    "supplier_payments",
    "audit_logs",
]

# Reverse order for clearing before re-import
TABLES_CLEAR = list(reversed(TABLES))


def sql_literal(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        # SQLite sometimes stores bool as 0/1 ints — keep as number
        return str(value)
    if isinstance(value, bytes):
        value = value.decode("utf-8", errors="replace")
    text = str(value).replace("'", "''")
    return f"'{text}'"


def fetch_table(conn: sqlite3.Connection, table: str) -> tuple[list[str], list[sqlite3.Row]]:
    conn.row_factory = sqlite3.Row
    try:
        cur = conn.execute(f"SELECT * FROM {table}")
    except sqlite3.OperationalError as exc:
        print(f"  [skip] {table}: {exc}")
        return [], []
    rows = cur.fetchall()
    cols = [d[0] for d in cur.description] if cur.description else []
    return cols, rows


def row_to_dict(cols: list[str], row: sqlite3.Row) -> dict[str, Any]:
    data: dict[str, Any] = {}
    for col in cols:
        val = row[col]
        # Normalize SQLite boolean-ish values for is_active
        if col == "is_active" and isinstance(val, int):
            val = bool(val)
        data[col] = val
    return data


def build_sql_dump(conn: sqlite3.Connection) -> str:
    lines: list[str] = [
        "-- ============================================================",
        "-- Electrical Store — Data export from SQLite",
        f"-- Generated: {datetime.now().isoformat(timespec='seconds')}",
        "-- Run AFTER supabase/schema.sql",
        "-- ============================================================",
        "",
        "BEGIN;",
        "",
        "-- Clear existing rows (keeps table structure)",
    ]
    for table in TABLES_CLEAR:
        lines.append(f"TRUNCATE TABLE {table} RESTART IDENTITY CASCADE;")

    lines.append("")
    lines.append("-- Insert data with original IDs")

    for table in TABLES:
        cols, rows = fetch_table(conn, table)
        if not cols:
            continue
        print(f"  {table}: {len(rows)} rows")
        if not rows:
            continue
        col_list = ", ".join(cols)
        lines.append("")
        lines.append(f"-- {table} ({len(rows)} rows)")
        for row in rows:
            values = ", ".join(sql_literal(row[c]) for c in cols)
            lines.append(f"INSERT INTO {table} ({col_list}) VALUES ({values});")

    lines.append("")
    lines.append("-- Reset identity sequences to MAX(id)")
    for table in TABLES:
        lines.append(
            f"SELECT setval(pg_get_serial_sequence('{table}', 'id'), "
            f"COALESCE((SELECT MAX(id) FROM {table}), 1), true);"
        )

    lines.append("")
    lines.append("COMMIT;")
    lines.append("")
    lines.append("SELECT 'Data import completed' AS status;")
    return "\n".join(lines)


def upload_to_supabase(conn: sqlite3.Connection, url: str, key: str, clear: bool) -> None:
    try:
        from supabase import create_client
    except ImportError:
        print("ERROR: pip install supabase")
        sys.exit(1)

    client = create_client(url.rstrip("/"), key)

    if clear:
        print("Clearing remote tables...")
        for table in TABLES_CLEAR:
            try:
                # Delete all rows (service_role bypasses RLS)
                client.table(table).delete().neq("id", -1).execute()
                print(f"  cleared {table}")
            except Exception as exc:  # noqa: BLE001
                print(f"  warn clear {table}: {exc}")

    for table in TABLES:
        cols, rows = fetch_table(conn, table)
        if not cols or not rows:
            print(f"  {table}: 0 rows")
            continue

        batch: list[dict[str, Any]] = []
        for row in rows:
            batch.append(row_to_dict(cols, row))

        # Upsert in chunks of 200
        chunk_size = 200
        total = 0
        for i in range(0, len(batch), chunk_size):
            chunk = batch[i : i + chunk_size]
            try:
                client.table(table).upsert(chunk, on_conflict="id").execute()
                total += len(chunk)
            except Exception as exc:  # noqa: BLE001
                print(f"  ERROR upsert {table} chunk {i}: {exc}")
                # Try row-by-row to isolate bad rows
                for item in chunk:
                    try:
                        client.table(table).upsert(item, on_conflict="id").execute()
                        total += 1
                    except Exception as row_exc:  # noqa: BLE001
                        print(f"    fail id={item.get('id')}: {row_exc}")
                        print(f"    data={json.dumps(item, default=str)[:300]}")
        print(f"  {table}: uploaded {total}/{len(batch)}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Migrate d.db → Supabase")
    parser.add_argument(
        "--db",
        default=str(Path(__file__).resolve().parent.parent / "d.db"),
        help="Path to SQLite d.db",
    )
    parser.add_argument(
        "--out",
        default=str(Path(__file__).resolve().parent / "data_export.sql"),
        help="Output SQL dump path",
    )
    parser.add_argument(
        "--upload",
        action="store_true",
        help="Upload directly via Supabase API (service_role key)",
    )
    parser.add_argument("--url", default="", help="Supabase project URL")
    parser.add_argument("--key", default="", help="Supabase service_role key")
    parser.add_argument(
        "--clear",
        action="store_true",
        help="Clear remote tables before upload",
    )
    args = parser.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        print(f"ERROR: database not found: {db_path}")
        sys.exit(1)

    print(f"Opening SQLite: {db_path}")
    conn = sqlite3.connect(str(db_path))

    # List available tables
    existing = {
        r[0]
        for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        )
    }
    print(f"SQLite tables: {sorted(existing)}")

    missing = [t for t in TABLES if t not in existing]
    if missing:
        print(f"Note: missing tables (skipped): {missing}")

    if args.upload:
        if not args.url or not args.key:
            print("ERROR: --upload requires --url and --key (service_role)")
            sys.exit(1)
        print("Uploading to Supabase...")
        upload_to_supabase(conn, args.url, args.key, clear=args.clear)
        print("Done.")
    else:
        print("Building SQL dump...")
        dump = build_sql_dump(conn)
        out_path = Path(args.out)
        out_path.write_text(dump, encoding="utf-8")
        print(f"Wrote: {out_path}")
        print("Next: open Supabase SQL Editor and run data_export.sql")

    conn.close()


if __name__ == "__main__":
    main()
