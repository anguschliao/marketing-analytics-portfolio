-- ============================================================
-- Project A: Customer & Growth Analytics
-- Observed Session Acquisition
--
-- Purpose:
-- Reconstruct how each individual session arrived.
--
-- Method:
-- 1. Define sessions using user_pseudo_id + ga_session_id.
-- 2. Select the earliest usable traffic record.
-- 3. Ignore known Merchandise Store self-referrals.
-- 4. Detect presence of the GCLID parameter anywhere in session.
-- 5. GCLID presence is treated as evidence of Google Ads traffic.
--
-- IMPORTANT:
-- This represents observed SESSION ACQUISITION.
-- Direct sessions remain Direct unless the session itself
-- contains evidence of a Google Ads click.
-- No cross-session attribution is applied.
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

        MIN(event_timestamp)
            AS session_start_timestamp,

        LOGICAL_OR(has_gclid)
            AS session_has_gclid,

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
)

SELECT
    user_pseudo_id,
    ga_session_id,
    session_start_timestamp,

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
        AS session_campaign,

    session_has_gclid
        AS google_ads_click

FROM session_level;