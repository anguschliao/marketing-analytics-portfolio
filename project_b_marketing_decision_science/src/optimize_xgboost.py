
"""
XGBoost + Optuna optimization for Project B.

Primary objective: Mean expanding-window CV NRMSE.
Features: Raw paid media, controls, trend, Fourier seasonality.
Development: First 166 weeks only.
Previously examined 42-week holdout: Excluded.
"""

from pathlib import Path
import json

import numpy as np
import optuna
import pandas as pd
from xgboost import XGBRegressor

from fit_mmm import DATA_PATH, MEDIA, CONTROLS, EVENTS
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
OUTPUT_DIR = PROJECT_DIR / "outputs" / "optimization"

N_TRIALS = 100
RANDOM_SEED = 42

optuna.logging.set_verbosity(optuna.logging.WARNING)


# ============================================================
# FEATURE ENGINEERING
# ============================================================

def build_features(df):
    """
    Build raw-media predictive features.

    No future target values, rolling target statistics,
    or holdout observations are used.
    """
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
# CROSS-VALIDATION
# ============================================================

def evaluate_params(df, params, nrmse_scale):
    """
    Evaluate XGBoost across expanding-window folds.
    """
    features = build_features(df)
    fold_results = []

    for fold in get_cv_folds():
        train_end = fold["train_end"]
        val_end = fold["val_end"]

        X_train = features.iloc[:train_end]
        X_val = features.iloc[train_end:val_end]

        y_train = df["revenue"].iloc[
            :train_end
        ].to_numpy(dtype=float)

        y_val = df["revenue"].iloc[
            train_end:val_end
        ].to_numpy(dtype=float)

        model = XGBRegressor(
            objective="reg:squarederror",
            tree_method="hist",
            random_state=RANDOM_SEED,
            n_jobs=1,
            verbosity=0,
            **params,
        )

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
# OPTUNA OBJECTIVE
# ============================================================

def make_objective(df, nrmse_scale):
    def objective(trial):
        params = {
            "n_estimators": trial.suggest_int(
                "n_estimators", 50, 500
            ),
            "max_depth": trial.suggest_int(
                "max_depth", 1, 3
            ),
            "learning_rate": trial.suggest_float(
                "learning_rate", 0.005, 0.2, log=True
            ),
            "min_child_weight": trial.suggest_int(
                "min_child_weight", 3, 20
            ),
            "subsample": trial.suggest_float(
                "subsample", 0.6, 1.0
            ),
            "colsample_bytree": trial.suggest_float(
                "colsample_bytree", 0.6, 1.0
            ),
            "reg_alpha": trial.suggest_float(
                "reg_alpha", 1e-4, 10.0, log=True
            ),
            "reg_lambda": trial.suggest_float(
                "reg_lambda", 0.1, 100.0, log=True
            ),
            "gamma": trial.suggest_float(
                "gamma", 0.0, 5.0
            ),
        }

        summary, _ = evaluate_params(
            df, params, nrmse_scale
        )

        trial.set_user_attr(
            "mean_wmape_pct",
            summary["mean_wmape_pct"],
        )
        trial.set_user_attr(
            "mean_r2",
            summary["mean_r2"],
        )
        trial.set_user_attr(
            "std_nrmse",
            summary["std_nrmse"],
        )

        return summary["mean_nrmse"]

    return objective


# ============================================================
# MAIN
# ============================================================

def main():
    df = load_data(DATA_PATH)
    development = df.iloc[:DEVELOPMENT_END].copy()

    nrmse_scale = float(
        development["revenue"].mean()
    )

    OUTPUT_DIR.mkdir(
        parents=True, exist_ok=True
    )

    print("=== XGBOOST OPTUNA OPTIMIZATION ===")
    print(f"Trials: {N_TRIALS}")
    print(f"Seed: {RANDOM_SEED}")
    print(f"Development weeks: {len(development)}")
    print(f"CV folds: {len(get_cv_folds())}")
    print(f"NRMSE denominator: ${nrmse_scale:,.2f}")
    print("Final 42 weeks: excluded")

    sampler = optuna.samplers.TPESampler(
        seed=RANDOM_SEED,
        n_startup_trials=20,
    )

    study = optuna.create_study(
        direction="minimize",
        sampler=sampler,
        study_name="xgboost_raw_media",
    )

    study.optimize(
        make_objective(
            development, nrmse_scale
        ),
        n_trials=N_TRIALS,
        n_jobs=1,
        show_progress_bar=False,
    )

    summary, fold_results = evaluate_params(
        development,
        study.best_params,
        nrmse_scale,
    )

    print("\n=== BEST OPTIMIZATION RESULT ===")
    print(f"Best trial: {study.best_trial.number}")
    print(f"Mean CV NRMSE: {summary['mean_nrmse']:.6f}")
    print(f"Mean CV WMAPE: {summary['mean_wmape_pct']:.4f}%")
    print(f"Mean CV R2: {summary['mean_r2']:.4f}")
    print(f"Mean CV RMSE: ${summary['mean_rmse']:,.2f}")
    print(f"NRMSE std: {summary['std_nrmse']:.6f}")

    print("\n=== SELECTED PARAMETERS ===")
    for key, value in sorted(study.best_params.items()):
        print(f"{key}: {value}")

    print("\n=== FOLD-LEVEL RESULTS ===")
    print(
        pd.DataFrame(fold_results)
        .round(5)
        .to_string(index=False)
    )

    trials_path = (
        OUTPUT_DIR / "xgboost_optuna_trials.csv"
    )

    study.trials_dataframe().to_csv(
        trials_path,
        index=False,
    )

    results = {
        "model": "XGBoost",
        "features": "Raw media + controls + seasonality",
        "optimizer": "Optuna TPE",
        "seed": RANDOM_SEED,
        "n_trials": N_TRIALS,
        "development_weeks": DEVELOPMENT_END,
        "nrmse_scale": nrmse_scale,
        "best_params": study.best_params,
        "cv_summary": summary,
        "fold_results": fold_results,
        "evaluation_note": (
            "Expanding-window CV on development data. "
            "Previously examined holdout excluded."
        ),
    }

    results_path = (
        OUTPUT_DIR / "xgboost_optuna_best.json"
    )

    with open(results_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    print("\n=== OUTPUT FILES ===")
    print(trials_path)
    print(results_path)

    print("\nXGBOOST OPTIMIZATION COMPLETE")


if __name__ == "__main__":
    main()
