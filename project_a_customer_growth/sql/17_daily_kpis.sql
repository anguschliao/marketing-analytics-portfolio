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
--
-- Measurement note:
-- Ecommerce stage metrics represent independent observed event
-- participation within a session. They are not nested or
-- sequential funnel stages.
--
-- Add to Cart has known incomplete instrumentation and is
-- retained as a diagnostic metric rather than a definitive
-- funnel-abandonment stage.
--
-- Purchase metrics use all sessions with an observed purchase
-- event and are not restricted to sessions containing a
-- complete recorded ecommerce path.
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

    -- Observed ecommerce stage participation
    -- Each metric independently measures whether the event
    -- was observed within the session.
    COUNTIF(product_views > 0) AS product_view_sessions,
    COUNTIF(add_to_cart_events > 0) AS add_to_cart_sessions,
    COUNTIF(checkout_events > 0) AS checkout_sessions,
    COUNTIF(purchase_events > 0) AS purchasing_sessions,

    -- Conversion
    -- Based on all observed purchasing sessions.
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