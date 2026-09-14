WITH period (period_start, period_end) AS (
    VALUES ('2026-08-01'::timestamptz, '2026-09-01'::timestamptz)   -- edit this one line to change the month being checked
),
designation_rates (designation_code, designation_name, swayamvara_rate_per_gram, gold_gram_rate_pct) AS (
    VALUES
        ('SAE', 'Sales Executives',             20, 0.01),
        ('SHH', 'Floor Hostess',                 20, 0.01),
        (NULL,  'Scheme CRE',                    20, 0.01),
        ('CAS', 'Cashiers',                       20, 0.01),
        (NULL,  'Accountants',                    20, 0.01),
        ('DRI', 'Drivers',                         20, 0.01),
        ('SHA', 'Shop Assistants',                 20, 0.01),
        (NULL,  'Pantry / Maintenance / Cleaning', 20, 0.01),
        (NULL,  'Regal Care',                      20, 0.01),
        ('CRB', 'Care RBA',                        20, 0.01),
        (NULL,  'Direct Calling CRE',              20, 0.01)
),
employee_rate AS (
    SELECT dr.swayamvara_rate_per_gram, dr.gold_gram_rate_pct
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    JOIN designation_rates dr
        ON (dr.designation_code IS NOT NULL AND dr.designation_code = d.designation_code)
        OR (dr.designation_code IS NULL AND dr.designation_name = d.designation_name)
    WHERE au.id = 879
)
SELECT
    ca.id                              AS customer_advance_id,
    ca.customer_advance_code,
    ca.advance_type,
    ca.joined_at,
    cas.status                         AS current_status,
    net.net_weight_gm,
    gg.first_3mo_payments,
    CASE
        WHEN ca.advance_type IN ('SY6', 'SY10') THEN
            (ca.joined_at >= p.period_start AND ca.joined_at < p.period_end)
        WHEN ca.advance_type = 'ING' THEN
            (ca.joined_at >= p.period_start AND ca.joined_at < p.period_end
                AND cas.status = 'ACTIVE'
                AND ca.joined_at <= CURRENT_DATE - INTERVAL '6 months')
    END                                AS qualifies,
    CASE
        WHEN ca.advance_type IN ('SY6', 'SY10') AND (ca.joined_at >= p.period_start AND ca.joined_at < p.period_end)
            THEN ROUND(net.net_weight_gm * er.swayamvara_rate_per_gram, 2)
        WHEN ca.advance_type = 'ING'
            AND (ca.joined_at >= p.period_start AND ca.joined_at < p.period_end
                 AND cas.status = 'ACTIVE'
                 AND ca.joined_at <= CURRENT_DATE - INTERVAL '6 months')
            THEN ROUND(gg.first_3mo_payments * er.gold_gram_rate_pct, 2)
        ELSE 0
    END                                AS incentive_amount
FROM customer_advance ca
CROSS JOIN period p
CROSS JOIN employee_rate er
LEFT JOIN customer_advance_status cas
    ON cas.customer_advance_id = ca.id AND cas.end_time = '2100-01-01 00:00:00+00'
LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(cai.weight), 0) AS net_weight_gm
    FROM customer_advance_installment cai
    WHERE cai.customer_advance_id = ca.id
) net ON TRUE
LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(cai.amount), 0) AS first_3mo_payments
    FROM customer_advance_installment cai
    WHERE cai.customer_advance_id = ca.id
      AND cai.created_at >= ca.joined_at
      AND cai.created_at < ca.joined_at + INTERVAL '3 months'
) gg ON TRUE
WHERE ca.reference_user_id = 629
  AND ca.advance_type IN ('SY6', 'SY10', 'ING')
ORDER BY ca.joined_at;
