-- ============================================================
-- Project A: Customer & Growth Analytics
-- Daily KPI Reconciliation QA
--
-- Purpose:
-- Reconcile analytics.daily_kpis to analytics.session_base.
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

daily_kpi_totals AS (

    SELECT
        SUM(sessions) AS sessions,
        SUM(engaged_sessions) AS engaged_sessions,
        SUM(product_view_sessions) AS product_view_sessions,
        SUM(add_to_cart_sessions) AS add_to_cart_sessions,
        SUM(checkout_sessions) AS checkout_sessions,
        SUM(purchasing_sessions) AS purchasing_sessions,
        SUM(revenue) AS revenue

    FROM
        `turing-emitter-510722-h2.analytics.daily_kpis`
)

SELECT
    'sessions' AS metric,
    s.sessions AS session_base,
    d.sessions AS daily_kpis,
    s.sessions - d.sessions AS difference
FROM session_base_totals s
CROSS JOIN daily_kpi_totals d

UNION ALL

SELECT
    'engaged_sessions',
    s.engaged_sessions,
    d.engaged_sessions,
    s.engaged_sessions - d.engaged_sessions
FROM session_base_totals s
CROSS JOIN daily_kpi_totals d

UNION ALL

SELECT
    'product_view_sessions',
    s.product_view_sessions,
    d.product_view_sessions,
    s.product_view_sessions - d.product_view_sessions
FROM session_base_totals s
CROSS JOIN daily_kpi_totals d

UNION ALL

SELECT
    'add_to_cart_sessions',
    s.add_to_cart_sessions,
    d.add_to_cart_sessions,
    s.add_to_cart_sessions - d.add_to_cart_sessions
FROM session_base_totals s
CROSS JOIN daily_kpi_totals d

UNION ALL

SELECT
    'checkout_sessions',
    s.checkout_sessions,
    d.checkout_sessions,
    s.checkout_sessions - d.checkout_sessions
FROM session_base_totals s
CROSS JOIN daily_kpi_totals d

UNION ALL

SELECT
    'purchasing_sessions',
    s.purchasing_sessions,
    d.purchasing_sessions,
    s.purchasing_sessions - d.purchasing_sessions
FROM session_base_totals s
CROSS JOIN daily_kpi_totals d

UNION ALL

SELECT
    'revenue',
    s.revenue,
    d.revenue,
    s.revenue - d.revenue
FROM session_base_totals s
CROSS JOIN daily_kpi_totals d;