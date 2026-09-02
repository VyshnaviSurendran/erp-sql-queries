-----------------------------------customer payment & customer collection due IAM check----------------------------------------------------------------------
WITH active_employees AS (
    SELECT DISTINCT
        au.id AS user_id,
        d.designation_code,
        d.designation_name
    FROM app_user au
    JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
    JOIN designation d ON d.id = ud.designation_id
),
policy_check_all AS (
    SELECT
        ae.user_id,
        ae.designation_code,
        ae.designation_name,
        EXISTS (
            SELECT 1
            FROM jsonb_array_elements(COALESCE(up.policies, '[]'::jsonb)) elem
            WHERE elem->>'action' = 'CustomerCollectionDue.List'
              AND (elem->>'expires_at' IS NULL OR (elem->>'expires_at')::timestamptz > now())
        ) AS has_collection_due_list,
        EXISTS (
            SELECT 1
            FROM jsonb_array_elements(COALESCE(up.policies, '[]'::jsonb)) elem
            WHERE elem->>'action' = 'CustomerPaymentDue.List'
              AND (elem->>'expires_at' IS NULL OR (elem->>'expires_at')::timestamptz > now())
        ) AS has_payment_due_list
    FROM active_employees ae
    LEFT JOIN user_policy up ON up.user_id = ae.user_id
)
SELECT
    designation_code,
    designation_name,
    COUNT(*) FILTER (WHERE has_collection_due_list) AS with_collection_due_list,
    COUNT(*) FILTER (WHERE has_payment_due_list) AS with_payment_due_list,
    COUNT(*) AS total_employees
FROM policy_check_all
GROUP BY designation_code, designation_name
HAVING COUNT(*) FILTER (WHERE has_collection_due_list) > 0
    OR COUNT(*) FILTER (WHERE has_payment_due_list) > 0
ORDER BY designation_code;
-----------------------------------