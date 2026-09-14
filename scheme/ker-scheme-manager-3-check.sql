WITH period (period_start, period_end) AS (
    VALUES ('2026-08-01'::timestamptz, '2026-09-01'::timestamptz)   -- edit this line to change the month being checked
)
SELECT
    ca.id                              AS customer_advance_id,
    ca.customer_advance_code,
    ca.advance_type,
    ca.joined_at,
    ca.joined_at + INTERVAL '6 months' AS six_month_mark,
    cas.status                         AS current_status,
    (
        SELECT COALESCE(SUM(cai.amount), 0)
        FROM customer_advance_installment cai
        WHERE cai.customer_advance_id = ca.id
          AND cai.created_at >= ca.joined_at
          AND cai.created_at < ca.joined_at + INTERVAL '3 months'
    )                                   AS first_3mo_payments,
    (
        cas.status = 'ACTIVE'
        AND ca.joined_at + INTERVAL '6 months' >= p.period_start
        AND ca.joined_at + INTERVAL '6 months' <  p.period_end
    )                                   AS qualifies,
    CASE WHEN cas.status = 'ACTIVE'
        AND ca.joined_at + INTERVAL '6 months' >= p.period_start
        AND ca.joined_at + INTERVAL '6 months' <  p.period_end
    THEN ROUND(
        (SELECT COALESCE(SUM(cai.amount), 0)
         FROM customer_advance_installment cai
         WHERE cai.customer_advance_id = ca.id
           AND cai.created_at >= ca.joined_at
           AND cai.created_at < ca.joined_at + INTERVAL '3 months'
        ) * 0.0025, 2)
    ELSE 0
    END                                 AS incentive_amount
FROM customer_advance ca
CROSS JOIN period p
LEFT JOIN customer_advance_status cas
    ON cas.customer_advance_id = ca.id AND cas.end_time = '2100-01-01 00:00:00+00'
WHERE ca.reference_user_id = 46   -- swap in the Marketing Manager's app_user id
  AND ca.advance_type = 'ING'
ORDER BY ca.joined_at;
