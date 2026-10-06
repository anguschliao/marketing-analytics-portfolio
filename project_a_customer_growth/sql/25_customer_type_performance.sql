-- ============================================================
-- Project A: Customer & Growth Analytics
-- New vs Returning Customer Performance
--
-- Grain:
-- One row per customer/session type
--
-- Source:
-- analytics.session_base
--
-- Definition:
-- New       = session_number = 1
-- Returning = session_number > 1
--
-- Purpose:
-- Compare engagement, observed ecommerce behavior, conversion,
-- and revenue between new and returning traffic.
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

    CASE
        WHEN session_number = 1 THEN 'New'
        WHEN session_number > 1 THEN 'Returning'
    END AS customer_type,

    -- Traffic
    COUNT(DISTINCT user_pseudo_id) AS users,
    COUNT(*) AS sessions,

    -- Engagement
    COUNTIF(engaged_session = 1) AS engaged_sessions,

    SAFE_DIVIDE(
        COUNTIF(engaged_session = 1),
        COUNT(*)
    ) AS engagement_rate,

    -- Observed product view participation
    COUNTIF(product_views > 0) AS product_view_sessions,

    SAFE_DIVIDE(
        COUNTIF(product_views > 0),
        COUNT(*)
    ) AS product_view_rate,

    -- Observed Add to Cart participation
    -- Known incomplete instrumentation; diagnostic only.
    COUNTIF(add_to_cart_events > 0) AS add_to_cart_sessions,

    SAFE_DIVIDE(
        COUNTIF(add_to_cart_events > 0),
        COUNT(*)
    ) AS add_to_cart_rate,

    -- Observed checkout participation
    COUNTIF(checkout_events > 0) AS checkout_sessions,

    SAFE_DIVIDE(
        COUNTIF(checkout_events > 0),
        COUNT(*)
    ) AS checkout_rate,

    -- Purchase
    -- Includes all sessions with an observed purchase event.
    COUNTIF(purchase_events > 0) AS purchasing_sessions,

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
    customer_type

ORDER BY
    customer_type;