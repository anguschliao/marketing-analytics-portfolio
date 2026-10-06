-- ============================================================
-- Project A: Customer & Growth Analytics
-- Channel Performance Reconciliation QA
--
-- Purpose:
-- Reconcile additive metrics in analytics.channel_performance
-- back to the canonical analytics.session_base table.
-- ============================================================

WITH session_base_totals AS (

    SELECT
        COUNT(*) AS sessions,
        COUNTIF(engaged_session = 1) AS engaged_sessions,
        COUNTIF(product_views > 0) AS product_view_sessions,
        COUNTIF(add_to_cart_events > 0) AS add_to_cart_sessions,
        COUNTIF(checkout_events > 0) AS checkout_sessions,
        COUNTIF(purchase_events > 0) AS purchasing_sessions,
        SUM(revenue) AS revenue

    FROM
        `turing-emitter-510722-h2.analytics.session_base`
),

channel_totals AS (

    SELECT
        SUM(sessions) AS sessions,
        SUM(engaged_sessions) AS engaged_sessions,
        SUM(product_view_sessions) AS product_view_sessions,
        SUM(add_to_cart_sessions) AS add_to_cart_sessions,
        SUM(checkout_sessions) AS checkout_sessions,
        SUM(purchasing_sessions) AS purchasing_sessions,
        SUM(revenue) AS revenue

    FROM
        `turing-emitter-510722-h2.analytics.channel_performance`
)

SELECT
    'sessions' AS metric,
    s.sessions AS session_base,
    c.sessions AS channel_performance,
    s.sessions - c.sessions AS difference
FROM session_base_totals s
CROSS JOIN channel_totals c

UNION ALL

SELECT
    'engaged_sessions',
    s.engaged_sessions,
    c.engaged_sessions,
    s.engaged_sessions - c.engaged_sessions
FROM session_base_totals s
CROSS JOIN channel_totals c

UNION ALL

SELECT
    'product_view_sessions',
    s.product_view_sessions,
    c.product_view_sessions,
    s.product_view_sessions - c.product_view_sessions
FROM session_base_totals s
CROSS JOIN channel_totals c

UNION ALL

SELECT
    'add_to_cart_sessions',
    s.add_to_cart_sessions,
    c.add_to_cart_sessions,
    s.add_to_cart_sessions - c.add_to_cart_sessions
FROM session_base_totals s
CROSS JOIN channel_totals c

UNION ALL

SELECT
    'checkout_sessions',
    s.checkout_sessions,
    c.checkout_sessions,
    s.checkout_sessions - c.checkout_sessions
FROM session_base_totals s
CROSS JOIN channel_totals c

UNION ALL

SELECT
    'purchasing_sessions',
    s.purchasing_sessions,
    c.purchasing_sessions,
    s.purchasing_sessions - c.purchasing_sessions
FROM session_base_totals s
CROSS JOIN channel_totals c

UNION ALL

SELECT
    'revenue',
    s.revenue,
    c.revenue,
    s.revenue - c.revenue
FROM session_base_totals s
CROSS JOIN channel_totals c;