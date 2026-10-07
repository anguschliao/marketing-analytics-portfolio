-- ============================================================
-- Project A: Customer & Growth Analytics
-- Standardized 30-Day Customer Value
--
-- Purpose:
-- Compare customer value using a consistent 30-day observation
-- window from each customer's first observed date.
--
-- Only customers with a complete 30-day observation window are
-- included.
--
-- This is observed 30-day customer value, NOT lifetime value.
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
        first_observed_source,
        first_observed_medium

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

        COUNTIF(s.engaged_session = 1)
            AS engaged_sessions_30d,

        COUNTIF(s.product_views > 0)
            AS product_view_sessions_30d,

        COUNTIF(s.checkout_events > 0)
            AS checkout_sessions_30d,

        COUNTIF(s.purchase_events > 0)
            AS purchasing_sessions_30d,

        SUM(s.purchase_events)
            AS purchase_events_30d,

        COALESCE(SUM(s.revenue), 0)
            AS revenue_30d,

        COUNT(
            DISTINCT IF(
                s.purchase_events > 0,
                s.session_date,
                NULL
            )
        ) AS purchase_days_30d

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

classified AS (
    SELECT
        *,

        CASE
            WHEN purchase_days_30d >= 2
                THEN 'Repeat Purchaser'
            WHEN purchase_days_30d = 1
                THEN 'One-Time Purchaser'
            WHEN sessions_30d > 1
                THEN 'Returning Non-Purchaser'
            ELSE 'Single-Session Non-Purchaser'
        END AS customer_segment

    FROM customer_30_day_activity
),

overall AS (
    SELECT
        COUNT(*) AS customers,
        SUM(revenue_30d) AS revenue
    FROM classified
),

segment_summary AS (
    SELECT
        customer_segment,

        COUNT(*) AS customers,

        SUM(sessions_30d) AS sessions,

        SUM(purchasing_sessions_30d)
            AS purchasing_sessions,

        SUM(revenue_30d) AS revenue,

        AVG(sessions_30d)
            AS avg_sessions_per_customer,

        AVG(revenue_30d)
            AS avg_revenue_per_customer,

        COUNTIF(purchasing_sessions_30d > 0)
            AS purchasing_customers

    FROM classified

    GROUP BY customer_segment
)

SELECT
    customer_segment,

    customers,

    SAFE_DIVIDE(
        customers,
        (SELECT customers FROM overall)
    ) AS customer_share,

    sessions,

    avg_sessions_per_customer,

    purchasing_customers,

    purchasing_sessions,

    revenue,

    SAFE_DIVIDE(
        revenue,
        (SELECT revenue FROM overall)
    ) AS revenue_share,

    avg_revenue_per_customer,

    SAFE_DIVIDE(
        revenue,
        purchasing_customers
    ) AS avg_revenue_per_purchasing_customer

FROM segment_summary

ORDER BY
    CASE customer_segment
        WHEN 'Repeat Purchaser' THEN 1
        WHEN 'One-Time Purchaser' THEN 2
        WHEN 'Returning Non-Purchaser' THEN 3
        WHEN 'Single-Session Non-Purchaser' THEN 4
    END;