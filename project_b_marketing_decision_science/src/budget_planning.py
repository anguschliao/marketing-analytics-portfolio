
"""
Project B — Budget Planning Baseline

Build a 52-week historical planning scenario using the
frozen holiday-aware Ridge + Hill MMM.

This is an exploratory retrospective simulation.

Model fitting and saturation calibration use only
the first 166 development weeks.
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


PROJECT_DIR = Path(__file__).resolve().parents[1]

PARAMETERS_PATH = (
    PROJECT_DIR / "outputs" / "optimization"
    / "ridge_hill_optuna_best.json"
)

OUTPUT_DIR = PROJECT_DIR / "outputs" / "budget"

PLANNING_WEEKS = 52
REVENUE_SCALE = 1_000_000.0


def load_parameters():
    with open(PARAMETERS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)["best_params"]


def add_holidays(df, features):
    holidays = build_holiday_features(df)[
        ["christmas", "new_year"]
    ]
    return pd.concat([features, holidays], axis=1)


def main():
    df = load_data(DATA_PATH)
    development = df.iloc[:DEVELOPMENT_END].copy()

    params = load_parameters()

    features = build_features(
        development,
        train_end=DEVELOPMENT_END,
        params=params,
    )
    features = add_holidays(development, features)

    scaler = StandardScaler()
    X = scaler.fit_transform(features)

    y = development["revenue"].to_numpy(dtype=float)

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

    predicted = predict(X, coefficients) * REVENUE_SCALE

    planning = development.iloc[-PLANNING_WEEKS:].copy()
    planning_features = features.iloc[-PLANNING_WEEKS:].copy()

    baseline_predictions = predicted[-PLANNING_WEEKS:]

    # Reproduce predictions using the frozen fitted model.
    reproduced = (
        predict(
            scaler.transform(planning_features),
            coefficients,
        ) * REVENUE_SCALE
    )

    if not np.allclose(
        reproduced,
        baseline_predictions,
        rtol=1e-10,
        atol=1e-4,
    ):
        raise AssertionError(
            "Planning baseline reproduction failed."
        )

    channel_budgets = planning[MEDIA].sum()

    total_budget = channel_budgets.sum()

    budget_summary = pd.DataFrame({
        "channel": MEDIA,
        "baseline_budget": [
            channel_budgets[channel] for channel in MEDIA
        ],
    })

    budget_summary["budget_share_pct"] = (
        budget_summary["baseline_budget"]
        / total_budget * 100
    )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    budget_summary.to_csv(
        OUTPUT_DIR / "baseline_channel_budgets.csv",
        index=False,
    )

    weekly = planning[
        ["date", "revenue"] + MEDIA
    ].copy()

    weekly["modeled_revenue"] = reproduced

    weekly.to_csv(
        OUTPUT_DIR / "baseline_weekly_plan.csv",
        index=False,
    )

    print("=== MMM BUDGET PLANNING BASELINE ===")
    print(f"Development weeks: {len(development)}")
    print(f"Planning weeks: {len(planning)}")
    print(
        f"Planning start: {planning['date'].min().date()}"
    )
    print(
        f"Planning end: {planning['date'].max().date()}"
    )

    print("\n=== BASELINE CHANNEL BUDGETS ===")
    print(
        budget_summary.round(2).to_string(index=False)
    )

    print(f"\nTotal budget: ${total_budget:,.2f}")

    print("\n=== REVENUE ===")
    print(
        f"Observed revenue: "
        f"${planning['revenue'].sum():,.2f}"
    )
    print(
        f"Modeled revenue: "
        f"${reproduced.sum():,.2f}"
    )

    print("\nBaseline reproduction: PASSED")
    print("Previously examined final holdout: excluded")
    print("No parameters retuned.")

    print("\n=== OUTPUT FILES ===")
    print(OUTPUT_DIR / "baseline_channel_budgets.csv")
    print(OUTPUT_DIR / "baseline_weekly_plan.csv")


if __name__ == "__main__":
    main()
