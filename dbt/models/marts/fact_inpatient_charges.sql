{{ config(materialized='table') }}

-- Grain: one row per hospital × DRG. The natural grain of the source.
-- Measures are a mix of additive (discharges) and non-additive averages
-- (the charge/payment columns are already per-discharge averages, so they
-- must be weighted by discharges when rolled up — see docs/star_schema.md).

with c as (
    select * from {{ ref('stg_inpatient_charges') }}
)

select
    c.ccn,
    c.drg_code,
    p.provider_sk,
    d.drg_sk,
    g.geo_sk,

    -- additive
    c.total_discharges,

    -- per-discharge averages (non-additive; weight by discharges to roll up)
    c.avg_covered_charge,
    c.avg_total_payment,
    c.avg_medicare_payment,
    c.markup_ratio,
    c.medicare_share,

    -- pre-weighted helpers so dashboards can SUM then divide
    c.avg_covered_charge   * c.total_discharges  as wtd_covered_charge,
    c.avg_medicare_payment * c.total_discharges  as wtd_medicare_payment

from c
left join {{ ref('dim_provider') }}  p on c.ccn   = p.ccn
left join {{ ref('dim_drg') }}       d on c.drg_code = d.drg_code
left join {{ ref('dim_geography') }} g on c.provider_state = g.state_code
