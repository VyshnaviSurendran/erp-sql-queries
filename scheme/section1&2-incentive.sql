WITH designation_rates (
    designation_code, designation_name, section,
    regalia_rate_pct, illuminati_rate_pct, swayamvara_rate_per_gram, gold_gram_rate_pct,
    swayamvara_advance_types, regalia_condition
) AS (
    VALUES
        ('SAE', 'Sales Executives',                'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHH', 'Floor Hostess',                    'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),  -- Floor Hostess -> Showroom Hostess
        (NULL,  'Scheme CRE',                       'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),  -- no designation_code yet, name-matched placeholder
        ('CAS', 'Cashiers',                          'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Accountants',                       'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),  -- no designation_code yet, name-matched placeholder
        ('DRI', 'Drivers',                            'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('SHA', 'Shop Assistants',                    'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Pantry / Maintenance / Cleaning',    'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'), -- no designation_code yet, name-matched placeholder
        (NULL,  'Regal Care',                         'STORE',   0.10, 0.05, 20, 0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'), -- no designation_code yet, name-matched placeholder

        -- Special Roles -- Care RBA & Direct Calling CRE
        ('CRB', 'Care RBA',                           'SPECIAL', 0.20, 0.20, 20,   0.01, ARRAY['SY6', 'SY10'], 'SAME_MONTH'),
        (NULL,  'Direct Calling CRE',                 'SPECIAL', 0.05, 0.05, 20,   0.01, ARRAY['SY6', 'SY10'], 'GATED_90D'), -- no designation_code yet, name-matched placeholder

        -- Section 2 -- Marketing Staff. Swayamvara/Gold Gram are NULL for
        -- the first four roles ("Closing Weight" in the doc, no rate given
        -- -- see header note); Marketing Swayamvara CRE has real rates.
        ('AMM', 'Asst Marketing Manager',             'MARKETING', 0.07, 0.07, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        ('ZOE', 'Zonal Manager',                       'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Marketing CRE',                       'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),  -- no designation_code yet, name-matched placeholder
        ('RBA', 'RBA',                                 'MARKETING', 0.05, 0.05, NULL, NULL, ARRAY['SY6', 'SY10'], 'GATED_90D'),
        (NULL,  'Marketing Swayamvara CRE',            'MARKETING', 0.05, 0.05, 20,   0.01, ARRAY['SY6', 'SY10'], 'GATED_90D')  -- no designation_code yet, name-matched placeholder
),
eligible_employees AS (
    SELECT
        e.id AS employee_id,
        au.id AS app_user_id,
        au.user_code,
        CONCAT(au.first_name, ' ', au.last_name) AS employee_name,
        d.designation_name,
        b.branch_name,
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
    JOIN designation_rates dr
        ON (dr.designation_code IS NOT NULL AND dr.designation_code = d.designation_code)
        OR (dr.designation_code IS NULL AND dr.designation_name = d.designation_name)
    JOIN user_branch ub
        ON ub.user_id = au.id
        AND ub.end_time = '2100-01-01 00:00:00+00'
    JOIN branch b ON b.id = ub.branch_id
    JOIN address a ON a.id = b.address_id
    WHERE a.state_code = 'KL'
),
regalia_agg_gated AS (
    SELECT
        ee.employee_id,
        SUM(pr.amount) AS term_amount_total,
        SUM(ROUND(pr.amount * ee.regalia_rate_pct, 2)) AS incentive_total
    FROM customer_plan cp
    JOIN LATERAL (
        SELECT pr2.amount
        FROM plan_regalia pr2
        WHERE pr2.customer_plan_id = cp.id
        ORDER BY pr2.created_at DESC
        LIMIT 1
    ) pr ON TRUE
    JOIN employee emp ON emp.user_id = cp.referral_user_id
    JOIN eligible_employees ee ON ee.employee_id = emp.id AND ee.regalia_condition = 'GATED_90D'
    JOIN customer_plan_status cps
        ON cps.customer_plan_id = cp.id
        AND cps.end_time = '2100-01-01 00:00:00+00'
        AND cps.status = 'ACTIVE'
    JOIN LATERAL (
        SELECT COUNT(*) AS qualifying_payment_count
        FROM plan_installment_regalia pir
        WHERE pir.customer_plan_id = cp.id
          AND pir.status = 'PAID'
          AND pir.paid_at >= cp.joined_at + INTERVAL '90 days'
        HAVING COUNT(*) >= 2
    ) paid ON TRUE
    WHERE cp.type = 'REG'
      AND cp.joined_at + INTERVAL '90 days' >= '2026-08-01'   -- period start: month the plan turns 90 days old, edit as needed
      AND cp.joined_at + INTERVAL '90 days' <  '2026-09-01'   -- period end, edit as needed
    GROUP BY ee.employee_id
),
regalia_agg_samemonth AS (
    SELECT
        ee.employee_id,
        SUM(pr.amount) AS term_amount_total,
        SUM(ROUND(pr.amount * ee.regalia_rate_pct, 2)) AS incentive_total
    FROM customer_plan cp
    JOIN LATERAL (
        SELECT pr2.amount
        FROM plan_regalia pr2
        WHERE pr2.customer_plan_id = cp.id
        ORDER BY pr2.created_at DESC
        LIMIT 1
    ) pr ON TRUE
    JOIN employee emp ON emp.user_id = cp.referral_user_id
    JOIN eligible_employees ee ON ee.employee_id = emp.id AND ee.regalia_condition = 'SAME_MONTH'
    WHERE cp.type = 'REG'
      AND cp.joined_at >= '2026-08-01'   -- period start, edit as needed
      AND cp.joined_at <  '2026-09-01'   -- period end, edit as needed
    GROUP BY ee.employee_id
),
regalia_agg AS (
    SELECT * FROM regalia_agg_gated
    UNION ALL
    SELECT * FROM regalia_agg_samemonth
),
illuminati_agg_gated AS (
    SELECT
        ee.employee_id,
        SUM(pi.amount) AS term_amount_total,
        SUM(ROUND(pi.amount * ee.illuminati_rate_pct, 2)) AS incentive_total
    FROM customer_plan cp
    JOIN LATERAL (
        SELECT pi2.amount
        FROM plan_illuminati pi2
        WHERE pi2.customer_plan_id = cp.id
        ORDER BY pi2.created_at DESC
        LIMIT 1
    ) pi ON TRUE
    JOIN employee emp ON emp.user_id = cp.referral_user_id
    JOIN eligible_employees ee ON ee.employee_id = emp.id AND ee.regalia_condition = 'GATED_90D'
    JOIN customer_plan_status cps
        ON cps.customer_plan_id = cp.id
        AND cps.end_time = '2100-01-01 00:00:00+00'
        AND cps.status = 'ACTIVE'
    JOIN LATERAL (
        SELECT COUNT(*) AS qualifying_payment_count
        FROM plan_installment_illuminati pii
        WHERE pii.customer_plan_id = cp.id
          AND pii.status = 'PAID'
          AND pii.paid_at >= cp.joined_at + INTERVAL '90 days'
        HAVING COUNT(*) >= 2
    ) paid ON TRUE
    WHERE cp.type = 'ILL'
      AND cp.joined_at + INTERVAL '90 days' >= '2026-08-01'   -- period start: month the plan turns 90 days old, edit as needed
      AND cp.joined_at + INTERVAL '90 days' <  '2026-09-01'   -- period end, edit as needed
    GROUP BY ee.employee_id
),
illuminati_agg_samemonth AS (
    SELECT
        ee.employee_id,
        SUM(pi.amount) AS term_amount_total,
        SUM(ROUND(pi.amount * ee.illuminati_rate_pct, 2)) AS incentive_total
    FROM customer_plan cp
    JOIN LATERAL (
        SELECT pi2.amount
        FROM plan_illuminati pi2
        WHERE pi2.customer_plan_id = cp.id
        ORDER BY pi2.created_at DESC
        LIMIT 1
    ) pi ON TRUE
    JOIN employee emp ON emp.user_id = cp.referral_user_id
    JOIN eligible_employees ee ON ee.employee_id = emp.id AND ee.regalia_condition = 'SAME_MONTH'
    WHERE cp.type = 'ILL'
      AND cp.joined_at >= '2026-08-01'   -- period start, edit as needed
      AND cp.joined_at <  '2026-09-01'   -- period end, edit as needed
    GROUP BY ee.employee_id
),
illuminati_agg AS (
    SELECT * FROM illuminati_agg_gated
    UNION ALL
    SELECT * FROM illuminati_agg_samemonth
),
swayamvara_agg AS (
    SELECT
        ee.employee_id,
        COALESCE(SUM(cai.weight), 0) AS net_weight_gm,
        ROUND(COALESCE(SUM(cai.weight), 0) * ee.swayamvara_rate_per_gram, 2) AS incentive_total
    FROM customer_advance ca
    JOIN customer_advance_installment cai ON cai.customer_advance_id = ca.id
    JOIN eligible_employees ee ON ee.app_user_id = ca.reference_user_id
    WHERE ca.advance_type::text = ANY(ee.swayamvara_advance_types)   -- SY6 + SY10 ("06/10") for all eleven roles here
      AND ca.joined_at >= '2026-08-01'   -- period start, edit as needed
      AND ca.joined_at <  '2026-09-01'   -- period end, edit as needed
    GROUP BY ee.employee_id, ee.swayamvara_rate_per_gram
),
gold_gram_plans AS (
    SELECT
        ee.employee_id,
        ee.gold_gram_rate_pct,
        (
            SELECT COALESCE(SUM(cai.amount), 0)
            FROM customer_advance_installment cai
            WHERE cai.customer_advance_id = ca.id
              AND cai.created_at >= ca.joined_at
              AND cai.created_at < ca.joined_at + INTERVAL '3 months'
        ) AS first_3mo_payments
    FROM customer_advance ca
    JOIN customer_advance_status cas
        ON cas.customer_advance_id = ca.id
        AND cas.end_time = '2100-01-01 00:00:00+00'
    JOIN eligible_employees ee ON ee.app_user_id = ca.reference_user_id
    WHERE ca.advance_type = 'ING'
      AND cas.status = 'ACTIVE'
      AND ca.joined_at + INTERVAL '6 months' >= '2026-08-01'   -- period start: month the scheme turns 6 months old, edit as needed
      AND ca.joined_at + INTERVAL '6 months' <  '2026-09-01'   -- period end, edit as needed
),
gold_gram_agg AS (
    SELECT
        employee_id,
        SUM(first_3mo_payments) AS first_3mo_payments_total,
        SUM(ROUND(first_3mo_payments * gold_gram_rate_pct, 2)) AS incentive_total
    FROM gold_gram_plans
    GROUP BY employee_id
)
SELECT
    ee.user_code                                       AS employee_code,
    ee.employee_name,
    ee.designation_name,
    ee.branch_name,

    COALESCE(rg.term_amount_total, 0)                  AS regalia_term_amount_total,
    COALESCE(rg.incentive_total, 0)                     AS regalia_incentive,

    COALESCE(il.term_amount_total, 0)                  AS akshayanidhi_term_amount_total,
    COALESCE(il.incentive_total, 0)                     AS akshayanidhi_incentive,

    COALESCE(sy.net_weight_gm, 0)                       AS swayamvara_net_weight_gm,
    COALESCE(sy.incentive_total, 0)                     AS swayamvara_incentive,

    COALESCE(gg.first_3mo_payments_total, 0)            AS gold_gram_first_3mo_payments_total,
    COALESCE(gg.incentive_total, 0)                     AS gold_gram_incentive,

    ROUND(
        COALESCE(rg.incentive_total, 0)
      + COALESCE(il.incentive_total, 0)
      + COALESCE(sy.incentive_total, 0)
      + COALESCE(gg.incentive_total, 0)
    , 2)                                                 AS total_incentive
FROM eligible_employees ee
LEFT JOIN regalia_agg rg ON rg.employee_id = ee.employee_id
LEFT JOIN illuminati_agg il ON il.employee_id = ee.employee_id
LEFT JOIN swayamvara_agg sy ON sy.employee_id = ee.employee_id
LEFT JOIN gold_gram_agg gg ON gg.employee_id = ee.employee_id
WHERE COALESCE(rg.incentive_total, 0)
    + COALESCE(il.incentive_total, 0)
    + COALESCE(sy.incentive_total, 0)
    + COALESCE(gg.incentive_total, 0) > 0
ORDER BY ee.branch_name, ee.employee_name;
