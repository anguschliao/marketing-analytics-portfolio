
from pathlib import Path
import pandas as pd
from google.cloud import bigquery

PROJECT_ID = "turing-emitter-510722-h2"
DATASET = f"{PROJECT_ID}.analytics"

PROJECT_DIR = Path(__file__).resolve().parents[1]
SQL_DIR = PROJECT_DIR / "sql"
OUTPUT_DIR = PROJECT_DIR / "outputs" / "power_bi"

TABLE_EXPORTS = {
    "daily_kpis": "fact_daily_kpis.csv",
    "channel_performance": "fact_channel_performance.csv",
    "customer_type_performance": "fact_customer_type.csv",
    "session_funnel": "fact_funnel.csv",
}

QUERY_EXPORTS = {
    "43_customer_retention_analysis.sql": "fact_customer_segments.csv",
    "44_monthly_retention_cohorts.sql": "fact_monthly_cohorts.csv",
    "45_fixed_window_retention.sql": "fact_customer_retention.csv",
    "46_fixed_window_purchase_retention.sql": "fact_purchase_retention.csv",
    "47_30_day_customer_value.sql": "fact_customer_value.csv",
    "48_acquisition_customer_value.sql": "fact_acquisition_value.csv",
}


def export_query(client, query, filename):
    df = client.query(
        query,
        location="US"
    ).to_dataframe(create_bqstorage_client=False)

    output_path = OUTPUT_DIR / filename
    df.to_csv(output_path, index=False)

    print(f"{filename}: {len(df):,} rows")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    client = bigquery.Client(project=PROJECT_ID)

    print("=== MATERIALIZED TABLE EXPORTS ===")

    for table, filename in TABLE_EXPORTS.items():
        query = f"SELECT * FROM `{DATASET}.{table}`"
        export_query(client, query, filename)

    print("\n=== ANALYTICAL QUERY EXPORTS ===")

    for sql_file, filename in QUERY_EXPORTS.items():
        query = (SQL_DIR / sql_file).read_text(
            encoding="utf-8-sig"
        )
        export_query(client, query, filename)

    print("\nPower BI exports complete.")
    print(f"Output directory: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
