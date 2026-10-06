-- Project A: Customer & Growth Analytics
-- Observed ecommerce funnel analysis
--
-- Purpose:
-- Compare participation across reliably instrumented ecommerce
-- stages and identify the largest observed-stage gaps.
--
-- Measurement note:
-- Funnel stages represent independently observed event
-- participation and do not enforce chronological progression.
--
-- Add to Cart is excluded because instrumentation QA identified
-- incomplete event coverage. It remains available separately
-- as a diagnostic metric.

SELECT
    stage_order,
    stage,
    sessions,
    stage_conversion_rate,
    stage_dropoff_rate,
    overall_session_rate,

    LAG(sessions) OVER (
        ORDER BY stage_order
    ) - sessions AS sessions_lost_from_previous_stage

FROM `turing-emitter-510722-h2.analytics.session_funnel`

ORDER BY stage_order;