
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler

from fit_mmm import (
    DATA_PATH,
    MEDIA,
    fit_constrained_ridge,
    predict,
)
from tune_mmm import build_fold_features


# ============================================================
# CONFIGURATION
# ============================================================

DEVELOPMENT_END = 166
RIDGE_ALPHA = 0.01
REVENUE_SCALE = 1_000_000.0

OPTIMIZED_THETA = {
    "tv_spend": 0.50,
    "ooh_spend": 0.70,
    "print_spend": 0.50,
    "facebook_spend": 0.60,
    "search_spend": 0.40,
}

OPTIMIZED_QUANTILES = {
    "tv_spend": 0.75,
    "ooh_spend": 0.75,
    "print_spend": 0.75,
    "facebook_spend": 0.25,
    "search_spend": 0.75,
}

CONTROLS = ["competitor_sales", "newsletter"]


# ============================================================
# MODEL FITTING
# ============================================================

def fit_model(df, train_end, excluded_controls=None):
    """
    Fit the frozen MMM specification using observations
    available through train_end.

    Return standardized media coefficients and residuals.
    """
    if excluded_controls is None:
        excluded_controls = []

    history = df.iloc[:train_end].copy()

    features = build_fold_features(
        history,
        train_end=train_end,
        theta_params=OPTIMIZED_THETA,
        saturation_quantiles=OPTIMIZED_QUANTILES,
    )

    features = features.drop(
        columns=excluded_controls,
    )

    scaler = StandardScaler()
    X = scaler.fit_transform(features)

    y = history["revenue"].to_numpy(dtype=float)

    media_indices = [
        features.columns.get_loc(col)
        for col in MEDIA
    ]

    coefficients = fit_constrained_ridge(
        X,
        y / REVENUE_SCALE,
        media_indices,
        RIDGE_ALPHA,
    )

    predictions = (
        predict(X, coefficients) * REVENUE_SCALE
    )

    residuals = y - predictions

    coef_series = pd.Series(
        coefficients[1:],
        index=features.columns,
    )

    return coef_series[MEDIA], residuals


# ============================================================
# RESIDUAL AUTOCORRELATION
# ============================================================

def residual_diagnostics(residuals):
    print("\n=== RESIDUAL AUTOCORRELATION ===")

    series = pd.Series(residuals)

    for lag in [1, 2, 4, 8, 13, 26]:
        correlation = series.autocorr(lag=lag)

        print(
            f"Lag {lag:2d}: {correlation:.4f}"
        )

    print("\n=== RESIDUAL SUMMARY ===")
    print(f"Mean residual: ${series.mean():,.2f}")
    print(f"Residual std: ${series.std():,.2f}")
    print(f"Maximum residual: ${series.max():,.2f}")
    print(f"Minimum residual: ${series.min():,.2f}")


# ============================================================
# COEFFICIENT STABILITY
# ============================================================

def coefficient_stability(df):
    print("\n=== MEDIA COEFFICIENT STABILITY ===")

    windows = [94, 118, 142, 166]

    results = []

    for end in windows:
        coefficients, _ = fit_model(
            df,
            train_end=end,
        )

        row = {
            "training_weeks": end,
            **coefficients.to_dict(),
        }

        results.append(row)

    table = pd.DataFrame(results)
    print(table.round(6).to_string(index=False))

    print("\n=== COEFFICIENT VARIATION ===")

    for channel in MEDIA:
        values = table[channel].to_numpy()

        print(
            f"{channel}: "
            f"min={values.min():.6f}, "
            f"max={values.max():.6f}"
        )


# ============================================================
# CONTROL SENSITIVITY
# ============================================================

def control_sensitivity(df):
    print("\n=== CONTROL SENSITIVITY ===")

    scenarios = {
        "Full model": [],
        "No competitor sales": ["competitor_sales"],
        "No newsletter": ["newsletter"],
        "Neither control": CONTROLS,
    }

    results = []

    for name, excluded in scenarios.items():
        coefficients, _ = fit_model(
            df,
            train_end=DEVELOPMENT_END,
            excluded_controls=excluded,
        )

        results.append({
            "scenario": name,
            **coefficients.to_dict(),
        })

    table = pd.DataFrame(results)
    print(table.round(6).to_string(index=False))

    print(
        "\nNOTE: Coefficients are standardized within "
        "each model specification."
    )


# ============================================================
# MAIN
# ============================================================

def main():
    df = pd.read_csv(DATA_PATH, parse_dates=["date"])
    df = df.sort_values("date").reset_index(drop=True)

    if len(df) != 208:
        raise ValueError("Expected 208 weekly observations.")

    # Exclude final holdout from all diagnostic fitting.
    development = df.iloc[:DEVELOPMENT_END].copy()

    print("=== MMM ATTRIBUTION READINESS DIAGNOSTICS ===")
    print(f"Development weeks: {len(development)}")
    print("Final holdout: excluded")

    coefficients, residuals = fit_model(
        development,
        train_end=DEVELOPMENT_END,
    )

    print("\n=== FULL MODEL MEDIA COEFFICIENTS ===")
    print(coefficients.round(6).to_string())

    residual_diagnostics(residuals)
    coefficient_stability(development)
    control_sensitivity(development)

    print("\n=== DIAGNOSTICS COMPLETE ===")
    print("No model parameters were retuned.")
    print("Final 42-week holdout was not used.")


if __name__ == "__main__":
    main()
