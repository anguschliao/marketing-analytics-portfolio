# Marketing Mix Modeling & Budget Optimization
**Technical Methodology | Marketing Decision Science**

## 1. Project Objective

This project developed an end-to-end marketing decision science framework to evaluate advertising effectiveness and explore opportunities to improve marketing budget allocation.

The analysis addressed four primary questions:

1. How do seasonality, external market conditions, and advertising activity relate to revenue?
2. Which statistical and machine learning approaches provide the strongest out-of-sample predictive performance?
3. How do advertising carryover, saturation, and model specification influence estimated channel contribution?
4. How could a fixed marketing budget be redistributed to maximize modeled revenue under operational constraints?

The project combined Marketing Mix Modeling (MMM), machine learning, Bayesian hyperparameter optimization, time-series validation, attribution sensitivity analysis, and constrained mathematical optimization.

All channel contributions and budget improvements are model-implied estimates rather than experimentally validated causal effects.

---

## 2. Dataset and Data Preparation

### 2.1 Data Source

The analysis used Meta Robyn's `dt_simulated_weekly` dataset, a simulated marketing dataset designed for Marketing Mix Modeling experimentation.

| Attribute | Description |
|---|---|
| Dataset | Meta Robyn simulated weekly marketing data |
| Observation period | November 23, 2015 – November 11, 2019 |
| Frequency | Weekly |
| Observations | 208 |
| Paid-media channels | TV, OOH, Print, Facebook, Search |
| Primary outcome | Revenue |
| Additional variables | Media exposure, newsletter, competitor sales, event indicators |

The processed dataset contained 13 variables.

### 2.2 Data Quality

Initial profiling verified:

- No missing observations or duplicate dates.
- Continuous seven-day intervals across the time series.
- No negative advertising expenditure.
- Meaningful spending variation across paid-media channels.
- Valid zero-spend observations retained for modeling.

The processed dataset preserved the original observation count and total revenue.

### 2.3 Exploratory Data Analysis

Exploratory analysis examined revenue distributions, advertising expenditure, seasonality, correlations, and external controls.

Revenue exhibited pronounced annual seasonality, including a 52-week autocorrelation of approximately 0.807 and a negative 26-week autocorrelation of approximately -0.792.

Competitor sales demonstrated a raw correlation of 0.916 with revenue. This declined to 0.435 when comparing week-over-week changes, suggesting that much of the raw association reflected shared temporal variation.

These correlations were treated as descriptive diagnostics rather than causal effects.

---

## 3. Modeling Framework

Four primary model families were developed and evaluated.

### 3.1 Ridge + Hill Marketing Mix Model

The parametric MMM represented revenue as a combination of underlying demand, external controls, and transformed advertising activity.

The model included:

- Linear time trend.
- Two annual Fourier harmonics.
- Competitor sales and newsletter controls.
- Recorded special-event indicators.
- Channel-specific geometric adstock.
- Channel-specific Hill saturation.
- Ridge regularization.
- Nonnegative media coefficient constraints.

**Geometric Adstock**

Advertising carryover was represented as:

\[
A_t = X_t + \theta A_{t-1}
\]

where \(X_t\) represents advertising activity and \(\theta\) controls the persistence of prior advertising effects.

**Hill Saturation**

Nonlinear advertising response was modeled using:

\[
H(A)=\frac{A^\alpha}{A^\alpha+K^\alpha}
\]

where:

- \(A\): Adstock-transformed advertising activity.
- \(\alpha\): Response curve shape.
- \(K\): Half-saturation parameter.

This allowed the model to represent nonlinear response patterns and diminishing marginal returns over relevant spending ranges.

### 3.2 XGBoost

XGBoost was implemented as a nonlinear predictive benchmark using gradient-boosted decision trees.

Features included raw paid-media spending, external controls, trend, and Fourier seasonality.

Hyperparameters included tree depth, learning rate, number of estimators, subsampling, and regularization.

### 3.3 Explainable Boosting Machine

An Explainable Boosting Machine (EBM) was evaluated as an interpretable nonlinear alternative.

The model used additive boosted-tree functions with feature interactions disabled.

This allowed nonlinear predictive relationships to be examined at the individual-feature level.

### 3.4 Generalized Additive Model

A spline-based Generalized Additive Model (GAM) was developed using scikit-learn's `SplineTransformer` and Ridge regression.

Media inputs received individual spline transformations, while controls and seasonal terms remained linear.

Spline complexity and regularization were optimized through Optuna.

The XGBoost, EBM, and GAM benchmarks initially used raw media spending rather than the explicit adstock and saturation transformations used by the Ridge + Hill MMM.

Consequently, the comparison evaluated complete predictive modeling pipelines, not only differences between regression algorithms.

---

## 4. Hyperparameter Optimization

### 4.1 Initial Sequential Optimization

The first MMM implementation optimized Ridge regularization, adstock decay, and saturation parameters sequentially.

Coordinate descent was used to adjust one channel parameter at a time while holding other parameters constant.

Although this improved cross-validation performance, it did not fully account for interactions between advertising carryover and saturation.

### 4.2 Joint Bayesian Optimization

The methodology was subsequently extended to joint hyperparameter optimization using Optuna's Tree-structured Parzen Estimator (TPE) sampler.

For the Ridge + Hill MMM, 16 parameters were optimized jointly:

- Five adstock decay parameters.
- Five Hill shape parameters.
- Five half-saturation quantiles.
- One Ridge regularization parameter.

Each candidate parameter combination was evaluated across the same chronological validation folds.

The initial optimization used 100 trials and random seed 42.

Optuna was also used to tune XGBoost, EBM, and GAM, with 100 trials per model family.

### 4.3 Primary Optimization Objective

The primary optimization metric was mean cross-validation Normalized Root Mean Squared Error (NRMSE).

\[
NRMSE = \frac{RMSE}{\overline{Revenue}_{development}}
\]

The denominator was fixed using mean revenue from the first 166 development observations.

Additional evaluation metrics included:

- Weighted Mean Absolute Percentage Error (WMAPE).
- Root Mean Squared Error (RMSE).
- Mean Absolute Error (MAE).
- Coefficient of determination (R²).
- Mean prediction bias.
- Fold-level performance variability.

NRMSE was selected as the primary predictive objective because it penalizes large prediction errors while providing a normalized measure for comparing model families.

---

## 5. Time-Series Cross-Validation

Chronological expanding-window cross-validation was used to preserve temporal ordering.

| Fold | Training Weeks | Validation Weeks |
|---|---:|---:|
| 1 | 94 | 24 |
| 2 | 118 | 24 |
| 3 | 142 | 24 |

The first 166 observations were used for model development and validation.

The final 42 observations were originally reserved for holdout evaluation.

Feature scaling and saturation reference values were calculated using training observations within each fold.

The final 42-week period was examined during earlier model development. It was subsequently excluded from the revised optimization studies and cannot be considered an untouched independent test for later model revisions.

### 5.1 Model Comparison Results

| Model | Mean CV NRMSE | Mean CV WMAPE | Mean CV R² |
|---|---:|---:|---:|
| Ridge + Hill MMM | 0.1549 | 9.89% | 0.611 |
| GAM | 0.1615 | 11.31% | 0.580 |
| XGBoost | 0.1645 | 11.29% | 0.578 |
| EBM | 0.1711 | 12.46% | 0.543 |

The Ridge + Hill MMM achieved the lowest mean CV NRMSE among the four original advanced modeling configurations.

The results also showed substantial performance differences across validation periods, particularly during periods containing unusual revenue spikes.

---

## 6. Holiday and Anomaly Treatment

### 6.1 Holiday Feature Engineering

Exploratory diagnostics identified large prediction errors around year-end holidays and isolated special events.

Calendar-derived indicators were evaluated for Christmas, New Year, Black Friday, and Easter.

The initial holiday experiment compared:

- H0: Seasonal baseline without holiday indicators.
- H1: Christmas and New Year indicators.
- H2: Christmas, New Year, Black Friday, and Easter indicators.

Christmas and New Year produced the strongest improvement under the primary NRMSE metric.

### 6.2 Holiday-Aware MMM

Christmas and New Year indicators were subsequently incorporated into the frozen Optuna MMM specification.

| Metric | Original MMM | Holiday-Aware MMM |
|---|---:|---:|
| Mean CV NRMSE | 0.15493 | 0.15301 |
| Mean CV WMAPE | 9.89% | 9.71% |
| Mean CV R² | 0.611 | 0.631 |

The holiday-aware model improved average predictive performance, although improvements were not consistent across all three folds.

The holiday-aware specification was used for subsequent exploratory attribution and budget optimization.

### 6.3 Robust Regression

Huber regression was evaluated as an alternative to squared-error regression.

Huber loss reduces the influence of unusually large residuals during model fitting.

The experiment compared Ridge and Huber regression with and without year-end holiday indicators.

Ridge with holiday indicators achieved the lowest NRMSE, while Huber with holiday indicators achieved the lowest WMAPE.

Huber regression was retained as a robustness benchmark rather than adopted as the primary MMM estimator.

---

## 7. Historical Channel Attribution

Channel contribution was estimated through zero-spend counterfactual predictions.

For each advertising channel, the model compared predicted revenue under observed advertising activity against predicted revenue with that channel's spending removed.

\[
Contribution_c =
\sum_t \left(
\hat{Y}_{observed,t} -
\hat{Y}_{channel\ off,t}
\right)
\]

Channel removal accounted for advertising carryover through the adstock transformation.

The original fitted coefficients, feature scaling, and saturation parameters were preserved when evaluating counterfactual scenarios.

### 7.1 Modeled ROAS

Historical modeled Return on Advertising Spend was calculated as:

\[
ROAS_c = \frac{Modeled\ Contribution_c}{Spend_c}
\]

These values represent model-implied revenue contributions relative to recorded advertising expenditure.

They are not experimentally validated estimates of incremental advertising effectiveness.

### 7.2 Attribution Sensitivity

Adding year-end holiday controls materially changed estimated channel contribution.

| Metric | Original MMM | Holiday-Aware MMM |
|---|---:|---:|
| Total modeled paid-media contribution | $81.80M | $69.75M |
| Media share of modeled revenue | 26.3% | 22.4% |

Total modeled paid-media contribution decreased by 14.73%.

Search's modeled historical ROAS decreased from 17.09 to 6.45, demonstrating substantial sensitivity to model specification.

Print exhibited unusually high modeled ROAS, while Facebook's fitted contribution was approximately zero.

These findings were treated as attribution uncertainty and identification limitations rather than definitive channel-effectiveness conclusions.

---

## 8. Constrained Marketing Budget Optimization

### 8.1 Planning Framework

Budget optimization was performed over a historical 52-week planning period:

**January 29, 2018 – January 21, 2019**

The model was fitted using the first 166 development weeks.

The planning exercise used the final 52 weeks of that development period, making it a retrospective in-sample simulation.

The total annual advertising budget was held constant at:

**$2,968,722**

Weekly advertising patterns were preserved within each channel, while channel-level spending totals were adjusted.

Advertising carryover from periods preceding the planning window was retained.

### 8.2 Optimization Objective

The objective was to maximize modeled revenue over the planning horizon:

\[
\max_{\mathbf{B}}
\sum_{t=1}^{52}
\widehat{Revenue}_t(\mathbf{B})
\]

Subject to:

\[
\sum_c B_c = B_{total}
\]

and channel-specific allocation bounds.

SciPy's Sequential Least Squares Programming (SLSQP) optimizer was used with multiple starting configurations.

Three budget scenarios were evaluated:

| Scenario | Channel Allocation Constraint |
|---|---|
| Conservative | ±20% of baseline spending |
| Moderate | ±40% |
| Aggressive | ±60% |

### 8.3 Optimization Results

| Scenario | Modeled Revenue Uplift | Uplift % |
|---|---:|---:|
| Conservative | $959,402 | 1.00% |
| Moderate | $1,692,144 | 1.76% |
| Aggressive | $2,254,752 | 2.34% |

All scenarios maintained the same total advertising budget.

The optimizer generally increased spending on TV and Print while reducing spending on OOH and Facebook.

These improvements represent changes in modeled revenue under alternative budget allocations, not observed business outcomes.

---

## 9. Marginal ROAS and Response Curves

Marginal ROAS was estimated using finite differences around each channel's spending level.

\[
mROAS_c \approx
\frac{
\widehat{Revenue}(B_c+\Delta B)
-
\widehat{Revenue}(B_c-\Delta B)
}{
2\Delta B
}
\]

Other channel budgets were held constant during each marginal calculation.

### 9.1 Baseline Marginal ROAS

| Channel | Modeled Marginal ROAS |
|---|---:|
| TV | 3.13 |
| OOH | 0.84 |
| Print | 20.69 |
| Facebook | 0.00 |
| Search | 2.12 |

Response curves were evaluated over 40%–160% of historical channel spending.

Marginal returns generally decreased as spending increased over the evaluated ranges.

Print retained unusually high modeled marginal returns, reinforcing the need for external validation before interpreting its optimized allocation as an actionable recommendation.

### 9.2 Optimization Validation

The budget response engine passed its unchanged-budget identity check.

All reported scenarios satisfied total-budget and channel-allocation constraints.

For the aggressive scenario, the interior allocations to OOH and Search produced approximately equal marginal ROAS, consistent with first-order conditions for a constrained local optimum.

These checks support numerical consistency but do not establish global optimality or causal validity.

---

## 10. Budget Recommendation Sensitivity

Budget optimization was repeated using the original and holiday-aware MMM specifications.

Both models used the same transformation hyperparameters and budget constraints.

Conservative and Moderate scenarios produced effectively identical channel allocations across the two specifications.

The Aggressive scenario showed greater sensitivity, particularly in the allocation between OOH and Search.

The holiday-aware MMM predicted lower revenue uplift across all scenarios.

| Scenario | Original MMM Uplift | Holiday-Aware MMM Uplift |
|---|---:|---:|
| Conservative | $1.18M | $0.96M |
| Moderate | $2.07M | $1.69M |
| Aggressive | $2.69M | $2.25M |

This supported the directional consistency of certain reallocation recommendations while highlighting uncertainty in their estimated financial impact.

The comparison represents sensitivity to one modeling choice, not a comprehensive statistical uncertainty interval.

---

## 11. Reporting and Business Intelligence

A validated reporting layer was created to support Power BI visualization.

The reporting datasets include:

| Dataset | Purpose |
|---|---|
| `dim_channels.csv` | Channel dimension and display order |
| `fact_budget_scenarios.csv` | Modeled scenario revenue and uplift |
| `fact_channel_allocations.csv` | Channel budget allocation comparisons |
| `fact_marginal_roas.csv` | Marginal returns by scenario |
| `fact_response_curves.csv` | Channel spending-response relationships |
| `fact_model_sensitivity.csv` | Budget optimization sensitivity |

Data-quality checks verified scenario coverage, channel coverage, budget reconciliation, and marginal ROAS key consistency.

These datasets provide the foundation for an interactive marketing decision-science dashboard.

---

## 12. Limitations and Interpretation

Several limitations affect the interpretation of results.

**Simulated data:** The dataset represents a simulated marketing environment rather than observed commercial operations.

**Limited historical observations:** The 208-week dataset provides relatively few observations for identifying nonlinear effects across five paid-media channels.

**Attribution sensitivity:** Estimated media contributions vary with control selection and model specification.

**Unexplained events:** Some unusually large revenue spikes remain unexplained by the available predictors.

**No experimental calibration:** Channel contributions and ROAS were not calibrated against randomized incrementality experiments.

**Post-diagnostic model development:** Holiday features were introduced after examining model residuals, and the final holdout had already been inspected.

**In-sample budget simulation:** The planning period was included in model estimation, and optimized revenue gains were not independently validated.

**Optimization assumptions:** Weekly campaign timing was preserved, and operational factors such as media inventory, channel capacity, and execution constraints were not explicitly modeled.

**No causal guarantee:** Predictive accuracy, coefficient constraints, and plausible response curves do not establish causal marketing effects.

Accordingly, the results should be interpreted as exploratory model-based decision support.

---

## 13. Reproducibility

The analysis was implemented in Python using:

- pandas and NumPy for data preparation.
- SciPy for numerical optimization.
- scikit-learn for regression, preprocessing, and evaluation.
- Optuna for joint hyperparameter optimization.
- XGBoost for gradient-boosted regression.
- InterpretML for Explainable Boosting Machines.
- SplineTransformer and Ridge regression for GAM estimation.

Scripts are organized under `src/`, with processed data in `data/` and analytical outputs in `outputs/`.

The workflow preserves the distinction between model fitting, cross-validation, attribution analysis, budget optimization, and reporting.

---

## 14. Conclusion

This project developed an end-to-end marketing decision science workflow connecting statistical modeling, machine learning, hyperparameter optimization, attribution analysis, and constrained budget allocation.

The holiday-aware Ridge + Hill MMM achieved the strongest reported mean cross-validation NRMSE among the evaluated advanced configurations, while the sensitivity analysis demonstrated that channel attribution can change substantially even when predictive performance remains similar.

The budget optimization identified potential model-implied revenue improvements of approximately $0.96 million to $2.25 million under a fixed $2.97 million annual marketing budget.

The project illustrates both the analytical opportunities and measurement limitations involved in translating marketing data into investment decisions.

The resulting framework provides a reproducible foundation for exploratory scenario planning, with experimental calibration and additional business data required before production investment recommendations.