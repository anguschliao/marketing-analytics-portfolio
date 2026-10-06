-- ============================================================
-- Project A: Customer & Growth Analytics
-- Daily KPI Analysis Table
--
-- Grain:
-- One row per calendar date
--
-- Source:
-- analytics.session_base
--
-- Purpose:
-- Provide core daily marketing and ecommerce KPIs for
-- trend analysis, reporting, and Power BI.
-- ============================================================

SELECT
    session_date AS date,

    -- Traffic
    COUNT(DISTINCT user_pseudo_id) AS users,
    COUNT(*) AS sessions,

    -- Engagement
    SUM(engaged_session) AS engaged_sessions,

    SAFE_DIVIDE(
        SUM(engaged_session),
        COUNT(*)
    ) AS engagement_rate,

    -- Ecommerce funnel
    COUNTIF(product_views > 0) AS product_view_sessions,
    COUNTIF(add_to_cart_events > 0) AS add_to_cart_sessions,
    COUNTIF(checkout_events > 0) AS checkout_sessions,
    COUNTIF(purchase_events > 0) AS purchasing_sessions,

    -- Conversion
    SAFE_DIVIDE(
        COUNTIF(purchase_events > 0),
        COUNT(*)
    ) AS conversion_rate,

    -- Revenue
    SUM(revenue) AS revenue,

    SAFE_DIVIDE(
        SUM(revenue),
        COUNT(*)
    ) AS revenue_per_session

FROM
    `turing-emitter-510722-h2.analytics.session_base`

GROUP BY
    session_date

ORDER BY
    session_date;