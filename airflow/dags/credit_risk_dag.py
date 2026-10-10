from datetime import datetime, timedelta
try: from airflow.sdk import DAG
except ImportError: from airflow import DAG
try: from airflow.providers.standard.operators.bash import BashOperator
except ImportError: from airflow.operators.bash import BashOperator
PY = "/usr/local/airflow/pipeline_venv/bin"
with DAG("credit_risk_pipeline", start_date=datetime(2026, 1, 1), schedule="0 2 * * *", catchup=False, max_active_runs=1, default_args={"retries": 2, "retry_delay": timedelta(minutes=5)}, tags=["credit", "sec-edgar"]) as dag:
 ingest = BashOperator(task_id="ingest_sec_edgar", bash_command=f"cd /usr/local/airflow/ingestion && {PY}/python pipeline.py")
 transform = BashOperator(task_id="dbt_build", bash_command=f"cd /usr/local/airflow/dbt_project && {PY}/dbt build")
 report = BashOperator(task_id="report_freshness", bash_command=f"{PY}/python /usr/local/airflow/include/report_freshness.py")
 ingest >> transform >> report
