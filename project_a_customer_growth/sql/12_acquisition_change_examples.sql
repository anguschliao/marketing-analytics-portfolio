-- ============================================================
-- Project A: Customer & Growth Analytics
-- Acquisition Change Examples
--
-- Purpose:
-- Inspect sessions containing multiple source values and see
-- how acquisition parameters change chronologically.
-- ============================================================

WITH events AS (

    SELECT
        user_pseudo_id,
        event_timestamp,
        event_name,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id,

        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'source'
        ) AS source,

        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'medium'
        ) AS medium,

        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'campaign'
        ) AS campaign

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

multi_source_sessions AS (

    SELECT
        user_pseudo_id,
        ga_session_id

    FROM events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL

    GROUP BY
        user_pseudo_id,
        ga_session_id

    HAVING
        COUNT(DISTINCT source) > 1

    LIMIT 10
)

SELECT
    e.user_pseudo_id,
    e.ga_session_id,
    e.event_timestamp,
    e.event_name,
    e.source,
    e.medium,
    e.campaign

FROM events e

INNER JOIN multi_source_sessions m
    USING (user_pseudo_id, ga_session_id)

ORDER BY
    e.user_pseudo_id,
    e.ga_session_id,
    e.event_timestamp;