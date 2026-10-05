-- ============================================================
-- Project A: Customer & Growth Analytics
-- Session Acquisition Inventory
--
-- Purpose:
-- Inspect source / medium / campaign values contained in
-- event parameters and determine their suitability for
-- session-level acquisition analysis.
-- ============================================================

WITH events AS (

    SELECT
        user_pseudo_id,

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

sessions AS (

    SELECT
        user_pseudo_id,
        ga_session_id,

        ARRAY_AGG(
            source IGNORE NULLS
            LIMIT 1
        )[SAFE_OFFSET(0)] AS session_source,

        ARRAY_AGG(
            medium IGNORE NULLS
            LIMIT 1
        )[SAFE_OFFSET(0)] AS session_medium,

        ARRAY_AGG(
            campaign IGNORE NULLS
            LIMIT 1
        )[SAFE_OFFSET(0)] AS session_campaign

    FROM events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL

    GROUP BY
        user_pseudo_id,
        ga_session_id
)

SELECT
    session_source,
    session_medium,
    session_campaign,

    COUNT(*) AS sessions

FROM sessions

GROUP BY
    session_source,
    session_medium,
    session_campaign

ORDER BY
    sessions DESC

LIMIT 100;