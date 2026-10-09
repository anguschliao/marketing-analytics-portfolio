
"""
Project B — Power BI Reporting Layer

Consolidate completed MMM budget optimization outputs
into validated, dashboard-ready CSV tables.

No model fitting or optimization is performed.
"""

from pathlib import Path

import numpy as np
import pandas as pd


PROJECT_DIR = Path(__file__).resolve().parents[1]
SOURCE_DIR = PROJECT_DIR / "outputs" / "budget"
REPORT_DIR = PROJECT_DIR / "outputs" / "power_bi"

SCENARIOS = ["Baseline", "Conservative", "Moderate", "Aggressive"]

CHANNELS = {
    "tv_spend": ("TV", 1),
    "ooh_spend": ("OOH", 2),
    "print_spend": ("Print", 3),
    "facebook_spend": ("Facebook", 4),
    "search_spend": ("Search", 5),
}

BUDGET_TOLERANCE = 0.05


def read_source(filename, required_columns):
    path = SOURCE_DIR / filename

    if not path.exists():
        raise FileNotFoundError(f"Missing source file: {path}")

    df = pd.read_csv(path)

    missing = set(required_columns) - set(df.columns)

    if missing:
        raise ValueError(
            f"{filename} missing columns: {sorted(missing)}"
        )

    return df


def validate_unique(df, columns, name):
    if df.duplicated(columns).any():
        raise ValueError(
            f"Duplicate keys in {name}: {columns}"
        )


def build_channel_dimension():
    return pd.DataFrame([
        {
            "channel": channel,
            "channel_name": name,
            "display_order": order,
        }
        for channel, (name, order) in CHANNELS.items()
    ])


def build_scenarios():
    source = read_source(
        "optimization_scenarios.csv",
        [
            "scenario",
            "total_budget",
            "baseline_revenue",
            "optimized_revenue",
            "modeled_revenue_uplift",
            "modeled_uplift_pct",
        ],
    )

    validate_unique(source, ["scenario"], "scenarios")

    if set(source["scenario"]) != set(SCENARIOS[1:]):
        raise ValueError("Unexpected optimization scenarios.")

    baseline_budget = float(source["total_budget"].iloc[0])
    baseline_revenue = float(source["baseline_revenue"].iloc[0])

    baseline = pd.DataFrame([{
        "scenario": "Baseline",
        "scenario_order": 0,
        "total_budget": baseline_budget,
        "baseline_modeled_revenue": baseline_revenue,
        "scenario_modeled_revenue": baseline_revenue,
        "modeled_revenue_uplift": 0.0,
        "modeled_uplift_pct": 0.0,
    }])

    result = source.rename(columns={
        "baseline_revenue": "baseline_modeled_revenue",
        "optimized_revenue": "scenario_modeled_revenue",
    }).copy()

    result["scenario_order"] = result["scenario"].map({
        "Conservative": 1,
        "Moderate": 2,
        "Aggressive": 3,
    })

    columns = baseline.columns.tolist()

    return pd.concat(
        [baseline, result[columns]],
        ignore_index=True,
    )


def build_allocations(scenarios):
    source = read_source(
        "optimized_channel_budgets.csv",
        [
            "scenario",
            "channel",
            "baseline_budget",
            "optimized_budget",
            "budget_change",
            "budget_change_pct",
        ],
    )

    baseline_source = read_source(
        "baseline_channel_budgets.csv",
        ["channel", "baseline_budget"],
    )

    validate_unique(
        source,
        ["scenario", "channel"],
        "allocations",
    )

    validate_unique(
        baseline_source,
        ["channel"],
        "baseline budgets",
    )

    baseline = baseline_source.copy()
    baseline["scenario"] = "Baseline"
    baseline["optimized_budget"] = baseline["baseline_budget"]
    baseline["budget_change"] = 0.0
    baseline["budget_change_pct"] = 0.0

    allocations = pd.concat(
        [baseline, source],
        ignore_index=True,
    )

    allocations = allocations.rename(columns={
        "optimized_budget": "scenario_budget",
    })

    allocations["scenario_order"] = allocations["scenario"].map({
        name: i for i, name in enumerate(SCENARIOS)
    })

    expected_keys = {
        (scenario, channel)
        for scenario in SCENARIOS
        for channel in CHANNELS
    }

    actual_keys = set(
        zip(allocations["scenario"], allocations["channel"])
    )

    if actual_keys != expected_keys:
        raise ValueError("Incomplete scenario/channel coverage.")

    for scenario, group in allocations.groupby("scenario"):
        expected_budget = float(
            scenarios.loc[
                scenarios["scenario"] == scenario,
                "total_budget",
            ].iloc[0]
        )

        actual_budget = group["scenario_budget"].sum()

        if abs(actual_budget - expected_budget) > BUDGET_TOLERANCE:
            raise AssertionError(
                f"Budget mismatch: {scenario}"
            )

    return allocations


def build_marginal_roas():
    df = read_source(
        "marginal_roas.csv",
        [
            "scenario",
            "channel",
            "budget",
            "modeled_revenue",
            "marginal_roas",
        ],
    )

    validate_unique(
        df,
        ["scenario", "channel"],
        "marginal ROAS",
    )

    return df.rename(columns={
        "budget": "scenario_budget",
        "modeled_revenue": "scenario_modeled_revenue",
    })


def build_response_curves():
    df = read_source(
        "media_response_curves.csv",
        [
            "channel",
            "budget_multiplier",
            "channel_budget",
            "modeled_revenue",
            "revenue_change_from_baseline",
            "marginal_roas",
        ],
    )

    validate_unique(
        df,
        ["channel", "budget_multiplier"],
        "response curves",
    )

    return df.rename(columns={
        "modeled_revenue": "modeled_total_revenue",
        "revenue_change_from_baseline": "modeled_revenue_change",
    })


def build_model_sensitivity():
    df = read_source(
        "budget_model_sensitivity.csv",
        [
            "model",
            "scenario",
            "baseline_revenue",
            "optimized_revenue",
            "modeled_uplift",
            "modeled_uplift_pct",
        ],
    )

    validate_unique(
        df,
        ["model", "scenario"],
        "model sensitivity",
    )

    return df.rename(columns={
        "baseline_revenue": "baseline_modeled_revenue",
        "optimized_revenue": "scenario_modeled_revenue",
        "modeled_uplift": "modeled_revenue_uplift",
    })


def main():
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    tables = {}

    tables["dim_channels"] = build_channel_dimension()
    tables["fact_budget_scenarios"] = build_scenarios()

    tables["fact_channel_allocations"] = build_allocations(
        tables["fact_budget_scenarios"]
    )

    tables["fact_marginal_roas"] = build_marginal_roas()
    tables["fact_response_curves"] = build_response_curves()
    tables["fact_model_sensitivity"] = build_model_sensitivity()

    # Validate consistent scenario/channel coverage.
    allocations = tables["fact_channel_allocations"]
    marginal = tables["fact_marginal_roas"]

    if set(zip(
        allocations["scenario"], allocations["channel"]
    )) != set(zip(
        marginal["scenario"], marginal["channel"]
    )):
        raise AssertionError(
            "Marginal ROAS and allocation keys do not match."
        )

    for name, df in tables.items():
        path = REPORT_DIR / f"{name}.csv"
        df.to_csv(path, index=False)

    print("=== PROJECT B POWER BI REPORTING LAYER ===")

    for name, df in tables.items():
        print(
            f"{name}: {len(df)} rows, "
            f"{len(df.columns)} columns"
        )

    print("\n=== SCENARIO SUMMARY ===")
    print(
        tables["fact_budget_scenarios"]
        .round(3)
        .to_string(index=False)
    )

    print("\n=== DATA QUALITY ===")
    print("Scenario coverage: PASSED")
    print("Channel coverage: PASSED")
    print("Budget reconciliation: PASSED")
    print("Marginal ROAS keys: PASSED")

    print("\n=== OUTPUT DIRECTORY ===")
    print(REPORT_DIR)

    print("\nREPORTING LAYER COMPLETE")


if __name__ == "__main__":
    main()
