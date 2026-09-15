WITH manager_lookup (designation_code, designation_name, manager_role) AS (
    VALUES
        ('SAM', 'Sales Manager',              'SALES_MANAGER'),
        ('MAM', 'Marketing Manager',           'MARKETING_MANAGER'),
        ('RMM', 'Regional Marketing Manager',  'MARKETING_RM')
),
target_manager AS (
    SELECT
        e.id AS employee_id,
        au.id AS app_user_id,
        au.user_code,
        CONCAT(au.first_name, ' ', au.last_name) AS employee_name,
        d.designation_name,
        ml.manager_role,
        b.branch_name,
        a.state_code
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud
        ON ud.user_id = au.id
        AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    LEFT JOIN manager_lookup ml
        ON (ml.designation_code IS NOT NULL AND ml.designation_code = d.designation_code)
        OR (ml.designation_code IS NULL AND ml.designation_name = d.designation_name)
    JOIN user_branch ub
        ON ub.user_id = au.id
        AND ub.end_time = '2100-01-01 00:00:00+00'
    JOIN branch b ON b.id = ub.branch_id
    JOIN address a ON a.id = b.address_id
    WHERE au.user_code = 'EMP0001'   -- <-- edit: target user_code
)
-- 0. Manager resolution: confirms the employee exists, is in KL, and matched
--    a manager_role (SALES_MANAGER / MARKETING_MANAGER / MARKETING_RM).
--    manager_role NULL => not one of the three Section-3 designations at all.
SELECT * FROM target_manager;

-- 1. Gold Gram detail (only meaningful for MARKETING_MANAGER -- Sales
--    Manager is Nil and Marketing RM's Gold Gram is team-wide/unimplemented,
--    so this will correctly return 0 rows for those two roles).
WITH manager_lookup (designation_code, designation_name, manager_role) AS (
    VALUES
        ('SAM', 'Sales Manager', 'SALES_MANAGER'),
        ('MAM', 'Marketing Manager', 'MARKETING_MANAGER'),
        ('RMM', 'Regional Marketing Manager', 'MARKETING_RM')
),
target_manager AS (
    SELECT au.id AS app_user_id, au.user_code, ml.manager_role
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
    LEFT JOIN manager_lookup ml
        ON (ml.designation_code IS NOT NULL AND ml.designation_code = d.designation_code)
        OR (ml.designation_code IS NULL AND ml.designation_name = d.designation_name)
    WHERE au.user_code = 'EMP0001'   -- <-- edit: target user_code
)
SELECT
    ca.id AS customer_advance_id,
    tm.manager_role,
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
    ROUND((
        SELECT COALESCE(SUM(cai.amount), 0)
        FROM customer_advance_installment cai
        WHERE cai.customer_advance_id = ca.id
          AND cai.created_at >= ca.joined_at
          AND cai.created_at < ca.joined_at + INTERVAL '3 months'
    ) * 0.0025, 2) AS incentive_if_all_conditions_met,
    (ca.joined_at + INTERVAL '6 months' >= '2026-08-01'
     AND ca.joined_at + INTERVAL '6 months' < '2026-09-01') AS falls_in_report_period,   -- <-- edit period
    (cas.status = 'ACTIVE'
     AND tm.manager_role = 'MARKETING_MANAGER'
     AND ca.joined_at + INTERVAL '6 months' >= '2026-08-01'                              -- <-- edit period
     AND ca.joined_at + INTERVAL '6 months' < '2026-09-01') AS counted_in_main_report     -- <-- edit period
FROM customer_advance ca
JOIN customer_advance_status cas
    ON cas.customer_advance_id = ca.id
    AND cas.end_time = '2100-01-01 00:00:00+00'
JOIN target_manager tm ON tm.app_user_id = ca.reference_user_id
WHERE ca.advance_type = 'ING'
ORDER BY ca.joined_at;
