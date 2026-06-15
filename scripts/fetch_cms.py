"""
Download the two CMS source extracts into data/raw/. No authentication —
the CMS endpoints are public.

Rather than hardcode dataset URLs (which CMS rotates each release year),
this resolves the latest distribution from the CMS DCAT catalog for the
inpatient dataset, and uses the stable Provider Data Catalog datastore
API for HRRP.

Usage:
    python scripts/fetch_cms.py
"""

from __future__ import annotations

import csv
import io
import json
import sys
import urllib.request
from pathlib import Path

RAW = Path(__file__).resolve().parent.parent / "data" / "raw"

# CMS DCAT catalog — lists every dataset on data.cms.gov with download URLs.
DCAT_CATALOG = "https://data.cms.gov/data.json"
INPATIENT_TITLE_NEEDLE = "Medicare Inpatient Hospitals - by Provider and Service"

# Provider Data Catalog (Socrata-style). HRRP dataset id is stable.
HRRP_DATASET_ID = "9n3s-kdb3"
HRRP_QUERY_URL = (
    f"https://data.cms.gov/provider-data/api/1/datastore/query/{HRRP_DATASET_ID}/0"
)


def _get(url: str, timeout: int = 120) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "medicare-cost-quality/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def resolve_inpatient_csv_url() -> str:
    """Find the latest-year CSV distribution for the inpatient dataset."""
    catalog = json.loads(_get(DCAT_CATALOG))
    datasets = catalog.get("dataset", [])
    candidates = [d for d in datasets if INPATIENT_TITLE_NEEDLE in d.get("title", "")]
    if not candidates:
        raise SystemExit("could not find the inpatient dataset in the CMS catalog")

    # Title carries the year, e.g. "... by Provider and Service : 2022".
    def year_of(d: dict) -> int:
        title = d.get("title", "")
        digits = "".join(ch for ch in title if ch.isdigit())
        return int(digits[-4:]) if len(digits) >= 4 else 0

    latest = max(candidates, key=year_of)
    for dist in latest.get("distribution", []):
        media = dist.get("mediaType", "")
        url = dist.get("downloadURL", "")
        if media == "text/csv" or url.lower().endswith(".csv"):
            print(f"  inpatient: {latest.get('title')} -> {url}")
            return url
    raise SystemExit("inpatient dataset had no CSV distribution")


def fetch_inpatient() -> None:
    url = resolve_inpatient_csv_url()
    RAW.mkdir(parents=True, exist_ok=True)
    out = RAW / "inpatient_charges.csv"
    out.write_bytes(_get(url, timeout=300))
    rows = sum(1 for _ in out.open()) - 1
    print(f"  wrote {out.name}: {rows:,} rows")


def fetch_hrrp() -> None:
    """Page the Provider Data Catalog datastore API into one CSV."""
    RAW.mkdir(parents=True, exist_ok=True)
    out = RAW / "hrrp_readmissions.csv"
    # The Provider Data Catalog datastore API caps page size at 1000.
    limit, offset, all_rows, header = 1000, 0, [], None
    while True:
        url = f"{HRRP_QUERY_URL}?limit={limit}&offset={offset}"
        payload = json.loads(_get(url))
        results = payload.get("results", [])
        if not results:
            break
        if header is None:
            header = list(results[0].keys())
        all_rows.extend(results)
        offset += limit
        if len(results) < limit:
            break
    if header is None:
        raise SystemExit("HRRP query returned no rows")
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=header)
    w.writeheader()
    w.writerows(all_rows)
    out.write_text(buf.getvalue())
    print(f"  wrote {out.name}: {len(all_rows):,} rows")


def main() -> int:
    print("fetching CMS inpatient charges...")
    fetch_inpatient()
    print("fetching HRRP readmissions...")
    fetch_hrrp()
    print("done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
