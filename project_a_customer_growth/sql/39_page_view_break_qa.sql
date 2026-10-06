-- ============================================================
-- Project A: Customer & Growth Analytics
-- Daily Page View Break QA
--
-- Purpose:
-- Investigate the increase in sessions with 2+ page views
-- beginning December 29, 2020.
-- Diagnostic only; uses existing session_base metric definitions.
--
-- Grain and measurement:
-- One row per session_date, December 20, 2020 to January 10, 2021.
-- pct_* columns are percentages of that day's sessions (0 to 100).
-- Percentiles approximate the distribution of page_views per session,
-- including sessions with zero page views.
-- ============================================================

SELECT
    session_date AS date,

    COUNT(*) AS sessions,
    SUM(page_views) AS total_page_views,
    AVG(page_views) AS avg_page_views_per_session,

    COUNTIF(page_views = 0) AS sessions_with_0_page_views,
    COUNTIF(page_views = 1) AS sessions_with_1_page_view,
    COUNTIF(page_views = 2) AS sessions_with_2_page_views,
    COUNTIF(page_views >= 3) AS sessions_with_3plus_page_views,

    SAFE_DIVIDE(
        COUNTIF(page_views = 0),
        COUNT(*)
    ) * 100 AS pct_0_page_views,

    SAFE_DIVIDE(
        COUNTIF(page_views = 1),
        COUNT(*)
    ) * 100 AS pct_1_page_view,

    SAFE_DIVIDE(
        COUNTIF(page_views = 2),
        COUNT(*)
    ) * 100 AS pct_2_page_views,

    SAFE_DIVIDE(
        COUNTIF(page_views >= 3),
        COUNT(*)
    ) * 100 AS pct_3plus_page_views,

    APPROX_QUANTILES(page_views, 100)[OFFSET(50)] AS median_page_views,
    APPROX_QUANTILES(page_views, 100)[OFFSET(75)] AS p75_page_views,
    APPROX_QUANTILES(page_views, 100)[OFFSET(90)] AS p90_page_views

FROM
    `turing-emitter-510722-h2.analytics.session_base`

WHERE
    session_date BETWEEN DATE '2020-12-20' AND DATE '2021-01-10'

GROUP BY session_date
ORDER BY date;
