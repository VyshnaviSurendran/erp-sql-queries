WITH current_loc AS (
    SELECT DISTINCT ON (product_id)
        product_id, location_id, end_time
    FROM product_location
    WHERE end_time = '2100-01-01 00:00:00+00'
    ORDER BY product_id, end_time DESC, start_time DESC
)
SELECT
    p.product_code AS barcode,
    p.product_name AS product_name,
    paev.value AS style,
    b.branch_name AS branch_name,
    p.created_at::date AS barcode_date
FROM product_attribute_value pav
JOIN product_attribute pa
    ON pa.id = pav.attribute_id AND pa.attribute_code = 'STL'
JOIN product_attribute_enum_value paev
    ON paev.id = pav.product_attribute_enum_value_id AND paev.is_enabled = false
JOIN product p ON p.id = pav.product_id
JOIN vendor v ON v.id = p.vendor_id
JOIN current_loc cl ON cl.product_id = p.id AND cl.location_id IS NOT NULL
JOIN branch b ON b.id = cl.location_id
ORDER BY paev.value, p.product_code;
