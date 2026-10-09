select cast(cik as bigint) as cik, ticker, name as company_name, subsector
from {{ source('raw', 'companies') }}
