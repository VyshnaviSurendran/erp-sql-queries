WITH sale_branch_states AS (
    SELECT DISTINCT
        i.salesperson_employee_id,
        a.state_code
    FROM invoice i
    JOIN invoice_status ist
        ON ist.invoice_id = i.id
        AND ist.end_time = '2100-01-01 00:00:00+00'
        AND ist.status <> 'CANCELLED'
    JOIN branch b ON b.id = i.location_id
    LEFT JOIN address a ON a.id = b.address_id
    WHERE i.created_at >= '2026-08-01'   -- period start, edit as needed
      AND i.created_at <  '2026-09-01'   -- period end, edit as needed
)
SELECT
    au.user_code                              AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)  AS employee_name,
    ARRAY_AGG(DISTINCT sbs.state_code ORDER BY sbs.state_code) AS states_sold_in
FROM sale_branch_states sbs
JOIN employee e ON e.id = sbs.salesperson_employee_id
JOIN app_user au ON au.id = e.user_id
GROUP BY au.user_code, au.first_name, au.last_name
HAVING
    BOOL_OR(sbs.state_code IN ('TN', 'KA'))       -- sold in at least one TN/KA branch
    AND BOOL_OR(sbs.state_code NOT IN ('TN', 'KA') OR sbs.state_code IS NULL)  -- AND at least one other-state branch
ORDER BY employee_code;
