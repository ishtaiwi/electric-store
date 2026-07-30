#!/usr/bin/env python3
"""Generate gitignored Dart secret files from .env (never committed)."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = ROOT / ".env"


def load_env(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    if not path.exists():
        raise SystemExit(f"Missing {path}. Copy .env.example to .env and fill values.")
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        data[k.strip()] = v.strip().strip('"').strip("'")
    return data


def dart_file(url: str, anon: str) -> str:
    return f"""// GENERATED FROM .env — DO NOT COMMIT
// Run: python supabase/generate_secrets.py

/// Private Supabase credentials loaded for this local/build machine only.
class SupabaseSecrets {{
  static const String url = {repr(url)};
  static const String anonKey = {repr(anon)};
}}
"""


def main() -> None:
    env = load_env(ENV_PATH)
    url = env.get("SUPABASE_URL", "").rstrip("/").replace("/rest/v1", "")
    anon = env.get("SUPABASE_ANON_KEY", "")
    if not url or not anon:
        raise SystemExit("SUPABASE_URL and SUPABASE_ANON_KEY are required in .env")
    if "SERVICE_ROLE" in anon.upper() or env.get("SUPABASE_SERVICE_ROLE_KEY", "") == anon:
        raise SystemExit("Refusing to embed service_role key into the app")

    targets = [
        ROOT / "lib" / "core" / "config" / "supabase_secrets.dart",
        ROOT / "mobile" / "lib" / "core" / "config" / "supabase_secrets.dart",
    ]
    content = dart_file(url, anon)
    for path in targets:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        print(f"Wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
