-- ============================================================
-- Project A: Customer & Growth Analytics
-- Retention & Customer Value Synthesis
--
-- Purpose:
-- Consolidate the major retention and customer-value KPIs into
-- a portfolio-ready executive summary.
--
-- Important:
-- - Retention is observed within the available dataset only.
-- - Fixed-window metrics control for right-censoring.
-- - Customer value is observed 30-day value, not lifetime value.
-- - First-observed acquisition is not necessarily true original
--   customer acquisition.
-- ============================================================


-- ============================================================
-- 1. OVERALL CUSTOMER BEHAVIOR
-- ============================================================

SELECT
    'Overall Customer Behavior' AS analysis_section,

    COUNT(*) AS customers,

    COUNTIF(returned_after_first_session = 1)
        AS repeat_session_customers,

    SAFE_DIVIDE(
        COUNTIF(returned_after_first_session = 1),
        COUNT(*)
    ) AS repeat_session_rate,

    COUNTIF(returned_on_later_day = 1)
        AS later_day_returning_customers,

    SAFE_DIVIDE(
        COUNTIF(returned_on_later_day = 1),
        COUNT(*)
    ) AS later_day_return_rate,

    COUNTIF(purchasing_sessions > 0)
        AS purchasing_customers,

    COUNTIF(repeat_purchaser = 1)
        AS repeat_purchasers,

    SAFE_DIVIDE(
        COUNTIF(repeat_purchaser = 1),
        COUNTIF(purchasing_sessions > 0)
    ) AS observed_repeat_purchaser_rate

FROM `turing-emitter-510722-h2.analytics.customer_base`;


-- ============================================================
-- 2. FIXED-WINDOW CUSTOMER RETENTION
--
-- Measures whether a customer returned on a later date within
-- 7, 14, or 30 days after first observation.
--
-- Only customers with a complete observation window are
-- included in each denominator.
-- ============================================================

WITH customer_activity AS (
    SELECT DISTINCT
        user_pseudo_id,
        session_date
    FROM `turing-emitter-510722-h2.analytics.session_base`
),

first_observation AS (
    SELECT
        user_pseudo_id,
        MIN(session_date) AS first_observed_date
    FROM customer_activity
    GROUP BY user_pseudo_id
),

customer_returns AS (
    SELECT
        f.user_pseudo_id,
        f.first_observed_date,

        MAX(
            IF(
                DATE_DIFF(
                    a.session_date,
                    f.first_observed_date,
                    DAY
                ) BETWEEN 1 AND 7,
                1,
                0
            )
        ) AS returned_within_7_days,

        MAX(
            IF(
                DATE_DIFF(
                    a.session_date,
                    f.first_observed_date,
                    DAY
                ) BETWEEN 1 AND 14,
                1,
                0
            )
        ) AS returned_within_14_days,

        MAX(
            IF(
                DATE_DIFF(
                    a.session_date,
                    f.first_observed_date,
                    DAY
                ) BETWEEN 1 AND 30,
                1,
                0
            )
        ) AS returned_within_30_days

    FROM first_observation AS f

    LEFT JOIN customer_activity AS a
        ON f.user_pseudo_id = a.user_pseudo_id
        AND a.session_date > f.first_observed_date

    GROUP BY
        f.user_pseudo_id,
        f.first_observed_date
),

dataset_boundary AS (
    SELECT
        MAX(session_date) AS dataset_end_date
    FROM `turing-emitter-510722-h2.analytics.session_base`
)

SELECT
    '7 Day' AS retention_window,

    COUNTIF(
        first_observed_date
            <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
    ) AS eligible_customers,

    COUNTIF(
        first_observed_date
            <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
        AND returned_within_7_days = 1
    ) AS retained_customers,

    SAFE_DIVIDE(
        COUNTIF(
            first_observed_date
                <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
            AND returned_within_7_days = 1
        ),
        COUNTIF(
            first_observed_date
                <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
        )
    ) AS retention_rate

FROM customer_returns
CROSS JOIN dataset_boundary

UNION ALL

SELECT
    '14 Day',

    COUNTIF(
        first_observed_date
            <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
    ),

    COUNTIF(
        first_observed_date
            <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
        AND returned_within_14_days = 1
    ),

    SAFE_DIVIDE(
        COUNTIF(
            first_observed_date
                <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
            AND returned_within_14_days = 1
        ),
        COUNTIF(
            first_observed_date
                <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
        )
    )

FROM customer_returns
CROSS JOIN dataset_boundary

UNION ALL

SELECT
    '30 Day',

    COUNTIF(
        first_observed_date
            <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
    ),

    COUNTIF(
        first_observed_date
            <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
        AND returned_within_30_days = 1
    ),

    SAFE_DIVIDE(
        COUNTIF(
            first_observed_date
                <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
            AND returned_within_30_days = 1
        ),
        COUNTIF(
            first_observed_date
                <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
        )
    )

FROM customer_returns
CROSS JOIN dataset_boundary

ORDER BY retention_window;


-- ============================================================
-- 3. FIXED-WINDOW PURCHASE RETENTION
--
-- Measures whether purchasing customers purchased again on a
-- later date within 7, 14, or 30 days of first purchase.
-- ============================================================

WITH purchase_activity AS (
    SELECT DISTINCT
        user_pseudo_id,
        session_date AS purchase_date
    FROM `turing-emitter-510722-h2.analytics.session_base`
    WHERE purchase_events > 0
),

first_purchase AS (
    SELECT
        user_pseudo_id,
        MIN(purchase_date) AS first_purchase_date
    FROM purchase_activity
    GROUP BY user_pseudo_id
),

purchase_returns AS (
    SELECT
        f.user_pseudo_id,
        f.first_purchase_date,

        MAX(
            IF(
                DATE_DIFF(
                    p.purchase_date,
                    f.first_purchase_date,
                    DAY
                ) BETWEEN 1 AND 7,
                1,
                0
            )
        ) AS repurchased_within_7_days,

        MAX(
            IF(
                DATE_DIFF(
                    p.purchase_date,
                    f.first_purchase_date,
                    DAY
                ) BETWEEN 1 AND 14,
                1,
                0
            )
        ) AS repurchased_within_14_days,

        MAX(
            IF(
                DATE_DIFF(
                    p.purchase_date,
                    f.first_purchase_date,
                    DAY
                ) BETWEEN 1 AND 30,
                1,
                0
            )
        ) AS repurchased_within_30_days

    FROM first_purchase AS f

    LEFT JOIN purchase_activity AS p
        ON f.user_pseudo_id = p.user_pseudo_id
        AND p.purchase_date > f.first_purchase_date

    GROUP BY
        f.user_pseudo_id,
        f.first_purchase_date
),

dataset_boundary AS (
    SELECT
        MAX(session_date) AS dataset_end_date
    FROM `turing-emitter-510722-h2.analytics.session_base`
)

SELECT
    '7 Day' AS purchase_retention_window,

    COUNTIF(
        first_purchase_date
            <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
    ) AS eligible_purchasers,

    COUNTIF(
        first_purchase_date
            <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
        AND repurchased_within_7_days = 1
    ) AS repeat_purchasers,

    SAFE_DIVIDE(
        COUNTIF(
            first_purchase_date
                <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
            AND repurchased_within_7_days = 1
        ),
        COUNTIF(
            first_purchase_date
                <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
        )
    ) AS repeat_purchase_rate

FROM purchase_returns
CROSS JOIN dataset_boundary

UNION ALL

SELECT
    '14 Day',

    COUNTIF(
        first_purchase_date
            <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
    ),

    COUNTIF(
        first_purchase_date
            <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
        AND repurchased_within_14_days = 1
    ),

    SAFE_DIVIDE(
        COUNTIF(
            first_purchase_date
                <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
            AND repurchased_within_14_days = 1
        ),
        COUNTIF(
            first_purchase_date
                <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
        )
    )

FROM purchase_returns
CROSS JOIN dataset_boundary

UNION ALL

SELECT
    '30 Day',

    COUNTIF(
        first_purchase_date
            <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
    ),

    COUNTIF(
        first_purchase_date
            <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
        AND repurchased_within_30_days = 1
    ),

    SAFE_DIVIDE(
        COUNTIF(
            first_purchase_date
                <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
            AND repurchased_within_30_days = 1
        ),
        COUNTIF(
            first_purchase_date
                <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
        )
    )

FROM purchase_returns
CROSS JOIN dataset_boundary

ORDER BY purchase_retention_window;


-- ============================================================
-- 4. STANDARDIZED 30-DAY CUSTOMER VALUE
-- ============================================================

WITH dataset_boundary AS (
    SELECT
        MAX(session_date) AS dataset_end_date
    FROM `turing-emitter-510722-h2.analytics.session_base`
),

eligible_customers AS (
    SELECT
        user_pseudo_id,
        first_observed_date

    FROM `turing-emitter-510722-h2.analytics.customer_base`
    CROSS JOIN dataset_boundary

    WHERE first_observed_date
        <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
),

customer_value AS (
    SELECT
        e.user_pseudo_id,

        COUNT(*) AS sessions_30d,

        COUNT(
            DISTINCT IF(
                s.purchase_events > 0,
                s.session_date,
                NULL
            )
        ) AS purchase_days_30d,

        SUM(s.revenue) AS revenue_30d

    FROM eligible_customers AS e

    INNER JOIN `turing-emitter-510722-h2.analytics.session_base` AS s
        ON e.user_pseudo_id = s.user_pseudo_id
        AND s.session_date BETWEEN
            e.first_observed_date
            AND DATE_ADD(e.first_observed_date, INTERVAL 30 DAY)

    GROUP BY e.user_pseudo_id
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
                THEN 'Multi-Session Non-Purchaser'

            ELSE 'Single-Session Non-Purchaser'
        END AS customer_segment

    FROM customer_value
),

totals AS (
    SELECT
        COUNT(*) AS customers,
        SUM(revenue_30d) AS revenue
    FROM classified
)

SELECT
    customer_segment,

    COUNT(*) AS customers,

    SAFE_DIVIDE(
        COUNT(*),
        (SELECT customers FROM totals)
    ) AS customer_share,

    SUM(revenue_30d) AS revenue,

    SAFE_DIVIDE(
        SUM(revenue_30d),
        (SELECT revenue FROM totals)
    ) AS revenue_share,

    AVG(revenue_30d)
        AS revenue_per_customer,

    AVG(sessions_30d)
        AS sessions_per_customer

FROM classified

GROUP BY customer_segment

ORDER BY
    CASE customer_segment
        WHEN 'Repeat Purchaser' THEN 1
        WHEN 'One-Time Purchaser' THEN 2
        WHEN 'Multi-Session Non-Purchaser' THEN 3
        WHEN 'Single-Session Non-Purchaser' THEN 4
    END;