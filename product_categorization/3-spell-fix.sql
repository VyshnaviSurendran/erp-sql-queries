DROP TABLE IF EXISTS step2_spelling_fixes;
CREATE TEMP TABLE step2_spelling_fixes (attribute_code text, old_value text, new_value text, new_code text);
INSERT INTO step2_spelling_fixes (attribute_code, old_value, new_value, new_code) VALUES
    ('COL', '18 Carat', '18 Karat', 195),
    ('COL', 'Culcutta', 'Kolkata', 821),
    ('COL', '14 Carat Ornaments', '14 Kt Ornaments', 716),
    ('STL', 'PIPE RODIUM', 'Pipe Rhodium', 'PRO'),
    ('STL', 'Dhasavatharam', 'Dasavatharam', 'DTM'),
    ('STL', 'Papper Cast', 'Paper Cast', 'PPC'),
    ('STL', 'Rajkot Beeds', 'Beeds', 'BDS'),
    ('STL', 'KARBH', 'Curb', 'CRB'),
    ('STL', 'Ilakka Thali', 'Elakkathali', 'ELK'),
    ('STL', 'LAKSHMI KAASHI', 'Kaasu', 'KSU'),
    ('STL', 'Ohm Thali', 'Om Thali', 'OMT'),
    ('STL', 'Kumbala Ohm Thali', 'Kumbala Om Thali', NULL),  -- from product_categorization_latest.xlsx; keeps code KOT
    ('STL', 'OHM', 'Om', 'OHM'),
    ('STL', 'JIMKKA STONE', 'Jhumka Stone', 'JMS'),
    ('STL', 'JIMKKA ENAMEL', 'Jhumka Enamel', 'JME'),
    ('STL', 'JIMKKA NAKSHI', 'Jhumka Nakshi', 'JMN'),
    ('STL', 'JIMKKA RAM PARIVAR', 'Jhumka Ram Parivar', 'JRP'),
    ('STL', 'JIMKKA GOD', 'Jhumka God', 'JMG'),
    ('STL', 'JIMKKA LAKSHMI', 'Jhumka Lakshmi', 'JML'),
    ('STL', 'Rodium', 'Rhodium', 'ROD'),
    ('STL', 'Jimkka', 'Jhumka', 'JMK'),
    ('STL', 'Vangi', 'Vanki', 'VNK');

SELECT
    cf.attribute_code, cf.old_value, cf.new_value, cf.new_code,
    e.id AS enum_value_id, e.value AS current_db_value, e.product_attribute_enum_value_code AS current_code,
    (SELECT COUNT(*) FROM product_attribute_value pav WHERE pav.product_attribute_enum_value_id = e.id) AS product_refs,
    (SELECT COUNT(*) FROM product_template_attribute_value ptav WHERE ptav.product_attribute_enum_value_id = e.id) AS template_refs,
    EXISTS (SELECT 1 FROM product_attribute_enum_value other
             WHERE other.product_attribute_id = e.product_attribute_id
               AND LOWER(other.value) = LOWER(cf.new_value) AND other.id <> e.id) AS target_already_exists_as_different_row,
    EXISTS (SELECT 1 FROM product_attribute_enum_value other
             WHERE other.product_attribute_id = e.product_attribute_id
               AND LOWER(other.product_attribute_enum_value_code) = LOWER(cf.new_code) AND other.id <> e.id) AS code_already_taken
FROM step2_spelling_fixes cf
JOIN product_attribute pa ON pa.attribute_code = cf.attribute_code
JOIN product_attribute_enum_value e ON e.product_attribute_id = pa.id AND e.value = cf.old_value
ORDER BY cf.attribute_code, cf.old_value;

-- Codes this step is about to change, captured BEFORE the rename so Step 2b
-- can carry them into product names and template codes. Empty on a rerun
-- (the old values no longer exist), which makes Step 2b a no-op then.
DROP TABLE IF EXISTS step2_code_changes;
CREATE TEMP TABLE step2_code_changes AS
SELECT e.id AS enum_id, cf.attribute_code, e.product_attribute_enum_value_code AS old_code, cf.new_code
FROM step2_spelling_fixes cf
JOIN product_attribute pa ON pa.attribute_code = cf.attribute_code
JOIN product_attribute_enum_value e ON e.product_attribute_id = pa.id AND e.value = cf.old_value
WHERE cf.new_code IS NOT NULL
  AND e.product_attribute_enum_value_code IS DISTINCT FROM cf.new_code;

-- UPDATE
BEGIN;
UPDATE product_attribute_enum_value e
SET value = cf.new_value,
    product_attribute_enum_value_code = COALESCE(cf.new_code, e.product_attribute_enum_value_code)
FROM step2_spelling_fixes cf
JOIN product_attribute pa ON pa.attribute_code = cf.attribute_code
WHERE e.product_attribute_id = pa.id
  AND e.value = cf.old_value
  AND NOT EXISTS (SELECT 1 FROM product_attribute_enum_value other
                   WHERE other.product_attribute_id = e.product_attribute_id
                     AND LOWER(other.value) = LOWER(cf.new_value) AND other.id <> e.id)
  AND (cf.new_code IS NULL OR NOT EXISTS (
      SELECT 1 FROM product_attribute_enum_value other
      WHERE other.product_attribute_id = e.product_attribute_id
        AND LOWER(other.product_attribute_enum_value_code) = LOWER(cf.new_code) AND other.id <> e.id
  ));
COMMIT;

-- ----------------------------------------------------------------------------
-- STEP 2b -- carry every code Step 2 just changed into the product names and
-- template codes that embed it (e.g. Vangi 'VNG' -> Vanki 'VNK'). Without
-- this, names and codes built before the rename keep the old code, and the
-- migration can't fix them (the value itself doesn't change there, only its
-- code did, here). Same rule as the migration: unsold products only; the old
-- code must appear exactly once and the new code must not already be there.
-- A template is skipped if another template already holds the new code.
-- Collection and Style run separately so a row with both codes changed gets
-- both swaps. Only rows whose code this run actually changed are touched.
-- ----------------------------------------------------------------------------
BEGIN;
UPDATE product p
SET product_name = REPLACE(p.product_name, c.old_code, c.new_code)
FROM step2_code_changes c
JOIN product_attribute_enum_value e ON e.id = c.enum_id AND e.product_attribute_enum_value_code = c.new_code
JOIN product_attribute_value pav ON pav.product_attribute_enum_value_id = c.enum_id
WHERE c.attribute_code = 'COL'
  AND p.id = pav.product_id
  AND EXISTS (SELECT 1 FROM product_location pl WHERE pl.product_id = p.id
                  AND pl.end_time = '2100-01-01 00:00:00+00' AND pl.location_id IS NOT NULL)
  AND (LENGTH(p.product_name) - LENGTH(REPLACE(p.product_name, c.old_code, ''))) / NULLIF(LENGTH(c.old_code), 0) = 1
  AND POSITION(c.new_code IN p.product_name) = 0;

UPDATE product p
SET product_name = REPLACE(p.product_name, c.old_code, c.new_code)
FROM step2_code_changes c
JOIN product_attribute_enum_value e ON e.id = c.enum_id AND e.product_attribute_enum_value_code = c.new_code
JOIN product_attribute_value pav ON pav.product_attribute_enum_value_id = c.enum_id
WHERE c.attribute_code = 'STL'
  AND p.id = pav.product_id
  AND EXISTS (SELECT 1 FROM product_location pl WHERE pl.product_id = p.id
                  AND pl.end_time = '2100-01-01 00:00:00+00' AND pl.location_id IS NOT NULL)
  AND (LENGTH(p.product_name) - LENGTH(REPLACE(p.product_name, c.old_code, ''))) / NULLIF(LENGTH(c.old_code), 0) = 1
  AND POSITION(c.new_code IN p.product_name) = 0;

UPDATE product_template pt
SET product_template_code = REPLACE(pt.product_template_code, c.old_code, c.new_code)
FROM step2_code_changes c
JOIN product_attribute_enum_value e ON e.id = c.enum_id AND e.product_attribute_enum_value_code = c.new_code
JOIN product_template_attribute_value ptav ON ptav.product_attribute_enum_value_id = c.enum_id
WHERE c.attribute_code = 'COL'
  AND pt.id = ptav.product_template_id
  AND (LENGTH(pt.product_template_code) - LENGTH(REPLACE(pt.product_template_code, c.old_code, ''))) / NULLIF(LENGTH(c.old_code), 0) = 1
  AND POSITION(c.new_code IN pt.product_template_code) = 0
  AND NOT EXISTS (SELECT 1 FROM product_template o
                  WHERE o.product_template_code = REPLACE(pt.product_template_code, c.old_code, c.new_code));

UPDATE product_template pt
SET product_template_code = REPLACE(pt.product_template_code, c.old_code, c.new_code)
FROM step2_code_changes c
JOIN product_attribute_enum_value e ON e.id = c.enum_id AND e.product_attribute_enum_value_code = c.new_code
JOIN product_template_attribute_value ptav ON ptav.product_attribute_enum_value_id = c.enum_id
WHERE c.attribute_code = 'STL'
  AND pt.id = ptav.product_template_id
  AND (LENGTH(pt.product_template_code) - LENGTH(REPLACE(pt.product_template_code, c.old_code, ''))) / NULLIF(LENGTH(c.old_code), 0) = 1
  AND POSITION(c.new_code IN pt.product_template_code) = 0
  AND NOT EXISTS (SELECT 1 FROM product_template o
                  WHERE o.product_template_code = REPLACE(pt.product_template_code, c.old_code, c.new_code));
COMMIT;

-- VERIFY Step 2b -- expect 0 in both rows.
SELECT 'unsold product names still carrying an old code' AS check_name, COUNT(*) AS remaining
FROM step2_code_changes c
JOIN product_attribute_value pav ON pav.product_attribute_enum_value_id = c.enum_id
JOIN product p ON p.id = pav.product_id
WHERE EXISTS (SELECT 1 FROM product_location pl WHERE pl.product_id = p.id
                  AND pl.end_time = '2100-01-01 00:00:00+00' AND pl.location_id IS NOT NULL)
  AND (LENGTH(p.product_name) - LENGTH(REPLACE(p.product_name, c.old_code, ''))) / NULLIF(LENGTH(c.old_code), 0) = 1
UNION ALL
SELECT 'template codes still carrying an old code', COUNT(*)
FROM step2_code_changes c
JOIN product_template_attribute_value ptav ON ptav.product_attribute_enum_value_id = c.enum_id
JOIN product_template pt ON pt.id = ptav.product_template_id
WHERE (LENGTH(pt.product_template_code) - LENGTH(REPLACE(pt.product_template_code, c.old_code, ''))) / NULLIF(LENGTH(c.old_code), 0) = 1;

-- VERIFY
SELECT cf.attribute_code, cf.old_value, cf.new_value, cf.new_code,
    e.id AS enum_value_id, e.product_attribute_enum_value_code AS assigned_code,
    EXISTS (SELECT 1 FROM product_attribute_enum_value stale
             WHERE stale.product_attribute_id = e.product_attribute_id AND stale.value = cf.old_value) AS old_value_still_present
FROM step2_spelling_fixes cf
JOIN product_attribute pa ON pa.attribute_code = cf.attribute_code
JOIN product_attribute_enum_value e ON e.product_attribute_id = pa.id AND e.value = cf.new_value
ORDER BY cf.attribute_code, cf.old_value;