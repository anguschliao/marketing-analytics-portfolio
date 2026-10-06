-- ============================================================
-- Project A: Customer & Growth Analytics
-- Channel Performance Summary
--
-- Purpose:
-- Inspect the highest-volume acquisition source / medium
-- combinations and compare traffic quality, funnel performance,
-- conversion, and revenue.
-- ============================================================

SELECT
    session_source,
    session_medium,
    users,
    sessions,

    ROUND(engagement_rate * 100, 2) AS engagement_pct,
    ROUND(product_view_rate * 100, 2) AS product_view_pct,
    ROUND(add_to_cart_rate * 100, 2) AS add_to_cart_pct,
    ROUND(checkout_rate * 100, 2) AS checkout_pct,
    ROUND(conversion_rate * 100, 2) AS conversion_pct,

    ROUND(revenue, 2) AS revenue,
    ROUND(revenue_per_session, 2) AS revenue_per_session

FROM
    `turing-emitter-510722-h2.analytics.channel_performance`

ORDER BY
    sessions DESC

LIMIT 20;