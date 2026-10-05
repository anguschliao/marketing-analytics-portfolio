from pathlib import Path

from google.cloud import bigquery


PROJECT_ID = "turing-emitter-510722-h2"

client = bigquery.Client(project=PROJECT_ID)


def run_query(sql_file):
    """Run a SQL file in BigQuery and return the results as a DataFrame."""

    sql_path = Path(sql_file)
    query = sql_path.read_text(encoding="utf-8")

    print(f"Running: {sql_path.name}")

    df = client.query(query).to_dataframe()

    print(f"Returned {len(df):,} rows.")
    return df


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("Usage: python run_query.py <sql_file>")
        sys.exit(1)

    df = run_query(sys.argv[1])

    print(df.to_string(index=False))