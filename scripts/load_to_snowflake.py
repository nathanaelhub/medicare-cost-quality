"""
Load data/raw/*.csv into CMS.RAW.* via PUT + COPY INTO.

Auth comes from ~/.snowflake/config.toml (set up with `snow connection add`).
A programmatic access token works in the password/token field.

Usage:
    pip install snowflake-connector-python
    python scripts/load_to_snowflake.py [--connection NAME] [--role ROLE]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore[no-redef]

import snowflake.connector  # type: ignore[import-not-found]

RAW = Path(__file__).resolve().parent.parent / "data" / "raw"
LOADS = [
    ("inpatient_charges.csv", "inpatient_charges"),
    ("hrrp_readmissions.csv", "hrrp_readmissions"),
]


def load_connection(name: str | None) -> dict:
    cfg = tomllib.loads((Path.home() / ".snowflake" / "config.toml").read_text())
    conns = cfg.get("connections", {})
    if not conns:
        raise SystemExit("no [connections.*] in ~/.snowflake/config.toml")
    if name and name in conns:
        return conns[name]
    default = cfg.get("default_connection_name")
    return conns.get(default, next(iter(conns.values())))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--connection")
    ap.add_argument("--role", default="ACCOUNTADMIN",
                    help="role to load under (default ACCOUNTADMIN; "
                         "use WAREHOUSE_DEV with an unrestricted credential)")
    args = ap.parse_args()

    if not RAW.exists():
        raise SystemExit(f"no raw data at {RAW} — run scripts/fetch_cms.py first")

    conn = {**load_connection(args.connection),
            "role": args.role, "warehouse": "LOAD_WH",
            "database": "CMS", "schema": "RAW"}
    print(f"connecting to {conn.get('account')} as {conn.get('user')} ({args.role})...")

    with snowflake.connector.connect(**conn) as cx, cx.cursor() as cur:
        cur.execute(f"USE ROLE {args.role}")
        cur.execute("USE WAREHOUSE LOAD_WH")
        cur.execute("USE SCHEMA CMS.RAW")
        for csv_name, table in LOADS:
            src = RAW / csv_name
            if not src.exists():
                print(f"  skip {csv_name} (missing)")
                continue
            cur.execute(f"TRUNCATE TABLE {table}")
            print(f"  PUT {csv_name}")
            cur.execute(
                f"PUT 'file://{src}' @CMS_STAGE/{table}/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE"
            )
            print(f"  COPY INTO {table}")
            cur.execute(f"""
                COPY INTO {table} FROM @CMS_STAGE/{table}/
                FILE_FORMAT = (TYPE='CSV' FIELD_OPTIONALLY_ENCLOSED_BY='"'
                               SKIP_HEADER=1 NULL_IF=('','NA','Not Available'))
                MATCH_BY_COLUMN_NAME = 'CASE_INSENSITIVE'
                ON_ERROR = 'CONTINUE'
            """)
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            print(f"    {table}: {cur.fetchone()[0]:,} rows\n")
        print("done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
