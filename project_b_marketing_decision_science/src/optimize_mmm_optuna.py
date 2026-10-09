
"""
Joint hyperparameter optimization for Ridge + Hill MMM.

Optimizer: Optuna TPE
Objective: Mean expanding-window CV NRMSE
Development period: First 166 weeks
Previously examined holdout: Excluded

Parameters optimized jointly:
- Five geometric adstock decay parameters
- Five Hill shape parameters
- Five half-saturation quantiles
- Ridge regularization
"""

from pathlib import Path
import json

import numpy as np
import optuna
import pandas as pd
from sklearn.preprocessing import StandardScaler

from fit_mmm import (
    DATA_PATH,
    MEDIA,
    fit_constrained_ridge,
    predict,
)
from media_transforms import geometric_adstock, hill_saturation
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
REVENUE_SCALE = 1_000_000.0

optuna.logging.set_verbosity(optuna.logging.WARNING)


# ============================================================
# FEATURE ENGINEERING
# ============================================================

def build_features(df, train_end, params):
    """
    Build chronological MMM features.

    All saturation reference values are derived from
    the current fold's training observations only.
    """
    features = pd.DataFrame(index=df.index)

    time = np.arange(len(df), dtype=float)
    period = 365.25 / 7

    features["time_index"] = time

    for k in [1, 2]:
        angle = 2 * np.pi * k * time / period
        features[f"sin_{k}"] = np.sin(angle)
        features[f"cos_{k}"] = np.cos(angle)

    for col in [
        "competitor_sales",
        "newsletter",
        "event_1",
        "event_2",
    ]:
        features[col] = df[col].to_numpy(dtype=float)

    for channel in MEDIA:
        theta = params[f"{channel}_theta"]
        alpha = params[f"{channel}_alpha"]
        quantile = params[f"{channel}_quantile"]

        adstock = geometric_adstock(
            df[channel].to_numpy(dtype=float),
            theta,
        )

        positive = adstock[:train_end]
        positive = positive[positive > 0]

        if len(positive) == 0:
            raise ValueError(
                f"No positive training adstock: {channel}"
            )

        half_saturation = float(
            np.quantile(positive, quantile)
        )

        features[channel] = hill_saturation(
            adstock,
            alpha=alpha,
            half_saturation=half_saturation,
        )

    return features


# ============================================================
# CROSS-VALIDATION
# ============================================================

def evaluate_params(df, params, nrmse_scale):
    """
    Evaluate one complete parameter configuration
    across all expanding-window CV folds.
    """
    fold_results = []

    for fold in get_cv_folds():
        train_end = fold["train_end"]
        val_end = fold["val_end"]

        # Do not construct features beyond this fold.
        fold_df = df.iloc[:val_end].copy()

        features = build_features(
            fold_df,
            train_end,
            params,
        )

        train_X = features.iloc[:train_end]
        val_X = features.iloc[train_end:val_end]

        train_y = fold_df["revenue"].iloc[
            :train_end
        ].to_numpy(dtype=float)

        val_y = fold_df["revenue"].iloc[
            train_end:val_end
        ].to_numpy(dtype=float)

        scaler = StandardScaler()

        X_train = scaler.fit_transform(train_X)
        X_val = scaler.transform(val_X)

        media_indices = [
            features.columns.get_loc(channel)
            for channel in MEDIA
        ]

        coefficients = fit_constrained_ridge(
            X_train,
            train_y / REVENUE_SCALE,
            media_indices,
            params["ridge_alpha"],
        )

        predictions = (
            predict(X_val, coefficients) * REVENUE_SCALE
        )

        metrics = calculate_metrics(
            val_y,
            predictions,
            nrmse_scale,
        )

        fold_results.append({
            "fold": fold["fold"],
            **metrics,
        })

    summary = summarize_cv(fold_results)

    return summary, fold_results


# ============================================================
# OPTUNA OBJECTIVE
# ============================================================

def make_objective(df, nrmse_scale):
    def objective(trial):
        params = {}

        params["ridge_alpha"] = trial.suggest_float(
            "ridge_alpha",
            0.001,
            100.0,
            log=True,
        )

        for channel in MEDIA:
            params[f"{channel}_theta"] = (
                trial.suggest_float(
                    f"{channel}_theta",
                    0.0,
                    0.9,
                )
            )

            params[f"{channel}_alpha"] = (
                trial.suggest_float(
                    f"{channel}_alpha",
                    0.5,
                    2.0,
                )
            )

            params[f"{channel}_quantile"] = (
                trial.suggest_float(
                    f"{channel}_quantile",
                    0.15,
                    0.85,
                )
            )

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

    # Exclude previously examined final holdout.
    development = df.iloc[:DEVELOPMENT_END].copy()

    nrmse_scale = float(
        development["revenue"].mean()
    )

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    print("=== OPTUNA JOINT MMM OPTIMIZATION ===")
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
        study_name="ridge_hill_mmm_joint",
    )

    study.optimize(
        make_objective(
            development,
            nrmse_scale,
        ),
        n_trials=N_TRIALS,
        n_jobs=1,
        show_progress_bar=True,
    )

    best_params = study.best_params

    summary, fold_results = evaluate_params(
        development,
        best_params,
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

    for key, value in sorted(best_params.items()):
        print(f"{key}: {value:.6f}")

    print("\n=== FOLD-LEVEL RESULTS ===")
    print(
        pd.DataFrame(fold_results)
        .round(5)
        .to_string(index=False)
    )

    # Save trial history for later comparison.
    trials_path = OUTPUT_DIR / "ridge_hill_optuna_trials.csv"

    study.trials_dataframe().to_csv(
        trials_path,
        index=False,
    )

    results = {
        "model": "Ridge + Hill MMM",
        "optimizer": "Optuna TPE",
        "seed": RANDOM_SEED,
        "n_trials": N_TRIALS,
        "development_weeks": DEVELOPMENT_END,
        "nrmse_scale": nrmse_scale,
        "best_params": best_params,
        "cv_summary": summary,
        "fold_results": fold_results,
        "evaluation_note": (
            "Expanding-window CV on development data. "
            "Previously examined final holdout excluded."
        ),
    }

    results_path = (
        OUTPUT_DIR / "ridge_hill_optuna_best.json"
    )

    with open(results_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    print("\n=== OUTPUT FILES ===")
    print(trials_path)
    print(results_path)

    print("\nOPTIMIZATION COMPLETE")


if __name__ == "__main__":
    main()
