-- ============================================================
-- Project A: Customer & Growth Analytics
-- GA4 Event Inventory
--
-- Purpose:
-- Understand which events exist in the GA4 sample dataset
-- before defining funnel and engagement metrics.
-- ============================================================

SELECT
    event_name,
    COUNT(*) AS event_count,
    COUNT(DISTINCT user_pseudo_id) AS unique_users,
    MIN(PARSE_DATE('%Y%m%d', event_date)) AS first_date,
    MAX(PARSE_DATE('%Y%m%d', event_date)) AS last_date
FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY
    event_name
ORDER BY
    event_count DESC;