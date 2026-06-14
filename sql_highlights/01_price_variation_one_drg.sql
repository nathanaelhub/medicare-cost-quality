/*
  Q1 — Same procedure, different price.

  For DRG 470 (major joint replacement w/o complications — one of the most
  common, most "shoppable" inpatient procedures), how wide is the spread of
  average covered charges across hospitals?

  Technique: percentile window functions to get the distribution shape
  (p10 / median / p90 / max) plus the fold-difference, in one pass.
*/

with drg470 as (
    select
        f.avg_covered_charge,
        f.avg_medicare_payment,
        p.provider_state
    from marts.fact_inpatient_charges f
    join marts.dim_drg d on f.drg_sk = d.drg_sk
    join marts.dim_provider p on f.provider_sk = p.provider_sk
    where d.drg_code = '470'
)

select
    count(*)                                                     as n_hospitals,
    min(avg_covered_charge)                                      as min_charge,
    percentile_cont(0.10) within group (order by avg_covered_charge) as p10_charge,
    percentile_cont(0.50) within group (order by avg_covered_charge) as median_charge,
    percentile_cont(0.90) within group (order by avg_covered_charge) as p90_charge,
    max(avg_covered_charge)                                      as max_charge,
    round(max(avg_covered_charge) / nullif(min(avg_covered_charge),0), 1) as fold_difference,
    -- for contrast: how much does the Medicare *payment* actually vary?
    round(
      percentile_cont(0.90) within group (order by avg_medicare_payment)
      / nullif(percentile_cont(0.10) within group (order by avg_medicare_payment),0), 1
    )                                                            as medicare_pay_p90_p10_ratio
from drg470;
