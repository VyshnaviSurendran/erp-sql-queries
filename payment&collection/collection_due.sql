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
-----------------------------------iam based on designation-----------------------------------------------------------------------------------------------
-- 1) Preview: who currently holds this designation
SELECT ud.user_id, up.policies
FROM user_designation ud
JOIN designation d ON d.id = ud.designation_id
LEFT JOIN user_policy up ON up.user_id = ud.user_id
WHERE d.designation_code = 'SAM'
  AND ud.end_time = '2100-01-01 00:00:00+00';

-- 2) Add/update policies for everyone currently in that designation
WITH new_policies AS (
    SELECT '[
        {"action": "CustomerCollectionDue.List", "effect": "allow", "context": {"location": [
        "${current_location}"
      ], "region": null}, "expires_at": null},
        {"action": "CustomerPaymentDue.List",     "effect": "allow", "context": {"location": [
        "${current_location}"
      ], "region": null}, "expires_at": null}
    ]'::jsonb AS policies
),
target_users AS (
    SELECT ud.user_id
    FROM user_designation ud
    JOIN designation d ON d.id = ud.designation_id
    WHERE d.designation_code = 'SAM'
      AND ud.end_time = '2100-01-01 00:00:00+00'
)
INSERT INTO user_policy (user_id, policies, updated_by)
SELECT tu.user_id, np.policies, 1080
FROM target_users tu
CROSS JOIN new_policies np
ON CONFLICT (user_id) DO UPDATE
SET
    policies = user_policy.policies || (
        SELECT jsonb_agg(elem)
        FROM jsonb_array_elements(EXCLUDED.policies) elem
        WHERE elem ->> 'action' NOT IN (
            SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e
        )
    ),
    updated_at = now(),
    updated_by = EXCLUDED.updated_by
WHERE EXISTS (
    SELECT 1
    FROM jsonb_array_elements(EXCLUDED.policies) elem
    WHERE elem ->> 'action' NOT IN (
        SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e
    )
);

-- 3) Verify
SELECT up.*
FROM user_policy up
JOIN user_designation ud ON ud.user_id = up.user_id AND ud.end_time = '2100-01-01 00:00:00+00'
JOIN designation d ON d.id = ud.designation_id
WHERE d.designation_code = 'CAS';

------------------------------------IAM based on userid----------------------------------------------------------------------
-- 1) Preview: current policies for these users
SELECT au.id AS user_id, up.policies
FROM app_user au
LEFT JOIN user_policy up ON up.user_id = au.id
WHERE au.id IN (348, 388);

-- 2) Add/update policies for these specific users
WITH new_policies AS (
    SELECT '[
        {"action": "CustomerCollectionDue.List", "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "CustomerPaymentDue.List",     "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null}
    ]'::jsonb AS policies
),
target_users AS (
    SELECT unnest(ARRAY[348, 388]) AS user_id
)
INSERT INTO user_policy (user_id, policies, updated_by)
SELECT tu.user_id, np.policies, 1080
FROM target_users tu
CROSS JOIN new_policies np
ON CONFLICT (user_id) DO UPDATE
SET
    policies = user_policy.policies || (
        SELECT jsonb_agg(elem)
        FROM jsonb_array_elements(EXCLUDED.policies) elem
        WHERE elem ->> 'action' NOT IN (
            SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e
        )
    ),
    updated_at = now(),
    updated_by = EXCLUDED.updated_by
WHERE EXISTS (
    SELECT 1
    FROM jsonb_array_elements(EXCLUDED.policies) elem
    WHERE elem ->> 'action' NOT IN (
        SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e
    )
);

-- 3) Verify
SELECT au.id AS user_id, up.policies
FROM app_user au
LEFT JOIN user_policy up ON up.user_id = au.id
WHERE au.id IN (348, 388);
-----------------------------------check the designation based IAM action to how many employees have the access to the action----------------------------------------------------------------------
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
-------------------------------------preview the policy and remove the access based on designation----------------------------------------------------------------------
-- 1) Preview: who in SAE currently has either policy
SELECT au.id AS user_id, au.user_code, up.policies
FROM app_user au
JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
JOIN designation d ON d.id = ud.designation_id
JOIN user_policy up ON up.user_id = au.id
WHERE d.designation_code = 'SAE'
  AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(up.policies) e
      WHERE e->>'action' IN ('CustomerCollectionDue.List', 'CustomerPaymentDue.List')
  );

-- 2) Remove the two policies for everyone currently in SAE
UPDATE user_policy up
SET
    policies = COALESCE(
        (
            SELECT jsonb_agg(elem)
            FROM jsonb_array_elements(up.policies) elem
            WHERE elem->>'action' NOT IN ('CustomerCollectionDue.List', 'CustomerPaymentDue.List')
        ),
        '[]'::jsonb
    ),
    updated_at = now(),
    updated_by = 1080
FROM user_designation ud
JOIN designation d ON d.id = ud.designation_id
WHERE ud.user_id = up.user_id
  AND d.designation_code = 'SAE'
  AND ud.end_time = '2100-01-01 00:00:00+00'
  AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(up.policies) e
      WHERE e->>'action' IN ('CustomerCollectionDue.List', 'CustomerPaymentDue.List')
  );

-- 3) Verify — should return no rows with either action left
SELECT au.id AS user_id, up.policies
FROM app_user au
JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
JOIN designation d ON d.id = ud.designation_id
JOIN user_policy up ON up.user_id = au.id
WHERE d.designation_code = 'SAE';
-----------------------------------collection summary and total count based on branch----------------------------------------------------------------------
SELECT COUNT(*) AS total_count, COALESCE(SUM(ccr.amount), 0) AS total_amount
FROM customer_collection_reminder ccr
JOIN invoice_customer_collection_reminder icr
    ON icr.customer_collection_reminder_id = ccr.id
JOIN invoice i
    ON i.id = icr.invoice_id
JOIN branch b
    ON b.id = i.location_id
WHERE b.id = 1
  AND ccr.is_done = TRUE;

------------------------------------customer payment total paid amount,unpaid amount, paid total count, unpaid total count----------------------------------------------------------------------
SELECT
    COALESCE(SUM(cpr.amount), 0) AS total_amount,
    COALESCE(SUM(cpr.amount) FILTER (WHERE cpr.is_done IS FALSE), 0) AS unpaid_total_amount,
    COUNT(*) FILTER (WHERE cpr.is_done IS FALSE) AS unpaid_total_count,
    COALESCE(SUM(cpr.amount) FILTER (WHERE cpr.is_done IS TRUE), 0) AS paid_total_amount,
    COUNT(*) FILTER (WHERE cpr.is_done IS TRUE) AS paid_total_count
FROM customer_payment_reminder cpr
LEFT JOIN customer c ON c.id = cpr.customer_id
LEFT JOIN invoice i ON i.id = cpr.document_id AND cpr.document_type = 'INVOICE'
LEFT JOIN repurchase r ON r.id = cpr.document_id AND cpr.document_type = 'REPURCHASE'
LEFT JOIN sales_return sr ON sr.id = cpr.document_id AND cpr.document_type = 'SALES_RETURN'
LEFT JOIN customer_advance ca ON ca.id = cpr.document_id AND cpr.document_type = 'CUSTOMER_ADVANCE'
LEFT JOIN customer_plan cp ON cp.id = cpr.document_id AND cpr.document_type = 'CUSTOMER_PLAN'
LEFT JOIN branch b ON b.id = COALESCE(i.location_id, r.location_id, sr.location_id, ca.location_id, cp.branch_id)
LEFT JOIN region rg ON rg.id = b.region_id
WHERE rg.code = 'KAR';
