-- ============================================================
-- Project A: Customer & Growth Analytics
-- Funnel Progression & Instrumentation QA
--
-- Purpose:
-- Validate event consistency across the primary observed
-- ecommerce funnel and separately monitor Add to Cart
-- instrumentation quality.
--
-- Primary business funnel:
-- Session -> Product View -> Begin Checkout
-- -> Payment Info -> Purchase
--
-- Measurement note:
-- Add to Cart is intentionally excluded from the primary
-- funnel because instrumentation QA identified incomplete
-- event coverage.
--
-- This QA tests event presence within the same session.
-- It does not enforce chronological event order.
-- ============================================================

SELECT

    -- Primary funnel progression QA

    COUNTIF(
        checkout_events > 0
        AND product_views = 0
    ) AS checkout_without_product_view,

    COUNTIF(
        payment_events > 0
        AND checkout_events = 0
    ) AS payment_without_checkout,

    COUNTIF(
        purchase_events > 0
        AND payment_events = 0
    ) AS purchase_without_payment,

    -- Add to Cart instrumentation diagnostics

    COUNTIF(
        add_to_cart_events > 0
        AND product_views = 0
    ) AS cart_without_product_view,

    COUNTIF(
        checkout_events > 0
        AND add_to_cart_events = 0
    ) AS checkout_without_cart,

    COUNTIF(
        purchase_events > 0
        AND add_to_cart_events = 0
    ) AS purchase_without_cart,

    -- Purchasing-session coverage diagnostics

    COUNTIF(
        purchase_events > 0
    ) AS purchasing_sessions,

    COUNTIF(
        purchase_events > 0
        AND product_views > 0
    ) AS purchases_with_product_view,

    COUNTIF(
        purchase_events > 0
        AND checkout_events > 0
    ) AS purchases_with_checkout,

    COUNTIF(
        purchase_events > 0
        AND payment_events > 0
    ) AS purchases_with_payment,

    COUNTIF(
        purchase_events > 0
        AND add_to_cart_events > 0
    ) AS purchases_with_add_to_cart

FROM
    `turing-emitter-510722-h2.analytics.session_base`;