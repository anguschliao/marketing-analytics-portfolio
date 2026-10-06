from pathlib import Path

import pandas as pd


PROJECT_DIR = Path(__file__).resolve().parents[1]
RAW_PATH = PROJECT_DIR / "data" / "raw" / "dt_simulated_weekly.csv"


def main():
    df = pd.read_csv(RAW_PATH)

    # Parse date
    df["DATE"] = pd.to_datetime(df["DATE"])

    spend_cols = [
        "tv_S",
        "ooh_S",
        "print_S",
        "facebook_S",
        "search_S",
    ]

    exposure_cols = [
        "facebook_I",
        "search_clicks_P",
    ]

    control_cols = [
        "competitor_sales_B",
        "events",
    ]

    organic_cols = [
        "newsletter",
    ]

    print("=" * 70)
    print("PROJECT B — MMM DATA PROFILE")
    print("=" * 70)

    print("\nDATASET")
    print(f"Rows: {len(df):,}")
    print(f"Columns: {len(df.columns)}")
    print(f"Start date: {df['DATE'].min().date()}")
    print(f"End date: {df['DATE'].max().date()}")

    print("\nDATE QA")
    date_diff = df["DATE"].sort_values().diff().dt.days
    print(f"Duplicate dates: {df['DATE'].duplicated().sum()}")
    print(f"Expected weekly interval: 7 days")
    print(f"Non-7-day intervals: {(date_diff.dropna() != 7).sum()}")

    print("\nMISSING VALUES")
    missing = df.isna().sum()
    print(missing[missing > 0] if (missing > 0).any() else "None")

    print("\nDUPLICATE ROWS")
    print(f"Duplicate rows: {df.duplicated().sum()}")

    print("\nOUTCOME")
    print(df["revenue"].describe())

    print("\nPAID MEDIA SPEND")
    print(df[spend_cols].describe().T)

    print("\nSPEND QA")
    for col in spend_cols:
        print(
            f"{col}: "
            f"zero_weeks={(df[col] == 0).sum()}, "
            f"negative_weeks={(df[col] < 0).sum()}, "
            f"unique_values={df[col].nunique()}"
        )

    print("\nMEDIA EXPOSURE")
    print(df[exposure_cols].describe().T)

    print("\nCONTROLS")
    for col in control_cols:
        print(f"\n{col}")
        print(df[col].value_counts(dropna=False).head(15))

    print("\nORGANIC")
    print(df[organic_cols].describe().T)

    print("\nCORRELATION WITH REVENUE")
    numeric_cols = df.select_dtypes(include="number").columns
    correlations = (
        df[numeric_cols]
        .corr()["revenue"]
        .drop("revenue")
        .sort_values(ascending=False)
    )
    print(correlations)

    print("\n" + "=" * 70)
    print("PROFILE COMPLETE")
    print("=" * 70)


if __name__ == "__main__":
    main()