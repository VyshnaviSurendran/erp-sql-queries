WITH designation_rates (
    designation_code, designation_name, section,
    regalia_rate_pct, illuminati_rate_pct, swayamvara_rate_per_gram, gold_gram_rate_pct,
    swayamvara_advance_types, regalia_condition
) AS (
    VALUES
        ('SAE', 'Sales Executives',                'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHH', 'Floor Hostess',                    'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Scheme CRE',                       'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CAS', 'Cashiers',                          'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Accountants',                       'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('DRI', 'Drivers',                            'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHA', 'Shop Assistants',                    'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Pantry / Maintenance / Cleaning',    'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Regal Care',                         'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CRB', 'Care RBA',                           'SPECIAL', 0.20, 0.20, 20,   0.01, ARRAY['SY6', 'SY10'], 'SAME_MONTH'),
        (NULL,  'Direct Calling CRE',                 'SPECIAL', 0.05, 0.05, 20,   0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('AMM', 'Asst Marketing Manager',             'MARKETING', 0.07, 0.07, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('ZOE', 'Zonal Manager',                       'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Marketing CRE',                       'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('RBA', 'RBA',                                 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Marketing Swayamvara CRE',            'MARKETING', 0.05, 0.05, 20,   0.01, ARRAY['SY6', 'SY10'], 'GATED_90D')
),
target_employee AS (
    SELECT
        e.id AS employee_id,
        au.id AS app_user_id,
        au.user_code,
        CONCAT(au.first_name, ' ', au.last_name) AS employee_name,
        d.designation_name,
        d.designation_code,
        b.branch_name,
        a.state_code,
        dr.section,
        dr.regalia_rate_pct,
        dr.illuminati_rate_pct,
        dr.swayamvara_rate_per_gram,
        dr.gold_gram_rate_pct,
        dr.swayamvara_advance_types,
        dr.regalia_condition
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud
        ON ud.user_id = au.id
        AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    LEFT JOIN designation_rates dr
        ON (dr.designation_code IS NOT NULL AND dr.designation_code = d.designation_code)
        OR (dr.designation_code IS NULL AND dr.designation_name = d.designation_name)
    JOIN user_branch ub
        ON ub.user_id = au.id
        AND ub.end_time = '2100-01-01 00:00:00+00'
    JOIN branch b ON b.id = ub.branch_id
    JOIN address a ON a.id = b.address_id
    WHERE au.user_code = 'EMP0001'   -- <-- edit: target user_code
)
-- 0. Employee resolution: confirms the employee exists, is in KL, and matched
--    a designation_rates row (regalia_rate_pct etc. NULL/no row => won't
--    appear in the main report at all).
SELECT * FROM target_employee;

-- 1. Regalia detail: every REG plan referred by this employee, evaluated
--    against whichever condition (GATED_90D vs SAME_MONTH) their designation uses.
WITH designation_rates (
    designation_code, designation_name, section,
    regalia_rate_pct, illuminati_rate_pct, swayamvara_rate_per_gram, gold_gram_rate_pct,
    swayamvara_advance_types, regalia_condition
) AS (
    VALUES
        ('SAE', 'Sales Executives', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHH', 'Floor Hostess', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Scheme CRE', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CAS', 'Cashiers', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Accountants', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('DRI', 'Drivers', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHA', 'Shop Assistants', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Pantry / Maintenance / Cleaning', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Regal Care', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CRB', 'Care RBA', 'SPECIAL', 0.20, 0.20, 20, 0.01, ARRAY['SY6', 'SY10'], 'SAME_MONTH'),
        (NULL, 'Direct Calling CRE', 'SPECIAL', 0.05, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('AMM', 'Asst Marketing Manager', 'MARKETING', 0.07, 0.07, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('ZOE', 'Zonal Manager', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Marketing CRE', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('RBA', 'RBA', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Marketing Swayamvara CRE', 'MARKETING', 0.05, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D')
),
target_employee AS (
    SELECT e.id AS employee_id, au.user_code, dr.regalia_rate_pct, dr.regalia_condition
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    LEFT JOIN designation_rates dr
        ON (dr.designation_code IS NOT NULL AND dr.designation_code = d.designation_code)
        OR (dr.designation_code IS NULL AND dr.designation_name = d.designation_name)
    WHERE au.user_code = 'EMP0001'   -- <-- edit: target user_code
)
SELECT
    cp.id AS customer_plan_id,
    cp.joined_at AS plan_joined_at,
    cps.status AS current_plan_status,
    pr.amount AS term_amount,
    te.regalia_rate_pct,
    te.regalia_condition,
    ROUND(pr.amount * te.regalia_rate_pct, 2) AS incentive_if_all_conditions_met,
    paid.qualifying_payment_count,
    -- GATED_90D path: needs >=2 payments after 90 days AND plan currently ACTIVE
    (te.regalia_condition = 'GATED_90D'
        AND COALESCE(paid.qualifying_payment_count, 0) >= 2
        AND cps.status = 'ACTIVE') AS meets_gated_90d_condition,
    -- SAME_MONTH path: no gate at all (Care RBA)
    (te.regalia_condition = 'SAME_MONTH') AS meets_same_month_condition,
    CASE te.regalia_condition
        WHEN 'GATED_90D' THEN (cp.joined_at + INTERVAL '90 days' >= '2026-08-01'
                                AND cp.joined_at + INTERVAL '90 days' < '2026-09-01')   -- <-- edit period
        WHEN 'SAME_MONTH' THEN (cp.joined_at >= '2026-08-01'
                                 AND cp.joined_at < '2026-09-01')                        -- <-- edit period
    END AS falls_in_report_period,
    CASE te.regalia_condition
        WHEN 'GATED_90D' THEN
            (COALESCE(paid.qualifying_payment_count, 0) >= 2
             AND cps.status = 'ACTIVE'
             AND cp.joined_at + INTERVAL '90 days' >= '2026-08-01'                       -- <-- edit period
             AND cp.joined_at + INTERVAL '90 days' < '2026-09-01')                       -- <-- edit period
        WHEN 'SAME_MONTH' THEN
            (cp.joined_at >= '2026-08-01' AND cp.joined_at < '2026-09-01')               -- <-- edit period
    END AS counted_in_main_report
FROM customer_plan cp
JOIN employee emp ON emp.user_id = cp.referral_user_id
JOIN target_employee te ON te.employee_id = emp.id
LEFT JOIN LATERAL (
    SELECT pr2.amount
    FROM plan_regalia pr2
    WHERE pr2.customer_plan_id = cp.id
    ORDER BY pr2.created_at DESC
    LIMIT 1
) pr ON TRUE
LEFT JOIN customer_plan_status cps
    ON cps.customer_plan_id = cp.id
    AND cps.end_time = '2100-01-01 00:00:00+00'
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS qualifying_payment_count
    FROM plan_installment_regalia pir
    WHERE pir.customer_plan_id = cp.id
      AND pir.status = 'PAID'
      AND pir.paid_at >= cp.joined_at + INTERVAL '90 days'
) paid ON TRUE
WHERE cp.type = 'REG'
ORDER BY cp.joined_at;

-- 2. Illuminati (Akshayanidhi) detail: same shape as Regalia above.
WITH designation_rates (
    designation_code, designation_name, section,
    regalia_rate_pct, illuminati_rate_pct, swayamvara_rate_per_gram, gold_gram_rate_pct,
    swayamvara_advance_types, regalia_condition
) AS (
    VALUES
        ('SAE', 'Sales Executives', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHH', 'Floor Hostess', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Scheme CRE', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CAS', 'Cashiers', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Accountants', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('DRI', 'Drivers', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHA', 'Shop Assistants', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Pantry / Maintenance / Cleaning', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Regal Care', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CRB', 'Care RBA', 'SPECIAL', 0.20, 0.20, 20, 0.01, ARRAY['SY6', 'SY10'], 'SAME_MONTH'),
        (NULL, 'Direct Calling CRE', 'SPECIAL', 0.05, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('AMM', 'Asst Marketing Manager', 'MARKETING', 0.07, 0.07, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('ZOE', 'Zonal Manager', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Marketing CRE', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('RBA', 'RBA', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Marketing Swayamvara CRE', 'MARKETING', 0.05, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D')
),
target_employee AS (
    SELECT e.id AS employee_id, au.user_code, dr.illuminati_rate_pct, dr.regalia_condition
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    LEFT JOIN designation_rates dr
        ON (dr.designation_code IS NOT NULL AND dr.designation_code = d.designation_code)
        OR (dr.designation_code IS NULL AND dr.designation_name = d.designation_name)
    WHERE au.user_code = 'EMP0001'   -- <-- edit: target user_code
)
SELECT
    cp.id AS customer_plan_id,
    cp.joined_at AS plan_joined_at,
    cps.status AS current_plan_status,
    pi.amount AS term_amount,
    te.illuminati_rate_pct,
    te.regalia_condition,
    ROUND(pi.amount * te.illuminati_rate_pct, 2) AS incentive_if_all_conditions_met,
    paid.qualifying_payment_count,
    (te.regalia_condition = 'GATED_90D'
        AND COALESCE(paid.qualifying_payment_count, 0) >= 2
        AND cps.status = 'ACTIVE') AS meets_gated_90d_condition,
    (te.regalia_condition = 'SAME_MONTH') AS meets_same_month_condition,
    CASE te.regalia_condition
        WHEN 'GATED_90D' THEN (cp.joined_at + INTERVAL '90 days' >= '2026-08-01'
                                AND cp.joined_at + INTERVAL '90 days' < '2026-09-01')   -- <-- edit period
        WHEN 'SAME_MONTH' THEN (cp.joined_at >= '2026-08-01'
                                 AND cp.joined_at < '2026-09-01')                        -- <-- edit period
    END AS falls_in_report_period,
    CASE te.regalia_condition
        WHEN 'GATED_90D' THEN
            (COALESCE(paid.qualifying_payment_count, 0) >= 2
             AND cps.status = 'ACTIVE'
             AND cp.joined_at + INTERVAL '90 days' >= '2026-08-01'                       -- <-- edit period
             AND cp.joined_at + INTERVAL '90 days' < '2026-09-01')                       -- <-- edit period
        WHEN 'SAME_MONTH' THEN
            (cp.joined_at >= '2026-08-01' AND cp.joined_at < '2026-09-01')               -- <-- edit period
    END AS counted_in_main_report
FROM customer_plan cp
JOIN employee emp ON emp.user_id = cp.referral_user_id
JOIN target_employee te ON te.employee_id = emp.id
LEFT JOIN LATERAL (
    SELECT pi2.amount
    FROM plan_illuminati pi2
    WHERE pi2.customer_plan_id = cp.id
    ORDER BY pi2.created_at DESC
    LIMIT 1
) pi ON TRUE
LEFT JOIN customer_plan_status cps
    ON cps.customer_plan_id = cp.id
    AND cps.end_time = '2100-01-01 00:00:00+00'
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS qualifying_payment_count
    FROM plan_installment_illuminati pii
    WHERE pii.customer_plan_id = cp.id
      AND pii.status = 'PAID'
      AND pii.paid_at >= cp.joined_at + INTERVAL '90 days'
) paid ON TRUE
WHERE cp.type = 'ILL'
ORDER BY cp.joined_at;

-- 3. Swayamvara detail: every advance for this employee. Note Kerala's
--    swayamvara_agg matches on ee.app_user_id = ca.reference_user_id, NOT
--    sales_person_employee_id -- preserved here to match the real join key.
WITH designation_rates (
    designation_code, designation_name, section,
    regalia_rate_pct, illuminati_rate_pct, swayamvara_rate_per_gram, gold_gram_rate_pct,
    swayamvara_advance_types, regalia_condition
) AS (
    VALUES
        ('SAE', 'Sales Executives', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHH', 'Floor Hostess', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Scheme CRE', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CAS', 'Cashiers', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Accountants', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('DRI', 'Drivers', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHA', 'Shop Assistants', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Pantry / Maintenance / Cleaning', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Regal Care', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CRB', 'Care RBA', 'SPECIAL', 0.20, 0.20, 20, 0.01, ARRAY['SY6', 'SY10'], 'SAME_MONTH'),
        (NULL, 'Direct Calling CRE', 'SPECIAL', 0.05, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('AMM', 'Asst Marketing Manager', 'MARKETING', 0.07, 0.07, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('ZOE', 'Zonal Manager', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Marketing CRE', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('RBA', 'RBA', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Marketing Swayamvara CRE', 'MARKETING', 0.05, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D')
),
target_employee AS (
    SELECT au.id AS app_user_id, au.user_code, dr.swayamvara_rate_per_gram, dr.swayamvara_advance_types
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    LEFT JOIN designation_rates dr
        ON (dr.designation_code IS NOT NULL AND dr.designation_code = d.designation_code)
        OR (dr.designation_code IS NULL AND dr.designation_name = d.designation_name)
    WHERE au.user_code = 'EMP0001'   -- <-- edit: target user_code
)
SELECT
    ca.id AS customer_advance_id,
    ca.advance_type,
    ca.joined_at AS advance_joined_at,
    te.swayamvara_advance_types AS designation_matches_types,
    (ca.advance_type::text = ANY(te.swayamvara_advance_types)) AS advance_type_is_credited,
    SUM(cai.weight) AS weight_total_gm,
    te.swayamvara_rate_per_gram,
    ROUND(SUM(cai.weight) * te.swayamvara_rate_per_gram, 2) AS incentive_if_credited,
    (ca.joined_at >= '2026-08-01' AND ca.joined_at < '2026-09-01') AS falls_in_report_period   -- <-- edit period
FROM customer_advance ca
JOIN customer_advance_installment cai ON cai.customer_advance_id = ca.id
JOIN target_employee te ON te.app_user_id = ca.reference_user_id
GROUP BY ca.id, ca.advance_type, ca.joined_at, te.swayamvara_advance_types, te.swayamvara_rate_per_gram
ORDER BY ca.joined_at;

-- 4. Gold Gram detail: every ING advance. Kerala's gold_gram_plans CTE joins
--    on ee.app_user_id = ca.reference_user_id (same as Swayamvara), requires
--    cas.status = 'ACTIVE', and periods on "the month the scheme turns 6
--    months old" falling in range -- there's no separate ca.joined_at-in-
--    period filter like Karnataka has.
WITH designation_rates (
    designation_code, designation_name, section,
    regalia_rate_pct, illuminati_rate_pct, swayamvara_rate_per_gram, gold_gram_rate_pct,
    swayamvara_advance_types, regalia_condition
) AS (
    VALUES
        ('SAE', 'Sales Executives', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHH', 'Floor Hostess', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Scheme CRE', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CAS', 'Cashiers', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Accountants', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('DRI', 'Drivers', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHA', 'Shop Assistants', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Pantry / Maintenance / Cleaning', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Regal Care', 'STORE', 0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('CRB', 'Care RBA', 'SPECIAL', 0.20, 0.20, 20, 0.01, ARRAY['SY6', 'SY10'], 'SAME_MONTH'),
        (NULL, 'Direct Calling CRE', 'SPECIAL', 0.05, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('AMM', 'Asst Marketing Manager', 'MARKETING', 0.07, 0.07, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('ZOE', 'Zonal Manager', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Marketing CRE', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('RBA', 'RBA', 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL, 'Marketing Swayamvara CRE', 'MARKETING', 0.05, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D')
),
target_employee AS (
    SELECT au.id AS app_user_id, au.user_code, dr.gold_gram_rate_pct
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    LEFT JOIN designation_rates dr
        ON (dr.designation_code IS NOT NULL AND dr.designation_code = d.designation_code)
        OR (dr.designation_code IS NULL AND dr.designation_name = d.designation_name)
    WHERE au.user_code = 'EMP0001'   -- <-- edit: target user_code
)
SELECT
    ca.id AS customer_advance_id,
    ca.joined_at AS advance_joined_at,
    cas.status AS current_advance_status,
    (cas.status = 'ACTIVE') AS is_currently_active,
    (
        SELECT COALESCE(SUM(cai.amount), 0)
        FROM customer_advance_installment cai
        WHERE cai.customer_advance_id = ca.id
          AND cai.created_at >= ca.joined_at
          AND cai.created_at < ca.joined_at + INTERVAL '3 months'
    ) AS first_3mo_payments,
    te.gold_gram_rate_pct,
    ROUND((
        SELECT COALESCE(SUM(cai.amount), 0)
        FROM customer_advance_installment cai
        WHERE cai.customer_advance_id = ca.id
          AND cai.created_at >= ca.joined_at
          AND cai.created_at < ca.joined_at + INTERVAL '3 months'
    ) * te.gold_gram_rate_pct, 2) AS incentive_if_all_conditions_met,
    (ca.joined_at + INTERVAL '6 months' >= '2026-08-01'
     AND ca.joined_at + INTERVAL '6 months' < '2026-09-01') AS falls_in_report_period   -- <-- edit period
FROM customer_advance ca
LEFT JOIN customer_advance_status cas
    ON cas.customer_advance_id = ca.id
    AND cas.end_time = '2100-01-01 00:00:00+00'
JOIN target_employee te ON te.app_user_id = ca.reference_user_id
WHERE ca.advance_type = 'ING'
ORDER BY ca.joined_at;
