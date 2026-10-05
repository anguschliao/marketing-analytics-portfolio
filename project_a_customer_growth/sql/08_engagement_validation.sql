WITH events AS (

    SELECT
        user_pseudo_id,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id,

        (
            SELECT COALESCE(
                value.string_value,
                CAST(value.int_value AS STRING)
            )
            FROM UNNEST(event_params)
            WHERE key = 'session_engaged'
        ) AS session_engaged,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'engaged_session_event'
        ) AS engaged_session_event,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'engagement_time_msec'
        ) AS engagement_time_msec

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

sessions AS (

    SELECT
        user_pseudo_id,
        ga_session_id,

        MAX(
            CASE WHEN session_engaged = '1'
            THEN 1 ELSE 0 END
        ) AS session_engaged_flag,

        MAX(
            CASE WHEN engaged_session_event = 1
            THEN 1 ELSE 0 END
        ) AS engaged_event_flag,

        SUM(COALESCE(engagement_time_msec, 0))
            AS engagement_time_msec

    FROM events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL

    GROUP BY
        user_pseudo_id,
        ga_session_id
)

SELECT
    COUNT(*) AS sessions,

    SUM(session_engaged_flag)
        AS session_engaged_sessions,

    SUM(engaged_event_flag)
        AS engaged_event_sessions,

    COUNTIF(engagement_time_msec > 0)
        AS sessions_with_engagement_time,

    COUNTIF(engagement_time_msec >= 10000)
        AS sessions_with_10s_engagement,

    COUNTIF(
        session_engaged_flag != engaged_event_flag
    ) AS flag_disagreements,

    ROUND(
        SAFE_DIVIDE(
            SUM(session_engaged_flag),
            COUNT(*)
        ) * 100,
        2
    ) AS session_engaged_rate_pct,

    ROUND(
        SAFE_DIVIDE(
            SUM(engaged_event_flag),
            COUNT(*)
        ) * 100,
        2
    ) AS engaged_event_rate_pct

FROM sessions;