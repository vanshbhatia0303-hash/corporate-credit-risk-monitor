---
title: Corporate Credit Risk Monitor
sidebar: never
---

# Which REITs are drifting toward covenant stress?

Tracks **Debt/EBITDA** and **interest coverage** (both on a trailing-four-quarter basis) over each company's last 8 reported quarters, for a basket of 50 US-listed REITs, using SEC EDGAR XBRL filings. Latest data snapshot: <Value data={meta} column=exported />. Use the filters to slice the list; every section below responds.

```sql meta
select strftime(exported_at, '%d %b %Y') as exported from credit.snapshot_meta
```

```sql sectors
select distinct sector from credit.stress_ranking order by sector
```

```sql scored
select
  stress_rank, coalesce(stress_rank, 999) as rank_sort, ticker, company_name, sector, rank_status,
  case when rank_status = 'ranked' then printf('%.1fx to %.1fx', first_debt_to_ebitda, latest_debt_to_ebitda) end as leverage_path,
  case when rank_status = 'ranked' then printf('%.1fx to %.1fx', first_interest_coverage, latest_interest_coverage) end as coverage_path,
  coalesce(stress_score, 0) as stress_score,
  first_debt_to_ebitda, latest_debt_to_ebitda, first_interest_coverage, latest_interest_coverage,
  latest_debt_to_ebitda - first_debt_to_ebitda as lev_change,
  latest_interest_coverage - first_interest_coverage as cov_change,
  case when rank_status <> 'ranked' then 'Not ranked' when drifting_toward_stress then 'Drifting toward stress' else 'Stable or improving' end as trend,
  case when rank_status <> 'ranked' then 'n/a' when latest_debt_to_ebitda >= 8 or latest_interest_coverage < 2.5 then 'High' when latest_debt_to_ebitda >= 6 or latest_interest_coverage < 4 then 'Elevated' else 'Moderate' end as risk_level,
  case when rank_status <> 'ranked' then 'Not ranked' when is_sec_lag then 'Ranked, awaiting SEC data' else 'Ranked, up to date' end as data_status,
  case when rank_status = 'insufficient_history' then 'Fewer than 6 recent quarters of usable ratios' when rank_status = 'not_current' then 'Latest usable ratios are over 9 months old (a required input stopped being reported)' when is_sec_lag then 'Newer 10-Q is on file but SEC has not yet published its figures, so ratios stop a quarter earlier' else '' end as reason,
  ebitda_basis, latest_period, latest_filed_period
from credit.stress_ranking
```

<Grid cols=2>
  <Dropdown name=sector title="Sub-sector" data={sectors} value=sector defaultValue="%">
    <DropdownOption value="%" valueLabel="All sub-sectors" />
  </Dropdown>
  <Dropdown name=data_status title="Data status" defaultValue="%">
    <DropdownOption value="%" valueLabel="All" />
    <DropdownOption value="Ranked, up to date" />
    <DropdownOption value="Ranked, awaiting SEC data" />
    <DropdownOption value="Not ranked" />
  </Dropdown>
  <ButtonGroup name=trend title="Trend">
    <ButtonGroupItem valueLabel="All" value="%" default />
    <ButtonGroupItem valueLabel="Drifting" value="Drifting toward stress" />
    <ButtonGroupItem valueLabel="Stable" value="Stable or improving" />
  </ButtonGroup>
  <Dropdown name=min_score title="Minimum stress score" defaultValue="0">
    <DropdownOption value="0" valueLabel="Any" />
    <DropdownOption value="50" valueLabel="50 or higher" />
    <DropdownOption value="70" valueLabel="70 or higher" />
    <DropdownOption value="85" valueLabel="85 or higher" />
  </Dropdown>
</Grid>

```sql filtered
select * from ${scored}
where ('${inputs.sector.value}' in ('', 'undefined', 'null') or sector ilike '${inputs.sector.value}')
  and ('${inputs.data_status.value}' in ('', 'undefined', 'null') or data_status ilike '${inputs.data_status.value}')
  and ('${inputs.trend.value}' in ('', 'undefined', 'null') or trend ilike '${inputs.trend.value}')
  and stress_score >= coalesce(try_cast(nullif(nullif('${inputs.min_score.value}', 'undefined'), '') as double), 0)
```

```sql summary
select count(*) as shown,
  count(*) filter (where rank_status = 'ranked') as ranked,
  count(*) filter (where trend = 'Drifting toward stress') as drifting,
  count(*) filter (where risk_level = 'High') as high_risk,
  count(*) filter (where data_status = 'Ranked, awaiting SEC data') as awaiting
from ${filtered}
```

<Grid cols=4>
  <BigValue data={summary} value=shown title="Companies shown" />
  <BigValue data={summary} value=drifting title="Drifting toward stress" />
  <BigValue data={summary} value=high_risk title="High risk level" />
  <BigValue data={summary} value=awaiting title="Ranked, awaiting SEC data" />
</Grid>

**In this selection:** <Value data={summary} column=drifting /> of <Value data={summary} column=ranked /> ranked companies show leverage rising and coverage falling together, and <Value data={summary} column=high_risk /> sit at a High risk level today.

## Stress ranking

```sql ranking
select * from ${filtered} order by stress_rank nulls last, company_name
```

<DataTable data={ranking} rows=20 search=true wrapTitles=true sort="rank_sort asc">
  <Column id=stress_rank title="Rank" />
  <Column id=company_name title="Company" />
  <Column id=sector title="Sub-sector" />
  <Column id=trend title="Trend" />
  <Column id=risk_level title="Risk level" />
  <Column id=stress_score title="Stress score (0-100)" fmt=num1 />
  <Column id=leverage_path title="Debt/EBITDA: 8 qtrs ago to now" />
  <Column id=coverage_path title="Interest coverage: 8 qtrs ago to now" />
  <Column id=data_status title="Data status" />
</DataTable>

## Analyst commentary

*Written on the <Value data={meta} column=exported /> snapshot; refresh the commentary when the data is refreshed.*

- **Stress is concentrated, not broad.** Twelve of 43 ranked names are flagged as drifting, but most of those moves are small. Only **ARE** (Debt/EBITDA 7.9x to 25.8x, coverage 10.0x to 2.0x) and **PK** (4.5x to 12.0x, coverage 4.1x to 1.6x) combine a large leverage increase with coverage below 2.5x. Those two are where covenant conversations are most likely.
- **Rank is relative, risk is absolute.** The stress score ranks trends against peers. **PSA** ranks 4th, yet sits at 3.1x leverage with about 10x coverage, a comfortable cushion that is only drifting slightly. Read the *Risk level* column next to the rank.
- **Treat ARE's number as a flag, not a verdict.** Its EBITDA is built from net income, which includes impairment charges, so the jump to 25.8x is probably overstated. It deserves a closer look rather than a conclusion.
- **Mid-pack names worth watching:** **MAA**, **DOC**, **CUZ**, **HIW** and **ADC** are all drifting the wrong way, but from healthy starting points. The early-warning value is in seeing them move before a rating agency does.
- **Data freshness matters.** Thirteen companies (nine of them ranked) have filed a Q2 2026 10-Q that SEC's structured-data API has not yet published, so their ratios are as of Q1 2026 (see *Data status* below).

## Where everyone sits

```sql scatter
select * from ${filtered} where rank_status = 'ranked'
```

<ScatterPlot data={scatter} x=lev_change y=cov_change series=sector tooltipTitle=company_name xAxisTitle="Change in Debt/EBITDA over the window (x)" yAxisTitle="Change in interest coverage (x)" />

Each dot is one company. **Lower right** (leverage up, coverage down) is the stress zone; upper left is improving.

## Company drill-down

```sql companies
select ticker, company_name from credit.stress_ranking order by company_name
```

<Dropdown name=company title="Company" data={companies} value=ticker label=company_name defaultValue="ARE" />

```sql history
select period_end, debt_to_ebitda, interest_coverage
from credit.metrics_quarterly
where ticker = '${inputs.company.value}' and debt_to_ebitda is not null
order by period_end
```

<Grid cols=2>
  <LineChart data={history} x=period_end y=debt_to_ebitda title="Debt / EBITDA, trailing four quarters (x)" yFmt=num1 />
  <LineChart data={history} x=period_end y=interest_coverage title="Interest coverage, trailing four quarters (x)" yFmt=num1 />
</Grid>

## Data status: who is not fully current, and why

```sql quality
select company_name, sector, data_status, latest_period, latest_filed_period, reason, ebitda_basis
from ${scored}
where data_status <> 'Ranked, up to date'
order by data_status, company_name
```

<DataTable data={quality} rows=20 search=true wrapTitles=true>
  <Column id=company_name title="Company" />
  <Column id=sector title="Sub-sector" />
  <Column id=data_status title="Data status" />
  <Column id=latest_period title="Latest quarter with ratios" />
  <Column id=latest_filed_period title="Latest quarter filed with SEC" />
  <Column id=reason title="Why" />
  <Column id=ebitda_basis title="EBITDA built from" />
</DataTable>

## Glossary: what each column means

| Term | Meaning |
|---|---|
| **Stress score (0-100)** | Average percentile rank of two trends over the company's last 8 quarters: how fast Debt/EBITDA is rising, and how fast interest coverage is falling. 100 is the worst trend in the basket. It compares companies with each other; it is not an absolute risk measure. |
| **Rank** | Position by stress score. 1 is most stressed; ties share a rank. |
| **Debt/EBITDA (x)** | Total debt divided by trailing-four-quarter EBITDA. Higher means more leveraged. "8 qtrs ago" is the oldest quarter in the window, "now" the latest. |
| **Interest coverage (x)** | Trailing-four-quarter EBITDA divided by trailing-four-quarter interest expense. Lower means a thinner cushion before covenants bite. |
| **Trend** | *Drifting toward stress*: leverage rose and coverage fell across the window. *Stable or improving*: otherwise. *Not ranked*: too little usable data. |
| **Risk level** | Rule of thumb on the latest values. *High*: Debt/EBITDA of 8x or more, or coverage under 2.5x. *Elevated*: 6x or more, or coverage under 4x. *Moderate*: otherwise. Illustrative thresholds, not covenant or rating-agency lines. |
| **Data status** | *Ranked, up to date*: latest filing is reflected. *Ranked, awaiting SEC data*: the company has filed a newer 10-Q, but SEC has not yet published its structured figures, so ratios are one quarter old. *Not ranked*: too little recent history or a missing input. |
| **Why** | The plain-English reason behind any status other than "up to date". |
| **Latest quarter with ratios / filed with SEC** | The most recent quarter we could compute ratios for, versus the most recent quarter the company has filed. A gap between them is the freshness issue. |
| **EBITDA built from** | SEC filings have no EBITDA line, so it is derived. Preferred: operating income + D&A. Fallbacks: pre-tax income + interest + D&A, or net income + (tax) + interest + D&A. The fallbacks include one-off gains and impairments, so they are less clean. |
| **Total debt** | The largest of the debt tags a company reports (long-term debt, notes, secured plus unsecured, etc.), rejected if under 3% of assets. Debt components never exceed their total, so taking the largest avoids undercounting. |
| **Trailing four quarters (TTM)** | The sum of the latest four quarters, which smooths seasonality. A ratio needs four consecutive quarters of data. |

<style>
  @page { size: A4 landscape; margin: 10mm; }
</style>