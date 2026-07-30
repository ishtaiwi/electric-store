#!/usr/bin/env python3
"""Apply schema.sql then upload d.db using credentials from supabase/.env"""

from __future__ import annotations

import os
import sys
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:
    print("pip install python-dotenv")
    sys.exit(1)

ROOT = Path(__file__).resolve().parent
load_dotenv(ROOT / ".env")

URL = os.getenv("SUPABASE_URL", "").rstrip("/").replace("/rest/v1", "")
SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")

if not URL or not SERVICE_KEY:
    print("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env")
    sys.exit(1)

print(f"Project: {URL}")


def run_sql(sql: str) -> None:
    """Execute SQL via Supabase Postgres Meta / SQL API if available, else via REST workaround."""
    import httpx

    headers = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
    }

    endpoints = [
        f"{URL}/pg/query",
        f"{URL}/pg-meta/default/query",
    ]

    last_err = None
    for ep in endpoints:
        try:
            r = httpx.post(
                ep,
                headers=headers,
                json={"query": sql},
                timeout=120.0,
            )
            if r.status_code < 300:
                print(f"SQL OK via {ep.split(URL)[-1]} ({r.status_code})")
                return
            last_err = f"{ep}: {r.status_code} {r.text[:500]}"
        except Exception as exc:  # noqa: BLE001
            last_err = str(exc)

    # Fallback: split into statements and try database webhook style — not available.
    raise RuntimeError(
        "Could not execute SQL via API.\n"
        f"Last error: {last_err}\n"
        "Please paste supabase/schema.sql into Supabase SQL Editor and Run, then re-run this script with --upload-only"
    )


def apply_schema() -> None:
    schema_path = ROOT / "schema.sql"
    sql = schema_path.read_text(encoding="utf-8")
    print(f"Applying schema ({len(sql)} chars)...")
    run_sql(sql)
    print("Schema applied.")


def upload_data(clear: bool = True) -> None:
    # Reuse migrate_from_sqlite
    from migrate_from_sqlite import upload_to_supabase
    import sqlite3

    db_path = ROOT.parent / "d.db"
    if not db_path.exists():
        print(f"Missing {db_path}")
        sys.exit(1)
    print(f"Uploading from {db_path} ...")
    conn = sqlite3.connect(str(db_path))
    upload_to_supabase(conn, URL, SERVICE_KEY, clear=clear)
    conn.close()
    print("Upload finished.")


def verify() -> None:
    from supabase import create_client

    client = create_client(URL, SERVICE_KEY)
    for table in ["users", "products", "customers", "invoices", "sales"]:
        try:
            res = client.table(table).select("id", count="exact").limit(1).execute()
            print(f"  {table}: count≈{res.count}")
        except Exception as exc:  # noqa: BLE001
            print(f"  {table}: ERROR {exc}")


def save_app_credentials() -> None:
    """Write URL + anon key into local SQLite store_settings for the Flutter app."""
    import sqlite3

    if not ANON_KEY:
        print("No ANON key — skip app settings")
        return
    db_path = ROOT.parent / "d.db"
    conn = sqlite3.connect(str(db_path))
    settings = {
        "supabase_url": URL,
        "supabase_anon_key": ANON_KEY,
        "supabase_sync_enabled": "1",
        "supabase_auto_sync": "0",
    }
    for k, v in settings.items():
        cur = conn.execute(
            "UPDATE store_settings SET setting_value=?, updated_at=CURRENT_TIMESTAMP WHERE setting_key=?",
            (v, k),
        )
        if cur.rowcount == 0:
            conn.execute(
                "INSERT INTO store_settings (setting_key, setting_value) VALUES (?, ?)",
                (k, v),
            )
    conn.commit()
    conn.close()
    print("Saved Supabase URL + anon key into local d.db (store_settings).")


if __name__ == "__main__":
    upload_only = "--upload-only" in sys.argv
    skip_schema = upload_only or "--skip-schema" in sys.argv

    if not skip_schema:
        try:
            apply_schema()
        except Exception as exc:  # noqa: BLE001
            print(f"\nSchema via API failed:\n{exc}\n")
            print("Continuing to check if tables already exist...")

    # Probe tables
    try:
        from supabase import create_client

        client = create_client(URL, SERVICE_KEY)
        client.table("users").select("id").limit(1).execute()
        print("Tables reachable.")
    except Exception as exc:  # noqa: BLE001
        print(f"Tables not ready: {exc}")
        print(
            "\n>>> ACTION REQUIRED: Open Supabase Dashboard -> SQL Editor ->\n"
            "    paste contents of supabase/schema.sql -> Run\n"
            "    Then run: python apply_and_migrate.py --upload-only\n"
        )
        sys.exit(2)

    upload_data(clear="--no-clear" not in sys.argv)
    verify()
    save_app_credentials()
    print("\nDone.")
