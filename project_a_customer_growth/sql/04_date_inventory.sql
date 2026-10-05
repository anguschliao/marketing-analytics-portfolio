SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    COUNT(*) AS events,
    COUNT(DISTINCT user_pseudo_id) AS users,

    COUNT(DISTINCT CONCAT(
        user_pseudo_id,
        '-',
        CAST(
            (SELECT value.int_value
             FROM UNNEST(event_params)
             WHERE key = 'ga_session_id')
        AS STRING)
    )) AS sessions,

    COUNTIF(event_name = 'purchase') AS purchase_events,

    SUM(
        CASE
            WHEN event_name = 'purchase'
            THEN ecommerce.purchase_revenue
            ELSE 0
        END
    ) AS revenue

FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

GROUP BY
    event_date

ORDER BY
    event_date;