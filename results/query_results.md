# Query results

Real output from the three `sql_highlights/` queries, run against the loaded warehouse (CMS DY2024 release). Reproducible — re-run the queries in `sql_highlights/` after `dbt run` and you'll get these numbers.

Warehouse at capture time: `inpatient_charges` 145,879 rows · `hrrp_readmissions` 18,330 rows · `dim_provider` 2,906 hospitals · `fact_inpatient_charges` 145,879 · `fact_readmissions` 11,720.

---

## Q1 — Price variation for DRG 470 (major joint replacement)

`sql_highlights/01_price_variation_one_drg.sql`

| n_hospitals | min | p10 | median | p90 | max | fold (max/min) | Medicare-pay p90/p10 |
|---|---|---|---|---|---|---|---|
| 1,212 | $19,194 | $42,710 | $79,947 | $167,283 | $383,606 | 20.0× | 1.7× |

The average **charge** for one standardized procedure spans 20× across hospitals; the average **Medicare payment** for the same procedure varies only 1.7×.

---

## Q2 — Markup by service line (discharge-weighted)

`sql_highlights/02_markup_by_service_line.sql`

| service_line | wavg_charge | wavg_medicare_pay | markup |
|---|---|---|---|
| Nervous system | $93,021 | $14,536 | 6.40× |
| Digestive | $74,426 | $11,635 | 6.40× |
| Musculoskeletal | $111,798 | $17,759 | 6.30× |
| Kidney/urinary | $61,196 | $9,786 | 6.25× |
| Other | $116,040 | $18,665 | 6.22× |
| Blood | $65,276 | $10,716 | 6.09× |
| Circulatory | $100,574 | $16,599 | 6.06× |
| Endocrine | $54,154 | $8,965 | 6.04× |
| Respiratory | $69,139 | $11,539 | 5.99× |
| Skin | $45,473 | $7,629 | 5.96× |
| Infectious/sepsis | $105,984 | $18,146 | 5.84× |
| Transplants | $983,090 | $174,427 | 5.64× |

The markup sits in a tight 5.6–6.4× band regardless of service line — a roughly fixed multiple, not a complexity-driven one.

---

## Q3 — Cost vs quality, by payment quintile (the two-fact join)

`sql_highlights/03_cost_vs_quality.sql`

| pay_quintile | n_hospitals | avg_medicare_pay | avg_excess_readmit_ratio |
|---|---|---|---|
| Q1 (lowest paid) | 558 | $8,410 | 1.0069 |
| Q2 | 558 | $10,216 | 1.0061 |
| Q3 | 558 | $11,805 | 1.0006 |
| Q4 | 558 | $14,140 | 0.9912 |
| Q5 (highest paid) | 557 | $21,939 | 0.9942 |

**Correlation across all 2,789 hospitals: r = −0.081.**

A faint downward tilt — the best-paid quintile dips just below the 1.0 risk-adjusted expectation — but payment explains under 1% of the variance in readmissions. Paying a hospital 2.6× more buys, at most, a rounding error of better outcomes.
