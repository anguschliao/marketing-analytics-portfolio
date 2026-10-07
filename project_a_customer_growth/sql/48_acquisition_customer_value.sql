-- ============================================================
-- Project A: Customer & Growth Analytics
-- Acquisition Source & Standardized 30-Day Customer Value
--
-- Purpose:
-- Compare downstream customer quality by first-observed
-- acquisition source using a consistent 30-day observation
-- window.
--
-- Only customers with a complete 30-day observation window are
-- included.
--
-- "First observed" acquisition represents the earliest source /
-- medium visible within the available dataset. It is not
-- necessarily the customer's true original acquisition source.
-- ============================================================

WITH dataset_boundary AS (
    SELECT
        MAX(session_date) AS dataset_end_date
    FROM `turing-emitter-510722-h2.analytics.session_base`
),

eligible_customers AS (
    SELECT
        user_pseudo_id,
        first_observed_date,

        COALESCE(first_observed_source, '(direct)')
            AS first_observed_source,

        COALESCE(first_observed_medium, '(none)')
            AS first_observed_medium

    FROM `turing-emitter-510722-h2.analytics.customer_base`
    CROSS JOIN dataset_boundary

    WHERE first_observed_date
        <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
),

customer_30_day_activity AS (
    SELECT
        e.user_pseudo_id,
        e.first_observed_date,
        e.first_observed_source,
        e.first_observed_medium,

        COUNT(*) AS sessions_30d,

        COUNTIF(s.purchase_events > 0)
            AS purchasing_sessions_30d,

        COUNT(
            DISTINCT IF(
                s.purchase_events > 0,
                s.session_date,
                NULL
            )
        ) AS purchase_days_30d,

        COALESCE(SUM(s.revenue), 0)
            AS revenue_30d

    FROM eligible_customers AS e

    INNER JOIN `turing-emitter-510722-h2.analytics.session_base` AS s
        ON e.user_pseudo_id = s.user_pseudo_id
        AND s.session_date BETWEEN
            e.first_observed_date
            AND DATE_ADD(e.first_observed_date, INTERVAL 30 DAY)

    GROUP BY
        e.user_pseudo_id,
        e.first_observed_date,
        e.first_observed_source,
        e.first_observed_medium
),

channel_summary AS (
    SELECT
        first_observed_source,
        first_observed_medium,

        COUNT(*) AS customers,

        COUNTIF(purchasing_sessions_30d > 0)
            AS purchasing_customers,

        COUNTIF(purchase_days_30d >= 2)
            AS repeat_purchasers,

        SUM(sessions_30d) AS sessions,

        SUM(revenue_30d) AS revenue,

        AVG(revenue_30d)
            AS revenue_per_customer,

        AVG(sessions_30d)
            AS sessions_per_customer

    FROM customer_30_day_activity

    GROUP BY
        first_observed_source,
        first_observed_medium
),

totals AS (
    SELECT
        SUM(customers) AS customers,
        SUM(revenue) AS revenue
    FROM channel_summary
)

SELECT
    c.first_observed_source,
    c.first_observed_medium,

    c.customers,

    SAFE_DIVIDE(
        c.customers,
        t.customers
    ) AS customer_share,

    c.purchasing_customers,

    SAFE_DIVIDE(
        c.purchasing_customers,
        c.customers
    ) AS purchaser_rate,

    c.repeat_purchasers,

    SAFE_DIVIDE(
        c.repeat_purchasers,
        c.purchasing_customers
    ) AS repeat_purchaser_rate,

    c.sessions_per_customer,

    c.revenue,

    SAFE_DIVIDE(
        c.revenue,
        t.revenue
    ) AS revenue_share,

    c.revenue_per_customer

FROM channel_summary AS c
CROSS JOIN totals AS t

ORDER BY
    c.revenue DESC;