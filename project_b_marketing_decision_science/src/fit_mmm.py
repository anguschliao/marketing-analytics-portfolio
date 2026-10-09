
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.optimize import lsq_linear
from sklearn.metrics import (
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)
from sklearn.preprocessing import StandardScaler

from media_transforms import geometric_adstock, hill_saturation


PROJECT_DIR = Path(__file__).resolve().parents[1]
DATA_PATH = PROJECT_DIR / "data" / "processed" / "mmm_weekly.csv"

MEDIA = [
    "tv_spend",
    "ooh_spend",
    "print_spend",
    "facebook_spend",
    "search_spend",
]

CONTROLS = ["competitor_sales", "newsletter"]
EVENTS = ["event_1", "event_2"]

TRAIN_END = 130
VALIDATION_END = 166

# Initial illustrative parameters, not optimized estimates.
THETA = {
    "tv_spend": 0.70,
    "ooh_spend": 0.60,
    "print_spend": 0.50,
    "facebook_spend": 0.40,
    "search_spend": 0.20,
}

ALPHA = 1.0
RIDGE_ALPHA = 10.0


def build_features(df):
    """
    Construct chronological seasonal and media features.

    Half-saturation values are determined using only
    the first 130 training observations.
    """
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

    half_saturation = {}

    for col in MEDIA:
        adstock = geometric_adstock(
            df[col].to_numpy(),
            THETA[col],
        )

        # Estimate saturation scale using training data only.
        positive = adstock[:TRAIN_END]
        positive = positive[positive > 0]

        if len(positive) == 0:
            raise ValueError(f"No positive adstock for {col}")

        half = float(np.median(positive))
        half_saturation[col] = half

        features[col] = hill_saturation(
            adstock,
            alpha=ALPHA,
            half_saturation=half,
        )

    return features, half_saturation


def fit_constrained_ridge(X, y, media_indices, alpha):
    """
    Fit Ridge regression with:
      - Nonnegative media coefficients
      - Unrestricted control coefficients
      - Unpenalized intercept

    Uses augmented least squares with coefficient bounds.
    """
    n, p = X.shape

    design = np.column_stack([np.ones(n), X])

    penalty = np.zeros((p, p + 1))
    penalty[:, 1:] = np.sqrt(alpha) * np.eye(p)

    augmented_X = np.vstack([design, penalty])
    augmented_y = np.concatenate([y, np.zeros(p)])

    lower = np.full(p + 1, -np.inf)
    upper = np.full(p + 1, np.inf)

    for idx in media_indices:
        lower[idx + 1] = 0.0

    result = lsq_linear(
        augmented_X,
        augmented_y,
        bounds=(lower, upper),
        method="trf",
        max_iter=2000,
        tol=1e-10,
    )

    if not result.success:
        raise RuntimeError(
            f"Constrained optimization failed: {result.message}"
        )

    return result.x


def predict(X, coefficients):
    design = np.column_stack([
        np.ones(len(X)),
        X,
    ])
    return design @ coefficients


def evaluate(y_true, y_pred):
    return {
        "r2": r2_score(y_true, y_pred),
        "rmse": np.sqrt(mean_squared_error(y_true, y_pred)),
        "mae": mean_absolute_error(y_true, y_pred),
        "wmape_pct": (
            np.abs(y_true - y_pred).sum()
            / np.abs(y_true).sum()
            * 100
        ),
    }


def main():
    df = pd.read_csv(DATA_PATH, parse_dates=["date"])
    df = df.sort_values("date").reset_index(drop=True)

    if len(df) != 208:
        raise ValueError("Expected 208 weekly observations.")

    features, half_saturation = build_features(df)

    train_X = features.iloc[:TRAIN_END]
    val_X = features.iloc[TRAIN_END:VALIDATION_END]

    train_y = df["revenue"].iloc[:TRAIN_END].to_numpy()
    val_y = df["revenue"].iloc[
        TRAIN_END:VALIDATION_END
    ].to_numpy()

    # Fit feature scaling on training data only.
    scaler = StandardScaler()

    X_train = scaler.fit_transform(train_X)
    X_val = scaler.transform(val_X)

    # Scale target to millions for numerical stability.
    revenue_scale = 1_000_000.0
    y_train = train_y / revenue_scale

    media_indices = [
        features.columns.get_loc(col)
        for col in MEDIA
    ]

    coefficients = fit_constrained_ridge(
        X_train,
        y_train,
        media_indices,
        RIDGE_ALPHA,
    )

    pred_train = predict(
        X_train, coefficients
    ) * revenue_scale

    pred_val = predict(
        X_val, coefficients
    ) * revenue_scale

    print("=== FULL MMM ESTIMATION ENGINE ===")

    print(f"Training weeks: {len(train_X)}")
    print(f"Validation weeks: {len(val_X)}")
    print("Final test weeks: 42 (untouched)")

    print("\n=== TRANSFORMATION PARAMETERS ===")

    for col in MEDIA:
        print(
            f"{col}: "
            f"theta={THETA[col]:.2f}, "
            f"alpha={ALPHA:.2f}, "
            f"half_saturation={half_saturation[col]:,.2f}"
        )

    print("\n=== MODEL PERFORMANCE ===")

    for name, actual, predicted in [
        ("TRAIN", train_y, pred_train),
        ("VALIDATION", val_y, pred_val),
    ]:
        metrics = evaluate(actual, predicted)

        print(f"\n{name}")

        for metric, value in metrics.items():
            print(f"{metric}: {value:,.4f}")

    print("\n=== MEDIA COEFFICIENTS ===")

    coef_series = pd.Series(
        coefficients[1:],
        index=features.columns,
    )

    for col in MEDIA:
        print(f"{col}: {coef_series[col]:.6f}")

    assert all(
        coef_series[col] >= -1e-8
        for col in MEDIA
    ), "Negative media coefficient detected"

    print("\nAll media coefficients are nonnegative.")
    print("Estimation completed successfully.")

    print(
        "\nNOTE: Media coefficients are on standardized "
        "features and a revenue-in-millions scale."
    )
    print(
        "They are not channel contributions or ROAS."
    )


if __name__ == "__main__":
    main()
