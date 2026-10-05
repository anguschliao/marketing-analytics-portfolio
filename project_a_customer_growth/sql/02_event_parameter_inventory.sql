SELECT
    ep.key AS parameter_name,
    COUNT(*) AS occurrences,
    COUNT(DISTINCT event_name) AS event_types
FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(event_params) AS ep
GROUP BY
    ep.key
ORDER BY
    occurrences DESC;