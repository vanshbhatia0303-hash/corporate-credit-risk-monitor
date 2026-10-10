FROM astrocrpublic.azurecr.io/runtime:3.3-9

RUN python -m venv /usr/local/airflow/pipeline_venv && /usr/local/airflow/pipeline_venv/bin/pip install --no-cache-dir "dlt[duckdb]" dbt-duckdb requests
