{{ config(materialized='table') }}
with f as (
select cik, concept, period_start, period_end, duration_days, val from {{ ref('stg_facts') }}
where duration_days is not null and concept in ('OperatingIncomeLoss','InterestExpense','InterestExpenseDebt','InterestExpenseNonoperating','InterestAndDebtExpense','DepreciationDepletionAndAmortization','DepreciationAndAmortization','DepreciationAmortizationAndAccretionNet','RealEstateInvestmentPropertyDepreciation','Revenues','NetIncomeLoss','IncomeTaxExpenseBenefit','IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest')
),
fy as (select cik, concept, period_start, period_end, val from f where duration_days between 350 and 380),
ytd9 as (select cik, concept, period_start, val from f where duration_days between 260 and 290),
cand as (
select cik, concept, period_end, val, 'direct' as derivation, abs(duration_days - 91) as dist from f where duration_days between 80 and 100
union all
select fy.cik, fy.concept, fy.period_end, fy.val - y.val, 'fy_minus_9m', 1000 from fy join ytd9 y on fy.cik = y.cik and fy.concept = y.concept and fy.period_start = y.period_start
)
select cik, concept, period_end, val, derivation from cand
qualify row_number() over (partition by cik, concept, period_end order by dist) = 1
