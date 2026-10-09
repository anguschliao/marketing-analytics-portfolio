
"""
Project B — Budget Optimization Sensitivity

Compare:
A: Original frozen Optuna Ridge + Hill MMM
B: Holiday-aware frozen Optuna Ridge + Hill MMM

Both use:
- Same 166 development weeks
- Same 52-week planning horizon
- Same total marketing budget
- Same transformation hyperparameters
- Same +/-20%, 40%, 60% budget constraints

Outputs:
- Budget allocations by model and scenario
- Modeled revenue uplift by model and scenario
- Allocation sensitivity
"""

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
from optimize_budget import (
    OUTPUT_DIR,
    PLANNING_START,
    SCENARIOS,
    REVENUE_SCALE,
    load_parameters,
    prepare_model,
    predict_budget,
    optimize_scenario,
)


# ============================================================
# ORIGINAL MMM PREPARATION
# ============================================================

def prepare_original_model(df, params):
    features = build_features(
        df,
        train_end=len(df),
        params=params,
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

    # Use the same training-derived saturation thresholds
    # as the holiday-aware model.
    holiday_model = prepare_model(df, params)

    return {
        "features": features,
        "scaler": scaler,
        "coefficients": coefficients,
        "predictions": predictions,
        "half_saturation": holiday_model["half_saturation"],
    }


# ============================================================
# RUN SCENARIOS
# ============================================================

def evaluate_model(
    df,
    model_name,
    model,
    params,
    baseline_budgets,
    total_budget,
):
    baseline_predictions = predict_budget(
        df,
        model,
        params,
        baseline_budgets,
        baseline_budgets,
    )

    expected = model["predictions"][PLANNING_START:]

    if not np.allclose(
        baseline_predictions,
        expected,
        rtol=1e-10,
        atol=1e-4,
    ):
        raise AssertionError(
            f"Baseline identity failed for {model_name}"
        )

    baseline_revenue = baseline_predictions.sum()

    summary_rows = []
    allocation_rows = []

    for scenario, limit in SCENARIOS.items():
        optimized_budgets = optimize_scenario(
            df,
            model,
            params,
            baseline_budgets,
            total_budget,
            limit,
        )

        optimized_predictions = predict_budget(
            df,
            model,
            params,
            optimized_budgets,
            baseline_budgets,
        )

        optimized_revenue = optimized_predictions.sum()

        uplift = optimized_revenue - baseline_revenue

        summary_rows.append({
            "model": model_name,
            "scenario": scenario,
            "baseline_revenue": baseline_revenue,
            "optimized_revenue": optimized_revenue,
            "modeled_uplift": uplift,
            "modeled_uplift_pct": (
                uplift / baseline_revenue * 100
            ),
        })

        for i, channel in enumerate(MEDIA):
            allocation_rows.append({
                "model": model_name,
                "scenario": scenario,
                "channel": channel,
                "baseline_budget": baseline_budgets[i],
                "optimized_budget": optimized_budgets[i],
                "budget_change": (
                    optimized_budgets[i] - baseline_budgets[i]
                ),
                "budget_change_pct": (
                    optimized_budgets[i]
                    / baseline_budgets[i] - 1
                ) * 100,
            })

    return summary_rows, allocation_rows


# ============================================================
# MAIN
# ============================================================

def main():
    df = load_data(DATA_PATH)
    development = df.iloc[:DEVELOPMENT_END].copy()

    params = load_parameters()

    planning = development.iloc[PLANNING_START:]

    baseline_budgets = (
        planning[MEDIA].sum().to_numpy(dtype=float)
    )

    total_budget = baseline_budgets.sum()

    models = {
        "Original MMM": prepare_original_model(
            development, params
        ),
        "Holiday-Aware MMM": prepare_model(
            development, params
        ),
    }

    summary_rows = []
    allocation_rows = []

    print("=== MMM BUDGET SENSITIVITY ===")
    print(f"Development weeks: {len(development)}")
    print(f"Planning weeks: {len(planning)}")
    print(f"Total budget: ${total_budget:,.2f}")

    for model_name, model in models.items():
        summaries, allocations = evaluate_model(
            development,
            model_name,
            model,
            params,
            baseline_budgets,
            total_budget,
        )

        summary_rows.extend(summaries)
        allocation_rows.extend(allocations)

    summary = pd.DataFrame(summary_rows)
    allocations = pd.DataFrame(allocation_rows)

    print("\n=== OPTIMIZATION SENSITIVITY ===")
    print(
        summary.round(4).to_string(index=False)
    )

    print("\n=== BUDGET ALLOCATION COMPARISON ===")

    comparison = allocations.pivot_table(
        index=["scenario", "channel"],
        columns="model",
        values="optimized_budget",
    )

    comparison["difference"] = (
        comparison["Holiday-Aware MMM"]
        - comparison["Original MMM"]
    )

    print(
        comparison.round(2).to_string()
    )

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    summary.to_csv(
        OUTPUT_DIR / "budget_model_sensitivity.csv",
        index=False,
    )

    allocations.to_csv(
        OUTPUT_DIR / "budget_allocation_sensitivity.csv",
        index=False,
    )

    print("\n=== OUTPUT FILES ===")
    print(OUTPUT_DIR / "budget_model_sensitivity.csv")
    print(OUTPUT_DIR / "budget_allocation_sensitivity.csv")

    print("\n=== INTERPRETATION ===")
    print(
        "Uplift is measured relative to each "
        "model's own baseline."
    )
    print(
        "These results represent sensitivity "
        "to holiday control specification."
    )
    print(
        "All budget scenarios are exploratory "
        "model-implied estimates."
    )

    print("\nBUDGET SENSITIVITY COMPLETE")


if __name__ == "__main__":
    main()
