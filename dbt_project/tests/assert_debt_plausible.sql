{{ config(severity='warn') }}
select ticker, period_end, debt_method, total_debt, total_assets from {{ ref('fct_credit_metrics_quarterly') }}
where total_debt is null or total_debt > 0.8 * total_assets
qualify row_number() over (partition by cik order by period_end desc) = 1
