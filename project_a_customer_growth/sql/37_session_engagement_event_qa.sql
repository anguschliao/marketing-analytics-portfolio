-- ============================================================
-- Project A: Customer & Growth Analytics
-- Session Engagement Event QA
--
-- Purpose:
-- Investigate why sessions with ga_session_number = 1 have an
-- unusually high observed engagement rate.
--
-- This query identifies which event types contain the
-- session_engaged parameter and how frequently that parameter
-- is set to 1 for first vs later sessions.
--
-- Source:
-- GA4 public ecommerce event export
-- ============================================================

WITH events AS (

    SELECT
        event_name,

        user_pseudo_id,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_number'
        ) AS ga_session_number,

        (
            SELECT COALESCE(
                value.string_value,
                CAST(value.int_value AS STRING)
            )
            FROM UNNEST(event_params)
            WHERE key = 'session_engaged'
        ) AS session_engaged

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

valid_events AS (

    SELECT *
    FROM events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL
        AND ga_session_number IS NOT NULL
),

classified AS (

    SELECT
        CASE
            WHEN ga_session_number = 1 THEN 'First Session'
            WHEN ga_session_number > 1 THEN 'Later Session'
        END AS session_type,

        event_name,
        session_engaged

    FROM valid_events
)

SELECT
    session_type,
    event_name,

    COUNT(*) AS events,

    COUNTIF(session_engaged IS NOT NULL)
        AS events_with_session_engaged_parameter,

    COUNTIF(session_engaged = '1')
        AS events_with_session_engaged_1,

    COUNTIF(session_engaged = '0')
        AS events_with_session_engaged_0,

    SAFE_DIVIDE(
        COUNTIF(session_engaged = '1'),
        COUNT(*)
    ) AS share_of_events_marked_engaged,

    SAFE_DIVIDE(
        COUNTIF(session_engaged = '1'),
        COUNTIF(session_engaged IS NOT NULL)
    ) AS share_of_parameter_events_marked_engaged

FROM classified

GROUP BY
    session_type,
    event_name

HAVING
    COUNTIF(session_engaged IS NOT NULL) > 0

ORDER BY
    session_type,
    events_with_session_engaged_1 DESC;