
"""
Project B — EBM + Optuna optimization.

Model: ExplainableBoostingRegressor
Optimizer: Optuna TPE
Objective: Mean expanding-window CV NRMSE

Uses first 166 weeks only.
Previously examined 42-week holdout excluded.
"""

from pathlib import Path
import json

import numpy as np
import optuna
import pandas as pd

from interpret.glassbox import ExplainableBoostingRegressor

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
    Construct common raw-media predictive features.
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
    Evaluate EBM on identical chronological CV folds.
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

        model = ExplainableBoostingRegressor(
            interactions=0,
            random_state=RANDOM_SEED,
            n_jobs=1,
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
            "learning_rate": trial.suggest_float(
                "learning_rate",
                0.005,
                0.1,
                log=True,
            ),
            "max_leaves": trial.suggest_int(
                "max_leaves",
                2,
                5,
            ),
            "min_samples_leaf": trial.suggest_int(
                "min_samples_leaf",
                5,
                25,
            ),
            "max_rounds": trial.suggest_int(
                "max_rounds",
                100,
                1000,
                step=100,
            ),
            "outer_bags": trial.suggest_int(
                "outer_bags",
                1,
                4,
            ),
            "smoothing_rounds": trial.suggest_int(
                "smoothing_rounds",
                0,
                100,
                step=25,
            ),
            "max_bins": trial.suggest_categorical(
                "max_bins",
                [16, 32, 64],
            ),
        }

        summary, _ = evaluate_params(
            df,
            params,
            nrmse_scale,
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

    development = df.iloc[
        :DEVELOPMENT_END
    ].copy()

    nrmse_scale = float(
        development["revenue"].mean()
    )

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    print("=== EBM OPTUNA OPTIMIZATION ===")
    print(f"Trials: {N_TRIALS}")
    print(f"Seed: {RANDOM_SEED}")
    print(f"Development weeks: {len(development)}")
    print(f"CV folds: {len(get_cv_folds())}")
    print(f"NRMSE denominator: ${nrmse_scale:,.2f}")
    print("Interactions: disabled")
    print("Final 42 weeks: excluded")

    sampler = optuna.samplers.TPESampler(
        seed=RANDOM_SEED,
        n_startup_trials=20,
    )

    study = optuna.create_study(
        direction="minimize",
        sampler=sampler,
        study_name="ebm_raw_media",
    )

    study.optimize(
        make_objective(
            development,
            nrmse_scale,
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

    # Save complete trial history.
    trials_path = (
        OUTPUT_DIR / "ebm_optuna_trials.csv"
    )

    study.trials_dataframe().to_csv(
        trials_path,
        index=False,
    )

    results = {
        "model": "Explainable Boosting Machine",
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
        OUTPUT_DIR / "ebm_optuna_best.json"
    )

    with open(results_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    print("\n=== OUTPUT FILES ===")
    print(trials_path)
    print(results_path)

    print("\nEBM OPTIMIZATION COMPLETE")


if __name__ == "__main__":
    main()
