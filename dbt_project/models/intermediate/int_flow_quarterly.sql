{{ config(materialized='table') }}
with f as (
select cik, concept, period_start, period_end, duration_days, val from {{ ref('stg_facts') }}
where duration_days is not null and concept in ('OperatingIncomeLoss','InterestExpense','InterestExpenseDebt','InterestExpenseNonoperating','InterestAndDebtExpense','DepreciationDepletionAndAmortization','DepreciationAndAmortization','DepreciationAmortizationAndAccretionNet','RealEstateInvestmentPropertyDepreciation','Revenues','NetIncomeLoss','IncomeTaxExpenseBenefit','IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest','Depreciation','InterestExpenseDebtExcludingAmortization','ProfitLoss','NetIncomeLossAvailableToCommonStockholdersBasic','InterestExpenseBorrowings','InterestExpenseOperating')
),
cum as (
select *, case when duration_days between 80 and 100 then 3 when duration_days between 170 and 195 then 6 when duration_days between 260 and 290 then 9 when duration_days between 350 and 380 then 12 end as m from f
),
cand as (
select cik, concept, period_end, val, 'direct' as derivation, abs(duration_days - 91) as dist from cum where m = 3
union all
select c.cik, c.concept, c.period_end, c.val - p.val, 'ytd_diff', 1000
from cum c join cum p on c.cik = p.cik and c.concept = p.concept and c.period_start = p.period_start and c.m = p.m + 3
)
select cik, concept, period_end, val, derivation from cand
qualify row_number() over (partition by cik, concept, period_end order by dist) = 1

