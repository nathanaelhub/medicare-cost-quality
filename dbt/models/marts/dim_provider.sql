{{ config(materialized='table') }}

-- One row per hospital (CCN). SCD1 — hospital attributes are stable
-- enough at this grain that overwrite is the right call. Conformed: used
-- by both fact_inpatient_charges and fact_readmissions.
-- Built from the charges source (the wider provider list); HRRP-only
-- facilities are rare and fall back to a coalesce in the readmissions fact.

with charges as (
    select
        ccn,
        max(provider_name)  as provider_name,
        max(provider_city)  as provider_city,
        max(provider_state) as provider_state,
        max(provider_zip)   as provider_zip,
        max(ruca_code)      as ruca_code
    from {{ ref('stg_inpatient_charges') }}
    group by ccn
)

select
    {{ dbt_utils.generate_surrogate_key(['ccn']) }} as provider_sk,
    ccn,
    provider_name,
    provider_city,
    provider_state,
    provider_zip,
    case when try_cast(ruca_code as float) <= 3 then 'Metro'
         when try_cast(ruca_code as float) <= 6 then 'Micro'
         else 'Rural' end                           as urbanicity
from charges
