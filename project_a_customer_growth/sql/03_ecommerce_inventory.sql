SELECT
    event_name,
    COUNT(*) AS event_count,
    COUNT(DISTINCT user_pseudo_id) AS unique_users,

    SUM(ecommerce.total_item_quantity) AS item_quantity,
    SUM(ecommerce.purchase_revenue) AS purchase_revenue,
    SUM(ecommerce.refund_value) AS refund_value,

    COUNT(DISTINCT ecommerce.transaction_id) AS unique_transactions

FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

WHERE event_name IN (
    'view_item',
    'add_to_cart',
    'begin_checkout',
    'add_shipping_info',
    'add_payment_info',
    'purchase'
)

GROUP BY
    event_name

ORDER BY
    event_count DESC;