/*
  Q3 — Does spending buy quality?  (The two-fact join.)

  Join the cost side (fact_inpatient_charges) to the quality side
  (fact_readmissions) through the conformed dim_provider, and ask: do
  hospitals that Medicare pays more per discharge have lower 30-day
  excess-readmission ratios?

  Bucket hospitals into payment quintiles and show the mean excess-
  readmission ratio per quintile. A flat line across quintiles is the
  "we pay more but don't get better outcomes" finding.

  Technique: cross-fact aggregation through a conformed dimension, NTILE
  bucketing, correlation in SQL.
*/

with provider_cost as (
    -- one mean Medicare payment per hospital (discharge-weighted)
    select
        provider_sk,
        sum(wtd_medicare_payment) / nullif(sum(total_discharges),0) as mean_medicare_pay
    from marts.fact_inpatient_charges
    group by provider_sk
),
provider_quality as (
    -- one mean excess-readmission ratio per hospital (across conditions)
    select
        provider_sk,
        avg(excess_readmission_ratio) as mean_excess_readmit
    from marts.fact_readmissions
    group by provider_sk
),
joined as (
    select
        c.provider_sk,
        c.mean_medicare_pay,
        q.mean_excess_readmit,
        ntile(5) over (order by c.mean_medicare_pay) as pay_quintile
    from provider_cost c
    join provider_quality q using (provider_sk)   -- conformed-dim join
    where q.mean_excess_readmit is not null
)

select
    pay_quintile,
    count(*)                                  as n_hospitals,
    round(avg(mean_medicare_pay), 0)          as avg_medicare_pay,
    round(avg(mean_excess_readmit), 4)        as avg_excess_readmit_ratio
from joined
group by pay_quintile
order by pay_quintile;

-- And the single-number version: the correlation across all hospitals.
-- (Run separately.)
--   select round(corr(mean_medicare_pay, mean_excess_readmit), 3) as r
--   from joined;
