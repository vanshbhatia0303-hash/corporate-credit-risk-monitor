with ranked as (
select *, row_number() over (partition by cik order by period_end desc) as rn
from {{ ref('fct_credit_metrics_quarterly') }} where debt_to_ebitda is not null and interest_coverage is not null
),
win as (select *, date_diff('day', date '2000-01-01', period_end) / 365.25 as yrs from ranked where rn <= 8),
agg as (
select cik, ticker, company_name, subsector, count(*) as quarters_in_window, max(period_end) as latest_period, min(period_end) as window_start,
regr_slope(debt_to_ebitda, yrs) as leverage_slope_per_yr, regr_slope(interest_coverage, yrs) as coverage_slope_per_yr,
arg_max(debt_to_ebitda, period_end) as latest_debt_to_ebitda, arg_min(debt_to_ebitda, period_end) as first_debt_to_ebitda,
arg_max(interest_coverage, period_end) as latest_interest_coverage, arg_min(interest_coverage, period_end) as first_interest_coverage,
arg_max(ebitda_method, period_end) as latest_ebitda_method
from win group by 1, 2, 3, 4
),
fil as (select cik, max(report_date) as latest_filed_period from {{ ref('stg_filings') }} where form in ('10-Q', '10-K') group by 1),
j as (
select a.*, f.latest_filed_period, coalesce(f.latest_filed_period > a.latest_period, false) as is_stale, date_diff('day', a.latest_period, f.latest_filed_period) as days_behind_filings,
a.quarters_in_window >= 6 and date_diff('day', a.window_start, a.latest_period) <= 800 as has_enough_history,
a.leverage_slope_per_yr > 0 and a.coverage_slope_per_yr < 0 as drifting_toward_stress
from agg a left join fil f using (cik)
),
scored as (
select *, case when has_enough_history then percent_rank() over (partition by has_enough_history order by leverage_slope_per_yr) + percent_rank() over (partition by has_enough_history order by coverage_slope_per_yr desc) end as raw_score
from j
)
select * exclude (raw_score), round(100 * raw_score / 2, 1) as stress_score,
case when has_enough_history then rank() over (partition by has_enough_history order by raw_score desc) end as stress_rank
from scored
