# Star schema design

A **two-fact, conformed-dimension** model. The two facts sit at different grains and share dimensions; the whole project exists to join them through `dim_provider`.

## Diagram

```
            ┌──────────────────┐         ┌──────────────────┐
            │   DIM_GEOGRAPHY  │         │     DIM_DRG      │
            │ geo_sk (PK)      │         │ drg_sk (PK)      │
            │ state, region    │         │ drg_code, desc,  │
            └───────┬──────────┘         │ service_line     │
                    │                    └────────┬─────────┘
        ┌───────────┼─────────────┐               │
        │           │             │               │
        ▼           ▼             ▼               ▼
┌────────────────────────┐   ┌──────────────────────────────┐
│   FACT_READMISSIONS    │   │   FACT_INPATIENT_CHARGES     │
│  grain: provider ×     │   │  grain: provider × DRG       │
│         measure        │   │                              │
│  provider_sk (FK)──────┼─┐ │  provider_sk (FK)────────┐   │
│  geo_sk (FK)           │ │ │  drg_sk (FK)             │   │
│  excess_readmit_ratio  │ │ │  geo_sk (FK)             │   │
│  predicted / expected  │ │ │  total_discharges        │   │
│  condition             │ │ │  avg_covered_charge      │   │
└────────────────────────┘ │ │  avg_medicare_payment    │   │
                           │ │  markup_ratio            │   │
                           │ │  wtd_* (pre-weighted)    │   │
                           │ └──────────────────────────┼───┘
                           │                            │
                           ▼                            ▼
                       ┌──────────────────────────────────┐
                       │          DIM_PROVIDER            │
                       │  provider_sk (PK)                │
                       │  ccn  ← the conformed join key   │
                       │  name, city, state, urbanicity   │
                       └──────────────────────────────────┘
```

## The conformed key: CCN

The entire project hinges on one fact: the **HRRP `Facility ID` is the same value as the inpatient dataset's `Rndrng_Prvdr_CCN`** — the CMS Certification Number that uniquely identifies a Medicare-participating hospital.

`dim_provider` is built once (from the charges source, which has the wider hospital list) and keyed by a surrogate `provider_sk` derived from CCN. Both facts carry `provider_sk`. That's what lets "average Medicare payment" (charges fact) sit next to "excess readmission ratio" (readmissions fact) for the same hospital.

The cross-fact `relationships` test in `_schema.yml` enforces this contract: every `fact_readmissions.provider_sk` must resolve in `dim_provider`. If a future CMS release ships an HRRP facility with no inpatient charges, the build fails rather than silently dropping it from cost-vs-quality joins.

## Why two facts instead of one

You *could* force everything into a single wide table, but the grains genuinely differ:

- **`fact_inpatient_charges`** — one row per hospital × DRG (~150k rows). The measures are per-discharge dollar averages.
- **`fact_readmissions`** — one row per hospital × condition (6 conditions, ~16k rows after dropping suppressed cells). The measure is a risk-adjusted ratio.

Jamming them together would either explode the row count (cross-join of DRGs × conditions, meaningless) or force a premature aggregation that throws away the per-DRG charge detail. Separate facts at their natural grains, joined on demand through the conformed dimension, is the textbook-correct shape — and the realistic one.

## Non-additive measures

The charge and payment columns are **already per-discharge averages**. You cannot `AVG()` an average — a 4,000-discharge hospital and a 12-discharge hospital would count equally. To roll up correctly you weight by discharges:

```
weighted_avg_charge = SUM(avg_covered_charge * total_discharges) / SUM(total_discharges)
```

`fact_inpatient_charges` pre-computes `wtd_covered_charge` and `wtd_medicare_payment` (the numerators) so dashboards can `SUM(wtd_*) / SUM(total_discharges)` without re-deriving the weighting every query. `sql_highlights/02` shows it in use.

## SCD choices

- **`dim_provider` — SCD1.** Hospital name/city/CCN are stable; a hospital changing its name between annual releases is rare and not analytically interesting here. Overwrite.
- **`dim_drg` — SCD1.** DRG definitions are versioned by CMS but stable within a release year. The service-line rollup is a derived attribute, not a source one.
- No SCD2 anywhere — this dataset is an annual snapshot, not a transaction stream, so there's no intra-period history to track. (Contrast with the Olist project, where customer relocation justified SCD2.)

## When this design would change

- **Multiple data years.** Adding 2019–2023 would introduce a `dim_date` (year grain) and turn both facts into periodic snapshots — at which point SCD2 on `dim_provider` becomes worth it (hospitals open, close, merge across years).
- **Patient-level claims.** The public data is provider×DRG aggregates. Real claim-line data would push `fact_inpatient_charges` down to the claim grain and warrant a `dim_patient` and `dim_diagnosis` — a different scale of project entirely.
