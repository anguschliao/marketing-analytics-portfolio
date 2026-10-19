# Customer & Growth Analytics
**Google Merchandise Store | Executive Summary**

## Executive Overview

This project analyzed 92 days of ecommerce activity from the Google Analytics 4 (GA4) Merchandise Store public dataset, covering November 1, 2020, through January 31, 2021.

Using Google BigQuery, SQL, Python, and Power BI, the analysis reconstructed customer sessions and acquisition sources, evaluated ecommerce conversion, segmented customer behavior, and measured observed retention and customer value.

## Business Performance

| Metric | Result |
|---|---:|
| Users | 270,154 |
| Sessions | 360,129 |
| Recorded Revenue | $362,165 |
| Purchasing Sessions | 4,848 |
| Session Conversion Rate | 1.35% |
| Canonical Engagement Rate | Approximately 67.2% |

## Key Findings

### 1. Acquisition measurement materially influences channel reporting

Reconstructing session acquisition from event-level traffic-source information and Google Ads click evidence improved paid-search identification.

However, 29.83% of sessions remained unattributed, demonstrating the importance of distinguishing observed channel information from unsupported attribution assumptions.

### 2. Ecommerce conversion presents an optimization opportunity

Approximately 21.4% of sessions included a product view, while 1.35% included a purchase.

The large difference suggests opportunities to investigate product discovery, purchase intent, and checkout friction. However, incomplete funnel instrumentation prevents reliable conclusions about sequential abandonment.

### 3. Repeat purchasers demonstrate higher customer value

One-time purchasers generated the majority of observed 30-day revenue.

Repeat purchasers generated substantially higher average revenue per customer, suggesting that repeat-purchase behavior is an important dimension of customer value.

These results describe observed customer behavior rather than experimentally measured retention-program effectiveness.

### 4. Customer retention remains limited

Fixed-window customer return rates were approximately:

| Observation Window | Customer Return Rate |
|---|---:|
| 7 Days | 8.4% |
| 14 Days | 9.7% |
| 30 Days | 11.8% |

The analysis accounts for right-censoring by including only customers with sufficient observation time.

### 5. Measurement reliability affects interpretation

The analysis identified several data-quality limitations:

- A structural engagement measurement change around December 29, 2020.
- Incomplete add-to-cart instrumentation.
- Deteriorating recorded revenue reliability in late January 2021.
- Missing or obfuscated acquisition information.

These limitations were explicitly incorporated into metric definitions and reporting recommendations.

## Recommended Business Actions

1. **Improve acquisition measurement:** Reduce unattributed traffic and strengthen paid-media tracking.
2. **Investigate conversion friction:** Evaluate product discovery and checkout behavior using improved event instrumentation.
3. **Develop retention strategies:** Explore repeat-purchase opportunities and test their incremental effectiveness.
4. **Monitor customer value:** Use standardized observation windows to compare acquisition quality and customer behavior.
5. **Strengthen measurement governance:** Investigate known tracking anomalies before interpreting changes as genuine business performance.

## Power BI Reporting

A three-page Power BI dashboard communicates the findings through:

- Executive Overview — revenue, traffic, conversion, and engagement.
- Acquisition & Conversion — acquisition source performance and ecommerce funnel participation.
- Customer Value & Retention — segmentation, standardized 30-day revenue, fixed-window retention, and monthly cohorts.

## Conclusion

The project demonstrates how raw digital analytics data can be transformed into validated, decision-oriented marketing intelligence.

Its principal contribution is an integrated view of acquisition, conversion, retention, and customer value, supported by transparent metric definitions and explicit recognition of data-quality limitations.