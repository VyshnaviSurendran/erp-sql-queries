WITH period (period_start, period_end) AS (
    VALUES ('2026-08-01'::timestamptz, '2026-09-01'::timestamptz)
),
designation_rates (designation_code, designation_name, regalia_rate_pct, illuminati_rate_pct) AS (
    VALUES
        ('SAE', 'Sales Executives', 0.10, 0.05),
        ('SHH', 'Floor Hostess', 0.10, 0.05),
        (NULL, 'Scheme CRE', 0.10, 0.05),
        ('CAS', 'Cashiers', 0.10, 0.05),
        (NULL, 'Accountants', 0.10, 0.05),
        ('DRI', 'Drivers', 0.10, 0.05),
        ('SHA', 'Shop Assistants', 0.10, 0.05),
        (NULL, 'Pantry / Maintenance / Cleaning', 0.10, 0.05),
        (NULL, 'Regal Care', 0.10, 0.05),
        ('CRB', 'Care RBA', 0.20, 0.20),
        (NULL, 'Direct Calling CRE', 0.05, 0.05)
),
employee_rate AS (
    SELECT dr.regalia_rate_pct, dr.illuminati_rate_pct
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud
        ON ud.user_id = au.id
       AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    JOIN designation_rates dr
        ON (dr.designation_code IS NOT NULL
            AND dr.designation_code = d.designation_code)
        OR (dr.designation_code IS NULL
            AND dr.designation_name = d.designation_name)
    WHERE au.id = 3120
),
report AS (
    SELECT
        cp.id AS customer_plan_id,
        cp.customer_plan_code,
        cp.type AS plan_type,
        cp.joined_at,
        cp.joined_at + INTERVAL '90 days' AS ninety_day_mark,
        cps.status AS current_status,
        term.term_amount,

        COALESCE(
            pay_reg.paid_after_90d_count,
            pay_ill.paid_after_90d_count,
            0
        ) AS paid_after_90d_count,

        (
            cp.joined_at + INTERVAL '90 days' >= p.period_start
            AND cp.joined_at + INTERVAL '90 days' < p.period_end
            AND COALESCE(
                pay_reg.paid_after_90d_count,
                pay_ill.paid_after_90d_count,
                0
            ) >= 2
            AND cps.status = 'ACTIVE'
        ) AS qualifies,

        CASE cp.type
            WHEN 'REG' THEN er.regalia_rate_pct
            ELSE er.illuminati_rate_pct
        END AS rate_pct,

        CASE
            WHEN (
                cp.joined_at + INTERVAL '90 days' >= p.period_start
                AND cp.joined_at + INTERVAL '90 days' < p.period_end
                AND COALESCE(
                    pay_reg.paid_after_90d_count,
                    pay_ill.paid_after_90d_count,
                    0
                ) >= 2
                AND cps.status = 'ACTIVE'
            )
            THEN ROUND(
                term.term_amount *
                CASE cp.type
                    WHEN 'REG' THEN er.regalia_rate_pct
                    ELSE er.illuminati_rate_pct
                END,
                2
            )
            ELSE 0
        END AS incentive_amount

    FROM customer_plan cp
    CROSS JOIN period p
    CROSS JOIN employee_rate er

    JOIN customer_plan_status cps
        ON cps.customer_plan_id = cp.id
       AND cps.end_time = '2100-01-01 00:00:00+00'

    JOIN LATERAL (
        (
            SELECT amount
            FROM plan_regalia
            WHERE customer_plan_id = cp.id
              AND cp.type = 'REG'
            ORDER BY created_at DESC
            LIMIT 1
        )
        UNION ALL
        (
            SELECT amount
            FROM plan_illuminati
            WHERE customer_plan_id = cp.id
              AND cp.type = 'ILL'
            ORDER BY created_at DESC
            LIMIT 1
        )
    ) term(term_amount) ON TRUE

    LEFT JOIN LATERAL (
        SELECT COUNT(*) FILTER (
            WHERE paid_at >= cp.joined_at + INTERVAL '90 days'
        ) AS paid_after_90d_count
        FROM plan_installment_regalia
        WHERE customer_plan_id = cp.id
          AND status = 'PAID'
    ) pay_reg ON cp.type = 'REG'

    LEFT JOIN LATERAL (
        SELECT COUNT(*) FILTER (
            WHERE paid_at >= cp.joined_at + INTERVAL '90 days'
        ) AS paid_after_90d_count
        FROM plan_installment_illuminati
        WHERE customer_plan_id = cp.id
          AND status = 'PAID'
    ) pay_ill ON cp.type = 'ILL'

    WHERE cp.referral_user_id = 629
      AND cp.type IN ('REG', 'ILL')
)

SELECT *
FROM report
WHERE qualifies = true
ORDER BY ninety_day_mark;