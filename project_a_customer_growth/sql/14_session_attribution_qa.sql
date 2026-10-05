-- ============================================================
-- Project A: Customer & Growth Analytics
-- Observed Session Acquisition QA
--
-- Purpose:
-- Validate coverage and classifications produced by the
-- observed session acquisition methodology.
--
-- IMPORTANT:
-- The public GA4 sample contains the GCLID parameter key,
-- but its underlying value is obfuscated/null.
-- Therefore, presence of the GCLID parameter is used as
-- evidence of Google Ads traffic.
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

valid_session_events AS (

    SELECT *
    FROM events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL
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

    FROM valid_session_events
),

session_level AS (

    SELECT
        user_pseudo_id,
        ga_session_id,

        -- GCLID parameter found anywhere in the session
        LOGICAL_OR(has_gclid)
            AS session_has_gclid,

        -- Earliest valid observed traffic record
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

        )[SAFE_OFFSET(0)] AS acquisition_record

    FROM candidates

    GROUP BY
        user_pseudo_id,
        ga_session_id
),

final_attribution AS (

    SELECT
        user_pseudo_id,
        ga_session_id,
        session_has_gclid,

        CASE
            WHEN session_has_gclid
                THEN 'google'
            ELSE acquisition_record.source
        END AS session_source,

        CASE
            WHEN session_has_gclid
                THEN 'cpc'
            ELSE acquisition_record.medium
        END AS session_medium,

        acquisition_record.campaign
            AS session_campaign

    FROM session_level
)

SELECT
    COUNT(*) AS total_sessions,

    COUNTIF(
        session_source IS NOT NULL
        OR session_medium IS NOT NULL
        OR session_has_gclid
    ) AS attributed_sessions,

    COUNTIF(
        session_source IS NULL
        AND session_medium IS NULL
        AND NOT session_has_gclid
    ) AS unattributed_sessions,

    ROUND(
        SAFE_DIVIDE(
            COUNTIF(
                session_source IS NULL
                AND session_medium IS NULL
                AND NOT session_has_gclid
            ),
            COUNT(*)
        ) * 100,
        2
    ) AS unattributed_pct,

    COUNTIF(
        session_source = '(direct)'
        AND session_medium = '(none)'
    ) AS direct_sessions,

    COUNTIF(
        session_source = 'google'
        AND session_medium = 'organic'
    ) AS google_organic_sessions,

    COUNTIF(
        session_source = 'google'
        AND session_medium = 'cpc'
    ) AS google_cpc_sessions,

    COUNTIF(
        session_has_gclid
    ) AS google_ads_click_sessions,

    COUNTIF(
        LOWER(session_source) IN (
            'shop.googlemerchandisestore.com',
            'googlemerchandisestore.com'
        )
    ) AS remaining_self_referral_sessions

FROM final_attribution;