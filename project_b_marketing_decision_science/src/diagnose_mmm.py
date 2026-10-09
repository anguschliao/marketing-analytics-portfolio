import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler

from fit_mmm import (
    DATA_PATH,
    MEDIA,
    fit_constrained_ridge,
    predict,
)
from tune_mmm import (
    INITIAL_TRAIN,
    VALIDATION_SIZE,
    N_FOLDS,
    HOLDOUT_START,
    SELECTED_RIDGE_ALPHA,
    build_fold_features,
)


OPTIMIZED_THETA = {
    "tv_spend": 0.50,
    "ooh_spend": 0.70,
    "print_spend": 0.50,
    "facebook_spend": 0.60,
    "search_spend": 0.40,
}


def main():
    df = pd.read_csv(DATA_PATH, parse_dates=["date"])
    df = df.sort_values("date").reset_index(drop=True)

    # Never include final holdout observations.
    df = df.iloc[:HOLDOUT_START].copy()

    all_results = []

    for fold in range(N_FOLDS):
        train_end = INITIAL_TRAIN + fold * VALIDATION_SIZE
        val_end = train_end + VALIDATION_SIZE

        fold_df = df.iloc[:val_end].copy()

        features = build_fold_features(
            fold_df,
            train_end,
            OPTIMIZED_THETA,
        )

        scaler = StandardScaler()

        X_train = scaler.fit_transform(
            features.iloc[:train_end]
        )

        X_val = scaler.transform(
            features.iloc[train_end:val_end]
        )

        y_train = fold_df["revenue"].iloc[
            :train_end
        ].to_numpy(dtype=float)

        y_val = fold_df["revenue"].iloc[
            train_end:val_end
        ].to_numpy(dtype=float)

        media_indices = [
            features.columns.get_loc(col)
            for col in MEDIA
        ]

        coefficients = fit_constrained_ridge(
            X_train,
            y_train / 1_000_000.0,
            media_indices,
            SELECTED_RIDGE_ALPHA,
        )

        predictions = (
            predict(X_val, coefficients) * 1_000_000.0
        )

        dates = fold_df["date"].iloc[
            train_end:val_end
        ].to_numpy()

        for date, actual, predicted in zip(
            dates, y_val, predictions
        ):
            all_results.append({
                "fold": fold + 1,
                "date": date,
                "actual": actual,
                "predicted": predicted,
                "error": predicted - actual,
                "absolute_error": abs(predicted - actual),
            })

    results = pd.DataFrame(all_results)

    results["month"] = results["date"].dt.month
    results["percentage_error"] = (
        results["error"] / results["actual"] * 100
    )

    print("=== FOLD-LEVEL RESIDUAL DIAGNOSTICS ===")

    summary = results.groupby("fold").agg(
        weeks=("actual", "count"),
        mean_actual=("actual", "mean"),
        mean_predicted=("predicted", "mean"),
        mean_bias=("error", "mean"),
        mae=("absolute_error", "mean"),
        max_absolute_error=("absolute_error", "max"),
        total_absolute_error=("absolute_error", "sum"),
        total_actual=("actual", "sum"),
    )

    summary["wmape_pct"] = (
        summary["total_absolute_error"]
        / summary["total_actual"] * 100
    )

    print("\n=== FOLD SUMMARY ===")
    print(summary.round(2).to_string())

    print("\n=== MONTHLY ERROR SUMMARY ===")

    monthly = results.groupby(["fold", "month"]).agg(
        weeks=("actual", "count"),
        mean_actual=("actual", "mean"),
        mean_predicted=("predicted", "mean"),
        mean_bias=("error", "mean"),
        mae=("absolute_error", "mean"),
    )

    print(monthly.round(2).to_string())

    print("\n=== FIVE LARGEST WEEKLY ERRORS ===")

    largest = results.nlargest(
        5, "absolute_error"
    )[
        [
            "fold",
            "date",
            "actual",
            "predicted",
            "error",
            "percentage_error",
        ]
    ]

    print(largest.round(2).to_string(index=False))

    print("\n=== PREDICTION DIRECTION ===")

    for fold, group in results.groupby("fold"):
        over = (group["error"] > 0).sum()
        under = (group["error"] < 0).sum()

        print(
            f"Fold {fold}: "
            f"overpredicted={over}, "
            f"underpredicted={under}"
        )

    print("\nFinal holdout remains untouched.")


if __name__ == "__main__":
    main()