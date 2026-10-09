# Marketing Investment Optimization
### Marketing Mix Modeling | Machine Learning | Bayesian Optimization | Marketing Decision Science

An end-to-end marketing decision science project combining Marketing Mix Modeling (MMM), machine learning, Bayesian hyperparameter optimization, and constrained budget allocation to evaluate marketing effectiveness and identify opportunities to improve advertising investment efficiency.

The project uses Meta Robyn's simulated marketing dataset to analyze five advertising channels, compare predictive modeling approaches, estimate nonlinear media response, and optimize a fixed annual marketing budget.

**Key Technologies:** Python · SQL Concepts · pandas · NumPy · SciPy · scikit-learn · Optuna · XGBoost · InterpretML · Power BI

---

## Project Highlights

| Metric | Result |
|---|---|
| Annual Marketing Budget | **$2.97M** |
| Best Mean CV NRMSE | **15.30%** |
| Modeling Approaches | **4** |
| Marketing Channels | **5** |
| Modeled Annual Revenue Uplift | **$0.96M–$2.25M** |
| Budget Optimization Scenarios | **3** |

*Revenue uplift figures are model-implied results from a retrospective simulation, not experimentally validated incremental revenue.*

## 1. Business Problem

Marketing teams must allocate limited advertising budgets across channels with different response characteristics, diminishing returns, and uncertain incremental effectiveness.

Traditional performance reporting often relies on historical ROAS, which does not necessarily reflect the incremental benefit of additional advertising expenditure.

This project investigated three business questions:

1. How do advertising investments, seasonality, and external demand factors relate to revenue?
2. Which modeling approaches provide the strongest predictive performance while retaining interpretable marketing-response relationships?
3. How could a fixed marketing budget be reallocated to improve modeled revenue while respecting channel-level investment constraints?

The objective was to develop a reproducible analytical framework that connects marketing measurement with investment decisions.

## 2. Dataset

**Source:** Meta Robyn — `dt_simulated_weekly`

The dataset contains 208 weekly observations from November 2015 through November 2019.

| Category | Variables |
|---|---|
| Revenue | Weekly revenue |
| Paid Media | TV, OOH, Print, Facebook, Search |
| Media Exposure | Facebook impressions, Search clicks |
| Organic Activity | Newsletter |
| External Controls | Competitor sales, special events |
| Time | Weekly dates |

Data preparation included validation of weekly continuity, missing values, duplicate observations, spending distributions, and variable relationships.

Exploratory analysis identified pronounced annual seasonality and a strong association between revenue and competitor sales.

These findings informed the inclusion of seasonal features and external controls in the modeling framework.

## 3. Analytical Approach

The project was organized into five major analytical stages.

### Stage 1 — Data Preparation & Exploratory Analysis

- Profiled revenue and advertising activity across 208 weeks.
- Evaluated channel spending distributions and zero-spend periods.
- Examined annual seasonality using revenue autocorrelation and calendar-month analysis.
- Investigated correlations between revenue, marketing activity, and competitor sales.
- Identified unusual revenue spikes and special-event observations.

### Stage 2 — Marketing Mix Modeling

Developed a parametric MMM incorporating:

- Geometric adstock to represent advertising carryover.
- Hill saturation functions to model nonlinear media response.
- Fourier terms to represent annual seasonality.
- External demand and organic marketing controls.
- Ridge regularization and nonnegative media coefficient constraints.

The model estimated revenue as a combination of underlying demand and transformed advertising activity.

### Stage 3 — Machine Learning & Bayesian Optimization

Developed and compared four modeling approaches:

| Model | Primary Role |
|---|---|
| Ridge + Hill MMM | Parametric marketing-response modeling |
| XGBoost | Nonlinear predictive benchmark |
| Explainable Boosting Machine | Interpretable boosted-tree benchmark |
| Generalized Additive Model | Smooth additive nonlinear modeling |

Optuna's Tree-structured Parzen Estimator (TPE) was used for joint hyperparameter optimization.

For the Ridge + Hill MMM, the optimization searched 16 parameters simultaneously, including channel-specific adstock decay, Hill saturation shape, half-saturation quantiles, and Ridge regularization.

Models were evaluated using expanding-window time-series cross-validation, with NRMSE as the primary metric.

### Stage 4 — Holiday & Attribution Analysis

Investigated whether sharp holiday-related revenue changes could be better represented using explicit calendar features.

Christmas and New Year indicators improved the non-media baseline and modestly improved the calibrated MMM.

Attribution sensitivity analysis then examined how model specification affected estimated channel contributions and ROAS.

Adding holiday controls reduced total modeled paid-media contribution by approximately 14.7%, demonstrating that predictive performance alone does not establish reliable marketing attribution.

### Stage 5 — Budget Optimization

Developed a constrained optimization framework using SciPy's SLSQP optimizer.

The optimization:

- Maintained a fixed annual advertising budget.
- Preserved historical weekly spending patterns.
- Recalculated adstock and saturation under alternative spending allocations.
- Retained advertising carryover from preceding periods.
- Evaluated conservative, moderate, and aggressive channel constraints.
- Calculated modeled marginal ROAS and revenue-response curves.
- Tested allocation sensitivity across two MMM specifications.

## 4. Model Performance

The original four-model comparison produced the following results:

| Model | Mean CV NRMSE ↓ | Mean CV WMAPE ↓ | Mean CV R² |
|---|---:|---:|---:|
| **Ridge + Hill MMM** | **15.49%** | **9.89%** | **0.611** |
| GAM | 16.15% | 11.31% | 0.580 |
| XGBoost | 16.45% | 11.29% | 0.578 |
| EBM | 17.11% | 12.46% | 0.543 |

The Ridge + Hill MMM achieved the lowest mean cross-validation NRMSE among the original four model configurations.

A subsequent holiday-aware specification improved mean CV NRMSE to **15.30%**.

The results illustrate that additional model flexibility does not necessarily improve prediction on relatively small, highly seasonal marketing datasets.

The holiday-aware result was obtained through post-diagnostic model development and should not be interpreted as an independent holdout result.

## 5. Marketing Budget Optimization Results

The optimization evaluated a fixed annual marketing budget of **$2,968,722** across five advertising channels.

Three scenarios were developed using channel-level spending constraints.

| Scenario | Maximum Channel Change | Modeled Revenue Uplift | Revenue Improvement |
|---|---:|---:|---:|
| Conservative | ±20% | $959,402 | +1.00% |
| Moderate | ±40% | $1,692,144 | +1.76% |
| Aggressive | ±60% | $2,254,752 | +2.34% |

The model generally favored increasing allocations to TV, Print, and Search while reducing OOH and Facebook expenditure.

These recommendations were based on modeled marginal revenue response rather than historical average ROAS.

### Marginal ROAS

| Channel | Baseline Modeled Marginal ROAS |
|---|---:|
| TV | 3.13 |
| OOH | 0.84 |
| Print | 20.69 |
| Facebook | 0.00 |
| Search | 2.12 |

Print exhibited exceptionally high modeled marginal returns, while Facebook's contribution was effectively zero under the fitted specification.

Both results were treated as measurement limitations requiring further validation rather than definitive evidence of channel effectiveness.

### Budget Sensitivity

Budget optimization was repeated using the original and holiday-aware MMM specifications.

Conservative and Moderate scenarios produced effectively identical allocations across both models.

The Aggressive scenario showed greater sensitivity, particularly in the allocation between Search and OOH.

This demonstrated directional consistency in several recommendations while highlighting uncertainty in the precise financial impact.

## 6. Power BI Reporting

The project includes a validated reporting layer designed for interactive Power BI analysis.

| Reporting Dataset | Purpose |
|---|---|
| `fact_budget_scenarios.csv` | Compare baseline and optimized revenue |
| `fact_channel_allocations.csv` | Examine channel budget changes |
| `fact_marginal_roas.csv` | Compare marginal returns |
| `fact_response_curves.csv` | Visualize nonlinear advertising response |
| `fact_model_sensitivity.csv` | Evaluate model-specification sensitivity |
| `dim_channels.csv` | Standardize channel labels and sorting |

These tables support executive reporting, scenario comparison, channel analysis, and marketing investment planning.

The Power BI dashboard is a separate presentation deliverable.

## 7. Project Structure

```text
project_b_marketing_decision_science/
│
├── README.md
│
├── data/
│   ├── raw/
│   ├── processed/
│   └── DATA_DICTIONARY.md
│
├── src/
│   ├── build_mmm_dataset.py
│   ├── profile_mmm_data.py
│   ├── model_evaluation.py
│   ├── fit_mmm.py
│   ├── tune_mmm.py
│   ├── optimize_mmm_optuna.py
│   ├── optimize_xgboost.py
│   ├── optimize_ebm.py
│   ├── optimize_gam.py
│   ├── diagnose_holidays.py
│   ├── evaluate_mmm_holidays.py
│   ├── compare_holiday_attribution.py
│   ├── optimize_budget.py
│   ├── analyze_marginal_roas.py
│   ├── compare_budget_sensitivity.py
│   └── build_reporting_layer.py
│
├── outputs/
│   ├── optimization/
│   ├── budget/
│   └── power_bi/
│
└── reports/
    ├── executive_summary.md
    └── methodology.md
```

*Structure highlights the principal analytical scripts and deliverables rather than every diagnostic or supporting file.*

## 8. Reproducibility

The project was developed in Python using a modular workflow.

Primary dependencies include:

- pandas and NumPy
- SciPy
- scikit-learn
- Optuna
- XGBoost
- InterpretML

The analytical workflow proceeds from data preparation and exploratory analysis through model development, optimization, attribution diagnostics, budget scenarios, and reporting-layer generation.

Model comparison used three expanding-window validation folds over the first 166 observations.

The previously examined final 42 weeks were excluded from subsequent model optimization.

Reproduction requires the original Meta Robyn simulated dataset, the Python dependencies, and the project scripts.

Saved optimization configurations and generated outputs are maintained in the `outputs/` directory.

## 9. Limitations

This project uses simulated marketing data and should be interpreted as an exploratory decision-science exercise.

Key limitations include:

- Model-implied channel contributions are not experimentally validated causal effects.
- Attribution estimates are sensitive to holiday controls and other model assumptions.
- The dataset contains only 208 weekly observations.
- Some unusual revenue spikes remain unexplained.
- The final holdout was examined before subsequent modeling revisions.
- Budget optimization uses a retrospective planning period included in model fitting.
- Operational constraints such as media inventory and campaign execution capacity were not explicitly modeled.

The modeled revenue uplift estimates should therefore not be interpreted as guaranteed or independently validated financial outcomes.

## 10. Business Implications

The analysis demonstrates how marketing analytics can progress beyond descriptive reporting toward structured investment decision support.

The most useful findings are:

- Revenue seasonality and external demand factors materially affect marketing measurement.
- Predictive accuracy and attribution reliability must be evaluated separately.
- Marginal returns provide more relevant information for budget allocation than historical average ROAS alone.
- Budget optimization can quantify potential opportunities while respecting spending constraints.
- Sensitivity analysis is essential for understanding how model assumptions influence investment recommendations.

A conservative reallocation scenario provides a potential starting point for controlled experimentation, subject to external validation.

## 11. Documentation

For additional detail, see:

- [Executive Summary](reports/executive_summary.md) — Business findings, modeled financial impact, and recommendations.
- [Technical Methodology](reports/methodology.md) — Data preparation, model architecture, validation, attribution, optimization, and limitations.
- [Data Dictionary](data/DATA_DICTIONARY.md) — Source variables and dataset definitions.

---

## Conclusion

This project demonstrates an end-to-end marketing decision science workflow integrating statistical modeling, machine learning, Bayesian hyperparameter optimization, marketing attribution, and constrained budget optimization.

By connecting predictive modeling with marginal revenue response and scenario analysis, the project illustrates how marketing analytics can support investment decisions while explicitly accounting for uncertainty and model limitations.

**Core capabilities demonstrated:** Marketing Mix Modeling · Marketing Analytics · Bayesian Hyperparameter Optimization · Time-Series Cross-Validation · Machine Learning · Attribution Analysis · Marginal ROAS · Budget Optimization · Power BI Reporting