WITH manager_lookup (designation_code, designation_name, manager_role) AS (
    VALUES
        ('SAM', 'Sales Manager',              'SALES_MANAGER'),
        ('MAM', 'Marketing Manager',           'MARKETING_MANAGER'),
        ('RMM', 'Regional Marketing Manager',  'MARKETING_RM')   -- doc calls this "Marketing RM"; live designation_name is "Regional Marketing Manager"
),
managers AS (
    SELECT
        e.id AS employee_id,
        au.id AS app_user_id,
        au.user_code,
        CONCAT(au.first_name, ' ', au.last_name) AS employee_name,
        d.designation_name,
        ml.manager_role,
        b.branch_name
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud
        ON ud.user_id = au.id
        AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    JOIN manager_lookup ml
        ON (ml.designation_code IS NOT NULL AND ml.designation_code = d.designation_code)
        OR (ml.designation_code IS NULL AND ml.designation_name = d.designation_name)
    JOIN user_branch ub
        ON ub.user_id = au.id
        AND ub.end_time = '2100-01-01 00:00:00+00'
    JOIN branch b ON b.id = ub.branch_id
    JOIN address a ON a.id = b.address_id
    WHERE a.state_code = 'KL'
),
marketing_manager_gold_gram_plans AS (
    SELECT
        m.employee_id,
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
        AND cas.status = 'ACTIVE'
    JOIN managers m
        ON m.app_user_id = ca.reference_user_id
        AND m.manager_role = 'MARKETING_MANAGER'
    WHERE ca.advance_type = 'ING'
      AND ca.joined_at + INTERVAL '6 months' >= '2026-08-01'   -- period start: month the scheme turns 6 months old, edit as needed
      AND ca.joined_at + INTERVAL '6 months' <  '2026-09-01'   -- period end, edit as needed
),
marketing_manager_gold_gram_agg AS (
    SELECT
        employee_id,
        SUM(first_3mo_payments) AS first_3mo_payments_total,
        ROUND(SUM(first_3mo_payments) * 0.0025, 2) AS incentive_total
    FROM marketing_manager_gold_gram_plans
    GROUP BY employee_id
)
SELECT
    m.user_code                    AS employee_code,
    m.employee_name,
    m.designation_name,
    m.branch_name,
    NULL::numeric                  AS regalia_akshayanidhi_incentive,   -- held, see header note
    NULL::numeric                  AS swayamvara_incentive,             -- held, slab wise, see header note
    gg.first_3mo_payments_total    AS gold_gram_first_3mo_payments_total,
    gg.incentive_total             AS gold_gram_incentive,
    gg.incentive_total             AS total_incentive
FROM managers m
JOIN marketing_manager_gold_gram_agg gg ON gg.employee_id = m.employee_id
WHERE gg.incentive_total > 0
ORDER BY m.branch_name, m.employee_name;
