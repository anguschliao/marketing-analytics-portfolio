-- Project A: Customer & Growth Analytics
-- Add to Cart instrumentation coverage trend
--
-- Purpose:
-- Determine whether Add to Cart event coverage among purchasing
-- sessions stabilizes after its initial appearance on Nov 16.

SELECT
    session_date,

    COUNT(*) AS purchasing_sessions,

    COUNTIF(add_to_cart_events > 0) AS purchases_with_add_to_cart,

    SAFE_DIVIDE(
        COUNTIF(add_to_cart_events > 0),
        COUNT(*)
    ) AS add_to_cart_coverage,

    COUNTIF(product_views > 0) AS purchases_with_product_view,

    SAFE_DIVIDE(
        COUNTIF(product_views > 0),
        COUNT(*)
    ) AS product_view_coverage

FROM `turing-emitter-510722-h2.analytics.session_base`

WHERE purchase_events > 0
  AND session_date >= '2020-11-16'

GROUP BY session_date

ORDER BY session_date;