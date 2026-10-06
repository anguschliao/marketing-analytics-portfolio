-- Project A: Customer & Growth Analytics
-- Daily performance analysis
--
-- Purpose:
-- Establish the overall business performance trend before
-- investigating acquisition channels, customer segments, and funnel behavior.

SELECT
    date,
    users,
    sessions,
    engaged_sessions,
    engagement_rate,
    product_view_sessions,
    add_to_cart_sessions,
    checkout_sessions,
    purchasing_sessions,
    conversion_rate,
    revenue,
    revenue_per_session,

    SAFE_DIVIDE(revenue, purchasing_sessions) AS revenue_per_purchase

FROM `turing-emitter-510722-h2.analytics.daily_kpis`

ORDER BY date;