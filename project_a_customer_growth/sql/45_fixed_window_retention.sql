-- ============================================================
-- Project A: Customer & Growth Analytics
-- Fixed-Window Customer Retention
--
-- Purpose:
-- Measure customer return behavior within fixed periods after
-- first observation while controlling for right-censoring.
--
-- A customer is eligible for a retention window only when the
-- dataset contains enough subsequent calendar days to observe
-- the entire window.
--
-- First observed activity represents first observation within
-- the available dataset, not true customer acquisition.
-- ============================================================

WITH first_observation AS (
    SELECT
        user_pseudo_id,
        MIN(session_date) AS first_observed_date
    FROM `turing-emitter-510722-h2.analytics.session_base`
    GROUP BY user_pseudo_id
),

later_activity AS (
    SELECT
        f.user_pseudo_id,
        f.first_observed_date,
        s.session_date,

        DATE_DIFF(
            s.session_date,
            f.first_observed_date,
            DAY
        ) AS days_since_first_observation

    FROM first_observation AS f

    INNER JOIN `turing-emitter-510722-h2.analytics.session_base` AS s
        USING (user_pseudo_id)

    WHERE s.session_date > f.first_observed_date
),

customer_returns AS (
    SELECT
        f.user_pseudo_id,
        f.first_observed_date,

        MAX(
            IF(
                a.days_since_first_observation BETWEEN 1 AND 7,
                1,
                0
            )
        ) AS returned_within_7_days,

        MAX(
            IF(
                a.days_since_first_observation BETWEEN 1 AND 14,
                1,
                0
            )
        ) AS returned_within_14_days,

        MAX(
            IF(
                a.days_since_first_observation BETWEEN 1 AND 30,
                1,
                0
            )
        ) AS returned_within_30_days

    FROM first_observation AS f

    LEFT JOIN later_activity AS a
        USING (user_pseudo_id, first_observed_date)

    GROUP BY
        f.user_pseudo_id,
        f.first_observed_date
),

dataset_boundary AS (
    SELECT
        MAX(session_date) AS dataset_end_date
    FROM `turing-emitter-510722-h2.analytics.session_base`
),

retention_windows AS (

    SELECT
        '7 Day' AS retention_window,
        1 AS window_order,

        COUNTIF(
            first_observed_date <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
        ) AS eligible_customers,

        COUNTIF(
            first_observed_date <= DATE_SUB(dataset_end_date, INTERVAL 7 DAY)
            AND returned_within_7_days = 1
        ) AS retained_customers

    FROM customer_returns
    CROSS JOIN dataset_boundary

    UNION ALL

    SELECT
        '14 Day',
        2,

        COUNTIF(
            first_observed_date <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
        ),

        COUNTIF(
            first_observed_date <= DATE_SUB(dataset_end_date, INTERVAL 14 DAY)
            AND returned_within_14_days = 1
        )

    FROM customer_returns
    CROSS JOIN dataset_boundary

    UNION ALL

    SELECT
        '30 Day',
        3,

        COUNTIF(
            first_observed_date <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
        ),

        COUNTIF(
            first_observed_date <= DATE_SUB(dataset_end_date, INTERVAL 30 DAY)
            AND returned_within_30_days = 1
        )

    FROM customer_returns
    CROSS JOIN dataset_boundary
)

SELECT
    retention_window,
    eligible_customers,
    retained_customers,

    SAFE_DIVIDE(
        retained_customers,
        eligible_customers
    ) AS retention_rate

FROM retention_windows

ORDER BY window_order;