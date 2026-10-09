with w as (
select quarter_id, cik, period_end, total_assets, cash, total_debt, debt_method, ebitda, ebitda_method, interest_expense,
sum(ebitda) over win as s_ebitda, count(ebitda) over win as n_ebitda, sum(interest_expense) over win as s_int, count(interest_expense) over win as n_int,
count(*) over win as n_rows, min(period_end) over win as win_start
from {{ ref('int_metrics_quarterly') }}
window win as (partition by cik order by period_end rows between 3 preceding and current row)
),
t as (
select *, n_rows = 4 and date_diff('day', win_start, period_end) <= 290 as full_window,
case when n_rows = 4 and n_ebitda = 4 and date_diff('day', win_start, period_end) <= 290 then s_ebitda end as ttm_ebitda,
case when n_rows = 4 and n_int = 4 and date_diff('day', win_start, period_end) <= 290 then s_int end as ttm_interest
from w
)
select t.quarter_id, t.cik, c.ticker, c.company_name, c.subsector, t.period_end, t.total_assets, t.cash, t.total_debt, t.debt_method, t.ebitda, t.ebitda_method, t.interest_expense, t.ttm_ebitda, t.ttm_interest,
case when t.total_debt is not null and t.ttm_ebitda > 0 then t.total_debt / t.ttm_ebitda end as debt_to_ebitda,
case when t.ttm_ebitda is not null and t.ttm_interest > 0 then t.ttm_ebitda / t.ttm_interest end as interest_coverage
from t join {{ ref('stg_companies') }} c using (cik)
