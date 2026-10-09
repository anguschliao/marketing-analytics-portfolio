
"""
Project B — Robust Regression Experiment

Compare Ridge and Huber regression with and without
Christmas/New Year holiday indicators.

R0: Ridge, no holidays
R1: Ridge, year-end holidays
R2: Huber, no holidays
R3: Huber, year-end holidays

Primary metric: Mean expanding-window CV NRMSE.
Paid media excluded.
Final 42 weeks excluded.
"""

import numpy as np
import pandas as pd

from sklearn.linear_model import Ridge, HuberRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from fit_mmm import DATA_PATH, CONTROLS, EVENTS
from diagnose_holidays import build_holiday_features
from model_evaluation import (
    load_data,
    get_cv_folds,
    calculate_metrics,
    summarize_cv,
    DEVELOPMENT_END,
)


# ============================================================
# CONFIGURATION
# ============================================================

RIDGE_ALPHA = 0.01
HUBER_ALPHA = 0.01
HUBER_EPSILON = 1.35
REVENUE_SCALE = 1_000_000.0

BASE_FEATURES = [
    "time_index",
    "sin_1",
    "cos_1",
    "sin_2",
    "cos_2",
] + CONTROLS + EVENTS

YEAR_END_FEATURES = [
    "christmas",
    "new_year",
]

EXPERIMENTS = {
    "R0 Ridge": {
        "model": "ridge",
        "holidays": False,
    },
    "R1 Ridge + Holidays": {
        "model": "ridge",
        "holidays": True,
    },
    "R2 Huber": {
        "model": "huber",
        "holidays": False,
    },
    "R3 Huber + Holidays": {
        "model": "huber",
        "holidays": True,
    },
}


# ============================================================
# FEATURE ENGINEERING
# ============================================================

def build_features(df):
    features = pd.DataFrame(index=df.index)

    time = np.arange(len(df), dtype=float)
    period = 365.25 / 7

    features["time_index"] = time

    for k in [1, 2]:
        angle = 2 * np.pi * k * time / period
        features[f"sin_{k}"] = np.sin(angle)
        features[f"cos_{k}"] = np.cos(angle)

    for col in CONTROLS + EVENTS:
        features[col] = df[col].to_numpy(dtype=float)

    holiday_features = build_holiday_features(df)

    return pd.concat(
        [features, holiday_features],
        axis=1,
    )


# ============================================================
# MODEL CONSTRUCTION
# ============================================================

def build_model(model_type):
    if model_type == "ridge":
        estimator = Ridge(
            alpha=RIDGE_ALPHA,
        )

    elif model_type == "huber":
        estimator = HuberRegressor(
            epsilon=HUBER_EPSILON,
            alpha=HUBER_ALPHA,
            max_iter=2000,
            tol=1e-6,
        )

    else:
        raise ValueError(
            f"Unknown model type: {model_type}"
        )

    return Pipeline([
        ("scaler", StandardScaler()),
        ("model", estimator),
    ])


# ============================================================
# CROSS-VALIDATION
# ============================================================

def evaluate_experiment(
    df,
    features,
    experiment,
    nrmse_scale,
):
    columns = BASE_FEATURES.copy()

    if experiment["holidays"]:
        columns += YEAR_END_FEATURES

    fold_results = []

    for fold in get_cv_folds():
        train_end = fold["train_end"]
        val_end = fold["val_end"]

        X_train = features.iloc[
            :train_end
        ][columns]

        X_val = features.iloc[
            train_end:val_end
        ][columns]

        y_train = df["revenue"].iloc[
            :train_end
        ].to_numpy(dtype=float)

        y_val = df["revenue"].iloc[
            train_end:val_end
        ].to_numpy(dtype=float)

        model = build_model(
            experiment["model"]
        )

        model.fit(
            X_train,
            y_train / REVENUE_SCALE,
        )

        predictions = (
            model.predict(X_val) * REVENUE_SCALE
        )

        metrics = calculate_metrics(
            y_val,
            predictions,
            nrmse_scale,
        )

        fold_results.append({
            "fold": fold["fold"],
            **metrics,
        })

    return summarize_cv(fold_results), fold_results


# ============================================================
# MAIN
# ============================================================

def main():
    df = load_data(DATA_PATH)

    development = df.iloc[
        :DEVELOPMENT_END
    ].copy()

    features = build_features(development)

    nrmse_scale = float(
        development["revenue"].mean()
    )

    print("=== ROBUST REGRESSION EXPERIMENT ===")
    print(f"Development weeks: {len(development)}")
    print(f"CV folds: {len(get_cv_folds())}")
    print(f"Ridge alpha: {RIDGE_ALPHA}")
    print(f"Huber alpha: {HUBER_ALPHA}")
    print(f"Huber epsilon: {HUBER_EPSILON}")
    print(f"NRMSE denominator: ${nrmse_scale:,.2f}")
    print("Paid media: excluded")
    print("Final 42 weeks: excluded")

    comparison = []

    for name, experiment in EXPERIMENTS.items():
        summary, folds = evaluate_experiment(
            development,
            features,
            experiment,
            nrmse_scale,
        )

        comparison.append({
            "model": name,
            "mean_nrmse": summary["mean_nrmse"],
            "mean_wmape_pct": summary["mean_wmape_pct"],
            "mean_r2": summary["mean_r2"],
            "mean_rmse": summary["mean_rmse"],
            "std_nrmse": summary["std_nrmse"],
            "mean_bias": summary["mean_bias"],
        })

        print(f"\n=== {name.upper()} ===")
        print(
            pd.DataFrame(folds)
            .round(5)
            .to_string(index=False)
        )

    results = pd.DataFrame(comparison)
    results = results.sort_values("mean_nrmse")

    print("\n=== ROBUST REGRESSION COMPARISON ===")
    print(
        results.round(5).to_string(index=False)
    )

    print("\n=== INTERPRETATION NOTES ===")
    print(
        "Huber regression reduces the influence "
        "of large training residuals."
    )
    print(
        "It does not automatically predict unknown events."
    )
    print(
        "All models use the same folds and evaluation metrics."
    )
    print(
        "This is exploratory post-diagnostic analysis."
    )

    print("\nEXPERIMENT COMPLETE")


if __name__ == "__main__":
    main()
