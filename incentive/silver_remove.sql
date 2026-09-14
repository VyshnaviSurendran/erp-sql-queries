SELECT
    b.branch_name,
    i.invoice_code,
    i.created_at::date AS invoice_date,
    au.user_code                              AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)  AS employee_name,
    p.product_code,
    p.product_name,
	enum_typ.value AS type,
    enum_cty.value AS category,
    enum_sty.value AS style,
    enum_col.value AS collection,
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
JOIN branch b ON b.id = i.location_id
LEFT JOIN product_attribute_value pav_cty
    ON pav_cty.product_id = p.id
    AND pav_cty.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'CTY')
LEFT JOIN product_attribute_enum_value enum_cty
    ON enum_cty.id = pav_cty.product_attribute_enum_value_id
LEFT JOIN product_attribute_value pav_sty
    ON pav_sty.product_id = p.id
    AND pav_sty.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'STL')
LEFT JOIN product_attribute_enum_value enum_sty
    ON enum_sty.id = pav_sty.product_attribute_enum_value_id
LEFT JOIN product_attribute_value pav_typ
    ON pav_typ.product_id = p.id
    AND pav_typ.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'TYP')
LEFT JOIN product_attribute_enum_value enum_typ
    ON enum_typ.id = pav_typ.product_attribute_enum_value_id
LEFT JOIN product_attribute_value pav_col
    ON pav_col.product_id = p.id
    AND pav_col.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
LEFT JOIN product_attribute_enum_value enum_col
    ON enum_col.id = pav_col.product_attribute_enum_value_id
WHERE i.created_at >= '2026-08-01'   -- period start, edit as needed
  AND i.created_at <  '2026-09-01'   -- period end, edit as needed
  AND ili.sales_va_percentage > 18
  AND enum_typ.product_attribute_enum_value_code IS DISTINCT FROM 'SL3'   -- exclude Silver
ORDER BY ili.sales_va_percentage DESC;
