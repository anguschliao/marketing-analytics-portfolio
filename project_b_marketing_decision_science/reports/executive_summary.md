# Marketing Investment Optimization
**Marketing Decision Science | Executive Summary**

## Executive Overview

This analysis evaluated how a fixed annual marketing budget of **$2.97 million** could be redistributed across five advertising channels to improve revenue efficiency.

Using Meta Robyn's simulated weekly marketing dataset, the project developed and compared four modeling approaches: Ridge + Hill Marketing Mix Modeling (MMM), XGBoost, Explainable Boosting Machines (EBM), and Generalized Additive Models (GAM).

The analysis incorporated advertising carryover, nonlinear saturation, seasonality, external demand controls, holiday effects, and constrained budget optimization.

The holiday-aware Ridge + Hill MMM achieved the lowest mean cross-validation NRMSE among the evaluated configurations at **15.30%**. Its modeled response functions were subsequently used to evaluate three budget reallocation scenarios.

## Key Findings

**1. Marketing allocation efficiency presents a modeled opportunity.**

Under a fixed $2.97 million advertising budget, the MMM estimated additional annual revenue of:

| Scenario | Allowed Budget Change | Modeled Revenue Uplift |
|---|---:|---:|
| Conservative | ±20% per channel | $959,402 (+1.00%) |
| Moderate | ±40% per channel | $1,692,144 (+1.76%) |
| Aggressive | ±60% per channel | $2,254,752 (+2.34%) |

These represent model-implied outcomes from a retrospective planning simulation, not experimentally verified incremental revenue.

**2. Marginal returns differ considerably across channels.**

At historical spending levels, the model estimated marginal ROAS of 20.69 for Print, 3.13 for TV, 2.12 for Search, 0.84 for OOH, and approximately zero for Facebook.

The optimizer consistently favored additional investment in TV and Print while reducing allocations to OOH and Facebook.

Print's unusually high modeled returns require independent validation before being treated as reliable investment guidance.

**3. Attribution is sensitive to model specification.**

Adding Christmas and New Year controls reduced total modeled paid-media contribution by 14.7%.

Search's modeled historical ROAS declined from 17.09 to 6.45, demonstrating that channel-level effectiveness estimates are sensitive to assumptions about underlying demand.

Despite this, Conservative and Moderate budget allocations were effectively identical across the original and holiday-aware MMM specifications.

**4. Explicit holiday modeling improves revenue prediction.**

Christmas and New Year indicators improved mean CV NRMSE in the non-media baseline from 18.41% to 17.18%.

Within the frozen MMM specification, adding the same indicators improved mean CV NRMSE from 15.49% to 15.30%.

This demonstrates the value of incorporating known calendar effects alongside smooth seasonal patterns.

## Recommended Business Action

Use the **Conservative reallocation scenario as a candidate for controlled testing**, rather than immediately implementing a large-scale budget shift.

The scenario would increase TV, Print, and Search investment while reducing OOH and Facebook spending, maintaining the existing $2.97 million total budget.

Before implementing changes, validate the modeled returns through incrementality experiments or a phased market-level test.

Particular attention should be given to Print's exceptionally high modeled ROAS, Facebook's poorly identified contribution, and Search's sensitivity to holiday controls.

## Limitations

The analysis uses simulated historical marketing data and does not include independent experimental lift calibration.

The 52-week budget simulation uses a period included in model fitting. Therefore, optimized revenue gains represent in-sample model-implied scenarios rather than independently validated forecasts.

The final 42-week holdout was examined during earlier model development and cannot serve as a fresh independent test for subsequent model revisions.

Results should be interpreted as exploratory marketing decision support, not causal proof of advertising effectiveness.

## Conclusion

The analysis demonstrates how marketing science can connect revenue modeling, nonlinear media response, and constrained optimization to support budget planning.

The strongest conclusion is not that a particular channel allocation is definitively optimal, but that a structured modeling framework can identify potential investment opportunities, quantify tradeoffs, and highlight where further measurement is needed before committing capital.