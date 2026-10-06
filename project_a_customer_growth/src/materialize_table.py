import argparse
from pathlib import Path

from google.cloud import bigquery


PROJECT_ID = "turing-emitter-510722-h2"

PROJECT_DIR = Path(__file__).resolve().parents[1]
SQL_DIR = PROJECT_DIR / "sql"


def main():
    parser = argparse.ArgumentParser(
        description="Materialize a Project A SQL query into BigQuery."
    )

    parser.add_argument(
        "--sql",
        required=True,
        help="SQL filename in the project's sql directory.",
    )

    parser.add_argument(
        "--table",
        required=True,
        help="Destination table name in the analytics dataset.",
    )

    args = parser.parse_args()

    sql_file = SQL_DIR / args.sql
    destination_table = f"{PROJECT_ID}.analytics.{args.table}"

    if not sql_file.exists():
        raise FileNotFoundError(
            f"SQL file not found: {sql_file}"
        )

    client = bigquery.Client(project=PROJECT_ID)

    sql = sql_file.read_text(encoding="utf-8")

    job_config = bigquery.QueryJobConfig(
        destination=destination_table,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    print(f"Reading: {sql_file.name}")
    print(f"Materializing: {destination_table}")

    query_job = client.query(
        sql,
        job_config=job_config,
        location="US",
    )

    query_job.result()

    table = client.get_table(destination_table)

    print("\nMaterialization complete.")
    print(f"Table: {destination_table}")
    print(f"Rows: {table.num_rows:,}")
    print(f"Columns: {len(table.schema)}")


if __name__ == "__main__":
    main()