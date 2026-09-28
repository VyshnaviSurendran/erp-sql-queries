-- not used all attributes disable
SELECT
    e.id,
    pa.attribute_code,
    e.value,
    (SELECT COUNT(*) FROM product_attribute_value pav
       JOIN product p ON p.id = pav.product_id
      WHERE pav.product_attribute_enum_value_id = e.id
        AND EXISTS (SELECT 1 FROM product_location pl
                     WHERE pl.product_id = p.id AND pl.end_time = '2100-01-01 00:00:00+00'
                       AND pl.location_id IS NULL)
    ) AS sold_refs,
    (SELECT COUNT(*) FROM product_template_attribute_value ptav
      WHERE ptav.product_attribute_enum_value_id = e.id
    ) AS template_refs
FROM product_attribute_enum_value e
JOIN product_attribute pa ON pa.id = e.product_attribute_id
WHERE e.is_enabled = true
  AND NOT EXISTS (   -- zero product references at all -- sold or unsold
      SELECT 1 FROM product_attribute_value pav
      WHERE pav.product_attribute_enum_value_id = e.id
  )
  AND NOT EXISTS (   -- zero template references
      SELECT 1 FROM product_template_attribute_value ptav
      WHERE ptav.product_attribute_enum_value_id = e.id
  )
ORDER BY pa.attribute_code, e.value;


BEGIN;
UPDATE product_attribute_enum_value e
SET is_enabled = false
WHERE e.is_enabled = true
  AND NOT EXISTS (
      SELECT 1 FROM product_attribute_value pav
      WHERE pav.product_attribute_enum_value_id = e.id
  )
  AND NOT EXISTS (
      SELECT 1 FROM product_template_attribute_value ptav
      WHERE ptav.product_attribute_enum_value_id = e.id
  );
COMMIT;



SELECT
    h.id AS hierarchy_edge_id,
    child_pa.attribute_code AS child_code, child_e.value AS child_value, child_e.is_enabled AS child_enabled,
    parent_pa.attribute_code AS parent_code, parent_e.value AS parent_value, parent_e.is_enabled AS parent_enabled
FROM product_attribute_enum_hierarchy h
JOIN product_attribute_enum_value child_e ON child_e.id = h.product_attribute_enum_value_id
JOIN product_attribute child_pa ON child_pa.id = child_e.product_attribute_id
JOIN product_attribute_enum_value parent_e ON parent_e.id = h.parent_product_attribute_enum_value_id
JOIN product_attribute parent_pa ON parent_pa.id = parent_e.product_attribute_id
WHERE child_e.is_enabled = false OR parent_e.is_enabled = false
ORDER BY child_code, child_value;


BEGIN;
DELETE FROM product_attribute_hierarchy_condition
WHERE product_attribute_enum_hierarchy_id IN (
    SELECT h.id
    FROM product_attribute_enum_hierarchy h
    JOIN product_attribute_enum_value child_e ON child_e.id = h.product_attribute_enum_value_id
    JOIN product_attribute_enum_value parent_e ON parent_e.id = h.parent_product_attribute_enum_value_id
    WHERE child_e.is_enabled = false OR parent_e.is_enabled = false
);

DELETE FROM product_attribute_enum_hierarchy h
USING product_attribute_enum_value child_e, product_attribute_enum_value parent_e
WHERE child_e.id = h.product_attribute_enum_value_id
  AND parent_e.id = h.parent_product_attribute_enum_value_id
  AND (child_e.is_enabled = false OR parent_e.is_enabled = false);
COMMIT;

SELECT
    h.id AS hierarchy_edge_id,
    child_pa.attribute_code AS child_code, child_e.value AS child_value,
    parent_pa.attribute_code AS parent_code, parent_e.value AS parent_value
FROM product_attribute_enum_hierarchy h
JOIN product_attribute_enum_value child_e ON child_e.id = h.product_attribute_enum_value_id
JOIN product_attribute child_pa ON child_pa.id = child_e.product_attribute_id
JOIN product_attribute_enum_value parent_e ON parent_e.id = h.parent_product_attribute_enum_value_id
JOIN product_attribute parent_pa ON parent_pa.id = parent_e.product_attribute_id
WHERE (child_pa.attribute_code = 'STL' AND parent_pa.attribute_code = 'CTY')
   OR (child_pa.attribute_code = 'BND' AND parent_pa.attribute_code = 'COL')
ORDER BY child_code, child_value;


BEGIN;
DELETE FROM product_attribute_hierarchy_condition
WHERE product_attribute_enum_hierarchy_id IN (
    SELECT h.id
    FROM product_attribute_enum_hierarchy h
    JOIN product_attribute_enum_value child_e ON child_e.id = h.product_attribute_enum_value_id
    JOIN product_attribute child_pa ON child_pa.id = child_e.product_attribute_id
    JOIN product_attribute_enum_value parent_e ON parent_e.id = h.parent_product_attribute_enum_value_id
    JOIN product_attribute parent_pa ON parent_pa.id = parent_e.product_attribute_id
    WHERE (child_pa.attribute_code = 'STL' AND parent_pa.attribute_code = 'CTY')
);

DELETE FROM product_attribute_enum_hierarchy h
USING product_attribute_enum_value child_e, product_attribute child_pa,
      product_attribute_enum_value parent_e, product_attribute parent_pa
WHERE child_e.id = h.product_attribute_enum_value_id
  AND child_pa.id = child_e.product_attribute_id
  AND parent_e.id = h.parent_product_attribute_enum_value_id
  AND parent_pa.id = parent_e.product_attribute_id
  AND ((child_pa.attribute_code = 'STL' AND parent_pa.attribute_code = 'CTY'));
COMMIT;