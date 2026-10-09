
"""
Project B — Holiday-Aware Ridge + Hill MMM

Compare:
M3A: Frozen Optuna MMM without holidays
M3B: Same MMM with Christmas and New Year

No hyperparameter retuning.
Primary metric: Mean expanding-window CV NRMSE.
Final 42 weeks excluded.
"""

from pathlib import Path
import json

import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler

from fit_mmm import (
    DATA_PATH,
    MEDIA,
    fit_constrained_ridge,
    predict,
)
from optimize_mmm_optuna import build_features
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

PROJECT_DIR = Path(__file__).resolve().parents[1]

PARAMETERS_PATH = (
    PROJECT_DIR
    / "outputs"
    / "optimization"
    / "ridge_hill_optuna_best.json"
)

REVENUE_SCALE = 1_000_000.0

EXPERIMENTS = {
    "M3A Original MMM": False,
    "M3B Holiday-Aware MMM": True,
}


# ============================================================
# LOAD FROZEN PARAMETERS
# ============================================================

def load_parameters():
    if not PARAMETERS_PATH.exists():
        raise FileNotFoundError(
            f"Missing optimized parameters: {PARAMETERS_PATH}"
        )

    with open(
        PARAMETERS_PATH,
        "r",
        encoding="utf-8",
    ) as f:
        results = json.load(f)

    return results["best_params"]


# ============================================================
# EVALUATION
# ============================================================

def evaluate_configuration(
    df,
    params,
    include_holidays,
    nrmse_scale,
):
    fold_results = []

    for fold in get_cv_folds():
        train_end = fold["train_end"]
        val_end = fold["val_end"]

        # Only observations through the current fold.
        fold_df = df.iloc[:val_end].copy()

        features = build_features(
            fold_df,
            train_end,
            params,
        )

        if include_holidays:
            holiday_features = build_holiday_features(
                fold_df
            )[
                ["christmas", "new_year"]
            ]

            features = pd.concat(
                [features, holiday_features],
                axis=1,
            )

        X_train = features.iloc[:train_end]
        X_val = features.iloc[train_end:val_end]

        y_train = fold_df["revenue"].iloc[
            :train_end
        ].to_numpy(dtype=float)

        y_val = fold_df["revenue"].iloc[
            train_end:val_end
        ].to_numpy(dtype=float)

        scaler = StandardScaler()

        X_train_scaled = scaler.fit_transform(X_train)
        X_val_scaled = scaler.transform(X_val)

        media_indices = [
            features.columns.get_loc(channel)
            for channel in MEDIA
        ]

        coefficients = fit_constrained_ridge(
            X_train_scaled,
            y_train / REVENUE_SCALE,
            media_indices,
            params["ridge_alpha"],
        )

        predictions = (
            predict(
                X_val_scaled,
                coefficients,
            ) * REVENUE_SCALE
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

    params = load_parameters()

    nrmse_scale = float(
        development["revenue"].mean()
    )

    print("=== HOLIDAY-AWARE MMM EXPERIMENT ===")
    print(f"Development weeks: {len(development)}")
    print(f"CV folds: {len(get_cv_folds())}")
    print(f"Ridge alpha: {params['ridge_alpha']:.6f}")
    print(f"NRMSE denominator: ${nrmse_scale:,.2f}")
    print("Hyperparameters: frozen")
    print("Final 42 weeks: excluded")

    comparison = []

    for name, include_holidays in EXPERIMENTS.items():
        summary, folds = evaluate_configuration(
            development,
            params,
            include_holidays,
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

    print("\n=== MMM HOLIDAY COMPARISON ===")
    print(
        results.round(5).to_string(index=False)
    )

    print("\n=== INTERPRETATION ===")
    print(
        "Both models use identical optimized "
        "media transformation parameters."
    )
    print(
        "Only the holiday feature specification changes."
    )
    print(
        "No final holdout observations were used."
    )
    print(
        "This is exploratory post-diagnostic analysis."
    )

    print("\nEXPERIMENT COMPLETE")


if __name__ == "__main__":
    main()
