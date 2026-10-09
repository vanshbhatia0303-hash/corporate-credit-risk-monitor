select quarter_id, total_debt from {{ ref('fct_credit_metrics_quarterly') }} where total_debt < 0
