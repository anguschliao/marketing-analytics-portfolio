-- ============================================================
-- Project A: Customer & Growth Analytics
-- Daily Engagement Break QA
--
-- Purpose:
-- Investigate the engagement-rate break around December 29, 2020.
-- Diagnostic only; the corrected canonical engaged_session is
-- consumed from session_base without redefining engagement.
--
-- Grain and measurement:
-- One row per session_date, December 20, 2020 to January 10, 2021.
-- All rates are proportions of that day's sessions (0 to 1).
-- Engagement time and page-view thresholds are independent diagnostics.
-- Raw user_engagement events are deduplicated by the same
-- (user_pseudo_id, ga_session_id) pair used by session_base.
-- The raw scan retains all dates so cross-date sessions keep all
-- their events; daily assignment comes from session_base.session_date.
-- ============================================================

WITH base AS (

    SELECT
        user_pseudo_id,
        ga_session_id,
        session_date,
        engaged_session,
        engagement_seconds,
        page_views

    FROM
        `turing-emitter-510722-h2.analytics.session_base`

    WHERE
        session_date BETWEEN DATE '2020-12-20' AND DATE '2021-01-10'
),

user_engagement_events AS (

    SELECT
        user_pseudo_id,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

    WHERE
        event_name = 'user_engagement'
),

user_engagement_sessions AS (

    SELECT DISTINCT
        user_pseudo_id,
        ga_session_id

    FROM user_engagement_events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL
)

SELECT
    b.session_date AS date,

    COUNT(*) AS sessions,

    COUNTIF(b.engaged_session = 1) AS engaged_sessions,

    SAFE_DIVIDE(
        COUNTIF(b.engaged_session = 1),
        COUNT(*)
    ) AS engagement_rate,

    COUNTIF(b.engagement_seconds > 0) AS sessions_with_engagement_time,

    SAFE_DIVIDE(
        COUNTIF(b.engagement_seconds > 0),
        COUNT(*)
    ) AS engagement_time_rate,

    COUNTIF(b.engagement_seconds >= 10) AS sessions_with_10s_engagement,

    SAFE_DIVIDE(
        COUNTIF(b.engagement_seconds >= 10),
        COUNT(*)
    ) AS ten_second_engagement_rate,

    COUNTIF(b.page_views >= 2) AS sessions_with_2plus_page_views,

    SAFE_DIVIDE(
        COUNTIF(b.page_views >= 2),
        COUNT(*)
    ) AS two_plus_page_view_rate,

    COUNTIF(u.ga_session_id IS NOT NULL) AS user_engagement_event_sessions,

    SAFE_DIVIDE(
        COUNTIF(u.ga_session_id IS NOT NULL),
        COUNT(*)
    ) AS user_engagement_event_rate,

    AVG(b.engagement_seconds) AS avg_engagement_seconds,
    AVG(b.page_views) AS avg_page_views

FROM base AS b

LEFT JOIN user_engagement_sessions AS u
    ON b.user_pseudo_id = u.user_pseudo_id
    AND b.ga_session_id = u.ga_session_id

GROUP BY b.session_date
ORDER BY date;
