-- Project A: Customer & Growth Analytics
-- Acquisition channel performance analysis
--
-- Purpose:
-- Compare acquisition sources/mediums on traffic contribution,
-- engagement, conversion, revenue contribution, and monetization efficiency.

WITH channel AS (
    SELECT
        session_source,
        session_medium,
        users,
        sessions,
        engaged_sessions,
        engagement_rate,
        product_view_sessions,
        product_view_rate,
        add_to_cart_sessions,
        add_to_cart_rate,
        checkout_sessions,
        checkout_rate,
        purchasing_sessions,
        conversion_rate,
        revenue,
        revenue_per_session
    FROM `turing-emitter-510722-h2.analytics.channel_performance`
),

totals AS (
    SELECT
        SUM(sessions) AS total_sessions,
        SUM(purchasing_sessions) AS total_purchasing_sessions,
        SUM(revenue) AS total_revenue
    FROM channel
)

SELECT
    c.session_source,
    c.session_medium,

    c.users,
    c.sessions,

    SAFE_DIVIDE(
        c.sessions,
        t.total_sessions
    ) AS traffic_share,

    c.engagement_rate,

    c.product_view_rate,
    c.add_to_cart_rate,
    c.checkout_rate,

    c.purchasing_sessions,
    c.conversion_rate,

    SAFE_DIVIDE(
        c.purchasing_sessions,
        t.total_purchasing_sessions
    ) AS purchase_share,

    c.revenue,

    SAFE_DIVIDE(
        c.revenue,
        t.total_revenue
    ) AS revenue_share,

    c.revenue_per_session,

    SAFE_DIVIDE(
        c.revenue,
        c.purchasing_sessions
    ) AS revenue_per_purchase

FROM channel c
CROSS JOIN totals t

ORDER BY c.sessions DESC;