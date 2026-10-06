-- ============================================================
-- Project A: Customer & Growth Analytics
-- Session Number QA
--
-- Purpose:
-- Validate GA4 session_number before using it to classify
-- sessions as new vs returning.
-- ============================================================

SELECT
    COUNT(*) AS total_sessions,

    COUNTIF(session_number IS NULL) AS null_session_number,

    COUNTIF(session_number = 1) AS first_sessions,

    COUNTIF(session_number > 1) AS returning_sessions,

    COUNTIF(session_number <= 0) AS invalid_session_number,

    MIN(session_number) AS min_session_number,
    MAX(session_number) AS max_session_number

FROM
    `turing-emitter-510722-h2.analytics.session_base`;