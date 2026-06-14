{{ config(materialized='view') }}

-- Rename CMS's machine field names to readable ones, cast the numerics,
-- and compute the two ratio measures every downstream question needs:
--   markup_ratio          = charge / Medicare payment (the "list price" gap)
--   medicare_share        = Medicare payment / total payment

with src as (
    select * from {{ source('raw', 'inpatient_charges') }}
)

select
    Rndrng_Prvdr_CCN                                  as ccn,
    initcap(Rndrng_Prvdr_Org_Name)                    as provider_name,
    initcap(Rndrng_Prvdr_City)                        as provider_city,
    upper(Rndrng_Prvdr_State_Abrvtn)                  as provider_state,
    Rndrng_Prvdr_Zip5                                 as provider_zip,
    Rndrng_Prvdr_RUCA                                 as ruca_code,
    DRG_Cd                                            as drg_code,
    DRG_Desc                                          as drg_desc,
    Tot_Dschrgs::number                               as total_discharges,
    Avg_Submtd_Cvrd_Chrg::number(14,2)                as avg_covered_charge,
    Avg_Tot_Pymt_Amt::number(14,2)                    as avg_total_payment,
    Avg_Mdcr_Pymt_Amt::number(14,2)                   as avg_medicare_payment,
    round(Avg_Submtd_Cvrd_Chrg
          / nullif(Avg_Mdcr_Pymt_Amt, 0), 2)          as markup_ratio,
    round(Avg_Mdcr_Pymt_Amt
          / nullif(Avg_Tot_Pymt_Amt, 0), 3)           as medicare_share
from src
where Avg_Mdcr_Pymt_Amt > 0
