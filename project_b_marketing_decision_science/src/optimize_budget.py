
"""
Project B — Constrained Marketing Budget Optimization

Optimize five paid-media budgets over a 52-week
historical planning period.

Model: Frozen holiday-aware Ridge + Hill MMM
Optimizer: SciPy SLSQP with multiple starting points

Scenarios:
- Conservative: +/-20%
- Moderate:     +/-40%
- Aggressive:   +/-60%

Total budget remains fixed.
Historical weekly spending patterns are preserved.
Pre-planning adstock carryover is preserved.

Results are exploratory model-implied scenarios.
"""

from pathlib import Path
import json

import numpy as np
import pandas as pd
from scipy.optimize import minimize
from sklearn.preprocessing import StandardScaler

from fit_mmm import (
    DATA_PATH,
    MEDIA,
    fit_constrained_ridge,
    predict,
)
from optimize_mmm_optuna import build_features
from diagnose_holidays import build_holiday_features
from media_transforms import geometric_adstock, hill_saturation
from model_evaluation import load_data, DEVELOPMENT_END


# ============================================================
# CONFIGURATION
# ============================================================

PROJECT_DIR = Path(__file__).resolve().parents[1]

PARAMETERS_PATH = (
    PROJECT_DIR / "outputs" / "optimization"
    / "ridge_hill_optuna_best.json"
)

OUTPUT_DIR = PROJECT_DIR / "outputs" / "budget"

PLANNING_WEEKS = 52
PLANNING_START = DEVELOPMENT_END - PLANNING_WEEKS

REVENUE_SCALE = 1_000_000.0
RANDOM_SEED = 42

SCENARIOS = {
    "Conservative": 0.20,
    "Moderate": 0.40,
    "Aggressive": 0.60,
}


# ============================================================
# MODEL PREPARATION
# ============================================================

def load_parameters():
    with open(PARAMETERS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)["best_params"]


def prepare_model(df, params):
    features = build_features(
        df,
        train_end=len(df),
        params=params,
    )

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

    # Freeze original training-derived half-saturation.
    half_saturation = {}

    for channel in MEDIA:
        adstock = geometric_adstock(
            df[channel].to_numpy(dtype=float),
            params[f"{channel}_theta"],
        )

        positive = adstock[adstock > 0]

        half_saturation[channel] = float(
            np.quantile(
                positive,
                params[f"{channel}_quantile"],
            )
        )

    return {
        "features": features,
        "scaler": scaler,
        "coefficients": coefficients,
        "predictions": predictions,
        "half_saturation": half_saturation,
    }


# ============================================================
# BUDGET RESPONSE ENGINE
# ============================================================

def predict_budget(
    df,
    model,
    params,
    budgets,
    baseline_budgets,
):
    """
    Scale each channel's planning-period spend schedule.

    All weeks before the planning period remain unchanged,
    preserving historical adstock carryover.
    """
    scenario_df = df.copy()

    for i, channel in enumerate(MEDIA):
        multiplier = budgets[i] / baseline_budgets[i]

        scenario_df.loc[
            scenario_df.index[PLANNING_START:],
            channel,
        ] *= multiplier

    scenario_features = model["features"].copy()

    for channel in MEDIA:
        adstock = geometric_adstock(
            scenario_df[channel].to_numpy(dtype=float),
            params[f"{channel}_theta"],
        )

        scenario_features[channel] = hill_saturation(
            adstock,
            alpha=params[f"{channel}_alpha"],
            half_saturation=model["half_saturation"][channel],
        )

    X = model["scaler"].transform(
        scenario_features
    )

    predictions = (
        predict(
            X,
            model["coefficients"],
        ) * REVENUE_SCALE
    )

    return predictions[PLANNING_START:]


# ============================================================
# OPTIMIZATION
# ============================================================

def optimize_scenario(
    df,
    model,
    params,
    baseline_budgets,
    total_budget,
    change_limit,
):
    lower = baseline_budgets * (1 - change_limit)
    upper = baseline_budgets * (1 + change_limit)

    # Optimize relative budget multipliers for
    # better numerical conditioning.
    lower_m = lower / baseline_budgets
    upper_m = upper / baseline_budgets

    def objective(multipliers):
        budgets = baseline_budgets * multipliers

        predictions = predict_budget(
            df,
            model,
            params,
            budgets,
            baseline_budgets,
        )

        # Revenue expressed in millions for stability.
        return -predictions.sum() / REVENUE_SCALE

    constraints = [{
        "type": "eq",
        "fun": lambda m: (
            np.dot(baseline_budgets, m)
            - total_budget
        ) / total_budget,
    }]

    bounds = list(zip(lower_m, upper_m))

    rng = np.random.default_rng(RANDOM_SEED)

    starts = [np.ones(len(MEDIA))]

    # Generate feasible random starts by projecting
    # candidate multipliers onto the budget equality.
    for _ in range(10):
        trial = rng.uniform(lower_m, upper_m)

        # Convex interpolation toward baseline ensures
        # feasibility of bounds but not exact equality.
        # SLSQP handles the equality constraint.
        starts.append(trial)

    candidates = []

    for start in starts:
        result = minimize(
            objective,
            start,
            method="SLSQP",
            bounds=bounds,
            constraints=constraints,
            options={
                "maxiter": 1000,
                "ftol": 1e-10,
            },
        )

        if not result.success:
            continue

        optimized_budgets = (
            baseline_budgets * result.x
        )

        budget_error = abs(
            optimized_budgets.sum() - total_budget
        )

        if budget_error > 0.01:
            continue

        if np.any(optimized_budgets < lower - 0.01):
            continue

        if np.any(optimized_budgets > upper + 0.01):
            continue

        candidates.append((
            -result.fun,
            optimized_budgets,
        ))

    if not candidates:
        raise RuntimeError(
            "No feasible optimization solution found."
        )

    best = max(candidates, key=lambda x: x[0])

    return best[1]


# ============================================================
# MAIN
# ============================================================

def main():
    df = load_data(DATA_PATH)
    development = df.iloc[:DEVELOPMENT_END].copy()

    params = load_parameters()
    model = prepare_model(development, params)

    planning = development.iloc[PLANNING_START:].copy()

    baseline_budgets = (
        planning[MEDIA].sum().to_numpy(dtype=float)
    )

    total_budget = baseline_budgets.sum()

    baseline_predictions = model["predictions"][
        PLANNING_START:
    ]

    # Identity test: unchanged budgets must reproduce
    # the original fitted predictions.
    reproduced = predict_budget(
        development,
        model,
        params,
        baseline_budgets,
        baseline_budgets,
    )

    if not np.allclose(
        reproduced,
        baseline_predictions,
        rtol=1e-10,
        atol=1e-4,
    ):
        raise AssertionError(
            "Budget response identity test failed."
        )

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    print("=== CONSTRAINED MMM BUDGET OPTIMIZATION ===")
    print(f"Planning weeks: {PLANNING_WEEKS}")
    print(f"Total budget: ${total_budget:,.2f}")
    print(
        f"Baseline modeled revenue: "
        f"${baseline_predictions.sum():,.2f}"
    )
    print("Budget response identity: PASSED")

    summary_rows = []
    allocation_rows = []

    baseline_total_revenue = baseline_predictions.sum()

    for scenario, limit in SCENARIOS.items():
        budgets = optimize_scenario(
            development,
            model,
            params,
            baseline_budgets,
            total_budget,
            limit,
        )

        predictions = predict_budget(
            development,
            model,
            params,
            budgets,
            baseline_budgets,
        )

        optimized_revenue = predictions.sum()

        uplift = (
            optimized_revenue - baseline_total_revenue
        )

        summary_rows.append({
            "scenario": scenario,
            "change_limit_pct": limit * 100,
            "total_budget": total_budget,
            "baseline_revenue": baseline_total_revenue,
            "optimized_revenue": optimized_revenue,
            "modeled_revenue_uplift": uplift,
            "modeled_uplift_pct": (
                uplift / baseline_total_revenue * 100
            ),
        })

        for i, channel in enumerate(MEDIA):
            allocation_rows.append({
                "scenario": scenario,
                "channel": channel,
                "baseline_budget": baseline_budgets[i],
                "optimized_budget": budgets[i],
                "budget_change": (
                    budgets[i] - baseline_budgets[i]
                ),
                "budget_change_pct": (
                    budgets[i] / baseline_budgets[i] - 1
                ) * 100,
            })

    summary = pd.DataFrame(summary_rows)
    allocations = pd.DataFrame(allocation_rows)

    summary.to_csv(
        OUTPUT_DIR / "optimization_scenarios.csv",
        index=False,
    )

    allocations.to_csv(
        OUTPUT_DIR / "optimized_channel_budgets.csv",
        index=False,
    )

    print("\n=== SCENARIO RESULTS ===")
    print(summary.round(3).to_string(index=False))

    print("\n=== OPTIMIZED CHANNEL ALLOCATIONS ===")
    print(allocations.round(2).to_string(index=False))

    print("\n=== OUTPUT FILES ===")
    print(OUTPUT_DIR / "optimization_scenarios.csv")
    print(OUTPUT_DIR / "optimized_channel_budgets.csv")

    print("\n=== INTERPRETATION ===")
    print(
        "Optimized uplift is model-implied, "
        "not experimentally validated."
    )
    print(
        "All scenarios preserve total budget "
        "and historical pre-planning adstock."
    )
    print(
        "No MMM parameters were retuned."
    )

    print("\nBUDGET OPTIMIZATION COMPLETE")


if __name__ == "__main__":
    main()
