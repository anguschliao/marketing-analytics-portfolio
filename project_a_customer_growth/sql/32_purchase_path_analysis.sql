-- Project A: Customer & Growth Analytics
-- Purchase path analysis
--
-- Purpose:
-- Investigate purchasing sessions that do not appear in the
-- strict sequential funnel by identifying which ecommerce
-- stages were recorded within each purchasing session.

WITH purchasing_sessions AS (
    SELECT
        user_pseudo_id,
        ga_session_id,
        product_views,
        add_to_cart_events,
        checkout_events,
        shipping_events,
        payment_events,
        purchase_events,
        revenue
    FROM `turing-emitter-510722-h2.analytics.session_base`
    WHERE purchase_events > 0
),

classified AS (
    SELECT
        *,
        CASE
            WHEN product_views > 0
             AND add_to_cart_events > 0
             AND checkout_events > 0
             AND shipping_events > 0
             AND payment_events > 0
                THEN 'Complete Recorded Funnel'

            WHEN product_views = 0
                THEN 'Missing Product View'

            WHEN add_to_cart_events = 0
                THEN 'Missing Add to Cart'

            WHEN checkout_events = 0
                THEN 'Missing Checkout'

            WHEN shipping_events = 0
                THEN 'Missing Shipping Info'

            WHEN payment_events = 0
                THEN 'Missing Payment Info'

            ELSE 'Other'
        END AS purchase_path
    FROM purchasing_sessions
)

SELECT
    purchase_path,
    COUNT(*) AS purchasing_sessions,

    SAFE_DIVIDE(
        COUNT(*),
        SUM(COUNT(*)) OVER ()
    ) AS share_of_purchasing_sessions,

    SUM(revenue) AS revenue,

    SAFE_DIVIDE(
        SUM(revenue),
        COUNT(*)
    ) AS revenue_per_purchasing_session

FROM classified

GROUP BY purchase_path

ORDER BY purchasing_sessions DESC;