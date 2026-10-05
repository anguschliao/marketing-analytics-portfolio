-- ============================================================
-- Project A: Customer & Growth Analytics
-- Session Acquisition QA
--
-- Purpose:
-- Determine whether source / medium / campaign values are
-- consistent within each derived GA4 session.
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

        COUNT(DISTINCT source) AS source_values,
        COUNT(DISTINCT medium) AS medium_values,
        COUNT(DISTINCT campaign) AS campaign_values,

        COUNTIF(source IS NOT NULL) AS events_with_source,
        COUNTIF(medium IS NOT NULL) AS events_with_medium,
        COUNTIF(campaign IS NOT NULL) AS events_with_campaign

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

    COUNTIF(source_values = 0) AS sessions_missing_source,
    COUNTIF(medium_values = 0) AS sessions_missing_medium,
    COUNTIF(campaign_values = 0) AS sessions_missing_campaign,

    COUNTIF(source_values = 1) AS sessions_with_one_source,
    COUNTIF(medium_values = 1) AS sessions_with_one_medium,
    COUNTIF(campaign_values = 1) AS sessions_with_one_campaign,

    COUNTIF(source_values > 1) AS sessions_with_multiple_sources,
    COUNTIF(medium_values > 1) AS sessions_with_multiple_mediums,
    COUNTIF(campaign_values > 1) AS sessions_with_multiple_campaigns

FROM sessions;