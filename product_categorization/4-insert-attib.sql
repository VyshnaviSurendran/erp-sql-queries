DROP TABLE IF EXISTS step3_new_values;
CREATE TEMP TABLE step3_new_values (attribute_code text, value text, code text);
INSERT INTO step3_new_values (attribute_code, value, code) VALUES
    ('COL', 'Karnataka Traditional', 109),
    ('COL', 'Tamil Traditional', 108),
    ('STL', 'CNC Cutting', 'CNT'),
    ('STL', 'Cocktail', 'CKT'),
    ('STL', 'Fusion', 'FSN'),
    ('STL', 'Nellore Bali', 'NLB'),
    ('STL', 'Nellore Chand Bali', 'NCB'),
    ('STL', 'Nellore God', 'NLG'),
    ('STL', 'Nellore Jimkka', 'NLJ'),
    ('STL', 'Nellore Jimkka God', 'NJG'),
    ('STL', 'Nellore Jimkka Lakshmi', 'NJL'),
    ('STL', 'Nellore Lakshmi', 'NLL'),
    ('STL', 'Nellore Nakashi', 'NLN'),
    ('STL', 'Rhodium CNC Cutting', 'RCC'),
    ('STL', 'Savariya', 'SVR');

SELECT
    nv.attribute_code, nv.value, nv.code,
    e.id AS enum_value_id, (e.id IS NOT NULL) AS already_exists,
    EXISTS (
        SELECT 1 FROM product_attribute_enum_value other
        WHERE other.product_attribute_id = pa.id
          AND LOWER(other.product_attribute_enum_value_code) = LOWER(nv.code)
    ) AS code_already_taken
FROM step3_new_values nv
JOIN product_attribute pa ON pa.attribute_code = nv.attribute_code
LEFT JOIN product_attribute_enum_value e ON e.product_attribute_id = pa.id AND LOWER(e.value) = LOWER(nv.value)
ORDER BY nv.attribute_code, nv.value;

-- INSERT
BEGIN;
INSERT INTO product_attribute_enum_value (product_attribute_id, value, product_attribute_enum_value_code)
SELECT
    pa.id, nv.value,
    COALESCE(nv.code, (100000 + floor(random() * 900000))::int::text)
FROM step3_new_values nv
JOIN product_attribute pa ON pa.attribute_code = nv.attribute_code
WHERE NOT EXISTS (SELECT 1 FROM product_attribute_enum_value e
                   WHERE e.product_attribute_id = pa.id AND LOWER(e.value) = LOWER(nv.value))
  AND (nv.code IS NULL OR NOT EXISTS (
      SELECT 1 FROM product_attribute_enum_value other
      WHERE other.product_attribute_id = pa.id
        AND LOWER(other.product_attribute_enum_value_code) = LOWER(nv.code)
  ));
COMMIT;

-- VERIFY
SELECT nv.attribute_code, nv.value, nv.code, e.id AS enum_value_id, e.product_attribute_enum_value_code AS assigned_code
FROM step3_new_values nv
JOIN product_attribute pa ON pa.attribute_code = nv.attribute_code
LEFT JOIN product_attribute_enum_value e ON e.product_attribute_id = pa.id AND LOWER(e.value) = LOWER(nv.value)
ORDER BY nv.attribute_code, nv.value;


-- enable product attribute enum value which are already disabled but included in sheet
DROP TABLE IF EXISTS step3b_enable_styles;
CREATE TEMP TABLE step3b_enable_styles (value text);
INSERT INTO step3b_enable_styles (value) VALUES
    ('Baby'), ('Beeds'), ('Cbt'), ('Cheth'), ('Elas'), ('Kerala'), ('Kerala Fancy'),
    ('Madrasi Sp'), ('Moulding'), ('Moulding Stone'), ('Nagas'), ('Navaratna Oval'),
    ('Nellore'), ('Oval'), ('Red Sandal Sp'), ('Rudraksham Sp'), ('Semi Nagas'),
    ('Semi Turkish'), ('Signity'), ('Singapore'), ('Singapore Stone'), ('Thali God'),
    ('Thali Plain'), ('Traditional'), ('Traditional thread locket'),
    ('Traditional Thread Locket Palakka'), ('Turkish'), ('Turkish Special'), ('Turkish stone');

-- CHECK -- expect 29 rows, currently_enabled = false. A value missing here
-- doesn't exist under that exact spelling (investigate before running UPDATE).
SELECT s.value, e.id AS enum_value_id, e.is_enabled AS currently_enabled
FROM step3b_enable_styles s
LEFT JOIN product_attribute_enum_value e
    ON e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'STL')
   AND LOWER(e.value) = LOWER(s.value)
ORDER BY s.value;

-- UPDATE
BEGIN;
UPDATE product_attribute_enum_value e
SET is_enabled = true
FROM step3b_enable_styles s
WHERE e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'STL')
  AND LOWER(e.value) = LOWER(s.value)
  AND e.is_enabled = false;
COMMIT;

-- VERIFY -- expect 0 rows.
SELECT s.value
FROM step3b_enable_styles s
WHERE NOT EXISTS (
    SELECT 1 FROM product_attribute_enum_value e
    WHERE e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'STL')
      AND LOWER(e.value) = LOWER(s.value) AND e.is_enabled = true
);
