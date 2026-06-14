/*
  RAW layer — one table per CMS extract, column names matched exactly
  to the published data dictionaries so the COPY INTO is positional and
  obvious. Staging models (dbt) do the rename + cast.

      snow sql -f snowflake/ddl/02_raw_tables.sql
*/

USE WAREHOUSE LOAD_WH;
USE DATABASE CMS;
USE SCHEMA RAW;

-- 1. Medicare Inpatient Hospitals — by Provider and Service
--    https://data.cms.gov/provider-summary-by-type-of-service/medicare-inpatient-hospitals
--    Field names per the official data dictionary (RY22+).
CREATE OR REPLACE TABLE inpatient_charges (
    Rndrng_Prvdr_CCN            STRING NOT NULL,   -- CMS Certification Number (joins to HRRP Facility ID)
    Rndrng_Prvdr_Org_Name       STRING,
    Rndrng_Prvdr_City           STRING,
    Rndrng_Prvdr_State_Abrvtn   STRING,
    Rndrng_Prvdr_State_FIPS     STRING,
    Rndrng_Prvdr_Zip5           STRING,
    Rndrng_Prvdr_RUCA           STRING,            -- rural-urban commuting area code
    Rndrng_Prvdr_RUCA_Desc      STRING,
    DRG_Cd                      STRING NOT NULL,   -- MS-DRG code
    DRG_Desc                    STRING,
    Tot_Dschrgs                 NUMBER,            -- total discharges in this DRG
    Avg_Submtd_Cvrd_Chrg        NUMBER(14,2),      -- avg charge the hospital billed
    Avg_Tot_Pymt_Amt            NUMBER(14,2),      -- avg total payment (Medicare + patient + others)
    Avg_Mdcr_Pymt_Amt           NUMBER(14,2)       -- avg Medicare payment
);

-- 2. Hospital Readmissions Reduction Program (HRRP)
--    https://data.cms.gov/provider-data/dataset/9n3s-kdb3
--    One row per (facility, measure). Facility ID == the CCN above.
CREATE OR REPLACE TABLE hrrp_readmissions (
    Facility_Name               STRING,
    Facility_ID                 STRING NOT NULL,   -- == Rndrng_Prvdr_CCN
    State                       STRING,
    Measure_Name                STRING,            -- e.g. READM-30-HIP-KNEE-HRRP
    Number_of_Discharges        STRING,            -- string in source ('N/A' appears); cast in staging
    Footnote                    STRING,
    Excess_Readmission_Ratio    STRING,            -- string in source; cast in staging
    Predicted_Readmission_Rate  STRING,
    Expected_Readmission_Rate   STRING,
    Number_of_Readmissions      STRING,
    Start_Date                  STRING,
    End_Date                    STRING
);

SELECT
    (SELECT COUNT(*) FROM inpatient_charges)  AS n_inpatient_rows,
    (SELECT COUNT(*) FROM hrrp_readmissions)  AS n_hrrp_rows;
