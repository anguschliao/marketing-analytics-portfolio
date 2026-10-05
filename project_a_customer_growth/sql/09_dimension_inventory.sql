-- ============================================================
-- Project A: Customer & Growth Analytics
-- Marketing Dimension Inventory
--
-- Purpose:
-- Inspect acquisition, device, and geographic dimensions
-- before adding them to the canonical session table.
-- ============================================================

SELECT
    traffic_source.source AS user_source,
    traffic_source.medium AS user_medium,
    traffic_source.name AS user_campaign,

    device.category AS device_category,

    geo.country AS country,

    COUNT(*) AS event_count,
    COUNT(DISTINCT user_pseudo_id) AS users

FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

GROUP BY
    user_source,
    user_medium,
    user_campaign,
    device_category,
    country

ORDER BY
    event_count DESC

LIMIT 100;