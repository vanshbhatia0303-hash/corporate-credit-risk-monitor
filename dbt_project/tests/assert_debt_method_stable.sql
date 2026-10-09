{{ config(severity='warn') }}
select ticker, count(distinct debt_method) as n_methods, string_agg(distinct debt_method, ', ') as methods
from (select *, row_number() over (partition by cik order by period_end desc) as rn from {{ ref('fct_credit_metrics_quarterly') }} where debt_to_ebitda is not null) where rn <= 8
group by 1 having count(distinct debt_method) > 1
