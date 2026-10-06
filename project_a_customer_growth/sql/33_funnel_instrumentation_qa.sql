-- Project A: Customer & Growth Analytics
-- Funnel instrumentation QA
--
-- Purpose:
-- Determine whether missing ecommerce funnel events are concentrated
-- before the apparent Add to Cart instrumentation change around Nov 16.
--
-- Important:
-- This does not impute or manufacture missing events. It measures
-- event coverage among sessions that ultimately recorded a purchase.

WITH purchasing_sessions AS (
    SELECT
        session_date,
        product_views,
        add_to_cart_events,
        checkout_events,
        shipping_events,
        payment_events,
        purchase_events,
        revenue,

        CASE
            WHEN session_date < '2020-11-16'
                THEN '1 - Before Nov 16'
            ELSE '2 - Nov 16 onward'
        END AS measurement_period

    FROM `turing-emitter-510722-h2.analytics.session_base`

    WHERE purchase_events > 0
),

period_summary AS (
    SELECT
        measurement_period,

        COUNT(*) AS purchasing_sessions,

        COUNTIF(product_views > 0) AS with_product_view,
        COUNTIF(add_to_cart_events > 0) AS with_add_to_cart,
        COUNTIF(checkout_events > 0) AS with_checkout,
        COUNTIF(shipping_events > 0) AS with_shipping_info,
        COUNTIF(payment_events > 0) AS with_payment_info,

        COUNTIF(
            product_views > 0
            AND add_to_cart_events > 0
            AND checkout_events > 0
            AND shipping_events > 0
            AND payment_events > 0
        ) AS complete_recorded_funnel,

        SUM(revenue) AS revenue

    FROM purchasing_sessions

    GROUP BY measurement_period
)

SELECT
    measurement_period,

    purchasing_sessions,

    with_product_view,
    SAFE_DIVIDE(
        with_product_view,
        purchasing_sessions
    ) AS product_view_coverage,

    with_add_to_cart,
    SAFE_DIVIDE(
        with_add_to_cart,
        purchasing_sessions
    ) AS add_to_cart_coverage,

    with_checkout,
    SAFE_DIVIDE(
        with_checkout,
        purchasing_sessions
    ) AS checkout_coverage,

    with_shipping_info,
    SAFE_DIVIDE(
        with_shipping_info,
        purchasing_sessions
    ) AS shipping_info_coverage,

    with_payment_info,
    SAFE_DIVIDE(
        with_payment_info,
        purchasing_sessions
    ) AS payment_info_coverage,

    complete_recorded_funnel,
    SAFE_DIVIDE(
        complete_recorded_funnel,
        purchasing_sessions
    ) AS complete_funnel_coverage,

    revenue

FROM period_summary

ORDER BY measurement_period;