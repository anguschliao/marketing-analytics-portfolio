-- ============================================================
-- Project A: Customer & Growth Analytics
-- GCLID Reclassification QA
--
-- Purpose:
-- Show how sessions containing the GCLID parameter would have
-- been classified before applying the Google Ads correction.
-- ============================================================

WITH events AS (

    SELECT
        user_pseudo_id,
        event_timestamp,

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
        ) AS campaign,

        EXISTS (
            SELECT 1
            FROM UNNEST(event_params)
            WHERE key = 'gclid'
        ) AS has_gclid

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

candidates AS (

    SELECT
        *,

        CASE
            WHEN source IS NULL
                 AND medium IS NULL
                 AND campaign IS NULL
                THEN 0

            WHEN LOWER(source) IN (
                'shop.googlemerchandisestore.com',
                'googlemerchandisestore.com'
            )
                THEN 0

            ELSE 1
        END AS valid_candidate

    FROM events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL
),

sessions AS (

    SELECT
        user_pseudo_id,
        ga_session_id,

        LOGICAL_OR(has_gclid) AS session_has_gclid,

        ARRAY_AGG(
            IF(
                valid_candidate = 1,

                STRUCT(
                    event_timestamp,
                    source,
                    medium,
                    campaign
                ),

                NULL
            )

            IGNORE NULLS
            ORDER BY event_timestamp
            LIMIT 1

        )[SAFE_OFFSET(0)] AS original_acquisition

    FROM candidates

    GROUP BY
        user_pseudo_id,
        ga_session_id
)

SELECT
    COALESCE(
        original_acquisition.source,
        '(unattributed)'
    ) AS original_source,

    COALESCE(
        original_acquisition.medium,
        '(unattributed)'
    ) AS original_medium,

    COUNT(*) AS gclid_sessions,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS pct_of_gclid_sessions

FROM sessions

WHERE
    session_has_gclid

GROUP BY
    original_source,
    original_medium

ORDER BY
    gclid_sessions DESC;