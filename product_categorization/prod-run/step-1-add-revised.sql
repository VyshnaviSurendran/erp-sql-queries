-- ============================================================================
-- PROD 1/4 -- Case fixes, spelling fixes (+ product names / template codes that carry a
-- renamed code), new values, enable the styles the Excel uses.
--
-- Run after nothing (first file).
-- Open in a new pgAdmin Query Tool tab (Auto commit ON), select nothing,
-- press F5 once. One transaction: all of it is saved, or (on any error)
-- none of it -- then run ROLLBACK; in that tab and send the error.
-- Generated from product-attrib/add_revised_collections_and_styles.sql without its CHECK/VERIFY queries.
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1 — casing/spacing-only renames. Enum id unchanged, so no product or
-- template repointing is needed for these; only product_attribute_enum_value
-- itself is touched.
-- ============================================================================

DROP TABLE IF EXISTS step1_case_fixes;

CREATE TEMP TABLE step1_case_fixes (attribute_code text, old_value text, new_value text);

INSERT INTO step1_case_fixes (attribute_code, old_value, new_value) VALUES
    ('COL', 'ITALIAN', 'Italian'),
    ('COL', 'BENGALI', 'Bengali'),
    ('COL', 'BIRTH STONE', 'Birth Stone'),
    ('COL', 'MECHINE', 'Machine'),
    ('STL', 'Rosary ', 'Rosary'),
    ('STL', 'NET', 'Net'),
    ('STL', 'CHARMS', 'Charms'),
    ('STL', 'CHETH', 'Cheth'),
    ('STL', 'HIGHWAY', 'Highway'),
    ('STL', 'PARASPARAM RODIUM', 'Parasparam Rodium'),
    ('STL', 'TIGHT ARANJAL', 'Tight Aranjal'),
    ('STL', 'NAKASHI', 'Nakashi'),
    ('STL', 'THREAD', 'Thread'),
    ('STL', 'HALF ROUND ENAMEL', 'Half Round Enamel'),
    ('STL', 'HALF ROUND STONE', 'Half Round Stone'),
    ('STL', 'PIPE', 'Pipe'),
    ('STL', 'PIPE ENAMEL', 'Pipe Enamel'),
    ('STL', 'LAKSHMI STONE', 'Lakshmi Stone'),
    ('STL', 'EYE', 'Eye'),
    ('STL', 'JAGUAR', 'Jaguar'),
    ('STL', 'LEAF', 'Leaf'),
    ('STL', 'SIMBA', 'Simba'),
    ('STL', 'CLOSED SETTING', 'Closed Setting'),
    ('STL', 'SCREW ENAMEL', 'Screw Enamel'),
    ('STL', 'CLUSTER', 'Cluster'),
    ('STL', 'OPEN CLOSE SETTING', 'Open Close Setting'),
    ('STL', 'FILIGREE', 'Filigree'),
    ('STL', 'GEMSTONE', 'Gemstone'),
    ('STL', 'BELVERY', 'Belvery'),
    ('STL', 'LAKSHMI CORAL', 'Lakshmi Coral'),
    ('STL', 'RAVA', 'Rava'),
    ('STL', 'DRISHYAM', 'Drishyam'),
    ('STL', 'DRISHYAM ENAMEL', 'Drishyam Enamel'),
    ('STL', 'PIRIYAN PIPE', 'Piriyan Pipe'),
    ('STL', 'SOLID RODIUM', 'Solid Rodium'),
    ('STL', 'SQUARE OPEN', 'Square Open'),
    ('STL', 'SQUARE PIPE RODIUM', 'Square Pipe Rodium'),
    ('STL', 'RADHA KRISHNA', 'Radha Krishna'),
    ('STL', 'MEENAKSHI', 'Meenakshi'),
    ('STL', 'PEACOCK', 'Peacock'),
    ('STL', 'RAM PARIVAR', 'Ram Parivar'),
    ('STL', 'CLOSED SETTING GOD', 'Closed Setting God'),
    ('STL', 'SINGAPORE STONE', 'Singapore Stone'),
    ('STL', 'SOLITAIRE', 'Solitaire'),
    ('STL', 'MEHNDI STONE', 'Mehndi Stone'),
    ('STL', 'BISCUIT', 'Biscuit'),
    ('STL', 'CARTIER', 'Cartier'),
    ('STL', 'CUBAN', 'Cuban'),
    ('STL', 'HOLLOW', 'Hollow'),
    ('STL', 'MEHNDI RODIUM', 'Mehndi Rodium'),
    ('STL', 'NAVABI', 'Navabi'),
    ('STL', 'NEW MAGIC', 'New Magic'),
    ('STL', 'JADAU', 'Jadau'),
    ('STL', 'CERA', 'Cera'),
    ('STL', 'CUPOD', 'Cupod'),
    ('STL', 'FLORA', 'Flora'),
    ('STL', 'YIN-YANG', 'Yin-Yang'),
    ('STL', 'KARINGALI', 'Karingali'),
    ('STL', 'SANDAL BRACELET', 'Sandal Bracelet'),
    ('STL', 'MADRASI SP', 'Madrasi Sp'),
    ('STL', 'MEHNDI PLAIN', 'Mehndi Plain'),
    ('STL', 'RAINBOW', 'Rainbow'),
    ('STL', 'SITA RAM', 'Sita Ram'),
    ('STL', 'TENNIS', 'Tennis'),
    ('STL', 'DELUXE', 'Deluxe'),
    ('STL', 'TURKISH SPECIAL', 'Turkish Special'),
    ('STL', 'MADHIRA', 'Madhira'),
    ('STL', 'MADHIRA CUTTING', 'Madhira Cutting'),
    ('STL', 'NAVABI KATTA', 'Navabi Katta'),
    ('STL', 'ANUSHKA', 'Anushka'),
    ('STL', 'BAHUBALI', 'Bahubali'),
    ('STL', 'BALL BASHA', 'Ball Basha'),
    ('STL', 'BASHA', 'Basha'),
    ('STL', 'BATTANI', 'Battani'),
    ('STL', 'BATTANI LAYER', 'Battani Layer'),
    ('STL', 'BATTANI MIX', 'Battani Mix'),
    ('STL', 'BATTANI MIX LAYER', 'Battani Mix Layer'),
    ('STL', 'BULB', 'Bulb'),
    ('STL', 'BULB LAYER', 'Bulb Layer'),
    ('STL', 'CHANDRAMUKHI', 'Chandramukhi'),
    ('STL', 'GENTLEMAN', 'Gentleman'),
    ('STL', 'HEART', 'Heart'),
    ('STL', 'HOLLOW CBT', 'Hollow Cbt'),
    ('STL', 'IPL', 'Ipl'),
    ('STL', 'IPL CUTTING', 'Ipl Cutting'),
    ('STL', 'KATTAPPA', 'Kattappa'),
    ('STL', 'MUDICHI THARA', 'Mudichi Thara'),
    ('STL', 'MUGAPPU LAKSHMI', 'Mugappu Lakshmi'),
    ('STL', 'MUGAPPU LAKSHMI STONE', 'Mugappu Lakshmi Stone'),
    ('STL', 'MUGAPPU PEACOCK', 'Mugappu Peacock'),
    ('STL', 'MULLBERRY', 'Mullberry'),
    ('STL', 'PYRAMID', 'Pyramid'),
    ('STL', 'PYRAMID MIX', 'Pyramid Mix'),
    ('STL', 'SQUARE ROPE', 'Square Rope'),
    ('STL', 'THALI KODI', 'Thali Kodi'),
    ('STL', 'TYRE', 'Tyre'),
    ('STL', 'TYRE LAYER', 'Tyre Layer'),
    ('STL', 'TYRE MIX', 'Tyre Mix'),
    ('STL', 'TYRE MIX LAYER', 'Tyre Mix Layer'),
    ('STL', 'BALL-URI KATTA', 'Ball-Uri Katta'),
    ('STL', 'DHRUVAM', 'Dhruvam'),
    ('STL', 'DISCO', 'Disco'),
    ('STL', 'DOUBLE SIDE KUMALA', 'Double Side Kumala'),
    ('STL', 'GOPURAM', 'Gopuram'),
    ('STL', 'INDIAN RUPEE', 'Indian Rupee'),
    ('STL', 'KANAKA MALA', 'Kanaka Mala'),
    ('STL', 'KILUKKAM', 'Kilukkam'),
    ('STL', 'MOGAMBO', 'Mogambo'),
    ('STL', 'MONKEYPEN', 'Monkeypen'),
    ('STL', 'NEELA THAMARA', 'Neela Thamara'),
    ('STL', 'ONE SIDE KUMALA', 'One Side Kumala'),
    ('STL', 'OVAL KANNI', 'Oval Kanni'),
    ('STL', 'PARASPARAM PLAIN', 'Parasparam Plain'),
    ('STL', 'PUZHU S', 'Puzhu S'),
    ('STL', 'SQUARE SUNDARI', 'Square Sundari'),
    ('STL', 'THARA', 'Thara'),
    ('STL', 'URI-KATTA', 'Uri-Katta'),
    ('STL', 'MC GF SPECIAL', 'Mc Gf Special'),
    ('STL', 'BOXCHAIN ROSE GOLD', 'Boxchain Rose Gold'),
    ('STL', 'BOXCHAIN YELLOW GOLD', 'Boxchain Yellow Gold'),
    ('STL', 'KAJU KATLI', 'Kaju Katli'),
    ('STL', 'ADDIGAI', 'Addigai'),
    ('STL', 'PADAKKA', 'Padakka'),
    ('STL', 'PEARL MALA', 'Pearl Mala'),
    ('STL', 'CLASSIC', 'Classic'),
    ('STL', 'AVIL MALA', 'Avil Mala'),
    ('STL', 'MANDAKASARA', 'Mandakasara'),
    ('STL', 'MOHANMALA', 'Mohanmala'),
    ('STL', 'NAVARATNA MALA', 'Navaratna Mala'),
    ('STL', 'STONE MALA', 'Stone Mala'),
    ('STL', 'CRYSTAL', 'Crystal'),
    ('STL', 'KASUMALA STONE', 'Kasumala Stone'),
    ('STL', 'MATTE', 'Matte'),
    ('STL', 'MATTE STONE', 'Matte Stone'),
    ('STL', 'MULLAMUTTU STONE', 'Mullamuttu Stone'),
    ('STL', 'PALAKKA THREAD LOCKET', 'Palakka Thread Locket'),
    ('STL', 'THREAD LOCKET GOD', 'Thread Locket God'),
    ('STL', 'BALAJI', 'Balaji'),
    ('STL', 'KANTI', 'Kanti'),
    ('STL', 'RED SANDAL SP', 'Red Sandal Sp'),
    ('STL', 'RUDRAKSHAM SP', 'Rudraksham Sp'),
    ('STL', 'TRADITIONAL THREAD LOCKET PALAKKA', 'Traditional Thread Locket Palakka'),
    ('STL', 'BUGADI', 'Bugadi'),
    ('STL', 'J TYPE', 'J Type'),
    ('STL', 'SANIYA', 'Saniya'),
    ('STL', 'SINGLE STONE', 'Single Stone'),
    ('STL', 'STAR', 'Star'),
    ('STL', 'SWASTIK', 'Swastik'),
    ('STL', 'ARASA ILLAI THALI', 'Arasa Illai Thali'),
    ('STL', 'LAKSHMI COIN', 'Lakshmi Coin'),
    ('STL', 'LAKSHMI DOLLAR', 'Lakshmi Dollar'),
    ('STL', 'MANGO STONE THALI', 'Mango Stone Thali'),
    ('STL', 'MANJIMA GOD', 'Manjima God'),
    ('STL', 'OHM DOLLAR', 'Ohm Dollar'),
    ('STL', 'PEACOCK THALI', 'Peacock Thali'),
    ('STL', 'PEARL THALI', 'Pearl Thali'),
    ('STL', 'PILLAYAR THALI', 'Pillayar Thali'),
    ('STL', 'POTTU THALI', 'Pottu Thali'),
    ('STL', 'SILLUVAI DOLLAR', 'Silluvai Dollar'),
    ('STL', 'SILUVAI THALI', 'Siluvai Thali'),
    ('STL', 'SOKKAR MEENAKSHI THALI', 'Sokkar Meenakshi Thali'),
    ('STL', 'URUTTU POTHARAM', 'Uruttu Potharam'),
    ('STL', 'TANMANIYA', 'Tanmaniya'),
    ('STL', 'TIGER NAIL', 'Tiger Nail'),
    ('STL', 'DISCO KASU', 'Disco Kasu'),
    ('STL', 'MYSUR THALI', 'Mysur Thali'),
    ('STL', 'KERALA FANCY', 'Kerala Fancy'),
    ('STL', 'KUMBALA OHM THALI', 'Kumbala Ohm Thali'),
    ('STL', 'KUMBALA PLAIN THALI', 'Kumbala Plain Thali'),
    ('STL', 'MANJIMA CROSS', 'Manjima Cross'),
    ('STL', 'MANJIMA GURUVAYURAPPAN', 'Manjima Guruvayurappan'),
    ('STL', 'MANJIMA JESUS', 'Manjima Jesus'),
    ('STL', 'MANJIMA KRISHNA', 'Manjima Krishna'),
    ('STL', 'MANJIMA LAKSHMI', 'Manjima Lakshmi'),
    ('STL', 'MANJIMA OM', 'Manjima Om'),
    ('STL', 'MANJIMA SARASWATHI', 'Manjima Saraswathi'),
    ('STL', 'PIPE CROSS', 'Pipe Cross'),
    ('STL', 'SLEEVA CROSS', 'Sleeva Cross'),
    ('STL', 'SLEEVA THALI', 'Sleeva Thali'),
    ('STL', 'SOLID CROSS', 'Solid Cross'),
    ('STL', 'FISH', 'Fish'),
    ('STL', 'GANDABERUNDA', 'Gandaberunda'),
    ('STL', 'WATTI', 'Watti'),
    ('STL', 'HANGING THALI', 'Hanging Thali'),
    ('STL', 'THALI', 'Thali'),
    ('STL', 'VANGI CLOSED SETTING', 'Vangi Closed Setting'),
    ('STL', 'PIE-CUT', 'Pie-Cut'),
    ('STL', 'KATTI TV', 'Katti Tv'),
    ('STL', 'MINCHI PIPE', 'Minchi Pipe'),
    ('STL', 'COUPLE', 'Couple'),
    ('STL', 'VANGI STONE', 'Vangi Stone'),
    ('STL', 'CHAND BALI STONE', 'Chand Bali Stone'),
    ('STL', 'BALI', 'Bali'),
    ('STL', 'CHAND BALI ENAMEL', 'Chand Bali Enamel'),
    ('STL', 'CHAND BALI GOD', 'Chand Bali God'),
    ('STL', 'CHAND BALI LAKSHMI', 'Chand Bali Lakshmi'),
    ('STL', 'CHAND BALI NAKSHI', 'Chand Bali Nakshi'),
    ('STL', 'CHAND BALI RAM PARIVAR', 'Chand Bali Ram Parivar');

UPDATE product_attribute_enum_value e
SET value = cf.new_value
FROM step1_case_fixes cf
JOIN product_attribute pa ON pa.attribute_code = cf.attribute_code
WHERE e.product_attribute_id = pa.id
  AND e.value = cf.old_value
  AND NOT EXISTS (SELECT 1 FROM product_attribute_enum_value other
                   WHERE other.product_attribute_id = e.product_attribute_id
                     AND LOWER(other.value) = LOWER(cf.new_value) AND other.id <> e.id);

-- ============================================================================
-- STEP 2 — spelling corrections. Same mechanics as Step 1, but the "corrected"
-- value is a genuine misspelling fix rather than a case fix. Each entry here
-- passed a stricter check: the old spelling is never kept as-is elsewhere, and
-- the correction doesn't collide with an unrelated old value that also
-- resolves to the same target (that pattern signals a real merge, not a
-- spelling fix — e.g. Collection 'HERITAGE'->'Moulding' and Style
-- 'Platinum Fusion'->'Fusion' were excluded for exactly this reason; they're
-- handled by Step 4 instead).
-- ============================================================================

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

-- ============================================================================
-- STEP 3 — create genuinely new Collection/Style enum values. Only creates
-- rows; does not repoint any product/template (that's Step 4).
-- ============================================================================
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

UPDATE product_attribute_enum_value e
SET is_enabled = true
FROM step3b_enable_styles s
WHERE e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'STL')
  AND LOWER(e.value) = LOWER(s.value)
  AND e.is_enabled = false;

COMMIT;