-- ============================================================
-- Project A: Customer & Growth Analytics
-- Customer Type Engagement QA
--
-- Purpose:
-- Investigate the unusually high engagement rate observed
-- among sessions classified as New.
--
-- Definition:
-- New       = session_number = 1
-- Returning = session_number > 1
-- ============================================================

SELECT
    session_number,

    COUNT(*) AS sessions,

    COUNTIF(engaged_session = 1) AS engaged_sessions,

    COUNTIF(engaged_session = 0) AS non_engaged_sessions,

    SAFE_DIVIDE(
        COUNTIF(engaged_session = 1),
        COUNT(*)
    ) AS engagement_rate,

    AVG(engagement_seconds) AS avg_engagement_seconds,

    AVG(page_views) AS avg_page_views,

    COUNTIF(product_views > 0) AS product_view_sessions,

    COUNTIF(purchase_events > 0) AS purchasing_sessions

FROM
    `turing-emitter-510722-h2.analytics.session_base`

GROUP BY
    session_number

ORDER BY
    session_number;