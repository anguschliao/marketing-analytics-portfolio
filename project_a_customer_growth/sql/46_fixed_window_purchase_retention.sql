-- ============================================================
-- Project A: Customer & Growth Analytics
-- Fixed-Window Purchase Retention
--
-- Purpose:
-- Measure repeat purchasing within fixed periods after a
-- customer's first observed purchase while controlling for
-- right-censoring.
--
-- Only customers with enough remaining observation time are
-- included in each retention window.
--
-- Purchases are observed within the available dataset only and
-- do not represent complete customer lifetime purchase history.
-- ============================================================

WITH purchase_activity AS (
    SELECT
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

later_purchases AS (
    SELECT
        f.user_pseudo_id,
        f.first_purchase_date,
        p.purchase_date,

        DATE_DIFF(
            p.purchase_date,
            f.first_purchase_date,
            DAY
        ) AS days_since_first_purchase

    FROM first_purchase AS f

    INNER JOIN purchase_activity AS p
        USING (user_pseudo_id)

    WHERE p.purchase_date > f.first_purchase_date
),

customer_repeat_purchase AS (
    SELECT
        f.user_pseudo_id,
        f.first_purchase_date,

        MAX(
            IF(
                p.days_since_first_purchase BETWEEN 1 AND 7,
                1,
                0
            )
        ) AS repurchased_within_7_days,

        MAX(
            IF(
                p.days_since_first_purchase BETWEEN 1 AND 14,
                1,
                0
            )
        ) AS repurchased_within_14_days,

        MAX(
            IF(
                p.days_since_first_purchase BETWEEN 1 AND 30,
                1,
                0
            )
        ) AS repurchased_within_30_days

    FROM first_purchase AS f

    LEFT JOIN later_purchases AS p
        USING (user_pseudo_id, first_purchase_date)

    GROUP BY
        f.user_pseudo_id,
        f.first_purchase_date
),

dataset_boundary AS (
    SELECT
        MAX(session_date) AS dataset_end_date
    FROM `turing-emitter-510722-h2.analytics.session_base`
),

purchase_retention_windows AS (

    SELECT
        '7 Day' AS retention_window,
        1 AS window_order,

        COUNTIF(
            first_purchase_date <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
        ) AS eligible_purchasers,

        COUNTIF(
            first_purchase_date <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
            AND repurchased_within_7_days = 1
        ) AS repeat_purchasers

    FROM customer_repeat_purchase
    CROSS JOIN dataset_boundary

    UNION ALL

    SELECT
        '14 Day',
        2,

        COUNTIF(
            first_purchase_date <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
        ),

        COUNTIF(
            first_purchase_date <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
            AND repurchased_within_14_days = 1
        )

    FROM customer_repeat_purchase
    CROSS JOIN dataset_boundary

    UNION ALL

    SELECT
        '30 Day',
        3,

        COUNTIF(
            first_purchase_date <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
        ),

        COUNTIF(
            first_purchase_date <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
            AND repurchased_within_30_days = 1
        )

    FROM customer_repeat_purchase
    CROSS JOIN dataset_boundary
)

SELECT
    retention_window,
    eligible_purchasers,
    repeat_purchasers,

    SAFE_DIVIDE(
        repeat_purchasers,
        eligible_purchasers
    ) AS repeat_purchase_rate

FROM purchase_retention_windows

ORDER BY window_order;