SELECT
	b.branch_name,
    i.invoice_code,
    i.created_at::date AS invoice_date,
    au.user_code                              AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)  AS employee_name,
    p.product_code,
    p.product_name,
    ili.sales_va_percentage
FROM invoice_line_item ili
JOIN invoice i ON i.id = ili.invoice_id
JOIN invoice_status ist
    ON ist.invoice_id = i.id
    AND ist.end_time = '2100-01-01 00:00:00+00'
    AND ist.status <> 'CANCELLED'
JOIN employee e ON e.id = i.salesperson_employee_id
JOIN app_user au ON au.id = e.user_id
JOIN product p ON p.id = ili.product_id
JOIN branch b on b.id = i.location_id
WHERE i.created_at >= '2026-08-01'   -- period start, edit as needed
  AND i.created_at <  '2026-09-01'   -- period end, edit as needed
  AND ili.sales_va_percentage > 18
ORDER BY ili.sales_va_percentage DESC;
