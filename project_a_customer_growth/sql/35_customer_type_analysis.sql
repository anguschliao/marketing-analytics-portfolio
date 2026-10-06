-- ============================================================
-- Project A: Customer & Growth Analytics
-- New vs Returning Customer Analysis
--
-- Purpose:
-- Compare traffic composition, engagement, observed ecommerce
-- behavior, conversion, and revenue performance between new
-- and returning sessions.
--
-- Source:
-- analytics.customer_type_performance
--
-- Measurement note:
-- Add to Cart is retained as a diagnostic metric because
-- instrumentation QA identified incomplete event coverage.
-- Purchase metrics include all observed purchasing sessions.
-- ============================================================

WITH totals AS (

    SELECT
        SUM(sessions) AS total_sessions,
        SUM(purchasing_sessions) AS total_purchases,
        SUM(revenue) AS total_revenue

    FROM
        `turing-emitter-510722-h2.analytics.customer_type_performance`
)

SELECT
    c.customer_type,

    -- Scale
    c.users,
    c.sessions,

    SAFE_DIVIDE(
        c.sessions,
        t.total_sessions
    ) AS session_share,

    -- Engagement
    c.engaged_sessions,
    c.engagement_rate,

    -- Observed ecommerce behavior
    c.product_view_sessions,
    c.product_view_rate,

    c.add_to_cart_sessions,
    c.add_to_cart_rate,

    c.checkout_sessions,
    c.checkout_rate,

    -- Purchase
    c.purchasing_sessions,
    c.conversion_rate,

    SAFE_DIVIDE(
        c.purchasing_sessions,
        t.total_purchases
    ) AS purchase_share,

    -- Revenue
    c.revenue,

    SAFE_DIVIDE(
        c.revenue,
        t.total_revenue
    ) AS revenue_share,

    c.revenue_per_session,

    SAFE_DIVIDE(
        c.revenue,
        c.purchasing_sessions
    ) AS revenue_per_purchase

FROM
    `turing-emitter-510722-h2.analytics.customer_type_performance` AS c

CROSS JOIN totals AS t

ORDER BY
    CASE c.customer_type
        WHEN 'New' THEN 1
        WHEN 'Returning' THEN 2
        ELSE 3
    END;