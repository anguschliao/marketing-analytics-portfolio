
import numpy as np
import pandas as pd
from sklearn.linear_model import Ridge
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from fit_mmm import (
    DATA_PATH,
    MEDIA,
    CONTROLS,
    EVENTS,
    fit_constrained_ridge,
    predict,
    evaluate,
)
from tune_mmm import build_fold_features


# ============================================================
# CONFIGURATION
# ============================================================

TRAIN_END = 166
EXPECTED_WEEKS = 208
REVENUE_SCALE = 1_000_000.0

# Frozen parameters selected during development.
RIDGE_ALPHA = 0.01

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


# ============================================================
# BASELINE FEATURES
# ============================================================

def build_baseline_features(df):
    features = pd.DataFrame(index=df.index)

    time = np.arange(len(df), dtype=float)
    period = 365.25 / 7

    features["time_index"] = time

    for k in [1, 2]:
        angle = 2 * np.pi * k * time / period
        features[f"sin_{k}"] = np.sin(angle)
        features[f"cos_{k}"] = np.cos(angle)

    for col in CONTROLS + EVENTS + MEDIA:
        features[col] = df[col].to_numpy(dtype=float)

    return features


# ============================================================
# MODEL EVALUATION
# ============================================================

def evaluate_baseline(df, features, columns, alpha):
    X_train = features.iloc[:TRAIN_END][columns]
    X_test = features.iloc[TRAIN_END:][columns]

    y_train = df["revenue"].iloc[:TRAIN_END]
    y_test = df["revenue"].iloc[TRAIN_END:]

    model = Pipeline([
        ("scaler", StandardScaler()),
        ("ridge", Ridge(alpha=alpha)),
    ])

    model.fit(X_train, y_train)

    predictions = model.predict(X_test)

    return evaluate(y_test.to_numpy(), predictions), predictions


def evaluate_calibrated_mmm(df):
    # Saturation scales use only the first 166 weeks.
    # Adstock carries chronologically into the test period.
    features = build_fold_features(
        df,
        train_end=TRAIN_END,
        theta_params=OPTIMIZED_THETA,
        saturation_quantiles=OPTIMIZED_QUANTILES,
    )

    scaler = StandardScaler()

    X_train = scaler.fit_transform(
        features.iloc[:TRAIN_END]
    )
    X_test = scaler.transform(
        features.iloc[TRAIN_END:]
    )

    y_train = df["revenue"].iloc[
        :TRAIN_END
    ].to_numpy(dtype=float)

    y_test = df["revenue"].iloc[
        TRAIN_END:
    ].to_numpy(dtype=float)

    media_indices = [
        features.columns.get_loc(col)
        for col in MEDIA
    ]

    coefficients = fit_constrained_ridge(
        X_train,
        y_train / REVENUE_SCALE,
        media_indices,
        RIDGE_ALPHA,
    )

    predictions = (
        predict(X_test, coefficients) * REVENUE_SCALE
    )

    coef_series = pd.Series(
        coefficients[1:],
        index=features.columns,
    )

    if (coef_series[MEDIA] < -1e-8).any():
        raise AssertionError(
            "Negative media coefficient detected."
        )

    return evaluate(y_test, predictions), predictions, coef_series


# ============================================================
# MAIN
# ============================================================

def main():
    df = pd.read_csv(DATA_PATH, parse_dates=["date"])
    df = df.sort_values("date").reset_index(drop=True)

    if len(df) != EXPECTED_WEEKS:
        raise ValueError("Unexpected observation count.")

    if not df["date"].is_unique:
        raise ValueError("Duplicate dates detected.")

    if not (
        df["date"].diff().dropna().dt.days == 7
    ).all():
        raise ValueError("Non-weekly date intervals detected.")

    baseline = build_baseline_features(df)

    seasonal = [
        "time_index",
        "sin_1",
        "cos_1",
        "sin_2",
        "cos_2",
    ] + EVENTS

    models = {
        "M0 Seasonal": seasonal,
        "M1 Controls": seasonal + CONTROLS,
        "M2 Raw Media": seasonal + CONTROLS + MEDIA,
    }

    print("=== FINAL MMM HOLDOUT EVALUATION ===")
    print(f"Training weeks: {TRAIN_END}")
    print(f"Test weeks: {len(df) - TRAIN_END}")
    print(
        "Train ends:",
        df["date"].iloc[TRAIN_END - 1].date(),
    )
    print(
        "Test begins:",
        df["date"].iloc[TRAIN_END].date(),
    )

    results = []
    predictions_by_model = {}

    # Baseline comparisons
    for name, columns in models.items():
        metrics, predictions = evaluate_baseline(
            df,
            baseline,
            columns,
            RIDGE_ALPHA,
        )

        results.append({
            "model": name,
            **metrics,
        })

        predictions_by_model[name] = predictions

    # Calibrated MMM
    metrics, predictions, coefficients = (
        evaluate_calibrated_mmm(df)
    )

    results.append({
        "model": "M3 Calibrated MMM",
        **metrics,
    })

    predictions_by_model["M3 Calibrated MMM"] = predictions

    results_df = pd.DataFrame(results)

    print("\n=== HOLDOUT MODEL COMPARISON ===")
    print(
        results_df.round(4).to_string(index=False)
    )

    print("\n=== CALIBRATED MMM MEDIA COEFFICIENTS ===")
    print(
        coefficients[MEDIA].round(6).to_string()
    )

    # Residual diagnostics for calibrated MMM.
    actual = df["revenue"].iloc[
        TRAIN_END:
    ].to_numpy(dtype=float)

    residuals = predictions - actual

    print("\n=== CALIBRATED MMM RESIDUAL DIAGNOSTICS ===")
    print(f"Mean bias: ${residuals.mean():,.2f}")
    print(
        f"Maximum absolute error: "
        f"${np.abs(residuals).max():,.2f}"
    )
    print(f"Overpredicted weeks: {(residuals > 0).sum()}")
    print(f"Underpredicted weeks: {(residuals < 0).sum()}")

    largest_indices = np.argsort(
        np.abs(residuals)
    )[-5:][::-1]

    print("\n=== FIVE LARGEST HOLDOUT ERRORS ===")

    for i in largest_indices:
        date = df["date"].iloc[TRAIN_END + i].date()

        print(
            f"{date}: "
            f"actual=${actual[i]:,.2f}, "
            f"predicted=${predictions[i]:,.2f}, "
            f"error=${residuals[i]:,.2f}"
        )

    print("\n=== EVALUATION NOTES ===")
    print(
        "All four models use the same 42-week holdout."
    )
    print(
        "M3 uses frozen transformation parameters."
    )
    print(
        "All feature scaling is fitted on training data."
    )
    print(
        "Historical conditional prediction, "
        "not advance forecasting."
    )
    print(
        "Do not retune model parameters using these results."
    )


if __name__ == "__main__":
    main()
