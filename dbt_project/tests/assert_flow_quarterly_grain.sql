select cik, concept, period_end, count(*) as n from {{ ref('int_flow_quarterly') }} group by 1, 2, 3 having count(*) > 1
