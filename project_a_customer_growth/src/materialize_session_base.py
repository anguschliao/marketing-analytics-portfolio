from pathlib import Path

from google.cloud import bigquery


PROJECT_ID = "turing-emitter-510722-h2"
DESTINATION_TABLE = f"{PROJECT_ID}.analytics.session_base"

SQL_FILE = (
    Path(__file__).resolve().parents[1]
    / "sql"
    / "05_session_base.sql"
)


def main():
    client = bigquery.Client(project=PROJECT_ID)

    sql = SQL_FILE.read_text(encoding="utf-8")

    job_config = bigquery.QueryJobConfig(
        destination=DESTINATION_TABLE,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    print(f"Reading: {SQL_FILE.name}")
    print(f"Materializing: {DESTINATION_TABLE}")

    query_job = client.query(
        sql,
        job_config=job_config,
        location="US",
    )

    query_job.result()

    table = client.get_table(DESTINATION_TABLE)

    print("\nMaterialization complete.")
    print(f"Table: {DESTINATION_TABLE}")
    print(f"Rows: {table.num_rows:,}")
    print(f"Columns: {len(table.schema)}")


if __name__ == "__main__":
    main()