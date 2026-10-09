{{ config(severity='warn') }}
select quarter_id, ticker, debt_to_ebitda, interest_coverage from {{ ref('fct_credit_metrics_quarterly') }} where debt_to_ebitda > 60 or interest_coverage < 0.5 or (interest_coverage > 100 and debt_to_ebitda > 2)
