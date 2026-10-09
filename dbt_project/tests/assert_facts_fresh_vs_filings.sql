{{ config(severity='warn') }}
select ticker, latest_period, latest_facts_period, latest_filed_period, is_sec_lag, has_metric_gap from {{ ref('mart_stress_ranking') }} where is_stale
