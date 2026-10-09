
"""
Project B — Marginal ROAS and Media Response Curves

Uses the frozen holiday-aware Ridge + Hill MMM.

Outputs:
- Marginal ROAS by channel and scenario
- Channel response curves
- Saturation / response-shape diagnostics

All estimates are model-implied.
"""

from pathlib import Path

import numpy as np
import pandas as pd

from fit_mmm import DATA_PATH, MEDIA
from model_evaluation import load_data, DEVELOPMENT_END
from optimize_budget import (
    OUTPUT_DIR,
    PLANNING_START,
    load_parameters,
    prepare_model,
    predict_budget,
)


# ============================================================
# CONFIGURATION
# ============================================================

MARGINAL_STEP_PCT = 0.001

RESPONSE_MULTIPLIERS = np.linspace(
    0.40, 1.60, 25
)

SCENARIO_ORDER = [
    "Baseline",
    "Conservative",
    "Moderate",
    "Aggressive",
]


# ============================================================
# REVENUE RESPONSE
# ============================================================

def total_revenue(
    df,
    model,
    params,
    budgets,
    baseline_budgets,
):
    predictions = predict_budget(
        df,
        model,
        params,
        budgets,
        baseline_budgets,
    )

    return float(predictions.sum())


def marginal_roas(
    df,
    model,
    params,
    budgets,
    baseline_budgets,
    channel_index,
):
    """
    Estimate derivative of modeled revenue with respect
    to a channel's 52-week budget.

    Other channel budgets remain unchanged.
    """
    current = budgets[channel_index]

    step = max(
        current * MARGINAL_STEP_PCT,
        1.0,
    )

    higher = budgets.copy()
    lower = budgets.copy()

    higher[channel_index] += step

    if current > step:
        lower[channel_index] -= step

        revenue_high = total_revenue(
            df, model, params, higher, baseline_budgets
        )
        revenue_low = total_revenue(
            df, model, params, lower, baseline_budgets
        )

        return (
            revenue_high - revenue_low
        ) / (2 * step)

    revenue_high = total_revenue(
        df, model, params, higher, baseline_budgets
    )

    revenue_current = total_revenue(
        df, model, params, budgets, baseline_budgets
    )

    return (
        revenue_high - revenue_current
    ) / step


# ============================================================
# LOAD OPTIMIZED ALLOCATIONS
# ============================================================

def load_scenario_budgets(baseline_budgets):
    path = OUTPUT_DIR / "optimized_channel_budgets.csv"

    if not path.exists():
        raise FileNotFoundError(
            "Run optimize_budget.py before this script."
        )

    allocations = pd.read_csv(path)

    scenarios = {
        "Baseline": baseline_budgets.copy()
    }

    for scenario in [
        "Conservative",
        "Moderate",
        "Aggressive",
    ]:
        rows = allocations.loc[
            allocations["scenario"] == scenario
        ].set_index("channel")

        scenarios[scenario] = np.array([
            rows.loc[channel, "optimized_budget"]
            for channel in MEDIA
        ], dtype=float)

    return scenarios


# ============================================================
# MAIN
# ============================================================

def main():
    df = load_data(DATA_PATH)

    development = df.iloc[
        :DEVELOPMENT_END
    ].copy()

    params = load_parameters()
    model = prepare_model(development, params)

    planning = development.iloc[
        PLANNING_START:
    ].copy()

    baseline_budgets = (
        planning[MEDIA].sum().to_numpy(dtype=float)
    )

    scenarios = load_scenario_budgets(
        baseline_budgets
    )

    baseline_revenue = total_revenue(
        development,
        model,
        params,
        baseline_budgets,
        baseline_budgets,
    )

    original_revenue = float(
        model["predictions"][PLANNING_START:].sum()
    )

    if not np.isclose(
        baseline_revenue,
        original_revenue,
        rtol=1e-10,
        atol=1e-4,
    ):
        raise AssertionError(
            "Baseline revenue reproduction failed."
        )

    marginal_rows = []
    response_rows = []

    for scenario_name in SCENARIO_ORDER:
        budgets = scenarios[scenario_name]

        scenario_revenue = total_revenue(
            development,
            model,
            params,
            budgets,
            baseline_budgets,
        )

        for i, channel in enumerate(MEDIA):
            mroas = marginal_roas(
                development,
                model,
                params,
                budgets,
                baseline_budgets,
                i,
            )

            marginal_rows.append({
                "scenario": scenario_name,
                "channel": channel,
                "budget": budgets[i],
                "modeled_revenue": scenario_revenue,
                "marginal_roas": mroas,
            })

    # Response curves around the historical baseline.
    # Other channels remain at their original budgets.
    for i, channel in enumerate(MEDIA):
        for multiplier in RESPONSE_MULTIPLIERS:
            budgets = baseline_budgets.copy()
            budgets[i] *= multiplier

            revenue = total_revenue(
                development,
                model,
                params,
                budgets,
                baseline_budgets,
            )

            mroas = marginal_roas(
                development,
                model,
                params,
                budgets,
                baseline_budgets,
                i,
            )

            response_rows.append({
                "channel": channel,
                "budget_multiplier": multiplier,
                "channel_budget": budgets[i],
                "modeled_revenue": revenue,
                "revenue_change_from_baseline": (
                    revenue - baseline_revenue
                ),
                "marginal_roas": mroas,
            })

    marginal_df = pd.DataFrame(marginal_rows)
    response_df = pd.DataFrame(response_rows)

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    marginal_df.to_csv(
        OUTPUT_DIR / "marginal_roas.csv",
        index=False,
    )

    response_df.to_csv(
        OUTPUT_DIR / "media_response_curves.csv",
        index=False,
    )

    print("=== MMM MARGINAL ROAS ANALYSIS ===")
    print(f"Development weeks: {len(development)}")
    print(f"Planning weeks: {len(planning)}")
    print(
        f"Baseline modeled revenue: "
        f"${baseline_revenue:,.2f}"
    )
    print("Baseline reproduction: PASSED")

    print("\n=== MARGINAL ROAS BY SCENARIO ===")

    pivot = marginal_df.pivot(
        index="channel",
        columns="scenario",
        values="marginal_roas",
    )

    print(
        pivot[SCENARIO_ORDER]
        .round(4)
        .to_string()
    )

    print("\n=== RESPONSE CURVE SUMMARY ===")

    for channel, group in response_df.groupby("channel"):
        print(
            f"{channel}: "
            f"min_mROAS={group['marginal_roas'].min():.4f}, "
            f"max_mROAS={group['marginal_roas'].max():.4f}"
        )

    print("\n=== OUTPUT FILES ===")
    print(OUTPUT_DIR / "marginal_roas.csv")
    print(OUTPUT_DIR / "media_response_curves.csv")

    print("\n=== INTERPRETATION NOTES ===")
    print(
        "Marginal ROAS is the modeled revenue derivative "
        "with respect to channel budget."
    )
    print(
        "Response curves hold other channels fixed "
        "at baseline spending."
    )
    print(
        "These estimates are not experimentally "
        "validated causal returns."
    )

    print("\nMARGINAL ROAS ANALYSIS COMPLETE")


if __name__ == "__main__":
    main()
