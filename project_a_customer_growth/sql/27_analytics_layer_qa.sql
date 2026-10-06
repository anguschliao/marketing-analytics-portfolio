-- ============================================================
-- Project A: Customer & Growth Analytics
-- Final Analytics Layer QA
--
-- Purpose:
-- Reconcile the major materialized analytical tables against
-- the canonical session_base table.
--
-- Validates:
--   1. daily_kpis
--   2. channel_performance
--   3. customer_type_performance
--   4. session_funnel
--
-- Note:
-- session_funnel uses a nested progression definition, so its
-- final purchase count is intentionally different from the
-- overall purchasing-session KPI.
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

daily AS (

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
),

channel AS (

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
),

funnel AS (

    SELECT
        MAX(IF(stage = 'Session', sessions, NULL)) AS funnel_sessions,
        MAX(IF(stage = 'Product View', sessions, NULL)) AS funnel_product_views,
        MAX(IF(stage = 'Add to Cart', sessions, NULL)) AS funnel_add_to_cart,
        MAX(IF(stage = 'Begin Checkout', sessions, NULL)) AS funnel_checkout,
        MAX(IF(stage = 'Purchase', sessions, NULL)) AS funnel_purchases

    FROM
        `turing-emitter-510722-h2.analytics.session_funnel`
)

SELECT
    base.sessions AS session_base_sessions,

    daily.sessions - base.sessions
        AS daily_sessions_diff,

    channel.sessions - base.sessions
        AS channel_sessions_diff,

    customer_type.sessions - base.sessions
        AS customer_type_sessions_diff,

    daily.engaged_sessions - base.engaged_sessions
        AS daily_engaged_diff,

    channel.engaged_sessions - base.engaged_sessions
        AS channel_engaged_diff,

    customer_type.engaged_sessions - base.engaged_sessions
        AS customer_type_engaged_diff,

    daily.purchasing_sessions - base.purchasing_sessions
        AS daily_purchase_diff,

    channel.purchasing_sessions - base.purchasing_sessions
        AS channel_purchase_diff,

    customer_type.purchasing_sessions - base.purchasing_sessions
        AS customer_type_purchase_diff,

    daily.revenue - base.revenue
        AS daily_revenue_diff,

    channel.revenue - base.revenue
        AS channel_revenue_diff,

    customer_type.revenue - base.revenue
        AS customer_type_revenue_diff,

    funnel.funnel_sessions - base.sessions
        AS funnel_session_diff,

    funnel.funnel_product_views - base.product_view_sessions
        AS funnel_product_view_diff,

    funnel.funnel_add_to_cart - base.add_to_cart_sessions
        AS funnel_add_to_cart_diff,

    funnel.funnel_checkout - base.checkout_sessions
        AS funnel_checkout_diff,

    base.purchasing_sessions
        AS all_purchasing_sessions,

    funnel.funnel_purchases
        AS nested_funnel_purchases,

    base.purchasing_sessions - funnel.funnel_purchases
        AS purchases_outside_complete_funnel

FROM
    base,
    daily,
    channel,
    customer_type,
    funnel;