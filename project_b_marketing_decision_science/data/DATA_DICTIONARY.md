# Project B — MMM Data Dictionary

## Dataset

**Processed dataset:** `data/processed/mmm_weekly.csv`

**Source:** Meta Robyn `dt_simulated_weekly`

**Grain:** One row per week

**Coverage:** 2015-11-23 to 2019-11-11

**Observations:** 208 weeks

## Variables

| Variable | Role | Description |
|---|---|---|
| `date` | Time | Week date |
| `revenue` | Outcome | Weekly revenue modeled as the primary business outcome |
| `tv_spend` | Paid Media | Weekly TV advertising spend |
| `ooh_spend` | Paid Media | Weekly out-of-home advertising spend |
| `print_spend` | Paid Media | Weekly print advertising spend |
| `facebook_spend` | Paid Media | Weekly Facebook advertising spend |
| `search_spend` | Paid Media | Weekly paid search spend |
| `facebook_impressions` | Media Exposure | Weekly Facebook impressions |
| `search_clicks` | Media Exposure | Weekly paid search clicks |
| `competitor_sales` | Control | Competitor sales used to control for external market movement |
| `newsletter` | Organic Media | Weekly newsletter activity |
| `event_1` | Control | Indicator for special event 1 |
| `event_2` | Control | Indicator for special event 2 |

## Modeling Structure

### Dependent Variable

`revenue`

### Paid Media Spend

- `tv_spend`
- `ooh_spend`
- `print_spend`
- `facebook_spend`
- `search_spend`

### Media Exposure

- `facebook_impressions`
- `search_clicks`

### Organic Media

- `newsletter`

### Controls

- `competitor_sales`
- `event_1`
- `event_2`

## Data Quality

Initial profiling identified:

- 208 weekly observations
- No missing values
- No duplicate rows
- No duplicate dates
- No gaps in the weekly time series
- No negative paid-media spend
- Meaningful spend variation across all paid-media channels
- Zero-spend weeks are present for several channels and retained as valid observations

The processed dataset preserves the original row count and total revenue.

## Notes

Raw correlations are diagnostic only and should not be interpreted as causal marketing effects.

Marketing Mix Modeling will account for factors including baseline demand, controls, channel overlap, carryover/adstock, and nonlinear saturation before estimating channel contribution and marginal returns.