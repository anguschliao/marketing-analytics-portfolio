-- ============================================================
-- Project A: Customer & Growth Analytics
-- Channel Performance Analysis Table
--
-- Grain:
-- One row per session source / medium combination
--
-- Source:
-- analytics.session_base
--
-- Purpose:
-- Compare acquisition traffic quality, funnel performance,
-- conversion, and revenue across observed session channels.
-- ============================================================

SELECT

    COALESCE(session_source, '(direct)')
        AS session_source,

    COALESCE(session_medium, '(none)')
        AS session_medium,

    -- Traffic
    COUNT(DISTINCT user_pseudo_id)
        AS users,

    COUNT(*)
        AS sessions,

    -- Engagement
    COUNTIF(engaged_session = 1)
        AS engaged_sessions,

    SAFE_DIVIDE(
        COUNTIF(engaged_session = 1),
        COUNT(*)
    ) AS engagement_rate,

    -- Product view
    COUNTIF(product_views > 0)
        AS product_view_sessions,

    SAFE_DIVIDE(
        COUNTIF(product_views > 0),
        COUNT(*)
    ) AS product_view_rate,

    -- Add to cart
    COUNTIF(add_to_cart_events > 0)
        AS add_to_cart_sessions,

    SAFE_DIVIDE(
        COUNTIF(add_to_cart_events > 0),
        COUNT(*)
    ) AS add_to_cart_rate,

    -- Checkout
    COUNTIF(checkout_events > 0)
        AS checkout_sessions,

    SAFE_DIVIDE(
        COUNTIF(checkout_events > 0),
        COUNT(*)
    ) AS checkout_rate,

    -- Purchase
    COUNTIF(purchase_events > 0)
        AS purchasing_sessions,

    SAFE_DIVIDE(
        COUNTIF(purchase_events > 0),
        COUNT(*)
    ) AS conversion_rate,

    -- Revenue
    SUM(revenue)
        AS revenue,

    SAFE_DIVIDE(
        SUM(revenue),
        COUNT(*)
    ) AS revenue_per_session

FROM
    `turing-emitter-510722-h2.analytics.session_base`

GROUP BY
    session_source,
    session_medium

ORDER BY
    sessions DESC;