with ranked as (
select cast(cik as bigint) as cik, ticker, concept, try_cast(period_start as date) as period_start, cast(period_end as date) as period_end, cast(val as double) as val, accn, form, cast(filed as date) as filed,
row_number() over (partition by cik, concept, period_start, period_end order by filed desc, accn desc) as rn
from {{ source('raw', 'facts') }}
)
select cast(cik as varchar) || '|' || concept || '|' || coalesce(cast(period_start as varchar), '') || '|' || cast(period_end as varchar) as fact_id,
cik, ticker, concept, period_start, period_end,
case when period_start is not null then date_diff('day', period_start, period_end) + 1 end as duration_days,
val, accn, form, filed
from ranked
where rn = 1
