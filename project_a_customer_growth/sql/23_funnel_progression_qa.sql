-- ============================================================
-- Project A: Customer & Growth Analytics
-- Funnel Progression QA
--
-- Purpose:
-- Identify sessions containing a downstream funnel event
-- without the expected preceding funnel event.
-- ============================================================

SELECT
    COUNTIF(
        add_to_cart_events > 0
        AND product_views = 0
    ) AS cart_without_product_view,

    COUNTIF(
        checkout_events > 0
        AND add_to_cart_events = 0
    ) AS checkout_without_cart,

    COUNTIF(
        shipping_events > 0
        AND checkout_events = 0
    ) AS shipping_without_checkout,

    COUNTIF(
        payment_events > 0
        AND shipping_events = 0
    ) AS payment_without_shipping,

    COUNTIF(
        purchase_events > 0
        AND payment_events = 0
    ) AS purchase_without_payment

FROM
    `turing-emitter-510722-h2.analytics.session_base`;