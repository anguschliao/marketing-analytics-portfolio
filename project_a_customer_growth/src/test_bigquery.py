from google.cloud import bigquery

PROJECT_ID = "turing-emitter-510722-h2"

client = bigquery.Client(project=PROJECT_ID)

query = """
SELECT
    event_name,
    COUNT(*) AS event_count
FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY
    event_name
ORDER BY
    event_count DESC
LIMIT 20
"""

df = client.query(query).to_dataframe()

print(df)