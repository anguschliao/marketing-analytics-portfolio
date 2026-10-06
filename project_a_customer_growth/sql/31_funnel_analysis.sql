-- Project A: Customer & Growth Analytics
-- Conversion funnel analysis
--
-- Purpose:
-- Measure progression through the sequential ecommerce funnel
-- and identify the stages with the greatest customer drop-off.

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