
"""
Project B — GAM + Optuna optimization.

Model: Additive spline regression with Ridge regularization
Optimizer: Optuna TPE
Objective: Mean expanding-window CV NRMSE

Media inputs: Raw weekly spend
Development: First 166 weeks
Previously examined final 42 weeks: Excluded
"""

from pathlib import Path
import json

import numpy as np
import optuna
import pandas as pd

from sklearn.compose import ColumnTransformer
from sklearn.linear_model import Ridge
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import (
    SplineTransformer,
    StandardScaler,
)

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
    Build raw-media features with trend and seasonality.
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
# MODEL
# ============================================================

def build_model(params):
    """
    Build additive spline regression.

    Media variables receive separate spline bases.
    Controls and seasonality remain linear.
    """
    linear_features = [
        "time_index",
        "sin_1",
        "cos_1",
        "sin_2",
        "cos_2",
    ] + CONTROLS + EVENTS

    transformers = []

    for channel in MEDIA:
        transformers.append((
            f"spline_{channel}",
            SplineTransformer(
                n_knots=params["n_knots"],
                degree=params["degree"],
                knots="quantile",
                extrapolation="constant",
                include_bias=False,
            ),
            [channel],
        ))

    transformers.append((
        "linear",
        "passthrough",
        linear_features,
    ))

    preprocessing = ColumnTransformer(
        transformers=transformers,
        remainder="drop",
    )

    model = Pipeline([
        ("preprocessing", preprocessing),
        ("scaler", StandardScaler()),
        ("ridge", Ridge(
            alpha=params["ridge_alpha"],
        )),
    ])

    return model


# ============================================================
# CROSS-VALIDATION
# ============================================================

def evaluate_params(df, params, nrmse_scale):
    """
    Evaluate one GAM configuration across
    expanding-window CV folds.
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

        model = build_model(params)

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
            "n_knots": trial.suggest_int(
                "n_knots",
                3,
                8,
            ),
            "degree": trial.suggest_int(
                "degree",
                2,
                3,
            ),
            "ridge_alpha": trial.suggest_float(
                "ridge_alpha",
                0.01,
                1000.0,
                log=True,
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

    print("=== GAM OPTUNA OPTIMIZATION ===")
    print(f"Trials: {N_TRIALS}")
    print(f"Seed: {RANDOM_SEED}")
    print(f"Development weeks: {len(development)}")
    print(f"CV folds: {len(get_cv_folds())}")
    print(f"NRMSE denominator: ${nrmse_scale:,.2f}")
    print("Media response: additive splines")
    print("Final 42 weeks: excluded")

    sampler = optuna.samplers.TPESampler(
        seed=RANDOM_SEED,
        n_startup_trials=20,
    )

    study = optuna.create_study(
        direction="minimize",
        sampler=sampler,
        study_name="gam_raw_media",
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

    trials_path = (
        OUTPUT_DIR / "gam_optuna_trials.csv"
    )

    study.trials_dataframe().to_csv(
        trials_path,
        index=False,
    )

    results = {
        "model": "Generalized Additive Model",
        "implementation": "SplineTransformer + Ridge",
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
        OUTPUT_DIR / "gam_optuna_best.json"
    )

    with open(results_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    print("\n=== OUTPUT FILES ===")
    print(trials_path)
    print(results_path)

    print("\nGAM OPTIMIZATION COMPLETE")


if __name__ == "__main__":
    main()
