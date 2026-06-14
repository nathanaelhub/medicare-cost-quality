{{ config(materialized='view') }}

-- HRRP ships everything as strings with 'N/A' / 'Not Available' sprinkled
-- in (suppressed small cells). try_cast turns those into nulls cleanly.
-- Measure names look like READM-30-HIP-KNEE-HRRP; we shorten to a
-- condition label for grouping.

with src as (
    select * from {{ source('raw', 'hrrp_readmissions') }}
)

select
    Facility_ID                                       as ccn,
    initcap(Facility_Name)                            as facility_name,
    upper(State)                                      as state,
    Measure_Name                                      as measure_raw,
    case Measure_Name
        when 'READM-30-AMI-HRRP'      then 'Heart attack'
        when 'READM-30-HF-HRRP'       then 'Heart failure'
        when 'READM-30-PN-HRRP'       then 'Pneumonia'
        when 'READM-30-COPD-HRRP'     then 'COPD'
        when 'READM-30-HIP-KNEE-HRRP' then 'Hip/knee replacement'
        when 'READM-30-CABG-HRRP'     then 'CABG (bypass)'
        else Measure_Name
    end                                               as condition,
    try_cast(Number_of_Discharges as number)          as discharges,
    try_cast(Excess_Readmission_Ratio as float)       as excess_readmission_ratio,
    try_cast(Predicted_Readmission_Rate as float)     as predicted_rate,
    try_cast(Expected_Readmission_Rate as float)      as expected_rate,
    try_cast(Number_of_Readmissions as number)        as readmissions
from src
where Facility_ID is not null
