from pathlib import Path

import pandas as pd


PROJECT_DIR = Path(__file__).resolve().parents[1]

RAW_PATH = (
    PROJECT_DIR
    / "data"
    / "raw"
    / "dt_simulated_weekly.csv"
)

OUTPUT_PATH = (
    PROJECT_DIR
    / "data"
    / "processed"
    / "mmm_weekly.csv"
)


def main():
    df = pd.read_csv(RAW_PATH)

    # Standardize column names for analysis
    df = df.rename(
        columns={
            "DATE": "date",
            "tv_S": "tv_spend",
            "ooh_S": "ooh_spend",
            "print_S": "print_spend",
            "facebook_S": "facebook_spend",
            "search_S": "search_spend",
            "facebook_I": "facebook_impressions",
            "search_clicks_P": "search_clicks",
            "competitor_sales_B": "competitor_sales",
        }
    )

    # Parse weekly date
    df["date"] = pd.to_datetime(df["date"])

    # Convert event field into explicit indicators
    df["event_1"] = (df["events"] == "event1").astype(int)
    df["event_2"] = (df["events"] == "event2").astype(int)

    # Remove original categorical event field
    df = df.drop(columns=["events"])

    # Sort chronologically
    df = df.sort_values("date").reset_index(drop=True)

    # Final column order
    df = df[
        [
            "date",
            "revenue",
            "tv_spend",
            "ooh_spend",
            "print_spend",
            "facebook_spend",
            "search_spend",
            "facebook_impressions",
            "search_clicks",
            "competitor_sales",
            "newsletter",
            "event_1",
            "event_2",
        ]
    ]

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    df.to_csv(
        OUTPUT_PATH,
        index=False,
        date_format="%Y-%m-%d",
    )

    print("MMM dataset materialized.")
    print(f"Output: {OUTPUT_PATH}")
    print(f"Rows: {len(df):,}")
    print(f"Columns: {len(df.columns)}")
    print(
        f"Date range: "
        f"{df['date'].min().date()} to "
        f"{df['date'].max().date()}"
    )

    print("\nColumns:")
    for col in df.columns:
        print(f"  - {col}")


if __name__ == "__main__":
    main()