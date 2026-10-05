WITH events AS (

    SELECT
        user_pseudo_id,
        event_name,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

sessions AS (

    SELECT
        user_pseudo_id,
        ga_session_id,

        COUNT(*) AS event_count,

        COUNTIF(event_name = 'session_start') AS session_start_events

    FROM events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL

    GROUP BY
        user_pseudo_id,
        ga_session_id

)

SELECT
    COUNT(*) AS derived_sessions,

    COUNTIF(session_start_events > 0)
        AS sessions_with_session_start,

    COUNTIF(session_start_events = 0)
        AS sessions_without_session_start,

    COUNTIF(session_start_events > 1)
        AS sessions_with_multiple_starts,

    SUM(session_start_events)
        AS total_session_start_events,

    SUM(
        CASE
            WHEN session_start_events = 0
            THEN event_count
            ELSE 0
        END
    ) AS events_in_sessions_without_start

FROM sessions;