with spine as (select distinct cik, period_end from {{ ref('int_balance_quarterly') }} where concept = 'Assets'),
bal as (
select cik, period_end,
max(case when concept = 'Assets' then val end) as total_assets,
max(case when concept = 'CashAndCashEquivalentsAtCarryingValue' then val end) as cash,
max(case when concept = 'LongTermDebt' then val end) as ltd,
max(case when concept = 'SecuredDebt' then val end) as secured,
max(case when concept = 'UnsecuredDebt' then val end) as unsecured,
max(case when concept = 'DebtInstrumentCarryingAmount' then val end) as debt_carrying,
max(case when concept = 'DebtAndCapitalLeaseObligations' then val end) as debt_cap_lease,
max(case when concept = 'LongTermDebtNoncurrent' then val end) as ltd_noncurrent,
max(case when concept = 'LongTermDebtCurrent' then val end) as ltd_current
from {{ ref('int_balance_quarterly') }} group by 1, 2
),
flow as (
select cik, period_end,
max(case when concept = 'Revenues' then val end) as revenues,
max(case when concept = 'OperatingIncomeLoss' then val end) as operating_income,
max(case when concept = 'IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest' then val end) as pretax_income,
max(case when concept = 'NetIncomeLoss' then val end) as net_income,
max(case when concept = 'IncomeTaxExpenseBenefit' then val end) as income_tax,
coalesce(max(case when concept = 'InterestExpense' then val end), max(case when concept = 'InterestExpenseDebt' then val end), max(case when concept = 'InterestAndDebtExpense' then val end), max(case when concept = 'InterestExpenseNonoperating' then val end)) as interest_expense,
coalesce(max(case when concept = 'DepreciationDepletionAndAmortization' then val end), max(case when concept = 'DepreciationAndAmortization' then val end), max(case when concept = 'DepreciationAmortizationAndAccretionNet' then val end), max(case when concept = 'RealEstateInvestmentPropertyDepreciation' then val end)) as depreciation_amortization
from {{ ref('int_flow_quarterly') }} group by 1, 2
),
j as (
select s.cik, s.period_end, b.total_assets, b.cash, f.revenues, f.operating_income, f.pretax_income, f.net_income, f.income_tax, f.interest_expense, f.depreciation_amortization,
coalesce(b.ltd, case when b.secured is not null or b.unsecured is not null then coalesce(b.secured, 0) + coalesce(b.unsecured, 0) end, b.debt_carrying, b.debt_cap_lease, b.ltd_noncurrent + coalesce(b.ltd_current, 0)) as total_debt,
case when b.ltd is not null then 'LongTermDebt' when b.secured is not null or b.unsecured is not null then 'Secured+Unsecured' when b.debt_carrying is not null then 'DebtInstrumentCarryingAmount' when b.debt_cap_lease is not null then 'DebtAndCapitalLeaseObligations' when b.ltd_noncurrent is not null then 'LongTermDebtNoncurrent+Current' end as debt_method
from spine s left join bal b using (cik, period_end) left join flow f using (cik, period_end)
)
select cast(cik as varchar) || '|' || cast(period_end as varchar) as quarter_id, *,
case when depreciation_amortization is null then null when operating_income is not null then operating_income + depreciation_amortization when pretax_income is not null and interest_expense is not null then pretax_income + interest_expense + depreciation_amortization when net_income is not null and income_tax is not null and interest_expense is not null then net_income + income_tax + interest_expense + depreciation_amortization end as ebitda,
case when depreciation_amortization is null then null when operating_income is not null then 'operating_income+da' when pretax_income is not null and interest_expense is not null then 'pretax+interest+da' when net_income is not null and income_tax is not null and interest_expense is not null then 'net_income+tax+interest+da' end as ebitda_method
from j
