/*
  Q2 — The markup gap.

  "Covered charges" are a list price almost nobody pays. How far above the
  actual Medicare payment do they sit, by service line? Discharge-weighted
  so a high-volume DRG counts more than a rare one.

  Technique: weighted aggregation (sum of weighted measures / sum of
  weights) — the correct way to roll up per-discharge averages.
*/

select
    d.service_line,
    sum(f.total_discharges)                                  as discharges,
    -- discharge-weighted average charge and Medicare payment
    round(sum(f.wtd_covered_charge)   / sum(f.total_discharges), 0) as wavg_charge,
    round(sum(f.wtd_medicare_payment) / sum(f.total_discharges), 0) as wavg_medicare_pay,
    -- the markup: weighted charge / weighted payment
    round(
        (sum(f.wtd_covered_charge)   / sum(f.total_discharges))
      / (sum(f.wtd_medicare_payment) / sum(f.total_discharges)), 2
    )                                                        as markup_ratio
from marts.fact_inpatient_charges f
join marts.dim_drg d on f.drg_sk = d.drg_sk
group by d.service_line
having sum(f.total_discharges) > 1000
order by markup_ratio desc;
