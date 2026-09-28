-- ============================================================================
-- PROD 3/4 -- Disable values nobody uses any more; remove hierarchy edges on disabled
-- values and the Style->Category edges (Brand->Collection edges are kept).
--
-- Run after 2_update_product_and_template_collection_style.sql.
-- Open in a new pgAdmin Query Tool tab (Auto commit ON), select nothing,
-- press F5 once. One transaction: all of it is saved, or (on any error)
-- none of it -- then run ROLLBACK; in that tab and send the error.
-- Generated from product-attrib/disable_unused_attributes_and_hierarchy.sql without its CHECK/VERIFY queries.
-- ============================================================================

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
