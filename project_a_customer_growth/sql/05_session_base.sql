-- ============================================================
-- Project A: Customer & Growth Analytics
-- Canonical Session-Level Analysis Base
--
-- Grain:
-- One row per GA4 user/session combination
-- (user_pseudo_id + ga_session_id)
--
-- Purpose:
-- Create a reusable session-level dataset containing:
-- - engagement
-- - ecommerce funnel behavior
-- - revenue
-- - observed session acquisition
-- - first-user acquisition
-- - device and geography
--
-- Session acquisition methodology:
-- 1. Detect the GCLID parameter anywhere within the session.
-- 2. If GCLID is present, classify session as google / cpc.
-- 3. Otherwise use the earliest valid source/medium/campaign.
-- 4. Exclude known Merchandise Store self-referrals.
--
-- IMPORTANT:
-- Session acquisition describes how THIS SESSION arrived.
-- It does not apply last-non-direct or multi-touch attribution.
-- ============================================================

WITH events AS (

    SELECT
        PARSE_DATE('%Y%m%d', event_date) AS event_date,
        event_timestamp,
        user_pseudo_id,
        event_name,

        -- ----------------------------------------------------
        -- Session identifiers
        -- ----------------------------------------------------

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

        -- ----------------------------------------------------
        -- Engagement
        -- ----------------------------------------------------

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

        -- ----------------------------------------------------
        -- Observed session acquisition
        -- ----------------------------------------------------

        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'source'
        ) AS event_source,

        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'medium'
        ) AS event_medium,

        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'campaign'
        ) AS event_campaign,

        -- GCLID values are obfuscated/null in the public
        -- dataset, but the parameter key remains available.
        EXISTS (
            SELECT 1
            FROM UNNEST(event_params)
            WHERE key = 'gclid'
        ) AS has_gclid,

        -- ----------------------------------------------------
        -- First-user acquisition
        -- ----------------------------------------------------

        traffic_source.source
            AS first_user_source,

        traffic_source.medium
            AS first_user_medium,

        traffic_source.name
            AS first_user_campaign,

        -- ----------------------------------------------------
        -- Dimensions
        -- ----------------------------------------------------

        device.category
            AS device_category,

        geo.country
            AS country,

        -- ----------------------------------------------------
        -- Ecommerce
        -- ----------------------------------------------------

        ecommerce.purchase_revenue
            AS purchase_revenue

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

valid_events AS (

    SELECT
        *,

        -- Identify records that can be used to reconstruct
        -- observed session acquisition.
        CASE

            WHEN event_source IS NULL
                 AND event_medium IS NULL
                 AND event_campaign IS NULL
                THEN 0

            -- Exclude known Merchandise Store self-referrals.
            WHEN LOWER(event_source) IN (
                'shop.googlemerchandisestore.com',
                'googlemerchandisestore.com'
            )
                THEN 0

            ELSE 1

        END AS valid_acquisition_candidate

    FROM events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL
),

sessions AS (

    SELECT
        user_pseudo_id,
        ga_session_id,

        -- ----------------------------------------------------
        -- Session timing
        -- ----------------------------------------------------

        MIN(event_date)
            AS session_date,

        MIN(event_timestamp)
            AS session_start_timestamp,

        MAX(ga_session_number)
            AS session_number,

        -- ----------------------------------------------------
        -- Engagement
        -- ----------------------------------------------------

        -- first_visit flags inflate first-session engagement in this export.
        -- Keep all events, but exclude first_visit, first_open, and
        -- session_start from establishing engaged_session only.
        MAX(
            CASE
                WHEN event_name NOT IN (
                    'first_visit',
                    'first_open',
                    'session_start'
                )
                AND session_engaged = '1'
                THEN 1
                ELSE 0
            END
        ) AS engaged_session,

        SUM(
            COALESCE(engagement_time_msec, 0)
        ) / 1000.0 AS engagement_seconds,

        -- ----------------------------------------------------
        -- Funnel activity
        -- ----------------------------------------------------

        COUNTIF(event_name = 'page_view')
            AS page_views,

        COUNTIF(event_name = 'view_item')
            AS product_views,

        COUNTIF(event_name = 'add_to_cart')
            AS add_to_cart_events,

        COUNTIF(event_name = 'begin_checkout')
            AS checkout_events,

        COUNTIF(event_name = 'add_shipping_info')
            AS shipping_events,

        COUNTIF(event_name = 'add_payment_info')
            AS payment_events,

        COUNTIF(event_name = 'purchase')
            AS purchase_events,

        -- ----------------------------------------------------
        -- Revenue
        -- ----------------------------------------------------

        SUM(
            CASE
                WHEN event_name = 'purchase'
                    THEN COALESCE(purchase_revenue, 0)
                ELSE 0
            END
        ) AS revenue,

        -- ----------------------------------------------------
        -- Session acquisition
        -- ----------------------------------------------------

        LOGICAL_OR(has_gclid)
            AS session_has_gclid,

        ARRAY_AGG(
            IF(
                valid_acquisition_candidate = 1,

                STRUCT(
                    event_timestamp,
                    event_source AS source,
                    event_medium AS medium,
                    event_campaign AS campaign
                ),

                NULL
            )

            IGNORE NULLS
            ORDER BY event_timestamp
            LIMIT 1

        )[SAFE_OFFSET(0)] AS acquisition_record,

        -- ----------------------------------------------------
        -- First-user acquisition
        -- ----------------------------------------------------

        ARRAY_AGG(
            first_user_source
            IGNORE NULLS
            ORDER BY event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS first_user_source,

        ARRAY_AGG(
            first_user_medium
            IGNORE NULLS
            ORDER BY event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS first_user_medium,

        ARRAY_AGG(
            first_user_campaign
            IGNORE NULLS
            ORDER BY event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS first_user_campaign,

        -- ----------------------------------------------------
        -- Session dimensions
        -- ----------------------------------------------------

        ARRAY_AGG(
            device_category
            IGNORE NULLS
            ORDER BY event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS device_category,

        ARRAY_AGG(
            country
            IGNORE NULLS
            ORDER BY event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS country

    FROM valid_events

    GROUP BY
        user_pseudo_id,
        ga_session_id
)

SELECT
    user_pseudo_id,
    ga_session_id,

    session_date,
    session_start_timestamp,
    session_number,

    engaged_session,
    engagement_seconds,

    page_views,
    product_views,
    add_to_cart_events,
    checkout_events,
    shipping_events,
    payment_events,
    purchase_events,

    revenue,

    -- --------------------------------------------------------
    -- Observed session acquisition
    -- --------------------------------------------------------

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
        AS google_ads_click,

    -- --------------------------------------------------------
    -- First-user acquisition
    -- --------------------------------------------------------

    first_user_source,
    first_user_medium,
    first_user_campaign,

    -- --------------------------------------------------------
    -- Dimensions
    -- --------------------------------------------------------

    device_category,
    country

FROM sessions;