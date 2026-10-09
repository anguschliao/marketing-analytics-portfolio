
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler

from fit_mmm import (
    DATA_PATH,
    MEDIA,
    THETA,
    ALPHA,
    fit_constrained_ridge,
    predict,
    evaluate,
)
from media_transforms import geometric_adstock, hill_saturation


# ============================================================
# CONFIGURATION
# ============================================================

INITIAL_TRAIN = 94
VALIDATION_SIZE = 24
N_FOLDS = 3
HOLDOUT_START = 166

RIDGE_CANDIDATES = [0.01, 0.1, 1.0, 10.0, 100.0]
SELECTED_RIDGE_ALPHA = 0.01

ADSTOCK_CANDIDATES = {
    "tv_spend": [0.3, 0.5, 0.7, 0.9],
    "ooh_spend": [0.3, 0.5, 0.7, 0.9],
    "print_spend": [0.1, 0.3, 0.5, 0.7],
    "facebook_spend": [0.0, 0.2, 0.4, 0.6],
    "search_spend": [0.0, 0.1, 0.2, 0.4],
}

OPTIMIZED_THETA = {
    "tv_spend": 0.50,
    "ooh_spend": 0.70,
    "print_spend": 0.50,
    "facebook_spend": 0.60,
    "search_spend": 0.40,
}

SATURATION_QUANTILES = [0.25, 0.50, 0.75]

MAX_PASSES = 3


# ============================================================
# FEATURE ENGINEERING
# ============================================================

def build_fold_features(
    df,
    train_end,
    theta_params=None,
    saturation_quantiles=None,
):
    """
    Build MMM features using fold-specific training statistics.

    Adstock is calculated chronologically, preserving
    carryover from earlier weeks.

    Half-saturation values are derived only from the
    training portion of the current fold.
    """
    if theta_params is None:
        theta_params = THETA

    if saturation_quantiles is None:
        saturation_quantiles = {
            col: 0.50 for col in MEDIA
        }

    features = pd.DataFrame(index=df.index)

    time = np.arange(len(df), dtype=float)
    period = 365.25 / 7

    # Trend
    features["time_index"] = time

    # Annual Fourier seasonality
    for k in [1, 2]:
        angle = 2 * np.pi * k * time / period
        features[f"sin_{k}"] = np.sin(angle)
        features[f"cos_{k}"] = np.cos(angle)

    # External and organic controls
    for col in [
        "competitor_sales",
        "newsletter",
        "event_1",
        "event_2",
    ]:
        features[col] = df[col].to_numpy(dtype=float)

    # Media transformations
    for col in MEDIA:
        adstock = geometric_adstock(
            df[col].to_numpy(dtype=float),
            theta_params[col],
        )

        positive = adstock[:train_end]
        positive = positive[positive > 0]

        if len(positive) == 0:
            raise ValueError(
                f"No positive training adstock for {col}"
            )

        quantile = saturation_quantiles[col]

        if not 0 < quantile < 1:
            raise ValueError(
                f"Invalid saturation quantile for {col}"
            )

        half_saturation = float(
            np.quantile(positive, quantile)
        )

        features[col] = hill_saturation(
            adstock,
            alpha=ALPHA,
            half_saturation=half_saturation,
        )

    return features


# ============================================================
# CROSS-VALIDATION
# ============================================================

def run_fold(
    df,
    train_end,
    val_end,
    ridge_alpha,
    theta_params=None,
    saturation_quantiles=None,
):
    """
    Fit constrained MMM on one chronological fold.

    Feature scaling and saturation reference values
    use training observations only.
    """
    if not (0 < train_end < val_end <= HOLDOUT_START):
        raise ValueError("Invalid chronological fold boundaries.")

    fold_df = df.iloc[:val_end].copy()

    features = build_fold_features(
        fold_df,
        train_end,
        theta_params,
        saturation_quantiles,
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
        features.columns.get_loc(col)
        for col in MEDIA
    ]

    revenue_scale = 1_000_000.0

    coefficients = fit_constrained_ridge(
        X_train,
        train_y / revenue_scale,
        media_indices,
        ridge_alpha,
    )

    predictions = (
        predict(X_val, coefficients) * revenue_scale
    )

    return evaluate(val_y, predictions)


def evaluate_theta(
    df,
    theta_params,
    ridge_alpha=SELECTED_RIDGE_ALPHA,
    saturation_quantiles=None,
):
    """
    Evaluate a parameter configuration across
    expanding-window validation folds.
    """
    fold_results = []

    for fold in range(N_FOLDS):
        train_end = (
            INITIAL_TRAIN + fold * VALIDATION_SIZE
        )
        val_end = train_end + VALIDATION_SIZE

        metrics = run_fold(
            df,
            train_end,
            val_end,
            ridge_alpha,
            theta_params,
            saturation_quantiles,
        )

        fold_results.append(metrics)

    return {
        "mean_wmape": float(np.mean([
            m["wmape_pct"] for m in fold_results
        ])),
        "mean_rmse": float(np.mean([
            m["rmse"] for m in fold_results
        ])),
        "mean_mae": float(np.mean([
            m["mae"] for m in fold_results
        ])),
        "mean_r2": float(np.mean([
            m["r2"] for m in fold_results
        ])),
        "fold_wmape": [
            float(m["wmape_pct"])
            for m in fold_results
        ],
    }


# ============================================================
# RIDGE REGULARIZATION TUNING
# ============================================================

def tune_ridge(df):
    """
    Evaluate candidate Ridge penalties using
    the initial fixed adstock parameters.
    """
    print("\n=== RIDGE REGULARIZATION TUNING ===")

    results = []

    for ridge_alpha in RIDGE_CANDIDATES:
        metrics = evaluate_theta(
            df,
            THETA,
            ridge_alpha,
        )

        results.append({
            "ridge_alpha": ridge_alpha,
            "mean_r2": metrics["mean_r2"],
            "mean_rmse": metrics["mean_rmse"],
            "mean_mae": metrics["mean_mae"],
            "mean_wmape_pct": metrics["mean_wmape"],
        })

    results_df = pd.DataFrame(results)
    results_df = results_df.sort_values(
        "mean_wmape_pct"
    )

    print(
        results_df.round(4).to_string(index=False)
    )

    best_alpha = float(
        results_df.iloc[0]["ridge_alpha"]
    )

    print(f"\nBest Ridge alpha: {best_alpha}")

    return best_alpha


# ============================================================
# ADSTOCK OPTIMIZATION
# ============================================================

def optimize_adstock(
    df,
    ridge_alpha=SELECTED_RIDGE_ALPHA,
    max_passes=MAX_PASSES,
):
    """
    Coordinate-descent optimization of channel-specific
    geometric adstock decay parameters.
    """
    theta = THETA.copy()

    best = evaluate_theta(
        df,
        theta,
        ridge_alpha,
    )

    print("\n=== ADSTOCK OPTIMIZATION ===")
    print(f"Initial WMAPE: {best['mean_wmape']:.4f}%")

    for iteration in range(max_passes):
        improved = False

        print(f"\nPASS {iteration + 1}")

        for channel in MEDIA:
            channel_best = best
            best_value = theta[channel]

            for candidate in ADSTOCK_CANDIDATES[channel]:
                trial = theta.copy()
                trial[channel] = candidate

                result = evaluate_theta(
                    df,
                    trial,
                    ridge_alpha,
                )

                if result["mean_wmape"] < (
                    channel_best["mean_wmape"] - 1e-6
                ):
                    channel_best = result
                    best_value = candidate

            if best_value != theta[channel]:
                improved = True

            theta[channel] = best_value
            best = channel_best

            print(
                f"{channel}: theta={best_value:.2f}, "
                f"WMAPE={best['mean_wmape']:.4f}%"
            )

        if not improved:
            print("No further improvement.")
            break

    print("\n=== OPTIMIZED ADSTOCK PARAMETERS ===")

    for channel in MEDIA:
        print(f"{channel}: {theta[channel]:.2f}")

    print("\n=== ADSTOCK CV METRICS ===")
    print(f"Mean WMAPE: {best['mean_wmape']:.4f}%")
    print(f"Mean RMSE: ${best['mean_rmse']:,.2f}")
    print(f"Mean R2: {best['mean_r2']:.4f}")

    return theta, best


# ============================================================
# HILL SATURATION OPTIMIZATION
# ============================================================

def optimize_saturation(
    df,
    theta_params,
    ridge_alpha=SELECTED_RIDGE_ALPHA,
    max_passes=MAX_PASSES,
):
    """
    Coordinate-descent optimization of channel-specific
    Hill half-saturation quantiles.

    Hill alpha remains fixed at 1.0.

    Each quantile is applied to positive adstock
    observations in the training portion of each fold.
    """
    quantiles = {
        col: 0.50 for col in MEDIA
    }

    best = evaluate_theta(
        df,
        theta_params,
        ridge_alpha,
        quantiles,
    )

    print("\n=== HILL SATURATION OPTIMIZATION ===")
    print(f"Initial mean WMAPE: {best['mean_wmape']:.4f}%")

    for iteration in range(max_passes):
        improved = False

        print(f"\nPASS {iteration + 1}")

        for channel in MEDIA:
            channel_best = best
            best_value = quantiles[channel]

            for candidate in SATURATION_QUANTILES:
                trial = quantiles.copy()
                trial[channel] = candidate

                result = evaluate_theta(
                    df,
                    theta_params,
                    ridge_alpha,
                    trial,
                )

                if result["mean_wmape"] < (
                    channel_best["mean_wmape"] - 1e-6
                ):
                    channel_best = result
                    best_value = candidate

            if best_value != quantiles[channel]:
                improved = True

            quantiles[channel] = best_value
            best = channel_best

            print(
                f"{channel}: q={best_value:.2f}, "
                f"WMAPE={best['mean_wmape']:.4f}%"
            )

        if not improved:
            print("No further improvement.")
            break

    print("\n=== OPTIMIZED SATURATION QUANTILES ===")

    for channel in MEDIA:
        print(f"{channel}: {quantiles[channel]:.2f}")

    print("\n=== FINAL CROSS-VALIDATION METRICS ===")
    print(f"Mean WMAPE: {best['mean_wmape']:.4f}%")
    print(f"Mean RMSE: ${best['mean_rmse']:,.2f}")
    print(f"Mean MAE: ${best['mean_mae']:,.2f}")
    print(f"Mean R2: {best['mean_r2']:.4f}")

    print("\nFold WMAPE:")
    for i, value in enumerate(best["fold_wmape"], 1):
        print(f"Fold {i}: {value:.4f}%")

    return quantiles, best


# ============================================================
# MAIN
# ============================================================

def main():
    df = pd.read_csv(
        DATA_PATH,
        parse_dates=["date"],
    )

    df = df.sort_values("date").reset_index(drop=True)

    if len(df) != 208:
        raise ValueError(
            f"Expected 208 observations, found {len(df)}"
        )

    if not df["date"].is_unique:
        raise ValueError("Duplicate dates detected.")

    if not (
        df["date"].diff().dropna().dt.days == 7
    ).all():
        raise ValueError("Non-weekly date intervals detected.")

    print("=== PROJECT B: MMM PARAMETER OPTIMIZATION ===")
    print(f"Observations: {len(df)}")
    print(f"CV folds: {N_FOLDS}")
    print(f"Validation weeks per fold: {VALIDATION_SIZE}")
    print(f"Final holdout starts at index: {HOLDOUT_START}")

    # Stage A: Ridge tuning
    selected_ridge = tune_ridge(df)

    # Stage B: Adstock optimization
    optimized_theta, adstock_metrics = optimize_adstock(
        df,
        ridge_alpha=selected_ridge,
    )

    # Stage C: Hill half-saturation optimization
    optimized_quantiles, saturation_metrics = optimize_saturation(
        df,
        theta_params=optimized_theta,
        ridge_alpha=selected_ridge,
    )

    print("\n=== OVERALL OPTIMIZATION SUMMARY ===")
    print(f"Ridge alpha: {selected_ridge}")
    print(
        f"Adstock WMAPE: "
        f"{adstock_metrics['mean_wmape']:.4f}%"
    )
    print(
        f"Saturation WMAPE: "
        f"{saturation_metrics['mean_wmape']:.4f}%"
    )
    print(
        f"Improvement: "
        f"{adstock_metrics['mean_wmape'] - saturation_metrics['mean_wmape']:.4f} "
        "percentage points"
    )

    print("\nSelected parameters:")
    for channel in MEDIA:
        print(
            f"{channel}: "
            f"theta={optimized_theta[channel]:.2f}, "
            f"quantile={optimized_quantiles[channel]:.2f}"
        )

    print("\nFinal 42-week holdout remains untouched.")


if __name__ == "__main__":
    main()
