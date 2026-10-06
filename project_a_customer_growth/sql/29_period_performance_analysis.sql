-- Project A: Customer & Growth Analytics
-- Period performance analysis
--
-- Purpose:
-- Summarize major business periods identified in the daily trend
-- to quantify changes in traffic, engagement, conversion, and monetization.

WITH periods AS (
    SELECT
        CASE
            WHEN date BETWEEN '2020-11-01' AND '2020-11-15'
                THEN '1 - Early November'
            WHEN date BETWEEN '2020-11-16' AND '2020-11-30'
                THEN '2 - Late November'
            WHEN date BETWEEN '2020-12-01' AND '2020-12-18'
                THEN '3 - Early/Mid December'
            WHEN date BETWEEN '2020-12-19' AND '2021-01-03'
                THEN '4 - Holiday Period'
            WHEN date BETWEEN '2021-01-04' AND '2021-01-25'
                THEN '5 - January'
            WHEN date BETWEEN '2021-01-26' AND '2021-01-31'
                THEN '6 - Late January Anomaly'
        END AS period,

        users,
        sessions,
        engaged_sessions,
        purchasing_sessions,
        revenue

    FROM `turing-emitter-510722-h2.analytics.daily_kpis`
)

SELECT
    period,

    SUM(users) AS users,
    SUM(sessions) AS sessions,
    SUM(engaged_sessions) AS engaged_sessions,
    SUM(purchasing_sessions) AS purchasing_sessions,
    SUM(revenue) AS revenue,

    SAFE_DIVIDE(
        SUM(engaged_sessions),
        SUM(sessions)
    ) AS engagement_rate,

    SAFE_DIVIDE(
        SUM(purchasing_sessions),
        SUM(sessions)
    ) AS conversion_rate,

    SAFE_DIVIDE(
        SUM(revenue),
        SUM(sessions)
    ) AS revenue_per_session,

    SAFE_DIVIDE(
        SUM(revenue),
        SUM(purchasing_sessions)
    ) AS revenue_per_purchase

FROM periods

GROUP BY period
ORDER BY period;