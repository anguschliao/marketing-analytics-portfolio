-- ============================================================
-- Project A: Customer & Growth Analytics
-- Customer Type Performance QA
--
-- Purpose:
-- Reconcile additive metrics in customer_type_performance
-- back to the canonical session_base table.
-- ============================================================

WITH base AS (

    SELECT
        COUNT(*) AS sessions,
        SUM(engaged_session) AS engaged_sessions,
        COUNTIF(product_views > 0) AS product_view_sessions,
        COUNTIF(add_to_cart_events > 0) AS add_to_cart_sessions,
        COUNTIF(checkout_events > 0) AS checkout_sessions,
        COUNTIF(purchase_events > 0) AS purchasing_sessions,
        SUM(revenue) AS revenue

    FROM
        `turing-emitter-510722-h2.analytics.session_base`
),

customer_type AS (

    SELECT
        SUM(sessions) AS sessions,
        SUM(engaged_sessions) AS engaged_sessions,
        SUM(product_view_sessions) AS product_view_sessions,
        SUM(add_to_cart_sessions) AS add_to_cart_sessions,
        SUM(checkout_sessions) AS checkout_sessions,
        SUM(purchasing_sessions) AS purchasing_sessions,
        SUM(revenue) AS revenue

    FROM
        `turing-emitter-510722-h2.analytics.customer_type_performance`
)

SELECT
    'sessions' AS metric,
    base.sessions AS session_base,
    customer_type.sessions AS customer_type_total,
    customer_type.sessions - base.sessions AS difference
FROM base, customer_type

UNION ALL

SELECT
    'engaged_sessions',
    base.engaged_sessions,
    customer_type.engaged_sessions,
    customer_type.engaged_sessions - base.engaged_sessions
FROM base, customer_type

UNION ALL

SELECT
    'product_view_sessions',
    base.product_view_sessions,
    customer_type.product_view_sessions,
    customer_type.product_view_sessions - base.product_view_sessions
FROM base, customer_type

UNION ALL

SELECT
    'add_to_cart_sessions',
    base.add_to_cart_sessions,
    customer_type.add_to_cart_sessions,
    customer_type.add_to_cart_sessions - base.add_to_cart_sessions
FROM base, customer_type

UNION ALL

SELECT
    'checkout_sessions',
    base.checkout_sessions,
    customer_type.checkout_sessions,
    customer_type.checkout_sessions - base.checkout_sessions
FROM base, customer_type

UNION ALL

SELECT
    'purchasing_sessions',
    base.purchasing_sessions,
    customer_type.purchasing_sessions,
    customer_type.purchasing_sessions - base.purchasing_sessions
FROM base, customer_type

UNION ALL

SELECT
    'revenue',
    base.revenue,
    customer_type.revenue,
    customer_type.revenue - base.revenue
FROM base, customer_type;