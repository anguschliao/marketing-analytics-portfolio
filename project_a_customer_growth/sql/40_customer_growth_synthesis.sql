-- ============================================================
-- Project A: Customer & Growth Analytics
-- Executive Customer & Growth Synthesis
--
-- Read-only synthesis of analytics.session_base.
-- Output is tidy: one numeric metric per labeled section/segment.
-- Rates and shares are proportions (0 to 1), with no rounding.
-- Revenue retains the source table's recorded values.
-- Customer and channel shares use full-dataset totals, including
-- sessions outside the displayed customer types or top 10 channels.
-- Channel null labels match 19_channel_performance.sql.
--
-- Measurement limitations:
-- Engagement is not adjusted for the December 29 measurement break.
-- Late-January recorded revenue is not adjusted; interpret cautiously.
-- Funnel stages are independent observed session participation,
-- not guaranteed chronological progression. Relative stage rates
-- can exceed 1. Purchase includes all purchasing sessions.
-- Add to Cart is excluded from the primary business funnel.
-- ============================================================

WITH base AS (
    SELECT
        user_pseudo_id,
        session_date,
        session_number,
        COALESCE(session_source, '(direct)') AS session_source,
        COALESCE(session_medium, '(none)') AS session_medium,
        engaged_session,
        product_views,
        checkout_events,
        payment_events,
        purchase_events,
        revenue
    FROM `turing-emitter-510722-h2.analytics.session_base`
),

periods AS (
    SELECT *
    FROM UNNEST([
        STRUCT(1 AS period_order, 'Early November' AS period,
            DATE '2020-11-01' AS start_date, DATE '2020-11-15' AS end_date),
        STRUCT(2, 'Late November', DATE '2020-11-16', DATE '2020-11-30'),
        STRUCT(3, 'Early/Mid December', DATE '2020-12-01', DATE '2020-12-18'),
        STRUCT(4, 'Holiday Period', DATE '2020-12-19', DATE '2020-12-31'),
        STRUCT(5, 'January', DATE '2021-01-01', DATE '2021-01-25'),
        STRUCT(6, 'Late January Anomaly', DATE '2021-01-26', DATE '2021-01-31')
    ])
),

segmented AS (
    SELECT
        1 AS group_order,
        'OVERALL PERFORMANCE' AS metric_group,
        1 AS segment_order,
        'All Sessions' AS segment,
        CAST(NULL AS STRING) AS channel_source,
        CAST(NULL AS STRING) AS channel_medium,
        b.*
    FROM base AS b

    UNION ALL

    SELECT
        2,
        'CUSTOMER TYPE',
        IF(session_number = 1, 1, 2),
        IF(session_number = 1, 'New', 'Returning'),
        NULL,
        NULL,
        b.*
    FROM base AS b
    WHERE session_number = 1 OR session_number > 1

    UNION ALL

    SELECT
        3,
        'TOP ACQUISITION CHANNELS',
        1,
        CONCAT(session_source, ' / ', session_medium),
        session_source,
        session_medium,
        b.*
    FROM base AS b

    UNION ALL

    SELECT
        4,
        'PERIOD PERFORMANCE',
        p.period_order,
        p.period,
        NULL,
        NULL,
        b.*
    FROM base AS b
    INNER JOIN periods AS p
        ON b.session_date BETWEEN p.start_date AND p.end_date
),

aggregated AS (
    SELECT
        group_order,
        metric_group,
        segment_order,
        segment,
        channel_source,
        channel_medium,
        COUNT(DISTINCT user_pseudo_id) AS users,
        COUNT(*) AS sessions,
        COUNTIF(engaged_session = 1) AS engaged_sessions,
        COUNTIF(product_views > 0) AS product_view_sessions,
        COUNTIF(checkout_events > 0) AS checkout_sessions,
        COUNTIF(payment_events > 0) AS payment_sessions,
        COUNTIF(purchase_events > 0) AS purchasing_sessions,
        SUM(revenue) AS revenue
    FROM segmented
    GROUP BY
        group_order, metric_group, segment_order, segment,
        channel_source, channel_medium
),

totals AS (
    SELECT *
    FROM aggregated
    WHERE group_order = 1
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY group_order
            ORDER BY sessions DESC, channel_source, channel_medium
        ) AS channel_rank
    FROM aggregated
),

performance AS (
    SELECT
        a.group_order,
        a.metric_group,
        IF(a.group_order = 3, a.channel_rank, a.segment_order) AS segment_order,
        a.segment,
        a.channel_source AS session_source,
        a.channel_medium AS session_medium,
        CAST(NULL AS STRING) AS stage,
        m.metric_order,
        m.metric,
        m.value
    FROM ranked AS a
    CROSS JOIN totals AS t
    CROSS JOIN UNNEST([
        STRUCT(1 AS metric_order, 'users' AS metric,
            CAST(a.users AS FLOAT64) AS value, a.group_order = 1 AS include_metric),
        STRUCT(2, 'sessions', CAST(a.sessions AS FLOAT64), TRUE),
        STRUCT(3, IF(a.group_order = 3, 'traffic_share', 'session_share'),
            SAFE_DIVIDE(a.sessions, t.sessions), a.group_order IN (2, 3)),
        STRUCT(4, 'engaged_sessions', CAST(a.engaged_sessions AS FLOAT64), a.group_order = 1),
        STRUCT(5, 'engagement_rate', SAFE_DIVIDE(a.engaged_sessions, a.sessions), TRUE),
        STRUCT(6, 'product_view_sessions', CAST(a.product_view_sessions AS FLOAT64), a.group_order = 1),
        STRUCT(7, 'product_view_rate', SAFE_DIVIDE(a.product_view_sessions, a.sessions), a.group_order IN (2, 3)),
        STRUCT(8, 'checkout_sessions', CAST(a.checkout_sessions AS FLOAT64), a.group_order = 1),
        STRUCT(9, 'checkout_rate', SAFE_DIVIDE(a.checkout_sessions, a.sessions), a.group_order IN (2, 3)),
        STRUCT(10, 'purchasing_sessions', CAST(a.purchasing_sessions AS FLOAT64), TRUE),
        STRUCT(11, 'conversion_rate', SAFE_DIVIDE(a.purchasing_sessions, a.sessions), TRUE),
        STRUCT(12, 'purchase_share', SAFE_DIVIDE(a.purchasing_sessions, t.purchasing_sessions), a.group_order IN (2, 3)),
        STRUCT(13, 'revenue', CAST(a.revenue AS FLOAT64), TRUE),
        STRUCT(14, 'revenue_share', SAFE_DIVIDE(a.revenue, t.revenue), a.group_order IN (2, 3)),
        STRUCT(15, 'revenue_per_session', SAFE_DIVIDE(a.revenue, a.sessions), TRUE),
        STRUCT(16, 'revenue_per_purchasing_session', SAFE_DIVIDE(a.revenue, a.purchasing_sessions), TRUE)
    ]) AS m
    WHERE m.include_metric
        AND (a.group_order != 3 OR a.channel_rank <= 10)
),

funnel AS (
    SELECT
        f.stage_order,
        f.stage,
        f.sessions,
        t.sessions AS total_sessions,
        LAG(f.sessions) OVER (ORDER BY f.stage_order) AS previous_stage_sessions
    FROM totals AS t
    CROSS JOIN UNNEST([
        STRUCT(1 AS stage_order, 'Session' AS stage, t.sessions AS sessions),
        STRUCT(2, 'Product View', t.product_view_sessions),
        STRUCT(3, 'Begin Checkout', t.checkout_sessions),
        STRUCT(4, 'Payment Info', t.payment_sessions),
        STRUCT(5, 'Purchase', t.purchasing_sessions)
    ]) AS f
),

results AS (
    SELECT * FROM performance

    UNION ALL

    SELECT
        5,
        'PRIMARY FUNNEL',
        f.stage_order,
        f.stage,
        NULL,
        NULL,
        f.stage,
        m.metric_order,
        m.metric,
        m.value
    FROM funnel AS f
    CROSS JOIN UNNEST([
        STRUCT(1 AS metric_order, 'sessions' AS metric,
            CAST(f.sessions AS FLOAT64) AS value),
        STRUCT(2, 'overall_session_rate', SAFE_DIVIDE(f.sessions, f.total_sessions)),
        -- The first stage has no previous stage, so its relative rate is NULL.
        STRUCT(3, 'relative_observed_stage_rate', SAFE_DIVIDE(f.sessions, f.previous_stage_sessions))
    ]) AS m
)

SELECT
    metric_group,
    segment,
    session_source,
    session_medium,
    stage,
    metric,
    value
FROM results
ORDER BY group_order, segment_order, metric_order;
