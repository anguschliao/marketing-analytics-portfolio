
"""
Shared evaluation framework for Project B.

All model families use identical chronological folds
and the same evaluation metrics.

Primary optimization metric:
    Mean expanding-window CV NRMSE.

The final 42 weeks are excluded from model selection.
"""

import numpy as np
import pandas as pd
from sklearn.metrics import r2_score


# ============================================================
# CONFIGURATION
# ============================================================

INITIAL_TRAIN = 94
VALIDATION_SIZE = 24
N_FOLDS = 3
DEVELOPMENT_END = 166
EXPECTED_WEEKS = 208


# ============================================================
# DATA LOADING
# ============================================================

def load_data(path):
    df = pd.read_csv(path, parse_dates=["date"])
    df = df.sort_values("date").reset_index(drop=True)

    if len(df) != EXPECTED_WEEKS:
        raise ValueError(
            f"Expected {EXPECTED_WEEKS} weeks, got {len(df)}."
        )

    if df["date"].duplicated().any():
        raise ValueError("Duplicate dates detected.")

    if not (
        df["date"].diff().dropna().dt.days == 7
    ).all():
        raise ValueError("Non-weekly intervals detected.")

    if df.isna().any().any():
        raise ValueError("Missing values detected.")

    return df


# ============================================================
# TIME-SERIES SPLITS
# ============================================================

def get_cv_folds():
    folds = []

    for i in range(N_FOLDS):
        train_end = INITIAL_TRAIN + i * VALIDATION_SIZE
        val_end = train_end + VALIDATION_SIZE

        if val_end > DEVELOPMENT_END:
            raise ValueError(
                "Cross-validation overlaps final holdout."
            )

        folds.append({
            "fold": i + 1,
            "train_start": 0,
            "train_end": train_end,
            "val_start": train_end,
            "val_end": val_end,
        })

    return folds


# ============================================================
# EVALUATION METRICS
# ============================================================

def calculate_metrics(y_true, y_pred, nrmse_scale):
    """
    Calculate common regression metrics.

    NRMSE denominator is a fixed mean revenue
    calculated from the development period.
    """
    actual = np.asarray(y_true, dtype=float)
    predicted = np.asarray(y_pred, dtype=float)

    if actual.shape != predicted.shape:
        raise ValueError("Actual and predicted shapes differ.")

    if actual.ndim != 1 or len(actual) == 0:
        raise ValueError("Expected nonempty 1D arrays.")

    if not np.all(np.isfinite(actual)):
        raise ValueError("Actual values must be finite.")

    if not np.all(np.isfinite(predicted)):
        raise ValueError("Predictions must be finite.")

    if not np.isfinite(nrmse_scale) or nrmse_scale <= 0:
        raise ValueError("Invalid NRMSE normalization scale.")

    errors = predicted - actual

    mae = np.mean(np.abs(errors))
    rmse = np.sqrt(np.mean(errors ** 2))

    actual_total = np.sum(np.abs(actual))

    wmape = (
        np.sum(np.abs(errors)) / actual_total * 100
        if actual_total > 0 else np.nan
    )

    return {
        "r2": float(r2_score(actual, predicted)),
        "rmse": float(rmse),
        "nrmse": float(rmse / nrmse_scale),
        "mae": float(mae),
        "wmape_pct": float(wmape),
        "bias": float(np.mean(errors)),
    }


# ============================================================
# CROSS-VALIDATION SUMMARY
# ============================================================

def summarize_cv(fold_results):
    """
    Aggregate fold-level metrics.

    Each validation fold contains 24 weeks,
    so the arithmetic mean weights folds equally.
    """
    results = pd.DataFrame(fold_results)

    required = [
        "r2",
        "rmse",
        "nrmse",
        "mae",
        "wmape_pct",
        "bias",
    ]

    missing = [
        col for col in required
        if col not in results.columns
    ]

    if missing:
        raise ValueError(
            f"Missing metric columns: {missing}"
        )

    summary = {}

    for col in required:
        summary[f"mean_{col}"] = float(
            results[col].mean()
        )
        summary[f"std_{col}"] = float(
            results[col].std(ddof=0)
        )

    return summary


# ============================================================
# SELF-TEST
# ============================================================

def self_test():
    folds = get_cv_folds()

    assert len(folds) == 3
    assert folds[0]["train_end"] == 94
    assert folds[0]["val_end"] == 118
    assert folds[1]["train_end"] == 118
    assert folds[1]["val_end"] == 142
    assert folds[2]["train_end"] == 142
    assert folds[2]["val_end"] == 166

    actual = np.array([100.0, 200.0, 300.0])
    predicted = np.array([110.0, 190.0, 290.0])

    metrics = calculate_metrics(
        actual,
        predicted,
        nrmse_scale=200.0,
    )

    assert np.isclose(metrics["mae"], 10.0)
    assert np.isclose(metrics["rmse"], 10.0)
    assert np.isclose(metrics["nrmse"], 0.05)
    assert np.isclose(metrics["wmape_pct"], 5.0)
    assert np.isclose(metrics["bias"], -10.0 / 3.0)

    summary = summarize_cv([
        {"fold": i, **metrics}
        for i in range(1, 4)
    ])

    assert np.isclose(summary["mean_nrmse"], 0.05)
    assert np.isclose(summary["std_nrmse"], 0.0)

    print("=== SHARED MODEL EVALUATION TEST ===")
    print("Cross-validation folds: PASSED")
    print("Regression metrics: PASSED")
    print("CV aggregation: PASSED")
    print("Final holdout exclusion: PASSED")

    print("\n=== CROSS-VALIDATION FOLDS ===")

    for fold in folds:
        print(
            f"Fold {fold['fold']}: "
            f"train={fold['train_end']} weeks, "
            f"validation={fold['val_start']}:{fold['val_end']}"
        )

    print("\n=== SAMPLE METRICS ===")

    for name, value in metrics.items():
        print(f"{name}: {value:.6f}")

    print("\nALL EVALUATION TESTS PASSED")


if __name__ == "__main__":
    self_test()
