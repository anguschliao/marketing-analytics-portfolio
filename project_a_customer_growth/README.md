# Customer & Growth Analytics — GA4 Merchandise Store

## Project Overview

This project builds an end-to-end customer and growth analytics workflow using the public Google Analytics 4 (GA4) Merchandise Store ecommerce dataset in BigQuery.

The objective is to transform raw event-level GA4 data into a validated session-level analytical dataset that can support marketing analysis across acquisition, engagement, conversion, customer behavior, and revenue.

The final analytical workflow is designed to support Python analysis and a Power BI dashboard.

---

## Data Source

**Source:** Google Analytics 4 public ecommerce sample dataset  
**Platform:** Google BigQuery

```text
bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*
```

The dataset contains anonymized and obfuscated GA4 event-level ecommerce data from the Google Merchandise Store.

### Data Coverage

- Date range: **November 1, 2020 – January 31, 2021**
- Complete daily coverage: **92 days**
- Raw data grain: **event**
- Canonical analysis grain: **session**
- Canonical sessions: **360,129**
- Users: **270,154**

---

## Analytics Architecture

```text
Google GA4 Public Dataset
          ↓
      BigQuery
          ↓
    SQL Inventory
          ↓
Session Reconstruction
          ↓
Acquisition Reconstruction
          ↓
   Data Quality / QA
          ↓
analytics.session_base
          ↓
 Python Analysis
          ↓
   Power BI Dashboard
```

The raw GA4 events remain the source of truth, while a curated session-level table provides the primary analytical layer.

---

## Canonical Session Table

The primary analysis table is:

```text
turing-emitter-510722-h2.analytics.session_base
```

**Grain:** one row per unique combination of:

```text
user_pseudo_id + ga_session_id
```

The materialized table contains:

- **360,129 rows**
- **24 columns**

### Session Table Structure

#### Identity and Time

| Field | Description |
|---|---|
| `user_pseudo_id` | Anonymous GA4 user identifier |
| `ga_session_id` | GA4 session identifier |
| `session_date` | Date of the session |
| `session_start_timestamp` | Earliest event timestamp in the derived session |
| `session_number` | GA4 session number for the user |

#### Engagement

| Field | Description |
|---|---|
| `engaged_session` | 1 when GA4 flags the session as engaged |
| `engagement_seconds` | Total recorded engagement time in seconds |
| `page_views` | Number of page view events in the session |

#### Ecommerce Funnel

| Field | Description |
|---|---|
| `product_views` | Number of `view_item` events |
| `add_to_cart_events` | Number of `add_to_cart` events |
| `checkout_events` | Number of `begin_checkout` events |
| `shipping_events` | Number of `add_shipping_info` events |
| `payment_events` | Number of `add_payment_info` events |
| `purchase_events` | Number of `purchase` events |
| `revenue` | Purchase revenue recorded during the session |

#### Observed Session Acquisition

| Field | Description |
|---|---|
| `session_source` | Reconstructed source that brought the current session |
| `session_medium` | Reconstructed medium for the current session |
| `session_campaign` | Reconstructed campaign for the current session |
| `google_ads_click` | Indicates whether the session contains the GA4 `gclid` parameter |

#### First-User Acquisition

| Field | Description |
|---|---|
| `first_user_source` | Source associated with the user's original acquisition |
| `first_user_medium` | Medium associated with the user's original acquisition |
| `first_user_campaign` | Campaign associated with the user's original acquisition |

#### Context

| Field | Description |
|---|---|
| `device_category` | Device category associated with the session |
| `country` | Country associated with the session |

---

## Core Metric Definitions

| Metric | Definition |
|---|---|
| Users | Distinct `user_pseudo_id` |
| Sessions | Distinct `user_pseudo_id + ga_session_id` |
| Engaged Sessions | Sessions where `session_engaged = 1` on at least one event |
| Engagement Rate | Engaged Sessions / Sessions |
| Product Views | `view_item` events |
| Add to Cart | `add_to_cart` events |
| Checkout | `begin_checkout` events |
| Shipping | `add_shipping_info` events |
| Payment | `add_payment_info` events |
| Purchase Events | `purchase` events |
| Purchasing Sessions | Sessions containing at least one purchase event |
| Revenue | Sum of `ecommerce.purchase_revenue` on purchase events |

---

## Ecommerce Funnel

The primary customer journey is represented as:

```text
Users
  ↓
Sessions
  ↓
Engaged Sessions
  ↓
Product Views
  ↓
Add to Cart
  ↓
Begin Checkout
  ↓
Shipping Information
  ↓
Payment Information
  ↓
Purchase
  ↓
Revenue
```

The sample dataset does not contain a meaningful `view_cart` event, so cart viewing is not included as a separate funnel stage.

Funnel conversion rates will be calculated using session- or user-level progression rather than dividing raw event counts, since users can generate multiple instances of the same event.

---

## Session Definition

A session is defined as a unique combination of:

```text
user_pseudo_id + ga_session_id
```

This definition was chosen instead of counting `session_start` events directly.

### Session Validation

The reconstructed session layer contains:

- **360,129 derived sessions**
- **354,857 sessions containing a `session_start` event**
- **5,272 sessions without a `session_start` event**
- **105 sessions containing multiple `session_start` events**

These differences demonstrate why `session_start` event counts alone are not used as the canonical session definition.

---

## Engagement Definition

An engaged session is defined as a derived session where at least one event contains:

```text
session_engaged = 1
```

The GA4-provided engagement classification is retained rather than attempting to reconstruct engagement from `engagement_time_msec`.

### Engagement Validation

- Sessions: **360,129**
- Engaged sessions: **320,096**
- Engagement rate: **88.88%**

Alternative engagement indicators were investigated and did not perfectly agree with `session_engaged`, reinforcing the decision to retain GA4's session engagement flag as the canonical definition.

---

## Session Acquisition Methodology

Two acquisition concepts are intentionally maintained separately.

### First-User Acquisition

First-user acquisition describes:

> How was this user originally acquired?

These fields come from GA4's `traffic_source` structure:

```text
first_user_source
first_user_medium
first_user_campaign
```

### Observed Session Acquisition

Observed session acquisition describes:

> How did this particular visit arrive?

Because the historical GA4 sample predates newer session-level traffic-source fields, session acquisition is reconstructed from event-level source, medium, and campaign parameters.

The methodology is:

1. Group events by `user_pseudo_id + ga_session_id`.
2. Identify acquisition information chronologically within the session.
3. Exclude known Google Merchandise Store self-referrals.
4. Use the earliest valid source / medium / campaign record.
5. Detect the presence of the `gclid` parameter anywhere within the session.
6. Sessions containing `gclid` are classified as:

```text
source = google
medium = cpc
```

Direct sessions remain Direct unless the same session contains evidence of a Google Ads click.

No previous-session information is used to overwrite observed session acquisition.

---

## GCLID Investigation

The public dataset contains:

- **118,481 `gclid` parameter occurrences**
- **57,362 users associated with the parameter**
- **59,680 sessions associated with the parameter**

However, the actual GCLID values are obfuscated/null across the available GA4 parameter value fields.

The presence of the parameter key is therefore used as evidence of a Google Ads click.

### Impact of GCLID Correction

Before applying the correction, GCLID-bearing sessions were primarily classified as:

| Previous Classification | Share of GCLID Sessions |
|---|---:|
| Unattributed | 70.16% |
| Google / Organic | 26.35% |
| Direct / None | 1.23% |
| Other / Other | 0.94% |
| Other / Referral | 0.50% |
| Google / CPC | 0.27% |

After the correction:

- Google CPC sessions: **67,214**
- Sessions containing GCLID evidence: **59,680**
- Unattributed sessions: **107,411**
- Unattributed rate: **29.83%**
- Known self-referrals remaining: **0**

This correction substantially improves paid-search identification while retaining unknown acquisition when sufficient evidence is unavailable.

---

## Validated Session Metrics

The final enriched session table reconciles to the original event-level ecommerce metrics.

| Metric | Validated Value |
|---|---:|
| Sessions | 360,129 |
| Users | 270,154 |
| Engaged Sessions | 320,096 |
| Engagement Rate | 88.88% |
| Product View Events | 386,068 |
| Add-to-Cart Events | 58,543 |
| Checkout Events | 38,757 |
| Purchase Events | 5,692 |
| Purchasing Sessions | 4,848 |
| Revenue Sessions | 4,446 |
| Revenue | $362,165 |

Adding acquisition, device, geography, and first-user dimensions did not alter the validated engagement, funnel, purchase, or revenue totals.

---

## Data Quality Findings

Several limitations and anomalies were identified during validation:

- The dataset is a public, obfuscated GA4 sample and should not be treated as pristine production data.
- **5,272** derived sessions do not contain a `session_start` event.
- **105** derived sessions contain multiple `session_start` events.
- GA4 engagement indicators do not perfectly agree across all sessions.
- `add_to_cart` contains an unrealistic aggregate `total_item_quantity`, so that field is not used for funnel measurement.
- Purchase events do not always contain usable transaction IDs.
- Some purchase events have zero or missing recorded purchase revenue.
- Revenue becomes sparse near the end of the sample period despite continued purchase activity.
- GCLID parameter keys remain available, while the underlying GCLID values are obfuscated.
- Approximately **29.83%** of sessions remain unattributed after reconstruction rather than assigning unsupported acquisition sources.

These issues are retained and documented rather than silently corrected.

---

## Attribution vs. Acquisition

Observed session acquisition should not be interpreted as marketing attribution.

For example:

```text
Day -14    Google Ads
Day  -5    Organic Search
Day  -2    Email
Day   0    Direct → Purchase
```

The observed source of the converting session is still:

```text
Direct
```

A separate attribution model may assign some or all of the conversion value to earlier marketing touchpoints.

Future analysis will compare approaches such as:

- Last non-direct attribution
- Linear multi-touch attribution
- Time-decay attribution

Time-decay attribution will allow recent marketing interactions to receive greater conversion credit while preserving observed session acquisition as a separate factual field.

---

## Technology

- **Google BigQuery** — source data and SQL transformation
- **SQL** — data profiling, session reconstruction, acquisition reconstruction, and QA
- **Python** — BigQuery execution and downstream analysis
- **Pandas** — analytical workflows
- **Git / GitHub** — version control
- **VS Code** — development environment
- **Power BI** — final interactive reporting layer

---

## Project Status

### Completed

```text
✓ BigQuery connectivity
✓ GA4 event inventory
✓ Parameter inventory
✓ Ecommerce inventory
✓ Date coverage validation
✓ Session reconstruction
✓ Session reconciliation
✓ Engagement validation
✓ Acquisition investigation
✓ Self-referral handling
✓ GCLID investigation and correction
✓ First-user acquisition
✓ Device and geography dimensions
✓ Canonical session table
✓ Final metric reconciliation
✓ BigQuery materialization
```

### Next

```text
Customer & Growth Analysis
        ↓
Acquisition Performance
        ↓
Engagement Analysis
        ↓
Conversion Funnel
        ↓
Customer Segmentation
        ↓
Cohort / Retention Analysis
        ↓
Customer Value
        ↓
Multi-Touch Attribution
        ↓
Power BI Dashboard
```