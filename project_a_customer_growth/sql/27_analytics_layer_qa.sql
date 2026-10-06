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
-- Measurement note:
-- session_funnel represents observed participation at reliably
-- instrumented ecommerce stages. It does not require every
-- preceding stage to have been observed.
--
-- Add to Cart is excluded from the primary session_funnel
-- because instrumentation QA identified incomplete coverage.
-- It remains reconciled across the other analytical tables as
-- a diagnostic event metric.
-- ============================================================

WITH base AS (

    SELECT
        COUNT(*) AS sessions,
        SUM(engaged_session) AS engaged_sessions,
        COUNTIF(product_views > 0) AS product_view_sessions,
        COUNTIF(add_to_cart_events > 0) AS add_to_cart_sessions,
        COUNTIF(checkout_events > 0) AS checkout_sessions,
        COUNTIF(payment_events > 0) AS payment_sessions,
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
        MAX(IF(stage = 'Session', sessions, NULL))
            AS funnel_sessions,

        MAX(IF(stage = 'Product View', sessions, NULL))
            AS funnel_product_views,

        MAX(IF(stage = 'Begin Checkout', sessions, NULL))
            AS funnel_checkout,

        MAX(IF(stage = 'Payment Info', sessions, NULL))
            AS funnel_payment,

        MAX(IF(stage = 'Purchase', sessions, NULL))
            AS funnel_purchases

    FROM
        `turing-emitter-510722-h2.analytics.session_funnel`
)

SELECT
    base.sessions AS session_base_sessions,

    -- Core table reconciliation
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

    -- Primary observed funnel reconciliation
    funnel.funnel_sessions - base.sessions
        AS funnel_session_diff,

    funnel.funnel_product_views - base.product_view_sessions
        AS funnel_product_view_diff,

    funnel.funnel_checkout - base.checkout_sessions
        AS funnel_checkout_diff,

    funnel.funnel_payment - base.payment_sessions
        AS funnel_payment_diff,

    funnel.funnel_purchases - base.purchasing_sessions
        AS funnel_purchase_diff,

    -- Add to Cart diagnostic reconciliation
    daily.add_to_cart_sessions - base.add_to_cart_sessions
        AS daily_add_to_cart_diff,

    channel.add_to_cart_sessions - base.add_to_cart_sessions
        AS channel_add_to_cart_diff,

    customer_type.add_to_cart_sessions - base.add_to_cart_sessions
        AS customer_type_add_to_cart_diff

FROM
    base,
    daily,
    channel,
    customer_type,
    funnel;