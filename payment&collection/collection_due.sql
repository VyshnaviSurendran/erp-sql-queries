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
