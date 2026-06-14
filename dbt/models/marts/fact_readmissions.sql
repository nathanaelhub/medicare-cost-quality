{{ config(materialized='table') }}

-- Grain: one row per hospital × readmission measure (6 conditions).
-- A SEPARATE fact from charges, at a different grain, conformed on
-- provider_sk. This is the second fact in the two-fact star — the whole
-- point of the project is being able to join cost (charges fact) to
-- quality (this fact) through the shared dim_provider.

with r as (
    select * from {{ ref('stg_readmissions') }}
    where excess_readmission_ratio is not null   -- drop suppressed cells
)

select
    r.ccn,
    r.condition,
    r.measure_raw,
    p.provider_sk,
    g.geo_sk,

    r.discharges,
    r.readmissions,
    r.excess_readmission_ratio,   -- >1.0 = worse than the risk-adjusted expectation
    r.predicted_rate,
    r.expected_rate

from r
left join {{ ref('dim_provider') }}  p on r.ccn   = p.ccn
left join {{ ref('dim_geography') }} g on r.state = g.state_code
