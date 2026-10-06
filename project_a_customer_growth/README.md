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
| `engaged_session` | 1 when `session_engaged = '1'` on an event other than `first_visit`, `first_open`, or `session_start` |
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
| Engaged Sessions | Sessions where `session_engaged = '1'` on at least one event excluding `first_visit`, `first_open`, and `session_start` |
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

The primary business funnel is:

```text
Session → Product View → Begin Checkout → Payment Info → Purchase
```

The sample dataset does not contain a meaningful `view_cart` event, so cart viewing is not included as a separate funnel stage.

Add-to-cart events are absent before November 16, 2020 and remain incomplete afterward. Add to Cart is retained as a diagnostic event but excluded from the primary business funnel; its coverage does not support reliable cart-abandonment conclusions.

Funnel stages measure observed event participation within a session, rather than raw event counts. They do not enforce chronological order or require every preceding stage to be recorded. The primary purchase KPI includes **all purchasing sessions**, not only sessions containing a complete recorded event path.

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

The canonical `engaged_session` flag is 1 when at least one event in the derived session meets both conditions:

```text
session_engaged = '1'
event_name NOT IN ('first_visit', 'first_open', 'session_start')
```

This uses the GA4 `session_engaged` parameter while preventing system/special events from artificially establishing engagement. The excluded event types remain in the underlying data for other session metrics. Engagement time is a separate diagnostic, not a replacement definition. This project-specific measure is not claimed to exactly reproduce the GA4 UI engaged-session metric.

### Engagement Validation

Raw event QA found that `first_visit` events with `session_engaged` populated were effectively always marked engaged. Under the original any-event `MAX` logic, first sessions therefore appeared approximately **99.9%** engaged.

After excluding the three event types from establishing the flag:

- First-session engagement is approximately **70.9%**.
- Overall canonical engagement is approximately **67.2%** across **360,129 sessions**.

Session numbering and the New/Returning classification are unchanged. The investigation is documented in [customer-type engagement QA](sql/36_customer_type_engagement_qa.sql) and [raw event engagement QA](sql/37_session_engagement_event_qa.sql).

### December 29 Measurement Break

Daily QA identified a structural measurement break beginning around **December 29, 2020**. The share of sessions with exactly one page view collapsed while exactly-two-page-view sessions increased sharply. Canonical engagement rose at the same time, while 10-second engagement and `user_engagement` event coverage remained relatively stable.

Engagement levels spanning this boundary should not be interpreted as directly comparable behavioral trends. The technical cause has not been established. Supporting diagnostics are [daily engagement break QA](sql/38_engagement_break_qa.sql) and [page-view distribution QA](sql/39_page_view_break_qa.sql).

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
| Engagement Rate | Approximately 67.2% under the corrected canonical definition |
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
- Canonical engagement excludes `first_visit`, `first_open`, and `session_start` from establishing the flag; alternative engagement indicators remain separate diagnostics.
- The December 29 measurement break limits direct engagement comparisons across the boundary.
- Add-to-cart events are absent before November 16 and remain incomplete afterward; Add to Cart is diagnostic only and excluded from the primary funnel.
- `add_to_cart` contains an unrealistic aggregate `total_item_quantity`, so that field is not used for funnel measurement.
- Purchase events do not always contain usable transaction IDs.
- Some purchase events have zero or missing recorded purchase revenue.
- Recorded revenue deteriorates sharply from approximately **January 26–31, 2021**, despite continued purchase events. Revenue-based conclusions for this period should be treated cautiously; the cause has not been established.
- GCLID parameter keys remain available, while the underlying GCLID values are obfuscated.
- Approximately **29.83%** of sessions remain unattributed after reconstruction rather than assigning unsupported acquisition sources.

These validation findings guide metric selection and interpretation. Observed data is retained, and measurement limitations are documented as analytical governance decisions.

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