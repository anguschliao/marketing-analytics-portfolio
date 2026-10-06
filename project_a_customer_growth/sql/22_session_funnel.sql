-- ============================================================
-- Project A: Customer & Growth Analytics
-- Observed Ecommerce Funnel
--
-- Grain:
-- One row per funnel stage
--
-- Source:
-- analytics.session_base
--
-- Purpose:
-- Measure observed participation at reliably instrumented
-- ecommerce stages.
--
-- Measurement decision:
-- Add to Cart is excluded from the primary funnel because QA
-- identified incomplete instrumentation. It remains available
-- in session_base and other analytical tables as a diagnostic
-- metric, but should not be interpreted as a definitive
-- abandonment stage.
--
-- Note:
-- Stages represent event presence within the same session.
-- This table does not enforce chronological event order or
-- require every preceding stage to have been observed.
-- ============================================================

WITH funnel_counts AS (

    SELECT
        COUNT(*) AS sessions,

        COUNTIF(
            product_views > 0
        ) AS product_view_sessions,

        COUNTIF(
            checkout_events > 0
        ) AS checkout_sessions,

        COUNTIF(
            payment_events > 0
        ) AS payment_sessions,

        COUNTIF(
            purchase_events > 0
        ) AS purchase_sessions

    FROM
        `turing-emitter-510722-h2.analytics.session_base`
),

funnel AS (

    SELECT
        1 AS stage_order,
        'Session' AS stage,
        sessions
    FROM funnel_counts

    UNION ALL

    SELECT
        2,
        'Product View',
        product_view_sessions
    FROM funnel_counts

    UNION ALL

    SELECT
        3,
        'Begin Checkout',
        checkout_sessions
    FROM funnel_counts

    UNION ALL

    SELECT
        4,
        'Payment Info',
        payment_sessions
    FROM funnel_counts

    UNION ALL

    SELECT
        5,
        'Purchase',
        purchase_sessions
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