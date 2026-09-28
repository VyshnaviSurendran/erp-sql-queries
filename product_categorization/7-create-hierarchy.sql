-- ============================================================================
-- STEP 1 -- Category -> Type 
-- ============================================================================

DROP TABLE IF EXISTS hier_category_type;
CREATE TEMP TABLE hier_category_type (child_value text, parent_value text);
INSERT INTO hier_category_type (child_value, parent_value) VALUES
    ('Anklet', 'Gold 14K'),
    ('Anklet', 'Gold 18K'),
    ('Anklet', 'Gold 22k'),
    ('Anklet', 'Precious'),
    ('Back Chain', 'Gold 18K'),
    ('Bangle', 'Diamond'),
    ('Bangle', 'Gold 18K'),
    ('Bangle', 'Gold 22k'),
    ('Bangle', 'Platinum'),
    ('Bangle', 'Polki'),
    ('Bangle', 'Precious'),
    ('Bangle', 'Uncut'),
    ('Bracelet', 'Diamond'),
    ('Bracelet', 'Gold 14K'),
    ('Bracelet', 'Gold 18K'),
    ('Bracelet', 'Gold 22k'),
    ('Bracelet', 'Platinum'),
    ('Bracelet', 'Polki'),
    ('Bracelet', 'Precious'),
    ('Bracelet', 'Uncut'),
    ('Chain', 'Gold 18K'),
    ('Chain', 'Gold 22k'),
    ('Chain', 'Platinum'),
    ('Chutti', 'Diamond'),
    ('Chutti', 'Gold 18K'),
    ('Chutti', 'Gold 22k'),
    ('Chutti', 'Polki'),
    ('Chutti', 'Precious'),
    ('Chutti', 'Uncut'),
    ('Hip Chain', 'Gold 22k'),
    ('Idols', 'Gold 22k'),
    ('Matti Chain', 'Gold 22k'),
    ('Matti Chain', 'Precious'),
    ('Necklace', 'Diamond'),
    ('Necklace', 'Gold 14K'),
    ('Necklace', 'Gold 18K'),
    ('Necklace', 'Gold 22k'),
    ('Necklace', 'Platinum'),
    ('Necklace', 'Polki'),
    ('Necklace', 'Precious'),
    ('Necklace', 'Uncut'),
    ('Nose Pin', 'Diamond'),
    ('Nose Pin', 'Gold 18K'),
    ('Nose Pin', 'Precious'),
    ('Odiyyanam', 'Diamond'),
    ('Odiyyanam', 'Gold 18K'),
    ('Odiyyanam', 'Gold 22k'),
    ('Odiyyanam', 'Precious'),
    ('Odiyyanam', 'Uncut'),
    ('Ovel Bracelet', 'Diamond'),
    ('Ovel Bracelet', 'Gold 14K'),
    ('Ovel Bracelet', 'Gold 18K'),
    ('Ovel Bracelet', 'Platinum'),
    ('Ovel Bracelet', 'Polki'),
    ('Ovel Bracelet', 'Precious'),
    ('Ovel Bracelet', 'Uncut'),
    ('Pendant', 'Diamond'),
    ('Pendant', 'Gold 14K'),
    ('Pendant', 'Gold 18K'),
    ('Pendant', 'Gold 22k'),
    ('Pendant', 'Platinum'),
    ('Pendant', 'Polki'),
    ('Pendant', 'Precious'),
    ('Pendant', 'Uncut'),
    ('Ring', 'Diamond'),
    ('Ring', 'Gold 14K'),
    ('Ring', 'Gold 18K'),
    ('Ring', 'Gold 22k'),
    ('Ring', 'Platinum'),
    ('Ring', 'Polki'),
    ('Ring', 'Precious'),
    ('Ring', 'Uncut'),
    ('Stud', 'Diamond'),
    ('Stud', 'Gold 14K'),
    ('Stud', 'Gold 18K'),
    ('Stud', 'Gold 22k'),
    ('Stud', 'Platinum'),
    ('Stud', 'Polki'),
    ('Stud', 'Precious'),
    ('Stud', 'Uncut');

-- INSERT
BEGIN;
INSERT INTO product_attribute_enum_hierarchy (product_attribute_enum_value_id, parent_product_attribute_enum_value_id)
SELECT DISTINCT child_e.id, parent_e.id
FROM hier_category_type t
JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'CTY')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'TYP')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
ON CONFLICT (product_attribute_enum_value_id, parent_product_attribute_enum_value_id) DO NOTHING;
COMMIT;

-- VERIFY -- re-run the CHECK query above (0 rows expected); the query below
-- should return 0 for missing_pairs.
SELECT COUNT(*) AS missing_pairs
FROM hier_category_type t
JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'CTY')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'TYP')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
WHERE NOT EXISTS (
    SELECT 1 FROM product_attribute_enum_hierarchy h
    WHERE h.product_attribute_enum_value_id = child_e.id
      AND h.parent_product_attribute_enum_value_id = parent_e.id
);

-- SHOW INSERTED -- lists the actual product_attribute_enum_hierarchy rows
-- for this step's pairs (80 rows expected).
SELECT
    h.id AS hierarchy_edge_id,
    child_e.id AS child_id, child_e.value AS child_value,
    parent_e.id AS parent_id, parent_e.value AS parent_value
FROM hier_category_type t
JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'CTY')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'TYP')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
JOIN product_attribute_enum_hierarchy h
    ON h.product_attribute_enum_value_id = child_e.id
   AND h.parent_product_attribute_enum_value_id = parent_e.id
ORDER BY child_value, parent_value;

-- ============================================================================
-- STEP 2 -- Collection -> Category edges (199 distinct pair
-- ============================================================================

DROP TABLE IF EXISTS hier_collection_category;
CREATE TEMP TABLE hier_collection_category (child_value text, parent_value text);
INSERT INTO hier_collection_category (child_value, parent_value) VALUES
    ('14 Kt Ornaments', 'Bracelet'),
    ('14 Kt Ornaments', 'Necklace'),
    ('14 Kt Ornaments', 'Pendant'),
    ('14 Kt Ornaments', 'Ring'),
    ('14 Kt Ornaments', 'Stud'),
    ('18 Karat', 'Anklet'),
    ('18 Karat', 'Back Chain'),
    ('18 Karat', 'Bangle'),
    ('18 Karat', 'Bracelet'),
    ('18 Karat', 'Chain'),
    ('18 Karat', 'Necklace'),
    ('18 Karat', 'Nose Pin'),
    ('18 Karat', 'Ovel Bracelet'),
    ('18 Karat', 'Pendant'),
    ('18 Karat', 'Ring'),
    ('18 Karat', 'Stud'),
    ('Antique', 'Bangle'),
    ('Antique', 'Bracelet'),
    ('Antique', 'Chutti'),
    ('Antique', 'Matti Chain'),
    ('Antique', 'Necklace'),
    ('Antique', 'Pendant'),
    ('Antique', 'Ring'),
    ('Antique', 'Stud'),
    ('Bengali', 'Necklace'),
    ('Birth Stone', 'Pendant'),
    ('Birth Stone', 'Ring'),
    ('Bombay', 'Anklet'),
    ('Bombay', 'Bangle'),
    ('Bombay', 'Bracelet'),
    ('Bombay', 'Chain'),
    ('Bombay', 'Chutti'),
    ('Bombay', 'Matti Chain'),
    ('Bombay', 'Necklace'),
    ('Bombay', 'Pendant'),
    ('Bombay', 'Ring'),
    ('Bombay', 'Stud'),
    ('Chettinadu', 'Bangle'),
    ('Chettinadu', 'Necklace'),
    ('Chettinadu', 'Ring'),
    ('Chettinadu', 'Stud'),
    ('Cnc', 'Bangle'),
    ('Coimbatore', 'Bangle'),
    ('Coimbatore', 'Bracelet'),
    ('Coimbatore', 'Chain'),
    ('Coimbatore', 'Matti Chain'),
    ('Coimbatore', 'Necklace'),
    ('Coimbatore', 'Pendant'),
    ('Coimbatore', 'Ring'),
    ('Coimbatore', 'Stud'),
    ('Italian', 'Anklet'),
    ('Italian', 'Back Chain'),
    ('Italian', 'Bracelet'),
    ('Italian', 'Chain'),
    ('Italian', 'Necklace'),
    ('Italian', 'Ovel Bracelet'),
    ('Italian', 'Pendant'),
    ('Italian', 'Ring'),
    ('Italian', 'Stud'),
    ('Karnataka', 'Bangle'),
    ('Karnataka', 'Bracelet'),
    ('Karnataka', 'Chain'),
    ('Karnataka', 'Necklace'),
    ('Karnataka', 'Pendant'),
    ('Karnataka', 'Stud'),
    ('Karnataka Traditional', 'Bangle'),
    ('Karnataka Traditional', 'Necklace'),
    ('Karnataka Traditional', 'Pendant'),
    ('Karnataka Traditional', 'Ring'),
    ('Karnataka Traditional', 'Stud'),
    ('Kerala', 'Anklet'),
    ('Kerala', 'Bangle'),
    ('Kerala', 'Bracelet'),
    ('Kerala', 'Chain'),
    ('Kerala', 'Hip Chain'),
    ('Kerala', 'Matti Chain'),
    ('Kerala', 'Necklace'),
    ('Kerala', 'Pendant'),
    ('Kerala', 'Ring'),
    ('Kerala', 'Stud'),
    ('Kerala Special', 'Chain'),
    ('Kerala Traditional', 'Anklet'),
    ('Kerala Traditional', 'Bangle'),
    ('Kerala Traditional', 'Bracelet'),
    ('Kerala Traditional', 'Chain'),
    ('Kerala Traditional', 'Necklace'),
    ('Kerala Traditional', 'Pendant'),
    ('Kerala Traditional', 'Ring'),
    ('Kerala Traditional', 'Stud'),
    ('Kolkata', 'Bangle'),
    ('Kolkata', 'Bracelet'),
    ('Kolkata', 'Chutti'),
    ('Kolkata', 'Matti Chain'),
    ('Kolkata', 'Necklace'),
    ('Kolkata', 'Pendant'),
    ('Kolkata', 'Ring'),
    ('Kolkata', 'Stud'),
    ('MADRASI', 'Bracelet'),
    ('Moulding', 'Anklet'),
    ('Moulding', 'Bangle'),
    ('Moulding', 'Bracelet'),
    ('Moulding', 'Chain'),
    ('Moulding', 'Chutti'),
    ('Moulding', 'Matti Chain'),
    ('Moulding', 'Necklace'),
    ('Moulding', 'Nose Pin'),
    ('Moulding', 'Odiyyanam'),
    ('Moulding', 'Ovel Bracelet'),
    ('Moulding', 'Pendant'),
    ('Moulding', 'Ring'),
    ('Moulding', 'Stud'),
    ('Nagas', 'Bangle'),
    ('Nagas', 'Bracelet'),
    ('Nagas', 'Chain'),
    ('Nagas', 'Chutti'),
    ('Nagas', 'Matti Chain'),
    ('Nagas', 'Necklace'),
    ('Nagas', 'Odiyyanam'),
    ('Nagas', 'Ovel Bracelet'),
    ('Nagas', 'Pendant'),
    ('Nagas', 'Ring'),
    ('Nagas', 'Stud'),
    ('Navaratna Jewellery', 'Bracelet'),
    ('Navaratna Jewellery', 'Nose Pin'),
    ('Navaratna Jewellery', 'Ovel Bracelet'),
    ('Navaratna Jewellery', 'Pendant'),
    ('Navaratna Jewellery', 'Ring'),
    ('Navaratna Jewellery', 'Stud'),
    ('Ovel Bracelet', 'Bracelet'),
    ('Platinum', 'Bangle'),
    ('Platinum', 'Bracelet'),
    ('Platinum', 'Chain'),
    ('Platinum', 'Necklace'),
    ('Platinum', 'Ovel Bracelet'),
    ('Platinum', 'Pendant'),
    ('Platinum', 'Ring'),
    ('Platinum', 'Stud'),
    ('Polki', 'Bangle'),
    ('Polki', 'Bracelet'),
    ('Polki', 'Chutti'),
    ('Polki', 'Necklace'),
    ('Polki', 'Ovel Bracelet'),
    ('Polki', 'Pendant'),
    ('Polki', 'Ring'),
    ('Polki', 'Stud'),
    ('Precious', 'Anklet'),
    ('Precious', 'Bangle'),
    ('Precious', 'Bracelet'),
    ('Precious', 'Nose Pin'),
    ('Precious', 'Ovel Bracelet'),
    ('Precious', 'Pendant'),
    ('Precious', 'Ring'),
    ('Precious', 'Stud'),
    ('Rajkot', 'Anklet'),
    ('Rajkot', 'Bangle'),
    ('Rajkot', 'Bracelet'),
    ('Rajkot', 'Chain'),
    ('Rajkot', 'Necklace'),
    ('Rajkot', 'Pendant'),
    ('Rajkot', 'Ring'),
    ('Rajkot', 'Stud'),
    ('Semi Antique', 'Bangle'),
    ('Semi Antique', 'Bracelet'),
    ('Semi Antique', 'Necklace'),
    ('Semi Antique', 'Pendant'),
    ('Semi Antique', 'Stud'),
    ('Semi Nagas', 'Bangle'),
    ('Semi Nagas', 'Necklace'),
    ('Semi Turkish', 'Necklace'),
    ('Semi Turkish', 'Stud'),
    ('SIGNITY', 'Bangle'),
    ('SIGNITY', 'Necklace'),
    ('SIGNITY', 'Pendant'),
    ('SIGNITY', 'Ring'),
    ('SIGNITY', 'Stud'),
    ('Singapore', 'Anklet'),
    ('Singapore', 'Bangle'),
    ('Singapore', 'Bracelet'),
    ('Singapore', 'Chain'),
    ('Singapore', 'Necklace'),
    ('Singapore', 'Pendant'),
    ('Singapore', 'Ring'),
    ('Singapore', 'Stud'),
    ('Statue Jewellery', 'Idols'),
    ('Tamil Traditional', 'Pendant'),
    ('Turkish', 'Bangle'),
    ('Turkish', 'Bracelet'),
    ('Turkish', 'Chutti'),
    ('Turkish', 'Necklace'),
    ('Turkish', 'Pendant'),
    ('Turkish', 'Ring'),
    ('Turkish', 'Stud'),
    ('Uncut', 'Bangle'),
    ('Uncut', 'Bracelet'),
    ('Uncut', 'Necklace'),
    ('Uncut', 'Ovel Bracelet'),
    ('Uncut', 'Pendant'),
    ('Uncut', 'Ring'),
    ('Uncut', 'Stud');

-- INSERT
BEGIN;
INSERT INTO product_attribute_enum_hierarchy (product_attribute_enum_value_id, parent_product_attribute_enum_value_id)
SELECT DISTINCT child_e.id, parent_e.id
FROM hier_collection_category t
JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'CTY')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
ON CONFLICT (product_attribute_enum_value_id, parent_product_attribute_enum_value_id) DO NOTHING;
COMMIT;

-- VERIFY -- re-run the CHECK query above (0 rows expected); the query below
-- should return 0 for missing_pairs.
SELECT COUNT(*) AS missing_pairs
FROM hier_collection_category t
JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'CTY')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
WHERE NOT EXISTS (
    SELECT 1 FROM product_attribute_enum_hierarchy h
    WHERE h.product_attribute_enum_value_id = child_e.id
      AND h.parent_product_attribute_enum_value_id = parent_e.id
);

-- SHOW INSERTED -- lists the actual product_attribute_enum_hierarchy rows
-- for this step's pairs (199 rows expected).
SELECT
    h.id AS hierarchy_edge_id,
    child_e.id AS child_id, child_e.value AS child_value,
    parent_e.id AS parent_id, parent_e.value AS parent_value
FROM hier_collection_category t
JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'CTY')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
JOIN product_attribute_enum_hierarchy h
    ON h.product_attribute_enum_value_id = child_e.id
   AND h.parent_product_attribute_enum_value_id = parent_e.id
ORDER BY child_value, parent_value;

-- ============================================================================
-- STEP 3 -- Style -> Collection edges (571 distinct pair
-- ============================================================================

DROP TABLE IF EXISTS hier_style_collection;
CREATE TEMP TABLE hier_style_collection (child_value text, parent_value text);
INSERT INTO hier_style_collection (child_value, parent_value) VALUES
    ('14 Karat Ornaments', '14 Kt Ornaments'),
    ('14 Karat Ornaments', 'Ovel Bracelet'),
    ('18 Karat', '18 Karat'),
    ('4S Chain', 'Kerala'),
    ('Addigai', 'Coimbatore'),
    ('Adukku Kasu', 'Coimbatore'),
    ('Adukku Kasu', 'Kerala'),
    ('Adukku Kasu', 'Nagas'),
    ('Alphabet', 'Kerala'),
    ('Alphabet', 'Moulding'),
    ('Anavaal', 'Kerala'),
    ('Anavaal', 'Kerala Traditional'),
    ('Anushka', 'Coimbatore'),
    ('Arasa Illai Thali', 'Coimbatore'),
    ('Avil Mala', 'Karnataka'),
    ('Baby', 'Kerala'),
    ('Back Chain', '18 Karat'),
    ('Bahubali', 'Coimbatore'),
    ('Balaji', 'Nagas'),
    ('Bali', 'Coimbatore'),
    ('Bali', 'Kerala'),
    ('Bali', 'Rajkot'),
    ('Ball Basha', 'Coimbatore'),
    ('Ball Joint', 'Kerala'),
    ('Ball-Uri', 'Coimbatore'),
    ('Ball-Uri', 'Kerala'),
    ('Ball-Uri Katta', 'Kerala'),
    ('Ball-Uri Katti', 'Coimbatore'),
    ('Basha', 'Coimbatore'),
    ('Battani', 'Coimbatore'),
    ('Battani Layer', 'Coimbatore'),
    ('Battani Mix', 'Coimbatore'),
    ('Battani Mix Layer', 'Coimbatore'),
    ('Beeds', 'Rajkot'),
    ('Belvery', 'Karnataka'),
    ('Biscuit', 'Bombay'),
    ('Biscuit', 'Coimbatore'),
    ('Biscuit', 'Singapore'),
    ('Black Beeds', 'Bombay'),
    ('Black Beeds', 'Italian'),
    ('Black Beeds', 'Karnataka'),
    ('Black Beeds', 'Kerala Traditional'),
    ('Black Beeds', 'Rajkot'),
    ('Box Chain', 'Bombay'),
    ('Box Chain', 'Italian'),
    ('Box Chain', 'Kerala'),
    ('Boxchain Rose Gold', 'Bombay'),
    ('Boxchain Yellow Gold', 'Bombay'),
    ('Bugadi', 'Moulding'),
    ('Bulb', 'Coimbatore'),
    ('Bulb Layer', 'Coimbatore'),
    ('Cartier', 'Bombay'),
    ('Casting', 'Moulding'),
    ('Cbt', 'Coimbatore'),
    ('Cbt', 'Kerala Special'),
    ('Celo', 'Kerala'),
    ('Celo Katta', 'Kerala'),
    ('Cera', 'Italian'),
    ('Chakkiri', 'Antique'),
    ('Chand Bali', 'Chettinadu'),
    ('Chand Bali', 'Kolkata'),
    ('Chand Bali Enamel', 'Kolkata'),
    ('Chand Bali God', 'Nagas'),
    ('Chand Bali Lakshmi', 'Nagas'),
    ('Chand Bali Nakshi', 'Nagas'),
    ('Chand Bali Ram Parivar', 'Nagas'),
    ('Chand Bali Stone', 'Chettinadu'),
    ('Chand Bali Stone', 'Kolkata'),
    ('Chandramukhi', 'Coimbatore'),
    ('Charms', 'Italian'),
    ('Charms', 'Moulding'),
    ('Cheth', 'Kerala'),
    ('Christian Thali', 'Kerala Traditional'),
    ('Classic', 'Moulding'),
    ('Closed Setting', 'Coimbatore'),
    ('Closed Setting', 'Moulding'),
    ('Closed Setting', 'SIGNITY'),
    ('Closed Setting God', 'SIGNITY'),
    ('Cluster', 'Moulding'),
    ('CNC', 'Singapore'),
    ('CNC Cutting', 'Bombay'),
    ('Cocktail', 'Chettinadu'),
    ('Coorgi', 'Karnataka'),
    ('Coorgi', 'Karnataka Traditional'),
    ('Coorgi stone', 'Karnataka'),
    ('Coorgi stone', 'Karnataka Traditional'),
    ('Coral', 'Coimbatore'),
    ('Coral', 'Karnataka'),
    ('Coral', 'Karnataka Traditional'),
    ('Coral', 'Kerala'),
    ('Coral', 'Kerala Traditional'),
    ('Couple', 'Moulding'),
    ('Cross', 'Kerala'),
    ('Cross', 'Kerala Traditional'),
    ('Cross', 'Moulding'),
    ('Crystal', 'Kerala'),
    ('Cuban', 'Bombay'),
    ('Cuban', 'Singapore'),
    ('Cupod', 'Italian'),
    ('Curb', 'Coimbatore'),
    ('Dasavatharam', 'Kerala Traditional'),
    ('Deluxe', 'Singapore'),
    ('Designer', 'Moulding'),
    ('Designer', 'Polki'),
    ('Dhruvam', 'Kerala'),
    ('Disco', 'Kerala'),
    ('Disco Kasu', 'Karnataka'),
    ('Don', 'Kerala'),
    ('Double Sachin', 'Kerala'),
    ('Double Sewag', 'Kerala'),
    ('Double Side Kumala', 'Kerala'),
    ('Drishyam', 'Kerala'),
    ('Drishyam Enamel', 'Kerala'),
    ('Dye', 'Kerala'),
    ('Elakkathali', 'Antique'),
    ('Elakkathali', 'Kerala Traditional'),
    ('Elas', 'Kerala'),
    ('Elas Round', 'Kerala'),
    ('Elas Tube', 'Kerala'),
    ('Enamel', 'Antique'),
    ('Enamel', 'Bombay'),
    ('Enamel', 'Cnc'),
    ('Enamel', 'Coimbatore'),
    ('Enamel', 'Kolkata'),
    ('Enamel', 'Moulding'),
    ('Enamel', 'Rajkot'),
    ('Enamel', 'Singapore'),
    ('Ettukanni', 'Kerala'),
    ('Eye', 'Cnc'),
    ('Fancy', '14 Kt Ornaments'),
    ('Fancy', 'Antique'),
    ('Fancy', 'Bombay'),
    ('Fancy', 'Coimbatore'),
    ('Fancy', 'Italian'),
    ('Fancy', 'Kerala'),
    ('Fancy', 'Moulding'),
    ('Fancy', 'Platinum'),
    ('Fancy', 'Polki'),
    ('Fancy', 'Singapore'),
    ('Filigree', 'Moulding'),
    ('Filigree', 'Nagas'),
    ('Filigree', 'Turkish'),
    ('Fish', 'Moulding'),
    ('Flora', 'Italian'),
    ('FLORAL', 'Moulding'),
    ('Flower', 'Bombay'),
    ('Flower', 'Coimbatore'),
    ('Fusion', 'Platinum'),
    ('Gandaberunda', 'Nagas'),
    ('Gemstone', 'Birth Stone'),
    ('Gemstone', 'Moulding'),
    ('Gemstone', 'Nagas'),
    ('Gemstone', 'Turkish'),
    ('Gentleman', 'Coimbatore'),
    ('Gini Buttu', 'Karnataka Traditional'),
    ('God', 'Chettinadu'),
    ('God', 'Cnc'),
    ('God', 'Kerala'),
    ('God', 'Moulding'),
    ('God', 'Nagas'),
    ('Gold Finger', 'Kerala'),
    ('Gopuram', 'Kerala'),
    ('Half Round', 'Bombay'),
    ('Half Round', 'Kerala'),
    ('Half Round Enamel', 'Bombay'),
    ('Half Round Stone', 'Bombay'),
    ('Hanging Thali', 'Moulding'),
    ('Heart', 'Coimbatore'),
    ('Highway', 'Kerala'),
    ('Hollow', 'Bombay'),
    ('Hollow Cbt', 'Coimbatore'),
    ('Hollow Rope', 'Kerala'),
    ('Indian Rupee', 'Kerala'),
    ('Indo Italian', 'Bombay'),
    ('Indo Italian', 'Singapore'),
    ('Ipl', 'Coimbatore'),
    ('Ipl Cutting', 'Coimbatore'),
    ('Islamic Thali', 'Karnataka Traditional'),
    ('J Type', 'Moulding'),
    ('Jadau', 'Polki'),
    ('Jade', 'Karnataka'),
    ('Jade', 'Nagas'),
    ('Jaguar', 'Cnc'),
    ('Jhumka', 'Bombay'),
    ('Jhumka', 'Chettinadu'),
    ('Jhumka', 'Coimbatore'),
    ('Jhumka', 'Kerala'),
    ('Jhumka', 'Kolkata'),
    ('Jhumka', 'Moulding'),
    ('Jhumka Enamel', 'Kolkata'),
    ('Jhumka God', 'Nagas'),
    ('Jhumka Lakshmi', 'Nagas'),
    ('Jhumka Nakshi', 'Nagas'),
    ('Jhumka Ram Parivar', 'Nagas'),
    ('Jhumka Stone', 'Bombay'),
    ('Jhumka Stone', 'Chettinadu'),
    ('Jhumka Stone', 'Coimbatore'),
    ('Jhumka Stone', 'Kolkata'),
    ('Kaasu', 'Karnataka Traditional'),
    ('Kaju Katli', 'Singapore'),
    ('Kanaka Mala', 'Kerala'),
    ('Kanti', 'Nagas'),
    ('Karingali', 'Kerala'),
    ('Karingali', 'Kerala Traditional'),
    ('Karwar', 'Karnataka Traditional'),
    ('Karwar', 'Kerala'),
    ('Kasumala', 'Kerala'),
    ('Kasumala', 'Nagas'),
    ('Kasumala Stone', 'Kerala'),
    ('Kattappa', 'Coimbatore'),
    ('Kattappa', 'Karnataka'),
    ('Katti Ozhukkan', 'Kerala'),
    ('Katti Ozhukkan', 'Moulding'),
    ('Katti Tv', 'Kerala'),
    ('Kerala', 'Kerala'),
    ('Kerala Fancy', 'Kerala'),
    ('Kilukkam', 'Kerala'),
    ('Kumbala Om Thali', 'Kerala'),
    ('Kumbala Plain Thali', 'Kerala'),
    ('Kundan', 'Antique'),
    ('Lakshmi', 'Antique'),
    ('Lakshmi', 'Chettinadu'),
    ('Lakshmi', 'Coimbatore'),
    ('Lakshmi', 'Karnataka Traditional'),
    ('Lakshmi', 'Kerala'),
    ('Lakshmi', 'Kerala Traditional'),
    ('Lakshmi', 'Moulding'),
    ('Lakshmi', 'Nagas'),
    ('Lakshmi', 'Semi Nagas'),
    ('Lakshmi', 'SIGNITY'),
    ('Lakshmi', 'Turkish'),
    ('Lakshmi Coin', 'Coimbatore'),
    ('Lakshmi Coral', 'Karnataka Traditional'),
    ('Lakshmi Dollar', 'Coimbatore'),
    ('Lakshmi Stone', 'Chettinadu'),
    ('Lakshmi Stone', 'Karnataka Traditional'),
    ('Lakshmi Stone', 'Kerala'),
    ('Lakshmi Stone', 'Nagas'),
    ('Lappa', 'Kerala'),
    ('Lappa', 'Turkish'),
    ('Lappa Layer', 'Kerala'),
    ('Layer', 'Moulding'),
    ('Layer', 'Turkish'),
    ('Leaf', 'Cnc'),
    ('Lotus', 'Coimbatore'),
    ('Lotus', 'Kerala'),
    ('M Thali', 'Karnataka Traditional'),
    ('Madhira', 'Bombay'),
    ('Madhira Cutting', 'Bombay'),
    ('Madrasi', 'Bombay'),
    ('Madrasi Sp', 'MADRASI'),
    ('Mandakasara', 'Karnataka Traditional'),
    ('Mangalore Thali', 'Karnataka Traditional'),
    ('Mangalsutra', 'Antique'),
    ('Mangalsutra', 'Bombay'),
    ('Mangalsutra', 'Karnataka Traditional'),
    ('Mangalsutra', 'Kolkata'),
    ('Mangalsutra', 'Moulding'),
    ('Mangalsutra', 'Nagas'),
    ('Mangalsutra', 'Rajkot'),
    ('Mangalsutra', 'Turkish'),
    ('Mango', 'Coimbatore'),
    ('Mango', 'Nagas'),
    ('Mango Palaka', 'Kerala'),
    ('Mango Stone Thali', 'Coimbatore'),
    ('Manikasu', 'Kerala Traditional'),
    ('Manimala', 'Kerala'),
    ('Manjima Cross', 'Kerala'),
    ('Manjima God', 'Coimbatore'),
    ('Manjima God', 'Kerala'),
    ('Manjima Guruvayurappan', 'Kerala'),
    ('Manjima Jesus', 'Kerala'),
    ('Manjima Krishna', 'Kerala'),
    ('Manjima Lakshmi', 'Kerala'),
    ('Manjima Om', 'Kerala'),
    ('Manjima Saraswathi', 'Kerala'),
    ('Matte', 'Coimbatore'),
    ('Matte', 'Kerala'),
    ('Matte Stone', 'Kerala'),
    ('Mc Gf Special', 'Kerala Special'),
    ('Meenakari', 'Antique'),
    ('Meenakshi', 'Moulding'),
    ('Meenakshi', 'Nagas'),
    ('Mehndi Plain', 'Moulding'),
    ('Mehndi Rodium', 'Bombay'),
    ('Mehndi Stone', 'Antique'),
    ('Mehndi Stone', 'Moulding'),
    ('Minchi Pipe', 'Kerala'),
    ('Minnu', 'Kerala'),
    ('Minnu', 'Kerala Traditional'),
    ('Minnu', 'Moulding'),
    ('Mogambo', 'Kerala'),
    ('Mohanmala', 'Karnataka Traditional'),
    ('Monkeypen', 'Kerala'),
    ('Moulding', 'Kerala Traditional'),
    ('Moulding', 'Rajkot'),
    ('Moulding Stone', 'Moulding'),
    ('Mudichi Thara', 'Coimbatore'),
    ('Mugappu', 'Coimbatore'),
    ('Mugappu', 'Moulding'),
    ('Mugappu God', 'Coimbatore'),
    ('Mugappu God', 'Kerala'),
    ('Mugappu God', 'Moulding'),
    ('Mugappu God', 'Nagas'),
    ('Mugappu God', 'Singapore'),
    ('Mugappu Lakshmi', 'Coimbatore'),
    ('Mugappu Lakshmi', 'Moulding'),
    ('Mugappu Lakshmi Stone', 'Coimbatore'),
    ('Mugappu Peacock', 'Coimbatore'),
    ('Mugappu Stone', 'Coimbatore'),
    ('Mugappu Stone', 'Singapore'),
    ('Mulla', 'Kerala'),
    ('Mullamuttu', 'Kerala'),
    ('Mullamuttu Stone', 'Kerala'),
    ('Mullberry', 'Coimbatore'),
    ('Mullberry', 'Kerala'),
    ('Mutharanjanam', 'Kerala'),
    ('Mysore Thali', 'Karnataka Traditional'),
    ('Mysur Thali', 'Karnataka Traditional'),
    ('Nagapadam', 'Kerala'),
    ('Nagas', 'Antique'),
    ('Nagas', 'Moulding'),
    ('Nakashi', 'Antique'),
    ('Nakashi', 'Chettinadu'),
    ('Nakashi', 'Kolkata'),
    ('Nakashi', 'Moulding'),
    ('Nakashi', 'Nagas'),
    ('Nakashi', 'Polki'),
    ('Nakashi', 'Semi Antique'),
    ('Nakashi', 'Semi Nagas'),
    ('Name', 'Kerala'),
    ('Name', 'Kerala Traditional'),
    ('Name', 'Moulding'),
    ('Navabi', 'Bombay'),
    ('Navabi Katta', 'Bombay'),
    ('Navabi Katta', 'Coimbatore'),
    ('Navaratna', 'Moulding'),
    ('Navaratna', 'Nagas'),
    ('Navaratna', 'Navaratna Jewellery'),
    ('Navaratna', 'Polki'),
    ('Navaratna Mala', 'Karnataka'),
    ('Navaratna Oval', 'Navaratna Jewellery'),
    ('Neela Thamara', 'Kerala'),
    ('Nellore', 'Karnataka Traditional'),
    ('Nellore Bali', 'Karnataka Traditional'),
    ('Nellore Chand Bali', 'Karnataka Traditional'),
    ('Nellore God', 'Karnataka Traditional'),
    ('Nellore Jimkka', 'Karnataka Traditional'),
    ('Nellore Jimkka God', 'Karnataka Traditional'),
    ('Nellore Jimkka Lakshmi', 'Karnataka Traditional'),
    ('Nellore Lakshmi', 'Karnataka Traditional'),
    ('Nellore Nakashi', 'Karnataka Traditional'),
    ('Net', 'Bombay'),
    ('New Magic', 'Bombay'),
    ('Ohm Dollar', 'Coimbatore'),
    ('Om', 'Moulding'),
    ('Om Thali', 'Kerala Traditional'),
    ('One Side Kumala', 'Kerala'),
    ('Open Close Setting', 'Moulding'),
    ('Open Close Setting', 'Polki'),
    ('Oval', '14 Kt Ornaments'),
    ('Oval', 'Moulding'),
    ('Oval Kanni', 'Kerala'),
    ('Padakka', 'Coimbatore'),
    ('Paksha Thali', 'Kerala Traditional'),
    ('Palakka', 'Kerala'),
    ('Palakka', 'Kerala Traditional'),
    ('Palakka Thread Locket', 'Kerala'),
    ('Paper Cast', 'Moulding'),
    ('Parantha', 'Kerala'),
    ('Parasparam', 'Rajkot'),
    ('Parasparam Plain', 'Kerala'),
    ('Parasparam Rodium', 'Kerala'),
    ('Parasparam Rodium', 'Rajkot'),
    ('Pathakam', 'Kerala'),
    ('Patly', 'Karnataka'),
    ('Peacock', 'Nagas'),
    ('Peacock Thali', 'Coimbatore'),
    ('Pearl', 'Karnataka'),
    ('Pearl', 'Kerala'),
    ('Pearl Mala', 'Coimbatore'),
    ('Pearl Mala', 'Karnataka'),
    ('Pearl Mala', 'Kerala'),
    ('Pearl Thali', 'Coimbatore'),
    ('Pie-Cut', 'Moulding'),
    ('Pillayar Thali', 'Coimbatore'),
    ('Pipe', 'Bombay'),
    ('Pipe', 'Kerala'),
    ('Pipe', 'Kolkata'),
    ('Pipe Cross', 'Kerala'),
    ('Pipe Enamel', 'Bombay'),
    ('Pipe Enamel', 'Kolkata'),
    ('Pipe Rhodium', 'Bombay'),
    ('Piriyan Pipe', 'Kerala'),
    ('Plain', 'Antique'),
    ('Plain', 'Bengali'),
    ('Plain', 'Bombay'),
    ('Plain', 'Chettinadu'),
    ('Plain', 'Cnc'),
    ('Plain', 'Coimbatore'),
    ('Plain', 'Italian'),
    ('Plain', 'Karnataka'),
    ('Plain', 'Kerala'),
    ('Plain', 'Kolkata'),
    ('Plain', 'Moulding'),
    ('Plain', 'Rajkot'),
    ('Plain', 'Semi Turkish'),
    ('Plain', 'Singapore'),
    ('Plain', 'Turkish'),
    ('Plain Thali', 'Kerala'),
    ('Polla Ozhukkan', 'Kerala'),
    ('Polla Tv', 'Kerala'),
    ('Pottu Thali', 'Coimbatore'),
    ('Precious', 'Precious'),
    ('Precious', 'Uncut'),
    ('Pulimurugan', 'Kerala'),
    ('Punjabi Polla', 'Kerala'),
    ('Punjabi Solid', 'Kerala'),
    ('Puzhu S', 'Kerala'),
    ('Pyramid', 'Coimbatore'),
    ('Pyramid Mix', 'Coimbatore'),
    ('Radha Krishna', 'Moulding'),
    ('Radha Krishna', 'Nagas'),
    ('Rail', 'Kerala'),
    ('Rainbow', 'Moulding'),
    ('Ram Parivar', 'Moulding'),
    ('Ram Parivar', 'Nagas'),
    ('Rava', 'Karnataka'),
    ('Red Sandal', 'Kerala'),
    ('Red Sandal', 'Kerala Traditional'),
    ('Red Sandal Sp', 'Kerala Traditional'),
    ('Rhodium', 'Bengali'),
    ('Rhodium', 'Bombay'),
    ('Rhodium', 'Cnc'),
    ('Rhodium', 'Italian'),
    ('Rhodium', 'Kolkata'),
    ('Rhodium', 'Moulding'),
    ('Rhodium', 'Rajkot'),
    ('Rhodium', 'Semi Turkish'),
    ('Rhodium', 'Singapore'),
    ('Rhodium', 'Turkish'),
    ('Rhodium CNC Cutting', 'Bombay'),
    ('Rosary', 'Kerala'),
    ('Rosary', 'Moulding'),
    ('Rosary', 'Rajkot'),
    ('Round Kurumulak', 'Coimbatore'),
    ('Round Kurumulak', 'Kerala'),
    ('Round Pipe', 'Bombay'),
    ('Round Pipe', 'Kerala'),
    ('Rudraksham', 'Kerala'),
    ('Rudraksham', 'Kerala Traditional'),
    ('Rudraksham Sp', 'Kerala Traditional'),
    ('S-Leaf', 'Coimbatore'),
    ('S-Leaf', 'Kerala'),
    ('Sachin', 'Kerala'),
    ('Sandal Bracelet', 'Kerala'),
    ('Saniya', 'Moulding'),
    ('Savariya', 'Moulding'),
    ('Savariya', 'Precious'),
    ('Savitham', 'Kerala'),
    ('Savitham Katta', 'Coimbatore'),
    ('Savitham Katta', 'Kerala'),
    ('Screw', 'Kolkata'),
    ('Screw Enamel', 'Kolkata'),
    ('Semi Nagas', 'Nagas'),
    ('Semi Turkish', 'Turkish'),
    ('Sewag', 'Kerala'),
    ('Signity', 'Moulding'),
    ('Silluvai Dollar', 'Coimbatore'),
    ('Siluvai Thali', 'Coimbatore'),
    ('Simba', 'Cnc'),
    ('Simba', 'Moulding'),
    ('Simba', 'Singapore'),
    ('Singapore', 'Singapore'),
    ('Singapore Stone', 'Singapore'),
    ('Single Aranjal', 'Kerala'),
    ('Single Stone', 'Moulding'),
    ('Sita Ram', 'Nagas'),
    ('Sleeva Cross', 'Kerala'),
    ('Sleeva Thali', 'Kerala'),
    ('Sokkar Meenakshi Thali', 'Coimbatore'),
    ('Solid', 'Karnataka'),
    ('Solid', 'Kerala'),
    ('Solid Cross', 'Kerala'),
    ('Solid Rodium', 'Kerala'),
    ('Solid Rope', 'Coimbatore'),
    ('Solid Rope', 'Kerala'),
    ('Solitaire', 'Moulding'),
    ('Special', 'Kerala'),
    ('Special', 'Singapore'),
    ('Square Kurumulak', 'Coimbatore'),
    ('Square Kurumulak', 'Kerala'),
    ('Square Open', 'Kerala'),
    ('Square Pipe', 'Kerala'),
    ('Square Pipe Rodium', 'Kerala'),
    ('Square Rope', 'Coimbatore'),
    ('Square Sundari', 'Kerala'),
    ('Star', 'Moulding'),
    ('Statue', 'Statue Jewellery'),
    ('Stone', 'Antique'),
    ('Stone', 'Bengali'),
    ('Stone', 'Bombay'),
    ('Stone', 'Cnc'),
    ('Stone', 'Coimbatore'),
    ('Stone', 'Italian'),
    ('Stone', 'Karnataka'),
    ('Stone', 'Kerala'),
    ('Stone', 'Kolkata'),
    ('Stone', 'Moulding'),
    ('Stone', 'Nagas'),
    ('Stone', 'Rajkot'),
    ('Stone', 'SIGNITY'),
    ('Stone', 'Singapore'),
    ('Stone', 'Turkish'),
    ('Stone Mala', 'Karnataka'),
    ('Stone Special', 'Kerala'),
    ('Stone Special', 'Kerala Traditional'),
    ('Stone Special', 'Moulding'),
    ('Sundari', 'Kerala'),
    ('Swastik', 'Moulding'),
    ('Tamil Thali', 'Coimbatore'),
    ('Tamil Thali', 'Tamil Traditional'),
    ('Tanmaniya', 'Moulding'),
    ('Tennis', 'Moulding'),
    ('Thala', 'Kerala'),
    ('Thali', 'Moulding'),
    ('Thali God', 'Kerala Traditional'),
    ('Thali Kodi', 'Coimbatore'),
    ('Thali Plain', 'Kerala Traditional'),
    ('Thara', 'Kerala'),
    ('Thoradu', 'Kerala'),
    ('Thread', 'Bengali'),
    ('Thread', 'Bombay'),
    ('Thread Locket', 'Bengali'),
    ('Thread Locket', 'Kerala'),
    ('Thread Locket God', 'Kerala'),
    ('Thulasi', 'Karnataka Traditional'),
    ('Thulasi', 'Kerala'),
    ('Thulasi', 'Kerala Traditional'),
    ('Tiger Nail', 'Moulding'),
    ('Tight Aranjal', 'Coimbatore'),
    ('Tight Aranjal', 'Kerala'),
    ('Traditional', 'Kerala'),
    ('Traditional', 'Kerala Traditional'),
    ('Traditional thread locket', 'Kerala Traditional'),
    ('Traditional Thread Locket Palakka', 'Kerala Traditional'),
    ('Turkish', 'Kerala'),
    ('Turkish', 'Turkish'),
    ('Turkish Special', 'Turkish'),
    ('Turkish stone', 'Turkish'),
    ('Twisted', 'Moulding'),
    ('Tyre', 'Coimbatore'),
    ('Tyre Layer', 'Coimbatore'),
    ('Tyre Mix', 'Coimbatore'),
    ('Tyre Mix Layer', 'Coimbatore'),
    ('Uncut', 'Uncut'),
    ('Uri', 'Kerala'),
    ('Uri-Katta', 'Kerala'),
    ('Uruttu Potharam', 'Coimbatore'),
    ('Urvasi', 'Kerala'),
    ('V Chain', 'Kerala'),
    ('Vangi Closed Setting', 'Coimbatore'),
    ('Vangi Stone', 'Moulding'),
    ('Vangi Stone', 'Nagas'),
    ('Vanki', 'Coimbatore'),
    ('Vanki', 'Kolkata'),
    ('Vanki', 'Moulding'),
    ('Vanki', 'Nagas'),
    ('Vanki', 'SIGNITY'),
    ('Watti', 'Rajkot'),
    ('Yin-Yang', 'Italian');

-- CHECK -- confirms every child/parent value already exists as an ENABLED
-- enum value of the expected attribute type. Investigate any row where
-- child_id or parent_id is NULL before running the INSERT below -- it means
-- that value either doesn't exist yet, or exists only as a disabled row
-- (e.g. a Step 3 "new value" from add_revised_collections_and_styles.sql
-- hasn't been run, the sheet has a typo, or the live value was disabled).
SELECT
    t.child_value, t.parent_value,
    child_e.id AS child_id, parent_e.id AS parent_id
FROM hier_style_collection t
LEFT JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'STL')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
LEFT JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
WHERE child_e.id IS NULL OR parent_e.id IS NULL
ORDER BY t.child_value, t.parent_value;

-- INSERT
BEGIN;
INSERT INTO product_attribute_enum_hierarchy (product_attribute_enum_value_id, parent_product_attribute_enum_value_id)
SELECT DISTINCT child_e.id, parent_e.id
FROM hier_style_collection t
JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'STL')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
ON CONFLICT (product_attribute_enum_value_id, parent_product_attribute_enum_value_id) DO NOTHING;
COMMIT;

-- VERIFY -- re-run the CHECK query above (0 rows expected); the query below
-- should return 0 for missing_pairs.
SELECT COUNT(*) AS missing_pairs
FROM hier_style_collection t
JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'STL')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
WHERE NOT EXISTS (
    SELECT 1 FROM product_attribute_enum_hierarchy h
    WHERE h.product_attribute_enum_value_id = child_e.id
      AND h.parent_product_attribute_enum_value_id = parent_e.id
);

-- SHOW INSERTED -- lists the actual product_attribute_enum_hierarchy rows
-- for this step's pairs (571 rows expected).
SELECT
    h.id AS hierarchy_edge_id,
    child_e.id AS child_id, child_e.value AS child_value,
    parent_e.id AS parent_id, parent_e.value AS parent_value
FROM hier_style_collection t
JOIN product_attribute_enum_value child_e
    ON child_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'STL')
   AND LOWER(child_e.value) = LOWER(t.child_value)
   AND child_e.is_enabled = true
JOIN product_attribute_enum_value parent_e
    ON parent_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
   AND LOWER(parent_e.value) = LOWER(t.parent_value)
   AND parent_e.is_enabled = true
JOIN product_attribute_enum_hierarchy h
    ON h.product_attribute_enum_value_id = child_e.id
   AND h.parent_product_attribute_enum_value_id = parent_e.id
ORDER BY child_value, parent_value;

-- ============================================================================
-- STEP 4 -- populate product_attribute_hierarchy_condition: for every enum
-- value that sits anywhere in the hierarchy, record the full set of
-- hierarchy-edge ids on its ancestor path (its own direct edge(s), its
-- parents' edges, and so on up to Type) so a caller can fetch a value's
-- whole Type/Category/Collection/Style lineage with one non-recursive query
-- instead of walking product_attribute_enum_hierarchy level by level.
--
-- No separate is_enabled check is needed here -- product_attribute_enum_hierarchy
-- itself never contains an edge touching a disabled value (Steps 1-3 filter
-- that out, and the CLEANUP block above removes any that slipped in from an
-- earlier run), so anything reachable through it is already enabled-only.
--
-- A value with multiple parents (see note above) gets the union of every
-- edge reachable from any of its parents.
-- ============================================================================

BEGIN;
WITH RECURSIVE ancestor_edges AS (
    SELECT
        h.product_attribute_enum_value_id AS value_id,
        h.id AS edge_id,
        h.parent_product_attribute_enum_value_id AS frontier_id
    FROM product_attribute_enum_hierarchy h

    UNION ALL

    SELECT
        ae.value_id,
        h2.id AS edge_id,
        h2.parent_product_attribute_enum_value_id AS frontier_id
    FROM ancestor_edges ae
    JOIN product_attribute_enum_hierarchy h2
        ON h2.product_attribute_enum_value_id = ae.frontier_id
)
INSERT INTO product_attribute_hierarchy_condition (product_attribute_enum_value_id, product_attribute_enum_hierarchy_id)
SELECT DISTINCT value_id, edge_id
FROM ancestor_edges
ON CONFLICT (product_attribute_enum_value_id, product_attribute_enum_hierarchy_id) DO NOTHING;
COMMIT;

-- VERIFY -- sample a value known to have a 3-level chain (Style 'Nakashi'
-- under Collection 'Nagas' under Category 'Bangle' under Type 'Gold 22k')
-- and confirm all of its ancestor edges came back in one query.
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
WHERE pa.attribute_code = 'STL' AND LOWER(e.value) = LOWER('Nakashi')
ORDER BY value_name, hierarchy_edge_id;
