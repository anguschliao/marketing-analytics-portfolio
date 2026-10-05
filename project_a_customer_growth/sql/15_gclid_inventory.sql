-- ============================================================
-- Project A: Customer & Growth Analytics
-- GCLID Parameter Investigation
--
-- Purpose:
-- Determine how the gclid event parameter is stored in the
-- historical GA4 sample dataset.
-- ============================================================

SELECT
    COUNT(*) AS gclid_parameter_occurrences,

    COUNTIF(ep.value.string_value IS NOT NULL)
        AS string_values,

    COUNTIF(ep.value.int_value IS NOT NULL)
        AS int_values,

    COUNTIF(ep.value.float_value IS NOT NULL)
        AS float_values,

    COUNTIF(ep.value.double_value IS NOT NULL)
        AS double_values,

    COUNT(DISTINCT user_pseudo_id)
        AS users_with_gclid,

    COUNT(
        DISTINCT CONCAT(
            user_pseudo_id,
            '-',
            CAST(
                (
                    SELECT value.int_value
                    FROM UNNEST(event_params)
                    WHERE key = 'ga_session_id'
                )
                AS STRING
            )
        )
    ) AS sessions_with_gclid

FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(event_params) AS ep

WHERE
    ep.key = 'gclid';