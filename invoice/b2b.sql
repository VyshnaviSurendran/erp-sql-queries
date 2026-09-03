-----------------------------------b2b invoice----------------------------------------------------------------------
SELECT
    i.id AS invoice_id,
    i.invoice_code,
    i.type AS invoice_type,
    i.created_at,
    i.location_id,
    i.customer_id,
    c.customer_code,
    c.full_name AS customer_name,
    c.gstin AS customer_gstin,
    i.vendor_id,
    v.name AS vendor_name,
    CASE
        WHEN i.customer_id IS NOT NULL AND c.gstin IS NOT NULL THEN 'CUSTOMER'
        WHEN i.customer_id IS NOT NULL AND c.gstin IS NULL THEN 'CUSTOMER (no GST on file — excluded from CUSTOMER bucket)'
        WHEN i.customer_id IS NULL THEN 'BRANCH'
    END AS b2b_type_classification
FROM invoice i
LEFT JOIN customer c ON c.id = i.customer_id
LEFT JOIN vendor v ON v.id = i.vendor_id
WHERE i.type = 'B2B'
ORDER BY i.created_at DESC
LIMIT 200;