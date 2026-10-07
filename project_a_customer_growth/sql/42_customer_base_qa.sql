-- ============================================================
-- Project A: Customer & Growth Analytics
-- Customer Base QA
--
-- Purpose:
-- Validate customer_base logic against the canonical
-- session-level analytical layer before materialization.
-- ============================================================

WITH customer_base AS (
    SELECT *
    FROM (
        -- Reuse the customer-base query directly so QA can run
        -- before analytics.customer_base is materialized.
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
                COUNT(DISTINCT DATE_TRUNC(session_date, MONTH)) AS distinct_active_months,
                COUNT(
                    DISTINCT IF(
                        purchase_events > 0,
                        session_date,
                        NULL
                    )
                ) AS purchase_active_days
            FROM session_data
            GROUP BY user_pseudo_id
        )

        SELECT
            d.user_pseudo_id,
            d.first_observed_date,
            d.last_observed_date,
            m.total_sessions,
            m.engaged_sessions,
            m.product_view_sessions,
            m.checkout_sessions,
            m.purchasing_sessions,
            m.total_purchase_events,
            m.total_revenue,
            m.distinct_active_days,
            m.distinct_active_months,
            m.purchase_active_days,

            IF(m.total_sessions > 1, 1, 0)
                AS returned_after_first_session,

            IF(d.last_observed_date > d.first_observed_date, 1, 0)
                AS returned_on_later_day,

            IF(m.purchase_active_days >= 2, 1, 0)
                AS repeat_purchaser,

            d.first_purchase_date,
            d.last_purchase_date

        FROM customer_dates AS d

        INNER JOIN customer_metrics AS m
            USING (user_pseudo_id)
    )
),

session_totals AS (
    SELECT
        COUNT(DISTINCT user_pseudo_id) AS users,
        COUNT(*) AS sessions,
        COUNTIF(engaged_session = 1) AS engaged_sessions,
        COUNTIF(product_views > 0) AS product_view_sessions,
        COUNTIF(checkout_events > 0) AS checkout_sessions,
        COUNTIF(purchase_events > 0) AS purchasing_sessions,
        SUM(purchase_events) AS purchase_events,
        SUM(revenue) AS revenue
    FROM `turing-emitter-510722-h2.analytics.session_base`
),

customer_totals AS (
    SELECT
        COUNT(*) AS users,
        SUM(total_sessions) AS sessions,
        SUM(engaged_sessions) AS engaged_sessions,
        SUM(product_view_sessions) AS product_view_sessions,
        SUM(checkout_sessions) AS checkout_sessions,
        SUM(purchasing_sessions) AS purchasing_sessions,
        SUM(total_purchase_events) AS purchase_events,
        SUM(total_revenue) AS revenue
    FROM customer_base
),

behavior_qa AS (
    SELECT
        COUNTIF(total_sessions < 1) AS customers_without_sessions,

        COUNTIF(
            returned_after_first_session = 1
            AND total_sessions <= 1
        ) AS invalid_return_flags,

        COUNTIF(
            returned_on_later_day = 1
            AND last_observed_date <= first_observed_date
        ) AS invalid_later_day_flags,

        COUNTIF(
            repeat_purchaser = 1
            AND purchase_active_days < 2
        ) AS invalid_repeat_purchaser_flags,

        COUNTIF(
            purchasing_sessions = 0
            AND first_purchase_date IS NOT NULL
        ) AS purchase_date_without_purchase,

        COUNTIF(
            purchasing_sessions > 0
            AND first_purchase_date IS NULL
        ) AS purchase_without_first_purchase_date,

        COUNTIF(
            first_purchase_date < first_observed_date
        ) AS purchase_before_first_observation,

        COUNTIF(
            last_purchase_date > last_observed_date
        ) AS purchase_after_last_observation

    FROM customer_base
)

SELECT
    s.users AS session_base_users,
    c.users AS customer_base_users,
    c.users - s.users AS user_diff,

    s.sessions AS session_base_sessions,
    c.sessions AS customer_base_sessions,
    c.sessions - s.sessions AS session_diff,

    c.engaged_sessions - s.engaged_sessions
        AS engaged_session_diff,

    c.product_view_sessions - s.product_view_sessions
        AS product_view_session_diff,

    c.checkout_sessions - s.checkout_sessions
        AS checkout_session_diff,

    c.purchasing_sessions - s.purchasing_sessions
        AS purchasing_session_diff,

    c.purchase_events - s.purchase_events
        AS purchase_event_diff,

    c.revenue - s.revenue
        AS revenue_diff,

    b.customers_without_sessions,
    b.invalid_return_flags,
    b.invalid_later_day_flags,
    b.invalid_repeat_purchaser_flags,
    b.purchase_date_without_purchase,
    b.purchase_without_first_purchase_date,
    b.purchase_before_first_observation,
    b.purchase_after_last_observation

FROM session_totals AS s
CROSS JOIN customer_totals AS c
CROSS JOIN behavior_qa AS b;