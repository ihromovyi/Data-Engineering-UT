"""dbt_pipeline.py — Airflow DAG that orchestrates the full dbt project.

Pipeline shape:
    dbt_seed → dbt_run_staging → dbt_run_marts → dbt_test → dbt_snapshot

Each task runs a dbt CLI command via BashOperator.  dbt-core and dbt-postgres
are pre-installed in the Airflow image (airflow.Dockerfile).  The dbt project
is mounted at /dbt inside the scheduler container.

Schedule: manual trigger only (schedule=None).  Run it from the Airflow UI or:

    docker compose exec airflow-scheduler \
        airflow dags trigger dbt_pipeline

Learning objectives for students
---------------------------------
1. Understand how Airflow wraps dbt commands into an orchestrated pipeline.
2. Observe how task dependencies (>>) enforce correct execution order.
3. Inspect XCom / task logs to see dbt output for each step.
4. (Extension) Add a sensor that waits for retail-db to be ready before seeding.
"""

from __future__ import annotations

import pendulum
from airflow import DAG
from airflow.operators.bash import BashOperator

DBT_PROJECT_DIR = "/dbt"
DBT_PROFILES_DIR = "/dbt"

# Common flags added to every dbt subcommand.
# In dbt 1.8+, --project-dir and --profiles-dir are subcommand flags
# (they follow the subcommand, not dbt itself).
DBT_FLAGS = (
    f"--no-use-colors "
    f"--project-dir {DBT_PROJECT_DIR} "
    f"--profiles-dir {DBT_PROFILES_DIR}"
)

default_args = {
    "owner": "airflow",
    "retries": 1,
}

with DAG(
    dag_id="dbt_pipeline",
    description="Seed raw data, build staging + mart models, run tests, take snapshot.",
    schedule="* * * * *",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    default_args=default_args,
    tags=["dbt", "retail"],
) as dag:

    dbt_snapshot = BashOperator(
        task_id="dbt_snapshot",
        bash_command=f"dbt build {DBT_FLAGS}",
        doc_md="""
        Runs dim_customer_snapshot.  On first run it creates the snapshot
        table.  On subsequent runs (after updating raw_customers.csv) it
        appends a new row for changed customers and closes the old one.
        """,
    )

    # Define execution order
    dbt_snapshot