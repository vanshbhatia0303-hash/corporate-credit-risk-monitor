import os, duckdb
c = duckdb.connect(os.environ["WAREHOUSE_PATH"], read_only=True)
rows = c.sql("select ticker, latest_period, latest_filed_period, is_sec_lag, has_metric_gap from marts.mart_stress_ranking where is_stale order by 1").fetchall()
print(f"{len(rows)} stale companies (SEC lag: {sum(r[3] for r in rows)}, metric gap: {sum(r[4] for r in rows)})")
for r in rows: print(*r)