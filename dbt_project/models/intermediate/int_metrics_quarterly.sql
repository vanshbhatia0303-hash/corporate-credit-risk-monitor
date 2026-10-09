with spine as (select distinct cik, period_end from {{ ref('int_balance_quarterly') }} where concept = 'Assets'),
bal as (
select cik, period_end,
max(case when concept = 'Assets' then val end) as total_assets,
max(case when concept = 'CashAndCashEquivalentsAtCarryingValue' then val end) as cash,
max(case when concept = 'LongTermDebt' then val end) as ltd,
max(case when concept = 'SecuredDebt' then val end) as secured,
max(case when concept = 'UnsecuredDebt' then val end) as unsecured,
max(case when concept = 'SeniorNotes' then val end) as senior_notes,
max(case when concept = 'LineOfCredit' then val end) as line_of_credit,
max(case when concept = 'LongTermDebtAndCapitalLeaseObligationsIncludingCurrentMaturities' then val end) as ltd_cl_incl,
max(case when concept = 'NotesAndLoansPayable' then val end) as notes_loans,
max(case when concept = 'DebtInstrumentCarryingAmount' then val end) as debt_carrying,
max(case when concept = 'NotesPayable' then val end) as notes_payable,
max(case when concept = 'DebtAndCapitalLeaseObligations' then val end) as debt_cap_lease,
max(case when concept = 'LongTermDebtAndCapitalLeaseObligations' then val end) as ltd_cl,
max(case when concept = 'LongTermDebtNoncurrent' then val end) as ltd_noncurrent,
max(case when concept = 'LongTermDebtCurrent' then val end) as ltd_current
from {{ ref('int_balance_quarterly') }} group by 1, 2
),
flow as (
select cik, period_end,
max(case when concept = 'Revenues' then val end) as revenues,
max(case when concept = 'OperatingIncomeLoss' then val end) as operating_income,
max(case when concept = 'IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest' then val end) as pretax_income,
coalesce(max(case when concept = 'NetIncomeLoss' then val end), max(case when concept = 'ProfitLoss' then val end), max(case when concept = 'NetIncomeLossAvailableToCommonStockholdersBasic' then val end)) as net_income,
max(case when concept = 'IncomeTaxExpenseBenefit' then val end) as income_tax,
coalesce(max(case when concept = 'InterestExpense' then val end), max(case when concept = 'InterestExpenseDebt' then val end), max(case when concept = 'InterestAndDebtExpense' then val end), max(case when concept = 'InterestExpenseNonoperating' then val end), max(case when concept = 'InterestExpenseDebtExcludingAmortization' then val end), max(case when concept = 'InterestExpenseBorrowings' then val end), max(case when concept = 'InterestExpenseOperating' then val end)) as interest_expense,
coalesce(max(case when concept = 'DepreciationDepletionAndAmortization' then val end), max(case when concept = 'DepreciationAndAmortization' then val end), max(case when concept = 'DepreciationAmortizationAndAccretionNet' then val end), max(case when concept = 'RealEstateInvestmentPropertyDepreciation' then val end), max(case when concept = 'Depreciation' then val end)) as depreciation_amortization
from {{ ref('int_flow_quarterly') }} group by 1, 2
),
j as (
select s.cik, s.period_end, b.total_assets, b.cash, f.revenues, f.operating_income, f.pretax_income, f.net_income, f.income_tax, f.interest_expense, f.depreciation_amortization,
coalesce(b.ltd, b.ltd_cl_incl, b.debt_cap_lease, case when b.senior_notes is not null then b.senior_notes + coalesce(b.line_of_credit, 0) + coalesce(b.secured, 0) + coalesce(b.unsecured, 0) end, case when (b.secured is not null or b.unsecured is not null) and coalesce(b.secured, 0) + coalesce(b.unsecured, 0) >= 0.1 * b.total_assets then coalesce(b.secured, 0) + coalesce(b.unsecured, 0) end, b.notes_loans, b.debt_carrying, b.notes_payable, b.ltd_cl, b.ltd_noncurrent + coalesce(b.ltd_current, 0)) as debt_raw,
case when b.ltd is not null then 'LongTermDebt' when b.ltd_cl_incl is not null then 'LongTermDebtAndCapitalLeaseObligationsIncludingCurrent' when b.debt_cap_lease is not null then 'DebtAndCapitalLeaseObligations' when b.senior_notes is not null then 'SeniorNotes+LineOfCredit+Secured+Unsecured' when (b.secured is not null or b.unsecured is not null) and coalesce(b.secured, 0) + coalesce(b.unsecured, 0) >= 0.1 * b.total_assets then 'Secured+Unsecured' when b.notes_loans is not null then 'NotesAndLoansPayable' when b.debt_carrying is not null then 'DebtInstrumentCarryingAmount' when b.notes_payable is not null then 'NotesPayable' when b.ltd_cl is not null then 'LongTermDebtAndCapitalLeaseObligations(noncurrent)' when b.ltd_noncurrent is not null then 'LongTermDebtNoncurrent+Current' end as method_raw
from spine s left join bal b using (cik, period_end) left join flow f using (cik, period_end)
)
select cast(cik as varchar) || '|' || cast(period_end as varchar) as quarter_id, * exclude (debt_raw, method_raw),
case when debt_raw < 0.03 * total_assets then null else debt_raw end as total_debt,
case when debt_raw < 0.03 * total_assets then 'rejected_under_3pct_of_assets' else method_raw end as debt_method,
case when depreciation_amortization is null then null when operating_income is not null then operating_income + depreciation_amortization when pretax_income is not null and interest_expense is not null then pretax_income + interest_expense + depreciation_amortization when net_income is not null and interest_expense is not null then net_income + coalesce(income_tax, 0) + interest_expense + depreciation_amortization end as ebitda,
case when depreciation_amortization is null then null when operating_income is not null then 'operating_income+da' when pretax_income is not null and interest_expense is not null then 'pretax+interest+da' when net_income is not null and interest_expense is not null then case when income_tax is null then 'net_income+interest+da (tax=0)' else 'net_income+tax+interest+da' end end as ebitda_method
from j

