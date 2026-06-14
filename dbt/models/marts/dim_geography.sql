{{ config(materialized='table') }}

-- Conformed US-state → census-region geography, shared by both facts.

with states as (
    select distinct provider_state as state_code
    from {{ ref('stg_inpatient_charges') }}
    where provider_state is not null
)

select
    {{ dbt_utils.generate_surrogate_key(['state_code']) }} as geo_sk,
    state_code,
    case
        when state_code in ('CT','ME','MA','NH','RI','VT','NJ','NY','PA') then 'Northeast'
        when state_code in ('IL','IN','MI','OH','WI','IA','KS','MN','MO','NE','ND','SD') then 'Midwest'
        when state_code in ('DE','FL','GA','MD','NC','SC','VA','DC','WV','AL','KY','MS','TN','AR','LA','OK','TX') then 'South'
        when state_code in ('AZ','CO','ID','MT','NV','NM','UT','WY','AK','CA','HI','OR','WA') then 'West'
        else 'Other'
    end                                                    as census_region
from states
