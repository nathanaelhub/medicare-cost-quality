# Medicare Cost & Quality

An analytics-engineering case study on Medicare inpatient hospital data: what the same procedure costs at different hospitals, how far hospital charges sit above what Medicare actually pays, and whether spending more buys better outcomes. Raw CMS CSVs land in Snowflake, get modeled into a **two-fact conformed-dimension star schema** with dbt, and back a narrative dashboard on [nathanaeljohnson.net/work/medicare-cost-quality](https://nathanaeljohnson.net/work/medicare-cost-quality).

The data is real and public — no authentication, published by the Centers for Medicare & Medicaid Services:

- **[Medicare Inpatient Hospitals — by Provider and Service](https://data.cms.gov/provider-summary-by-type-of-service/medicare-inpatient-hospitals)** — for every hospital and every MS-DRG (procedure group), the total discharges, average covered charge (what the hospital bills), average total payment, and average Medicare payment. ~150k provider × DRG rows.
- **[Hospital Readmissions Reduction Program (HRRP)](https://data.cms.gov/provider-data/dataset/9n3s-kdb3)** — per hospital, the 30-day excess-readmission ratio for six conditions (heart attack, heart failure, pneumonia, COPD, hip/knee replacement, CABG).

The two datasets share a key: HRRP's `Facility ID` **is** the inpatient dataset's `Rndrng_Prvdr_CCN` (the CMS Certification Number). That join is the spine of the project — it's what lets cost be compared to quality at the same hospital.

## What this proves

- **Two-fact dimensional modeling** — a charges fact and a readmissions fact at different grains, sharing conformed `dim_provider` / `dim_geography`. This is the model shape that separates "I've read the Kimball book" from "I've built one."
- **SQL warehouse work** — percentile/window functions for charge distributions, `QUALIFY` for per-DRG leaders, ratio measures computed in the mart, a correlation pulled in SQL.
- **Snowflake + dbt** — staging/marts layering, schema tests (including a `relationships` test on the CCN join that fails loudly if the two facts ever stop conforming), source freshness.
- **Healthcare-analytics literacy** — DRG service-line grouping, charge-vs-payment vs-Medicare-payment distinctions, risk-adjusted readmission ratios. The domain my BI roles (ROX Analytics, Amplion) actually lived in.

## The three questions

1. **Same procedure, different price.** For a single common DRG (470 — major joint replacement without complications), how wide is the spread of average covered charges across hospitals? (Answer: very.)
2. **The markup gap.** Hospitals' "covered charges" are a list price almost nobody pays. How far above the actual Medicare payment do they sit, and does the markup vary by service line or state?
3. **Does spending buy quality?** Join average Medicare payment to the 30-day excess-readmission ratio. Do higher-paid hospitals readmit fewer patients? (The payer's central question.)

## Repo layout

```
medicare-cost-quality/
├── snowflake/
│   ├── setup/    # database, warehouses, schemas, dev role
│   └── ddl/      # raw landing tables for both CMS extracts
├── scripts/
│   ├── fetch_cms.py        # pulls both datasets via the CMS data API (no auth)
│   └── load_to_snowflake.py
├── dbt/
│   └── models/
│       ├── staging/        # stg_* — rename + cast both sources
│       └── marts/          # fact_inpatient_charges, fact_readmissions,
│                           # dim_provider, dim_drg, dim_geography
├── sql_highlights/         # the 3 queries behind the portfolio charts
└── docs/
    └── star_schema.md      # grain, conformance, and the CCN-join contract
```

## The pipeline

```
CMS data API (public, no auth)
    │  scripts/fetch_cms.py
    ▼
data/raw/{inpatient_charges,hrrp_readmissions}.csv
    │  scripts/load_to_snowflake.py  (PUT + COPY INTO)
    ▼
RAW.CMS.*  (2 landing tables, untouched)
    │  dbt run --select staging
    ▼
STG.CMS.STG_*  (renamed, cast, cleaned)
    │  dbt run --select marts
    ▼
MARTS.CMS.{fact_inpatient_charges, fact_readmissions, dim_provider, dim_drg, dim_geography}
    │
    ▼  charts on the portfolio page query snapshotted aggregates
```

## Quick start

Same shape as the [olist-warehouse](https://github.com/nathanaelhub/olist-warehouse) project — stand up a Snowflake trial, install the `snow` CLI, run the setup SQL, fetch + load, then `dbt run && dbt test`. Full walkthrough in that repo's README; the only difference here is the data source is the CMS API (no Kaggle token needed — the CMS endpoints are open).

```bash
snow sql -f snowflake/setup/01_account_objects.sql
snow sql -f snowflake/ddl/02_raw_tables.sql
python scripts/fetch_cms.py
python scripts/load_to_snowflake.py
cd dbt && dbt deps && dbt run && dbt test
```

## Stack

| Layer | Tool |
|---|---|
| Source | CMS data.cms.gov API (public, no auth) |
| Warehouse | Snowflake (Standard, free trial) |
| Modeling | dbt Core with `dbt_utils` |
| Tests | dbt schema tests incl. cross-fact `relationships` on CCN |
| Presentation | Hand-coded SVG charts on the portfolio |

## License

MIT for the code. The CMS datasets are U.S. Government public-domain works.
