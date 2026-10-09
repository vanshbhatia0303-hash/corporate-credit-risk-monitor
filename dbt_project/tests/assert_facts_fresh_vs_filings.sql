{{ config(severity='warn') }}
select ticker, latest_period, latest_filed_period, days_behind_filings from {{ ref('mart_stress_ranking') }} where is_stale
