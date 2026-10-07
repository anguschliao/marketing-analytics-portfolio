-- ============================================================
-- Project A: Customer & Growth Analytics
-- Customer-Level Analytical Base
--
-- Purpose:
-- Create one row per observed GA4 user for retention, cohort,
-- repeat-purchase, and customer-value analysis.
--
-- Important:
-- This dataset covers only November 1, 2020 through
-- January 31, 2021. First/last observed dates describe activity
-- within this observation window and should not be interpreted
-- as true customer acquisition or lifetime dates.
--
-- Revenue represents observed-window revenue, not CLV.
-- ============================================================

WITH session_data AS (
    SELECT
        user_pseudo_id,
        ga_session_id,
        session_date,
        session_start_timestamp,
        engaged_session,
        product_views,
        checkout_events,
        purchase_events,
        revenue,
        session_source,
        session_medium
    FROM `turing-emitter-510722-h2.analytics.session_base`
),

customer_dates AS (
    SELECT
        user_pseudo_id,
        MIN(session_date) AS first_observed_date,
        MAX(session_date) AS last_observed_date,
        MIN(IF(purchase_events > 0, session_date, NULL)) AS first_purchase_date,
        MAX(IF(purchase_events > 0, session_date, NULL)) AS last_purchase_date
    FROM session_data
    GROUP BY user_pseudo_id
),

customer_metrics AS (
    SELECT
        user_pseudo_id,

        COUNT(*) AS total_sessions,
        COUNTIF(engaged_session = 1) AS engaged_sessions,
        COUNTIF(product_views > 0) AS product_view_sessions,
        COUNTIF(checkout_events > 0) AS checkout_sessions,
        COUNTIF(purchase_events > 0) AS purchasing_sessions,

        SUM(purchase_events) AS total_purchase_events,

        COALESCE(SUM(revenue), 0) AS total_revenue,

        COUNT(DISTINCT session_date) AS distinct_active_days,

        COUNT(
            DISTINCT DATE_TRUNC(session_date, MONTH)
        ) AS distinct_active_months,

        COUNT(
            DISTINCT IF(
                purchase_events > 0,
                session_date,
                NULL
            )
        ) AS purchase_active_days

    FROM session_data
    GROUP BY user_pseudo_id
),

first_session AS (
    SELECT
        user_pseudo_id,
        session_source AS first_observed_source,
        session_medium AS first_observed_medium
    FROM session_data
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY user_pseudo_id
        ORDER BY
            session_start_timestamp,
            ga_session_id
    ) = 1
)

SELECT
    d.user_pseudo_id,

    -- Observation window
    d.first_observed_date,
    d.last_observed_date,

    DATE_DIFF(
        d.last_observed_date,
        d.first_observed_date,
        DAY
    ) AS observed_lifespan_days,

    DATE_TRUNC(
        d.first_observed_date,
        MONTH
    ) AS first_observed_month,

    DATE_TRUNC(
        d.last_observed_date,
        MONTH
    ) AS last_observed_month,

    -- Session behavior
    m.total_sessions,
    m.engaged_sessions,
    m.product_view_sessions,
    m.checkout_sessions,
    m.purchasing_sessions,
    m.total_purchase_events,
    m.total_revenue,

    -- Return behavior
    m.distinct_active_days,
    m.distinct_active_months,

    IF(
        m.total_sessions > 1,
        1,
        0
    ) AS returned_after_first_session,

    IF(
        d.last_observed_date > d.first_observed_date,
        1,
        0
    ) AS returned_on_later_day,

    -- Purchase behavior
    d.first_purchase_date,
    d.last_purchase_date,
    m.purchase_active_days,

    IF(
        m.purchase_active_days >= 2,
        1,
        0
    ) AS repeat_purchaser,

    IF(
        d.first_purchase_date IS NOT NULL,
        DATE_DIFF(
            d.first_purchase_date,
            d.first_observed_date,
            DAY
        ),
        NULL
    ) AS days_to_first_purchase,

    IF(
        m.purchase_active_days >= 2,
        DATE_DIFF(
            d.last_purchase_date,
            d.first_purchase_date,
            DAY
        ),
        NULL
    ) AS days_between_first_last_purchase,

    -- Observed-window customer value
    SAFE_DIVIDE(
        m.total_revenue,
        m.total_sessions
    ) AS revenue_per_session,

    SAFE_DIVIDE(
        m.total_revenue,
        m.purchasing_sessions
    ) AS revenue_per_purchasing_session,

    -- Acquisition associated with the customer's earliest
    -- observed session in the available dataset.
    f.first_observed_source,
    f.first_observed_medium

FROM customer_dates AS d

INNER JOIN customer_metrics AS m
    USING (user_pseudo_id)

LEFT JOIN first_session AS f
    USING (user_pseudo_id);