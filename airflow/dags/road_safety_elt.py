from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator


with DAG(
    dag_id="road_safety_elt",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    tags=["road-safety", "elt"],
) as dag:

    load_raw = BashOperator(
        task_id="load_raw",
        bash_command="python /app/loader/load_raw.py",
    )

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=(
            "dbt run "
            "--project-dir /app/dbt "
            "--profiles-dir /app/dbt "
            "--target-path /tmp/dbt_target "
            "--log-path /tmp/dbt_logs"
        ),
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=(
            "dbt test "
            "--project-dir /app/dbt "
            "--profiles-dir /app/dbt "
            "--target-path /tmp/dbt_target "
            "--log-path /tmp/dbt_logs"
        ),
    )

    publish = BashOperator(
        task_id="publish",
        bash_command="python /app/loader/publish.py",
    )

    load_raw >> dbt_run >> dbt_test >> publish