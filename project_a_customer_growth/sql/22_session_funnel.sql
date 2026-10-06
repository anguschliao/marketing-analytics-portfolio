-- ============================================================
-- Project A: Customer & Growth Analytics
-- Nested Ecommerce Funnel
--
-- Grain:
-- One row per funnel stage
--
-- Source:
-- analytics.session_base
--
-- Purpose:
-- Measure progression through a nested ecommerce funnel.
-- Each downstream stage requires the session to have reached
-- all preceding stages.
--
-- Note:
-- This validates event presence within the same session.
-- It does not enforce chronological event order.
-- ============================================================

WITH funnel_counts AS (

    SELECT
        COUNT(*) AS sessions,

        COUNTIF(
            product_views > 0
        ) AS product_view_sessions,

        COUNTIF(
            product_views > 0
            AND add_to_cart_events > 0
        ) AS add_to_cart_sessions,

        COUNTIF(
            product_views > 0
            AND add_to_cart_events > 0
            AND checkout_events > 0
        ) AS checkout_sessions,

        COUNTIF(
            product_views > 0
            AND add_to_cart_events > 0
            AND checkout_events > 0
            AND shipping_events > 0
        ) AS shipping_sessions,

        COUNTIF(
            product_views > 0
            AND add_to_cart_events > 0
            AND checkout_events > 0
            AND shipping_events > 0
            AND payment_events > 0
        ) AS payment_sessions,

        COUNTIF(
            product_views > 0
            AND add_to_cart_events > 0
            AND checkout_events > 0
            AND shipping_events > 0
            AND payment_events > 0
            AND purchase_events > 0
        ) AS purchase_sessions

    FROM
        `turing-emitter-510722-h2.analytics.session_base`
),

funnel AS (

    SELECT 1 AS stage_order, 'Session' AS stage, sessions
    FROM funnel_counts

    UNION ALL

    SELECT 2, 'Product View', product_view_sessions
    FROM funnel_counts

    UNION ALL

    SELECT 3, 'Add to Cart', add_to_cart_sessions
    FROM funnel_counts

    UNION ALL

    SELECT 4, 'Begin Checkout', checkout_sessions
    FROM funnel_counts

    UNION ALL

    SELECT 5, 'Shipping Info', shipping_sessions
    FROM funnel_counts

    UNION ALL

    SELECT 6, 'Payment Info', payment_sessions
    FROM funnel_counts

    UNION ALL

    SELECT 7, 'Purchase', purchase_sessions
    FROM funnel_counts
),

with_previous AS (

    SELECT
        stage_order,
        stage,
        sessions,

        LAG(sessions) OVER (
            ORDER BY stage_order
        ) AS previous_stage_sessions,

        FIRST_VALUE(sessions) OVER (
            ORDER BY stage_order
        ) AS total_sessions

    FROM funnel
)

SELECT
    stage_order,
    stage,
    sessions,

    SAFE_DIVIDE(
        sessions,
        previous_stage_sessions
    ) AS stage_conversion_rate,

    SAFE_DIVIDE(
        previous_stage_sessions - sessions,
        previous_stage_sessions
    ) AS stage_dropoff_rate,

    SAFE_DIVIDE(
        sessions,
        total_sessions
    ) AS overall_session_rate

FROM with_previous

ORDER BY stage_order;