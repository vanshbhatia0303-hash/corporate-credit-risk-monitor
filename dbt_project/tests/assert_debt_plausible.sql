{{ config(severity='warn') }}
select * from (select ticker, period_end, debt_method, total_debt, total_assets, row_number() over (partition by cik order by period_end desc) as rn from {{ ref('fct_credit_metrics_quarterly') }}) where rn = 1 and (total_debt is null or total_debt > 0.8 * total_assets)
