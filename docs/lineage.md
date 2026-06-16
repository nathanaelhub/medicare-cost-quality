# Lineage

The dbt DAG from raw CMS tables through staging to the two-fact star. GitHub renders the mermaid graph below; `dbt docs generate && dbt docs serve` produces the interactive version locally.

```mermaid
flowchart LR
  %% sources
  src_inp[("RAW.inpatient_charges<br/>145,879 rows")]:::src
  src_hrrp[("RAW.hrrp_readmissions<br/>18,330 rows")]:::src

  %% staging (views)
  stg_inp["stg_inpatient_charges<br/><i>rename · cast · ratio measures</i>"]:::stg
  stg_rd["stg_readmissions<br/><i>try_cast · condition label</i>"]:::stg

  %% marts
  dim_prov["dim_provider<br/>2,906 hospitals"]:::dim
  dim_drg["dim_drg<br/>540 DRGs · service_line"]:::dim
  dim_geo["dim_geography<br/>51 states"]:::dim
  fact_chg["fact_inpatient_charges<br/>145,879 · hospital × DRG"]:::fact
  fact_rd["fact_readmissions<br/>11,720 · hospital × condition"]:::fact

  src_inp --> stg_inp
  src_hrrp --> stg_rd

  stg_inp --> dim_prov
  stg_inp --> dim_drg
  stg_inp --> dim_geo
  stg_inp --> fact_chg
  stg_rd  --> fact_rd

  dim_prov --> fact_chg
  dim_drg  --> fact_chg
  dim_geo  --> fact_chg
  dim_prov --> fact_rd
  dim_geo  --> fact_rd

  classDef src  fill:#e9f4f1,stroke:#1f7a6b,color:#1c1b18;
  classDef stg  fill:#fff,stroke:#1f7a6b,color:#1c1b18;
  classDef dim  fill:#f6f4ef,stroke:#605b50,color:#1c1b18;
  classDef fact fill:#1f7a6b,stroke:#1f7a6b,color:#fff;
```

**Reading it:** two raw CMS extracts → two staging views → the marts. `dim_provider` feeds **both** facts — that's the conformed key (CCN) that makes cost-vs-quality possible. The cross-fact `relationships` test in `dbt/models/marts/_schema.yml` enforces that every `fact_readmissions.provider_sk` resolves in `dim_provider`.

See [`results/dbt_run.log`](../results/dbt_run.log) and [`results/dbt_test.log`](../results/dbt_test.log) for the build that produced these row counts (7 models, 19/19 tests passing).
