select filing_key, cast(cik as bigint) as cik, ticker, accn, form, cast(filing_date as date) as filing_date, try_cast(report_date as date) as report_date
from {{ source('raw', 'filings') }}
