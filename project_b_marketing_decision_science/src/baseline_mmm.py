
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import RidgeCV
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


PROJECT_DIR = Path(__file__).resolve().parents[1]
DATA_PATH = PROJECT_DIR / "data" / "processed" / "mmm_weekly.csv"

MEDIA = [
    "tv_spend",
    "ooh_spend",
    "print_spend",
    "facebook_spend",
    "search_spend",
]

CONTROLS = ["competitor_sales", "newsletter"]
EVENTS = ["event_1", "event_2"]


def main():
    df = pd.read_csv(DATA_PATH, parse_dates=["date"])
    df = df.sort_values("date").reset_index(drop=True)

    # Continuous time index for trend and annual seasonality.
    df["time_index"] = np.arange(len(df))

    # Two annual Fourier harmonics.
    for k in [1, 2]:
        angle = 2 * np.pi * k * df["time_index"] / (365.25 / 7)
        df[f"sin_{k}"] = np.sin(angle)
        df[f"cos_{k}"] = np.cos(angle)

    seasonal = [
        "time_index",
        "sin_1", "cos_1",
        "sin_2", "cos_2",
    ] + EVENTS

    models = {
        "M0 Seasonal": seasonal,
        "M1 Controls": seasonal + CONTROLS,
        "M2 Raw Media": seasonal + CONTROLS + MEDIA,
    }

    split = int(len(df) * 0.8)
    train = df.iloc[:split]
    test = df.iloc[split:]

    print("=== BASELINE MMM BENCHMARK ===")
    print(f"Train: {len(train)} weeks")
    print(f"Test:  {len(test)} weeks")
    print(f"Train ends: {train['date'].max().date()}")
    print(f"Test begins: {test['date'].min().date()}")

    results = []

    for name, features in models.items():
        X_train = train[features]
        X_test = test[features]
        y_train = train["revenue"]
        y_test = test["revenue"]

        model = Pipeline([
            ("scaler", StandardScaler()),
            ("ridge", RidgeCV(
                alphas=np.logspace(-3, 5, 50),
                cv=None,
            )),
        ])

        model.fit(X_train, y_train)
        pred_train = model.predict(X_train)
        pred_test = model.predict(X_test)

        results.append({
            "model": name,
            "alpha": model.named_steps["ridge"].alpha_,
            "train_r2": r2_score(y_train, pred_train),
            "test_r2": r2_score(y_test, pred_test),
            "test_rmse": np.sqrt(
                mean_squared_error(y_test, pred_test)
            ),
            "test_mae": mean_absolute_error(y_test, pred_test),
            "test_wmape_pct": (
                np.abs(y_test - pred_test).sum()
                / np.abs(y_test).sum() * 100
            ),
        })

    results_df = pd.DataFrame(results)

    print("\n=== MODEL COMPARISON ===")
    print(results_df.round(3).to_string(index=False))

    print("\n=== M2 RAW MEDIA COEFFICIENTS ===")
    final_model = model
    coefs = pd.Series(
        final_model.named_steps["ridge"].coef_,
        index=models["M2 Raw Media"],
    )
    print(coefs.sort_values(ascending=False).round(2).to_string())

    print("\nNOTE: These are standardized Ridge coefficients.")
    print("They are not channel contributions or ROAS.")


if __name__ == "__main__":
    main()
