{{ config(materialized='table') }}

-- One row per MS-DRG. Adds a service-line rollup derived from the DRG
-- code ranges (CMS groups DRGs into Major Diagnostic Categories; this is
-- a readable approximation good enough for portfolio-grade analysis).

with src as (
    select distinct drg_code, drg_desc
    from {{ ref('stg_inpatient_charges') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['drg_code']) }} as drg_sk,
    drg_code,
    drg_desc,
    case
        when try_cast(drg_code as number) between 1   and 14  then 'Transplants'
        when try_cast(drg_code as number) between 20  and 103 then 'Nervous system'
        when try_cast(drg_code as number) between 163 and 208 then 'Respiratory'
        when try_cast(drg_code as number) between 215 and 316 then 'Circulatory'
        when try_cast(drg_code as number) between 326 and 395 then 'Digestive'
        when try_cast(drg_code as number) between 453 and 566 then 'Musculoskeletal'
        when try_cast(drg_code as number) between 573 and 607 then 'Skin'
        when try_cast(drg_code as number) between 614 and 645 then 'Endocrine'
        when try_cast(drg_code as number) between 652 and 700 then 'Kidney/urinary'
        when try_cast(drg_code as number) between 763 and 795 then 'Pregnancy/newborn'
        when try_cast(drg_code as number) between 808 and 816 then 'Blood'
        when try_cast(drg_code as number) between 853 and 872 then 'Infectious/sepsis'
        else 'Other'
    end                                                  as service_line,
    -- flag the handful of high-volume "shoppable" DRGs the charts focus on
    case when drg_code in ('470','871','291','312','392','775')
         then true else false end                        as is_common_drg
from src
