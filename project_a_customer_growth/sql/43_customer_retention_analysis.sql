-- ============================================================
-- Project A: Customer & Growth Analytics
-- Customer Retention & Repeat-Purchase Analysis
--
-- Purpose:
-- Measure observed return behavior, repeat purchasing, and
-- customer value within the available Nov 2020–Jan 2021 window.
--
-- Important:
-- These are observed-window retention measures, not lifetime
-- customer retention. Customers first observed later in the
-- dataset have less opportunity to return.
-- ============================================================

WITH base AS (
    SELECT *
    FROM `turing-emitter-510722-h2.analytics.customer_base`
),

overall AS (
    SELECT
        COUNT(*) AS customers,

        COUNTIF(returned_after_first_session = 1)
            AS customers_with_repeat_session,

        COUNTIF(returned_on_later_day = 1)
            AS customers_returning_later_day,

        COUNTIF(purchasing_sessions > 0)
            AS purchasing_customers,

        COUNTIF(repeat_purchaser = 1)
            AS repeat_purchasers,

        SUM(total_sessions) AS sessions,
        SUM(purchasing_sessions) AS purchasing_sessions,
        SUM(total_revenue) AS revenue

    FROM base
),

customer_segments AS (
    SELECT
        CASE
            WHEN repeat_purchaser = 1
                THEN 'Repeat Purchaser'
            WHEN purchasing_sessions > 0
                THEN 'One-Time Purchaser'
            WHEN returned_on_later_day = 1
                THEN 'Returning Non-Purchaser'
            ELSE 'Single-Day Non-Purchaser'
        END AS customer_segment,

        CASE
            WHEN repeat_purchaser = 1 THEN 1
            WHEN purchasing_sessions > 0 THEN 2
            WHEN returned_on_later_day = 1 THEN 3
            ELSE 4
        END AS segment_order,

        COUNT(*) AS customers,
        SUM(total_sessions) AS sessions,
        SUM(purchasing_sessions) AS purchasing_sessions,
        SUM(total_revenue) AS revenue,
        AVG(total_sessions) AS avg_sessions_per_customer,
        AVG(total_revenue) AS avg_revenue_per_customer

    FROM base
    GROUP BY
        customer_segment,
        segment_order
),

return_timing AS (
    SELECT
        CASE
            WHEN observed_lifespan_days = 0 THEN 'Same day only'
            WHEN observed_lifespan_days BETWEEN 1 AND 7 THEN '1-7 days'
            WHEN observed_lifespan_days BETWEEN 8 AND 30 THEN '8-30 days'
            WHEN observed_lifespan_days BETWEEN 31 AND 60 THEN '31-60 days'
            ELSE '61+ days'
        END AS return_window,

        CASE
            WHEN observed_lifespan_days = 0 THEN 1
            WHEN observed_lifespan_days BETWEEN 1 AND 7 THEN 2
            WHEN observed_lifespan_days BETWEEN 8 AND 30 THEN 3
            WHEN observed_lifespan_days BETWEEN 31 AND 60 THEN 4
            ELSE 5
        END AS return_order,

        COUNT(*) AS customers,
        SUM(total_revenue) AS revenue

    FROM base
    GROUP BY
        return_window,
        return_order
),

purchase_timing AS (
    SELECT
        CASE
            WHEN days_to_first_purchase = 0 THEN 'Purchased first observed day'
            WHEN days_to_first_purchase BETWEEN 1 AND 7 THEN 'Purchased within 1-7 days'
            WHEN days_to_first_purchase BETWEEN 8 AND 30 THEN 'Purchased within 8-30 days'
            WHEN days_to_first_purchase > 30 THEN 'Purchased after 30 days'
        END AS purchase_window,

        CASE
            WHEN days_to_first_purchase = 0 THEN 1
            WHEN days_to_first_purchase BETWEEN 1 AND 7 THEN 2
            WHEN days_to_first_purchase BETWEEN 8 AND 30 THEN 3
            WHEN days_to_first_purchase > 30 THEN 4
        END AS purchase_order,

        COUNT(*) AS customers,
        SUM(total_revenue) AS revenue

    FROM base
    WHERE first_purchase_date IS NOT NULL
    GROUP BY
        purchase_window,
        purchase_order
),

repeat_purchase_timing AS (
    SELECT
        CASE
            WHEN days_between_first_last_purchase BETWEEN 1 AND 7
                THEN '1-7 days'
            WHEN days_between_first_last_purchase BETWEEN 8 AND 30
                THEN '8-30 days'
            WHEN days_between_first_last_purchase BETWEEN 31 AND 60
                THEN '31-60 days'
            WHEN days_between_first_last_purchase > 60
                THEN '61+ days'
        END AS repeat_purchase_window,

        CASE
            WHEN days_between_first_last_purchase BETWEEN 1 AND 7 THEN 1
            WHEN days_between_first_last_purchase BETWEEN 8 AND 30 THEN 2
            WHEN days_between_first_last_purchase BETWEEN 31 AND 60 THEN 3
            WHEN days_between_first_last_purchase > 60 THEN 4
        END AS repeat_order,

        COUNT(*) AS customers,
        SUM(total_revenue) AS revenue

    FROM base
    WHERE repeat_purchaser = 1
    GROUP BY
        repeat_purchase_window,
        repeat_order
)

-- ------------------------------------------------------------
-- Overall observed-window retention
-- ------------------------------------------------------------

SELECT
    1 AS section_order,
    'OVERALL RETENTION' AS metric_group,
    'All Customers' AS segment,
    1 AS row_order,
    'customers' AS metric,
    CAST(customers AS FLOAT64) AS value
FROM overall

UNION ALL

SELECT
    1,
    'OVERALL RETENTION',
    'All Customers',
    2,
    'customers_with_repeat_session',
    CAST(customers_with_repeat_session AS FLOAT64)
FROM overall

UNION ALL

SELECT
    1,
    'OVERALL RETENTION',
    'All Customers',
    3,
    'repeat_session_rate',
    SAFE_DIVIDE(customers_with_repeat_session, customers)
FROM overall

UNION ALL

SELECT
    1,
    'OVERALL RETENTION',
    'All Customers',
    4,
    'customers_returning_later_day',
    CAST(customers_returning_later_day AS FLOAT64)
FROM overall

UNION ALL

SELECT
    1,
    'OVERALL RETENTION',
    'All Customers',
    5,
    'later_day_return_rate',
    SAFE_DIVIDE(customers_returning_later_day, customers)
FROM overall

UNION ALL

SELECT
    1,
    'OVERALL RETENTION',
    'Purchasing Customers',
    6,
    'purchasing_customers',
    CAST(purchasing_customers AS FLOAT64)
FROM overall

UNION ALL

SELECT
    1,
    'OVERALL RETENTION',
    'Purchasing Customers',
    7,
    'repeat_purchasers',
    CAST(repeat_purchasers AS FLOAT64)
FROM overall

UNION ALL

SELECT
    1,
    'OVERALL RETENTION',
    'Purchasing Customers',
    8,
    'repeat_purchaser_rate',
    SAFE_DIVIDE(repeat_purchasers, purchasing_customers)
FROM overall

UNION ALL

-- ------------------------------------------------------------
-- Customer segments
-- ------------------------------------------------------------

SELECT
    2,
    'CUSTOMER SEGMENTS',
    customer_segment,
    segment_order * 10 + 1,
    'customers',
    CAST(customers AS FLOAT64)
FROM customer_segments

UNION ALL

SELECT
    2,
    'CUSTOMER SEGMENTS',
    customer_segment,
    segment_order * 10 + 2,
    'customer_share',
    SAFE_DIVIDE(customers, (SELECT customers FROM overall))
FROM customer_segments

UNION ALL

SELECT
    2,
    'CUSTOMER SEGMENTS',
    customer_segment,
    segment_order * 10 + 3,
    'sessions',
    CAST(sessions AS FLOAT64)
FROM customer_segments

UNION ALL

SELECT
    2,
    'CUSTOMER SEGMENTS',
    customer_segment,
    segment_order * 10 + 4,
    'purchasing_sessions',
    CAST(purchasing_sessions AS FLOAT64)
FROM customer_segments

UNION ALL

SELECT
    2,
    'CUSTOMER SEGMENTS',
    customer_segment,
    segment_order * 10 + 5,
    'revenue',
    CAST(revenue AS FLOAT64)
FROM customer_segments

UNION ALL

SELECT
    2,
    'CUSTOMER SEGMENTS',
    customer_segment,
    segment_order * 10 + 6,
    'revenue_share',
    SAFE_DIVIDE(revenue, (SELECT revenue FROM overall))
FROM customer_segments

UNION ALL

SELECT
    2,
    'CUSTOMER SEGMENTS',
    customer_segment,
    segment_order * 10 + 7,
    'avg_sessions_per_customer',
    avg_sessions_per_customer
FROM customer_segments

UNION ALL

SELECT
    2,
    'CUSTOMER SEGMENTS',
    customer_segment,
    segment_order * 10 + 8,
    'avg_revenue_per_customer',
    avg_revenue_per_customer
FROM customer_segments

UNION ALL

-- ------------------------------------------------------------
-- Observed return timing
-- ------------------------------------------------------------

SELECT
    3,
    'RETURN TIMING',
    return_window,
    return_order,
    'customers',
    CAST(customers AS FLOAT64)
FROM return_timing

UNION ALL

SELECT
    3,
    'RETURN TIMING',
    return_window,
    return_order + 10,
    'customer_share',
    SAFE_DIVIDE(customers, (SELECT customers FROM overall))
FROM return_timing

UNION ALL

SELECT
    3,
    'RETURN TIMING',
    return_window,
    return_order + 20,
    'revenue',
    CAST(revenue AS FLOAT64)
FROM return_timing

UNION ALL

-- ------------------------------------------------------------
-- Time from first observation to first purchase
-- ------------------------------------------------------------

SELECT
    4,
    'FIRST PURCHASE TIMING',
    purchase_window,
    purchase_order,
    'customers',
    CAST(customers AS FLOAT64)
FROM purchase_timing

UNION ALL

SELECT
    4,
    'FIRST PURCHASE TIMING',
    purchase_window,
    purchase_order + 10,
    'purchaser_share',
    SAFE_DIVIDE(
        customers,
        (SELECT purchasing_customers FROM overall)
    )
FROM purchase_timing

UNION ALL

SELECT
    4,
    'FIRST PURCHASE TIMING',
    purchase_window,
    purchase_order + 20,
    'revenue',
    CAST(revenue AS FLOAT64)
FROM purchase_timing

UNION ALL

-- ------------------------------------------------------------
-- Repeat-purchase timing
-- ------------------------------------------------------------

SELECT
    5,
    'REPEAT PURCHASE TIMING',
    repeat_purchase_window,
    repeat_order,
    'customers',
    CAST(customers AS FLOAT64)
FROM repeat_purchase_timing

UNION ALL

SELECT
    5,
    'REPEAT PURCHASE TIMING',
    repeat_purchase_window,
    repeat_order + 10,
    'repeat_purchaser_share',
    SAFE_DIVIDE(
        customers,
        (SELECT repeat_purchasers FROM overall)
    )
FROM repeat_purchase_timing

ORDER BY
    section_order,
    row_order,
    segment;