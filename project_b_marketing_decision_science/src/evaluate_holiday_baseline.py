
"""
Project B — Holiday-Aware Baseline Experiment

Compare:
H0: Seasonality + controls + events
H1: H0 + Christmas + New Year
H2: H1 + Black Friday + Easter

Model: Ridge regression
Ridge alpha: 0.01 (fixed)
Primary metric: Mean expanding-window CV NRMSE

Paid media excluded.
Final 42 weeks excluded.
"""

import numpy as np
import pandas as pd

from sklearn.linear_model import Ridge
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

BASE_FEATURES = [
    "time_index",
    "sin_1",
    "cos_1",
    "sin_2",
    "cos_2",
] + CONTROLS + EVENTS

HOLIDAY_CONFIGS = {
    "H0 Baseline": [],
    "H1 Year-End": [
        "christmas",
        "new_year",
    ],
    "H2 Full Holidays": [
        "christmas",
        "new_year",
        "black_friday",
        "easter",
    ],
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

    features = pd.concat(
        [features, holiday_features],
        axis=1,
    )

    return features


# ============================================================
# EVALUATION
# ============================================================

def evaluate_configuration(
    df,
    features,
    feature_columns,
    nrmse_scale,
):
    fold_results = []

    for fold in get_cv_folds():
        train_end = fold["train_end"]
        val_end = fold["val_end"]

        X_train = features.iloc[
            :train_end
        ][feature_columns]

        X_val = features.iloc[
            train_end:val_end
        ][feature_columns]

        y_train = df["revenue"].iloc[
            :train_end
        ].to_numpy(dtype=float)

        y_val = df["revenue"].iloc[
            train_end:val_end
        ].to_numpy(dtype=float)

        model = Pipeline([
            ("scaler", StandardScaler()),
            ("ridge", Ridge(
                alpha=RIDGE_ALPHA,
            )),
        ])

        model.fit(X_train, y_train)
        predictions = model.predict(X_val)

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

    print("=== HOLIDAY-AWARE BASELINE EXPERIMENT ===")
    print(f"Development weeks: {len(development)}")
    print(f"CV folds: {len(get_cv_folds())}")
    print(f"Ridge alpha: {RIDGE_ALPHA}")
    print(f"NRMSE denominator: ${nrmse_scale:,.2f}")
    print("Paid media: excluded")
    print("Final 42 weeks: excluded")

    comparison = []

    for name, holiday_columns in HOLIDAY_CONFIGS.items():
        columns = BASE_FEATURES + holiday_columns

        summary, folds = evaluate_configuration(
            development,
            features,
            columns,
            nrmse_scale,
        )

        comparison.append({
            "model": name,
            "mean_nrmse": summary["mean_nrmse"],
            "mean_wmape_pct": summary["mean_wmape_pct"],
            "mean_r2": summary["mean_r2"],
            "mean_rmse": summary["mean_rmse"],
            "std_nrmse": summary["std_nrmse"],
        })

        print(f"\n=== {name.upper()} ===")
        print(
            pd.DataFrame(folds)
            .round(5)
            .to_string(index=False)
        )

    results = pd.DataFrame(comparison)

    results = results.sort_values(
        "mean_nrmse"
    )

    print("\n=== HOLIDAY MODEL COMPARISON ===")
    print(
        results.round(5).to_string(index=False)
    )

    print("\n=== INTERPRETATION ===")
    print(
        "Lower mean CV NRMSE indicates better "
        "predictive performance."
    )
    print(
        "Holiday features were defined using "
        "calendar dates, not revenue spikes."
    )
    print(
        "This is an exploratory post-diagnostic "
        "experiment, not independent validation."
    )

    print("\nEXPERIMENT COMPLETE")


if __name__ == "__main__":
    main()
