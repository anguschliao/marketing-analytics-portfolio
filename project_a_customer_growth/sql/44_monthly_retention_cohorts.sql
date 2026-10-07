-- ============================================================
-- Project A: Customer & Growth Analytics
-- Monthly Customer Retention Cohorts
--
-- Purpose:
-- Measure observed monthly return behavior by customers'
-- first observed month.
--
-- Cohort month represents first observation within the available
-- Nov 2020-Jan 2021 dataset, not true customer acquisition.
--
-- Later cohorts have less follow-up time:
-- November can be observed through Month 2.
-- December can be observed through Month 1.
-- January has no subsequent complete month available.
-- ============================================================

WITH customer_cohorts AS (
    SELECT
        user_pseudo_id,
        MIN(DATE_TRUNC(session_date, MONTH)) AS cohort_month
    FROM `turing-emitter-510722-h2.analytics.session_base`
    GROUP BY user_pseudo_id
),

customer_activity AS (
    SELECT DISTINCT
        user_pseudo_id,
        DATE_TRUNC(session_date, MONTH) AS activity_month
    FROM `turing-emitter-510722-h2.analytics.session_base`
),

cohort_activity AS (
    SELECT
        c.user_pseudo_id,
        c.cohort_month,
        a.activity_month,

        DATE_DIFF(
            a.activity_month,
            c.cohort_month,
            MONTH
        ) AS month_number

    FROM customer_cohorts AS c

    INNER JOIN customer_activity AS a
        USING (user_pseudo_id)

    WHERE a.activity_month >= c.cohort_month
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT user_pseudo_id) AS cohort_customers
    FROM customer_cohorts
    GROUP BY cohort_month
),

retention AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT user_pseudo_id) AS active_customers
    FROM cohort_activity
    GROUP BY
        cohort_month,
        month_number
)

SELECT
    r.cohort_month,
    r.month_number,
    s.cohort_customers,
    r.active_customers,

    SAFE_DIVIDE(
        r.active_customers,
        s.cohort_customers
    ) AS retention_rate

FROM retention AS r

INNER JOIN cohort_sizes AS s
    USING (cohort_month)

ORDER BY
    r.cohort_month,
    r.month_number;