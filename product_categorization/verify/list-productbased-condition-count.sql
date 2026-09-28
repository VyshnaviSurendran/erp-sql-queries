-- based on combination what all sold and unsold products are there
WITH current_loc AS (
    SELECT DISTINCT ON (product_id)
        product_id, location_id, end_time
    FROM product_location
    WHERE end_time = '2100-01-01 00:00:00+00'
    ORDER BY product_id, end_time DESC, start_time DESC
)
SELECT
	p.id as product_id,
    p.product_code AS barcode,
    p.product_name AS product_name,
    MAX(CASE WHEN pa.attribute_code='CTY' THEN paev.value END) AS category,
    MAX(CASE WHEN pa.attribute_code='TYP' THEN paev.value END) AS product_type,
    MAX(CASE WHEN pa.attribute_code='COL' THEN paev.value END) AS collection,
    MAX(CASE WHEN pa.attribute_code='STL' THEN paev.value END) AS style,
    CASE WHEN cl.location_id IS NOT NULL THEN 'Unsold' ELSE 'Sold' END AS status
FROM product_attribute_value pav
JOIN product_attribute pa
    ON pa.id = pav.attribute_id
    AND pa.attribute_code IN ('CTY','TYP','COL','STL')
JOIN product_attribute_enum_value paev
    ON paev.id = pav.product_attribute_enum_value_id
JOIN product p
    ON p.id = pav.product_id
JOIN current_loc cl ON cl.product_id = p.id
GROUP BY p.id, p.product_code, p.product_name, cl.location_id
HAVING
    LOWER(MAX(CASE WHEN pa.attribute_code='TYP' THEN paev.value END)) = 'gold 22k'
    AND LOWER(MAX(CASE WHEN pa.attribute_code='CTY' THEN paev.value END)) = 'ring'
    AND LOWER(MAX(CASE WHEN pa.attribute_code='COL' THEN paev.value END)) = 'nellore'
    AND LOWER(MAX(CASE WHEN pa.attribute_code='STL' THEN paev.value END)) IN ('nellore')
ORDER BY style, status, p.product_code;

-- which all conditions are currently used
SELECT
    child_pa.attribute_code AS child_code,
    parent_pa.attribute_code AS parent_code,
    COUNT(*) AS edge_count
FROM product_attribute_enum_hierarchy h
JOIN product_attribute_enum_value child_e ON child_e.id = h.product_attribute_enum_value_id
JOIN product_attribute child_pa ON child_pa.id = child_e.product_attribute_id
JOIN product_attribute_enum_value parent_e ON parent_e.id = h.parent_product_attribute_enum_value_id
JOIN product_attribute parent_pa ON parent_pa.id = parent_e.product_attribute_id
GROUP BY child_pa.attribute_code, parent_pa.attribute_code
ORDER BY edge_count DESC;

-- list based on parent child connection
SELECT
    hc.id AS condition_id,
    e.value AS value_name,
    pa.attribute_code AS value_attribute_code,
    h.id AS hierarchy_edge_id,
    child_e.value AS edge_child,
    parent_e.value AS edge_parent
FROM product_attribute_hierarchy_condition hc
JOIN product_attribute_enum_value e ON e.id = hc.product_attribute_enum_value_id
JOIN product_attribute pa ON pa.id = e.product_attribute_id
JOIN product_attribute_enum_hierarchy h ON h.id = hc.product_attribute_enum_hierarchy_id
JOIN product_attribute_enum_value child_e ON child_e.id = h.product_attribute_enum_value_id
JOIN product_attribute_enum_value parent_e ON parent_e.id = h.parent_product_attribute_enum_value_id
ORDER BY value_name, hierarchy_edge_id;
