WITH events AS (

    SELECT
        user_pseudo_id,
        event_name,

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
            WHERE key = 'engagement_time_msec'
        ) AS engagement_time_msec,

        ecommerce.purchase_revenue AS purchase_revenue

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

sessions AS (

    SELECT
        user_pseudo_id,
        ga_session_id,

        MAX(
            CASE
                WHEN session_engaged = '1' THEN 1
                ELSE 0
            END
        ) AS engaged_session,

        SUM(COALESCE(engagement_time_msec, 0)) / 1000.0
            AS engagement_seconds,

        COUNTIF(event_name = 'view_item')
            AS product_views,

        COUNTIF(event_name = 'add_to_cart')
            AS add_to_cart_events,

        COUNTIF(event_name = 'begin_checkout')
            AS checkout_events,

        COUNTIF(event_name = 'purchase')
            AS purchase_events,

        SUM(
            CASE
                WHEN event_name = 'purchase'
                THEN COALESCE(purchase_revenue, 0)
                ELSE 0
            END
        ) AS revenue

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

    COUNT(DISTINCT user_pseudo_id) AS users,

    SUM(engaged_session) AS engaged_sessions,

    ROUND(
        SAFE_DIVIDE(
            SUM(engaged_session),
            COUNT(*)
        ) * 100,
        2
    ) AS engagement_rate_pct,

    SUM(product_views) AS product_view_events,

    SUM(add_to_cart_events) AS add_to_cart_events,

    SUM(checkout_events) AS checkout_events,

    SUM(purchase_events) AS purchase_events,

    ROUND(SUM(revenue), 2) AS revenue,

    COUNTIF(purchase_events > 0) AS purchasing_sessions,

    COUNTIF(revenue > 0) AS revenue_sessions

FROM sessions;