
import pandas as pd
from datetime import date, timedelta

from fit_mmm import DATA_PATH
from model_evaluation import get_cv_folds


def easter_date(year):
    """Gregorian Easter Sunday."""
    a = year % 19
    b = year // 100
    c = year % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19*a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2*e + 2*i - h - k) % 7
    m = (a + 11*h + 22*l) // 451
    month = (h + l - 7*m + 114) // 31
    day = ((h + l - 7*m + 114) % 31) + 1
    return date(year, month, day)


def thanksgiving_us(year):
    """Fourth Thursday in November."""
    first = date(year, 11, 1)
    days_to_thursday = (3 - first.weekday()) % 7
    return first + timedelta(days=days_to_thursday + 21)


def week_start(day):
    """Monday of the calendar week containing day."""
    return day - timedelta(days=day.weekday())


def build_holiday_features(df):
    features = pd.DataFrame(index=df.index)

    for name in [
        "christmas",
        "new_year",
        "black_friday",
        "easter",
    ]:
        features[name] = 0

    for year in range(
        df["date"].dt.year.min() - 1,
        df["date"].dt.year.max() + 2,
    ):
        holidays = {
            "christmas": date(year, 12, 25),
            "new_year": date(year, 1, 1),
            "black_friday": thanksgiving_us(year)
                            + timedelta(days=1),
            "easter": easter_date(year),
        }

        for name, holiday in holidays.items():
            monday = pd.Timestamp(week_start(holiday))

            features.loc[
                df["date"] == monday, name
            ] = 1

    return features


def main():
    df = pd.read_csv(DATA_PATH, parse_dates=["date"])
    df = df.sort_values("date").reset_index(drop=True)

    holidays = build_holiday_features(df)

    print("=== HOLIDAY FEATURE DIAGNOSTICS ===")
    print(f"Observations: {len(df)}")

    print("\n=== HOLIDAY WEEKS ===")

    result = pd.concat(
        [df[["date", "revenue"]], holidays],
        axis=1,
    )

    mask = holidays.any(axis=1)
    print(result.loc[mask].to_string(index=False))

    print("\n=== HOLIDAY COUNTS BY CV FOLD ===")

    for fold in get_cv_folds():
        train = holidays.iloc[:fold["train_end"]]
        val = holidays.iloc[
            fold["val_start"]:fold["val_end"]
        ]

        print(f"\nFold {fold['fold']}")
        print("Training:")
        print(train.sum().to_string())
        print("Validation:")
        print(val.sum().to_string())

    print("\n=== HOLIDAY VS NON-HOLIDAY REVENUE ===")

    for name in holidays.columns:
        holiday_mean = df.loc[
            holidays[name] == 1, "revenue"
        ].mean()

        other_mean = df.loc[
            holidays[name] == 0, "revenue"
        ].mean()

        print(
            f"{name}: "
            f"holiday_mean=${holiday_mean:,.2f}, "
            f"other_mean=${other_mean:,.2f}, "
            f"observations={holidays[name].sum()}"
        )

    print("\n=== IMPORTANT ===")
    print("Calendar features are independent of revenue.")
    print("Revenue differences are descriptive, not causal.")
    print("No models have been modified.")


if __name__ == "__main__":
    main()
