
"""
Project B — Holiday Impact on MMM Attribution

Compare frozen Optuna Ridge + Hill MMM:
A: Original specification
B: Christmas + New Year controls

Fit both models on the same 166 development weeks.

Calculate:
- Modeled baseline revenue
- Channel-specific zero-spend contributions
- Contribution share
- Modeled ROAS
- Attribution changes after adding holidays

All estimates are model-implied, not causal proof.
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
from model_evaluation import load_data, DEVELOPMENT_END


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


# ============================================================
# LOAD PARAMETERS
# ============================================================

def load_parameters():
    with open(
        PARAMETERS_PATH,
        "r",
        encoding="utf-8",
    ) as f:
        return json.load(f)["best_params"]


# ============================================================
# FIT MODEL AND CALCULATE ATTRIBUTION
# ============================================================

def analyze_model(df, params, include_holidays):
    features = build_features(
        df,
        train_end=len(df),
        params=params,
    )

    if include_holidays:
        holidays = build_holiday_features(df)[
            ["christmas", "new_year"]
        ]

        features = pd.concat(
            [features, holidays],
            axis=1,
        )

    scaler = StandardScaler()

    X = scaler.fit_transform(features)

    y = df["revenue"].to_numpy(dtype=float)

    media_indices = [
        features.columns.get_loc(channel)
        for channel in MEDIA
    ]

    coefficients = fit_constrained_ridge(
        X,
        y / REVENUE_SCALE,
        media_indices,
        params["ridge_alpha"],
    )

    predictions = (
        predict(X, coefficients) * REVENUE_SCALE
    )

    # Counterfactual: remove all paid media.
    no_media_features = features.copy()
    no_media_features[MEDIA] = 0.0

    baseline = (
        predict(
            scaler.transform(no_media_features),
            coefficients,
        ) * REVENUE_SCALE
    )

    contributions = {}

    for channel in MEDIA:
        counterfactual = features.copy()

        # Entire channel history is set to zero.
        # Geometric adstock and Hill response become zero.
        counterfactual[channel] = 0.0

        prediction_without = (
            predict(
                scaler.transform(counterfactual),
                coefficients,
            ) * REVENUE_SCALE
        )

        contributions[channel] = (
            predictions - prediction_without
        )

    contribution_df = pd.DataFrame(contributions)

    # Additive model reconciliation.
    reconstructed = (
        baseline + contribution_df.sum(axis=1).to_numpy()
    )

    if not np.allclose(
        reconstructed,
        predictions,
        rtol=1e-8,
        atol=1e-4,
    ):
        raise AssertionError(
            "Attribution reconciliation failed."
        )

    summary = []

    total_media = contribution_df.sum().sum()

    for channel in MEDIA:
        contribution = contribution_df[channel].sum()
        spend = df[channel].sum()

        summary.append({
            "channel": channel,
            "spend": spend,
            "contribution": contribution,
            "modeled_roas": (
                contribution / spend
                if spend > 0 else np.nan
            ),
            "contribution_share_pct": (
                contribution / total_media * 100
                if total_media > 0 else np.nan
            ),
        })

    return {
        "summary": pd.DataFrame(summary),
        "predicted_revenue": predictions.sum(),
        "baseline_revenue": baseline.sum(),
        "media_revenue": total_media,
    }


# ============================================================
# MAIN
# ============================================================

def main():
    df = load_data(DATA_PATH)

    development = df.iloc[
        :DEVELOPMENT_END
    ].copy()

    params = load_parameters()

    original = analyze_model(
        development,
        params,
        include_holidays=False,
    )

    holiday = analyze_model(
        development,
        params,
        include_holidays=True,
    )

    original_table = original["summary"].set_index("channel")
    holiday_table = holiday["summary"].set_index("channel")

    comparison = pd.DataFrame({
        "spend": original_table["spend"],
        "original_contribution": original_table["contribution"],
        "holiday_contribution": holiday_table["contribution"],
        "original_roas": original_table["modeled_roas"],
        "holiday_roas": holiday_table["modeled_roas"],
    })

    comparison["contribution_change"] = (
        comparison["holiday_contribution"]
        - comparison["original_contribution"]
    )

    comparison["contribution_change_pct"] = np.where(
        comparison["original_contribution"].abs() > 1e-8,
        comparison["contribution_change"]
        / comparison["original_contribution"] * 100,
        np.nan,
    )

    print("=== HOLIDAY IMPACT ON MMM ATTRIBUTION ===")
    print(f"Development weeks: {len(development)}")
    print("Parameters: frozen")
    print("Final 42 weeks: excluded")

    print("\n=== CHANNEL ATTRIBUTION COMPARISON ===")
    print(
        comparison.round(4).to_string()
    )

    print("\n=== REVENUE DECOMPOSITION ===")

    for name, result in [
        ("Original MMM", original),
        ("Holiday-Aware MMM", holiday),
    ]:
        print(f"\n{name}")
        print(
            f"Predicted revenue: "
            f"${result['predicted_revenue']:,.2f}"
        )
        print(
            f"Baseline revenue: "
            f"${result['baseline_revenue']:,.2f}"
        )
        print(
            f"Media contribution: "
            f"${result['media_revenue']:,.2f}"
        )

    print("\n=== OVERALL ATTRIBUTION SHIFT ===")

    change = (
        holiday["media_revenue"]
        - original["media_revenue"]
    )

    print(f"Media contribution change: ${change:,.2f}")

    if abs(original["media_revenue"]) > 1e-8:
        print(
            f"Relative change: "
            f"{change / original['media_revenue'] * 100:.2f}%"
        )

    print("\n=== INTERPRETATION NOTES ===")
    print(
        "Holiday indicators may change the allocation "
        "between baseline and advertising."
    )
    print(
        "Modeled ROAS is based on model-implied "
        "zero-spend counterfactuals."
    )
    print(
        "Results are in-sample attribution estimates, "
        "not experimentally validated incrementality."
    )

    print("\nATTRIBUTION COMPARISON COMPLETE")


if __name__ == "__main__":
    main()
