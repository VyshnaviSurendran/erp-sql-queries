-- ============================================================================
-- PROD 2/4 -- Excel corrections: Category / Collection / Style of UNSOLD products and of
-- templates, then template codes (canonical flow) and product names.
-- Must run as ONE file in ONE go: later statements read temp tables
-- built by earlier ones.
--
-- Run after 1_add_revised_collections_and_styles.sql.
-- Open in a new pgAdmin Query Tool tab (Auto commit ON), select nothing,
-- press F5 once. One transaction: all of it is saved, or (on any error)
-- none of it -- then run ROLLBACK; in that tab and send the error.
-- Generated from product-attrib/update_product_and_template_collection_style.sql without its CHECK/VERIFY queries.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- The 896 corrections. new_* NULL = that attribute is not changed.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS category_fixes;

CREATE TEMP TABLE category_fixes (category text, product_type text, db_collection text, db_style text, new_category text, new_collection text, new_style text);

INSERT INTO category_fixes (category, product_type, db_collection, db_style, new_category, new_collection, new_style) VALUES
    ('Anklet', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Anklet', 'Gold 22k', 'Bombay', 'Bombay', NULL, NULL, 'Plain'),
    ('Anklet', 'Gold 22k', 'Bombay', 'NET', NULL, NULL, 'Net'),
    ('Anklet', 'Gold 22k', 'Bombay', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Anklet', 'Gold 22k', 'Coimbatore', 'Fancy', NULL, 'Bombay', 'Plain'),
    ('Anklet', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Savariya'),
    ('Anklet', 'Gold 14K', 'ITALIAN', 'CLASSIC', NULL, 'Italian', 'Fancy'),
    ('Anklet', 'Gold 18K', 'ITALIAN', 'CHARMS', NULL, 'Italian', 'Charms'),
    ('Anklet', 'Gold 18K', 'ITALIAN', 'Plain', NULL, 'Italian', NULL),
    ('Anklet', 'Gold 18K', 'ITALIAN', 'Rodium', NULL, 'Italian', 'Rhodium'),
    ('Anklet', 'Gold 18K', 'ITALIAN', 'Stone', NULL, 'Italian', NULL),
    ('Anklet', 'Gold 22k', 'Kerala', 'Black Beeds', NULL, 'Kerala Traditional', NULL),
    ('Anklet', 'Gold 22k', 'Kerala', 'CHETH', NULL, NULL, 'Cheth'),
    ('Anklet', 'Gold 22k', 'Kerala', 'HIGHWAY', NULL, NULL, 'Highway'),
    ('Anklet', 'Gold 22k', 'Kerala', 'PARASPARAM RODIUM', NULL, 'Rajkot', 'Parasparam Rodium'),
    ('Anklet', 'Gold 22k', 'Kerala', 'Stone Special', NULL, 'Moulding', NULL),
    ('Anklet', 'Gold 22k', 'Kerala', 'TIGHT ARANJAL', NULL, NULL, 'Tight Aranjal'),
    ('Anklet', 'Gold 22k', 'Kerala Special', 'CH-CHETH', NULL, 'Kerala', 'Cheth'),
    ('Anklet', 'Gold 22k', 'Kerala Special', 'Parasparam', NULL, 'Rajkot', NULL),
    ('Anklet', 'Gold 18K', 'MECHINE', 'Box Chain', NULL, 'Bombay', NULL),
    ('Anklet', 'Gold 18K', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Anklet', 'Gold 22k', 'Moulding', 'Moulding', NULL, NULL, 'Fancy'),
    ('Anklet', 'Precious', 'Precious', 'Precious', NULL, NULL, 'Savariya'),
    ('Anklet', 'Gold 22k', 'Rajkot', 'Black Beeds', NULL, 'Kerala Traditional', NULL),
    ('Anklet', 'Gold 22k', 'Rajkot', 'Rajkot', NULL, NULL, 'Plain'),
    ('Anklet', 'Gold 22k', 'Rajkot', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Anklet', 'Gold 22k', 'Singapore', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Anklet', 'Gold 22k', 'Singapore', 'Singapore', NULL, NULL, 'Plain'),
    ('Back Chain', 'Gold 18K', '18 Carat', 'Back Chain', NULL, '18 Karat', NULL),
    ('Bangle', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Bangle', 'Gold 22k', 'Antique', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Bangle', 'Gold 22k', 'Antique Premium', 'Antique', NULL, 'Antique', 'Fancy'),
    ('Bangle', 'Gold 22k', 'BENGALI', 'THREAD', NULL, 'Bombay', 'Thread'),
    ('Bangle', 'Gold 22k', 'Bengali special', 'Bengali', NULL, 'Bombay', 'Plain'),
    ('Bangle', 'Gold 22k', 'Bombay', 'Bombay', NULL, NULL, 'Plain'),
    ('Bangle', 'Gold 22k', 'Bombay', 'HALF ROUND ENAMEL', NULL, NULL, 'Half Round Enamel'),
    ('Bangle', 'Gold 22k', 'Bombay', 'HALF ROUND STONE', NULL, NULL, 'Half Round Stone'),
    ('Bangle', 'Gold 22k', 'Bombay', 'PIPE', NULL, NULL, 'Pipe'),
    ('Bangle', 'Gold 22k', 'Bombay', 'PIPE ENAMEL', NULL, NULL, 'Pipe Enamel'),
    ('Bangle', 'Gold 22k', 'Bombay', 'PIPE RODIUM', NULL, NULL, 'Pipe Rhodium'),
    ('Bangle', 'Gold 22k', 'Bombay', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bangle', 'Gold 22k', 'Bombay', 'SOLID RODIUM', NULL, NULL, 'Rhodium'),
    ('Bangle', 'Gold 22k', 'Bombay Special', 'CNC', NULL, 'Bombay', 'CNC Cutting'),
    ('Bangle', 'Gold 22k', 'Bombay Special', 'CNC CLASSIC', NULL, 'Bombay', 'CNC Cutting'),
    ('Bangle', 'Gold 22k', 'Bombay Special', 'CNC NORMAL', NULL, 'Bombay', 'CNC Cutting'),
    ('Bangle', 'Gold 22k', 'Bombay Special', 'CNC PREMIUM', NULL, 'Bombay', 'CNC Cutting'),
    ('Bangle', 'Gold 22k', 'Bombay Special', 'Rodium', NULL, 'Bombay', 'Rhodium CNC Cutting'),
    ('Bangle', 'Diamond', 'BRIDAL', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Bangle', 'Diamond', 'BRIDAL', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Bangle', 'Gold 22k', 'Chettinadu', 'Chettinadu', NULL, NULL, 'Nakashi'),
    ('Bangle', 'Gold 22k', 'Chettinadu', 'LAKSHMI STONE', NULL, NULL, 'Lakshmi Stone'),
    ('Bangle', 'Gold 22k', 'Chettinadu', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Bangle', 'Gold 22k', 'Cnc', 'Enamel', NULL, 'CNC', NULL),
    ('Bangle', 'Gold 22k', 'Cnc', 'EYE', NULL, 'CNC', 'Eye'),
    ('Bangle', 'Gold 22k', 'Cnc', 'God', NULL, 'CNC', NULL),
    ('Bangle', 'Gold 22k', 'Cnc', 'JAGUAR', NULL, 'CNC', 'Jaguar'),
    ('Bangle', 'Gold 22k', 'Cnc', 'LEAF', NULL, 'CNC', 'Leaf'),
    ('Bangle', 'Gold 22k', 'Cnc', 'Plain', NULL, 'CNC', NULL),
    ('Bangle', 'Gold 22k', 'Cnc', 'Rodium', NULL, 'CNC', 'Rhodium'),
    ('Bangle', 'Gold 22k', 'Cnc', 'SIMBA', NULL, 'CNC', 'Simba'),
    ('Bangle', 'Gold 22k', 'Cnc', 'Solid', NULL, 'CNC', 'Plain'),
    ('Bangle', 'Gold 22k', 'Cnc', 'Stone', NULL, 'CNC', NULL),
    ('Bangle', 'Gold 22k', 'Coimbatore', 'CLOSED SETTING', NULL, NULL, 'Closed Setting'),
    ('Bangle', 'Gold 22k', 'Culcutta', 'Culcutta plain', NULL, 'Kolkata', 'Plain'),
    ('Bangle', 'Gold 22k', 'Culcutta', 'Enamel', NULL, 'Kolkata', NULL),
    ('Bangle', 'Gold 22k', 'Culcutta', 'PIPE', NULL, 'Kolkata', 'Pipe'),
    ('Bangle', 'Gold 22k', 'Culcutta', 'PIPE ENAMEL', NULL, 'Kolkata', 'Pipe Enamel'),
    ('Bangle', 'Gold 22k', 'Culcutta', 'Plain', NULL, 'Kolkata', NULL),
    ('Bangle', 'Gold 22k', 'Culcutta', 'Screw', NULL, 'Kolkata', NULL),
    ('Bangle', 'Gold 22k', 'Culcutta', 'SCREW ENAMEL', NULL, 'Kolkata', 'Screw Enamel'),
    ('Bangle', 'Diamond', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Bangle', 'Diamond', 'DESIGNER', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Bangle', 'Diamond', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Bangle', 'Diamond', 'HERITAGE', 'CLOSED SETTING', NULL, 'Moulding', 'Closed Setting'),
    ('Bangle', 'Diamond', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Bangle', 'Diamond', 'HERITAGE', 'OPEN CLOSE SETTING', NULL, 'Moulding', 'Open Close Setting'),
    ('Bangle', 'Precious', 'HERITAGE', 'FILIGREE', NULL, 'Moulding', 'Filigree'),
    ('Bangle', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Bangle', 'Precious', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Bangle', 'Precious', 'HERITAGE', 'Navaratna', NULL, 'Moulding', NULL),
    ('Bangle', 'Uncut', 'HERITAGE', 'FILIGREE', NULL, 'Moulding', 'Filigree'),
    ('Bangle', 'Uncut', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Bangle', 'Uncut', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Bangle', 'Uncut', 'HERITAGE', 'Navaratna', NULL, 'Moulding', NULL),
    ('Bangle', 'Gold 22k', 'Karnataka', 'BELVERY', NULL, NULL, 'Belvery'),
    ('Bangle', 'Gold 22k', 'Karnataka', 'EYE', NULL, 'CNC', 'Eye'),
    ('Bangle', 'Gold 22k', 'Karnataka', 'Lakshmi', NULL, 'Karnataka Traditional', NULL),
    ('Bangle', 'Gold 22k', 'Karnataka', 'LAKSHMI CORAL', NULL, 'Karnataka Traditional', 'Lakshmi Coral'),
    ('Bangle', 'Gold 22k', 'Karnataka', 'LAKSHMI STONE', NULL, 'Karnataka Traditional', 'Lakshmi Stone'),
    ('Bangle', 'Gold 22k', 'Karnataka', 'RAVA', NULL, NULL, 'Rava'),
    ('Bangle', 'Gold 22k', 'Kerala', 'Dhasavatharam', NULL, 'Kerala Traditional', 'Dasavatharam'),
    ('Bangle', 'Gold 22k', 'Kerala', 'DRISHYAM', NULL, NULL, 'Drishyam'),
    ('Bangle', 'Gold 22k', 'Kerala', 'DRISHYAM ENAMEL', NULL, NULL, 'Drishyam Enamel'),
    ('Bangle', 'Gold 22k', 'Kerala', 'LAKSHMI STONE', NULL, NULL, 'Lakshmi Stone'),
    ('Bangle', 'Gold 22k', 'Kerala', 'PIPE', NULL, NULL, 'Pipe'),
    ('Bangle', 'Gold 22k', 'Kerala', 'PIRIYAN PIPE', NULL, NULL, 'Piriyan Pipe'),
    ('Bangle', 'Gold 22k', 'Kerala', 'SOLID RODIUM', NULL, NULL, 'Solid Rodium'),
    ('Bangle', 'Gold 22k', 'Kerala', 'SQUARE OPEN', NULL, NULL, 'Square Open'),
    ('Bangle', 'Gold 22k', 'Kerala', 'SQUARE PIPE RODIUM', NULL, NULL, 'Square Pipe Rodium'),
    ('Bangle', 'Gold 18K', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bangle', 'Gold 22k', 'Moulding', 'Moulding', NULL, NULL, 'Fancy'),
    ('Bangle', 'Gold 22k', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bangle', 'Gold 18K', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Bangle', 'Gold 22k', 'Nagas', 'LAKSHMI STONE', NULL, NULL, 'Lakshmi Stone'),
    ('Bangle', 'Gold 22k', 'Nagas', 'MEENAKSHI', NULL, NULL, 'Meenakshi'),
    ('Bangle', 'Gold 22k', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Bangle', 'Gold 22k', 'Nagas', 'PEACOCK', NULL, NULL, 'Peacock'),
    ('Bangle', 'Gold 22k', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Bangle', 'Gold 22k', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Bangle', 'Precious', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Bangle', 'Precious', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Bangle', 'Precious', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Bangle', 'Precious', 'Nagas', 'Vangi', NULL, NULL, 'Vanki'),
    ('Bangle', 'Uncut', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Bangle', 'Uncut', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Bangle', 'Uncut', 'Nagas', 'Vangi', NULL, NULL, 'Vanki'),
    ('Bangle', 'Gold 22k', 'Nagas Premium', 'Nagas', NULL, 'Nagas', 'Nakashi'),
    ('Bangle', 'Gold 22k', 'Nagas Premium', 'special nagas', NULL, 'Nagas', 'Nakashi'),
    ('Bangle', 'Gold 22k', 'Nellore', 'Nellore', NULL, 'Karnataka Traditional', NULL),
    ('Bangle', 'Gold 22k', 'Nellore', 'Stone', NULL, 'Karnataka Traditional', 'Nellore'),
    ('Bangle', 'Platinum', 'Platinum', 'Platinum', NULL, NULL, 'Fancy'),
    ('Bangle', 'Platinum', 'Platinum', 'Platinum Fusion', NULL, NULL, 'Fusion'),
    ('Bangle', 'Platinum', 'PLATINUM FUSION', 'CLASSIC', NULL, 'Platinum', 'Fusion'),
    ('Bangle', 'Polki', 'Polki', 'Polki', NULL, NULL, 'Fancy'),
    ('Bangle', 'Gold 22k', 'Rajkot', 'Rajkot', NULL, NULL, 'Plain'),
    ('Bangle', 'Gold 22k', 'Rajkot', 'RAJKOT SP', NULL, NULL, 'Plain'),
    ('Bangle', 'Gold 22k', 'Rajkot', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bangle', 'Gold 22k', 'Semi Antique', 'Semi Antique', NULL, NULL, 'Nakashi'),
    ('Bangle', 'Gold 22k', 'Semi Nagas', 'Semi Nagas', NULL, NULL, 'Nakashi'),
    ('Bangle', 'Diamond', 'SIGNATURE', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Bangle', 'Diamond', 'SIGNATURE', 'CLOSED SETTING', NULL, 'Moulding', 'Closed Setting'),
    ('Bangle', 'Diamond', 'SIGNATURE', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Bangle', 'Gold 22k', 'SIGNITY', 'CLOSED SETTING', NULL, NULL, 'Closed Setting'),
    ('Bangle', 'Gold 22k', 'SIGNITY', 'CLOSED SETTING GOD', NULL, NULL, 'Closed Setting God'),
    ('Bangle', 'Gold 22k', 'Singapore', 'CNC', NULL, NULL, 'Cnc'),
    ('Bangle', 'Gold 22k', 'Singapore', 'SINGAPORE STONE', NULL, NULL, 'Singapore Stone'),
    ('Bangle', 'Diamond', 'SOLITAIRE', 'SOLITAIRE', NULL, 'Moulding', 'Solitaire'),
    ('Bangle', 'Gold 22k', 'Traditional', 'Coorgi', NULL, 'Karnataka Traditional', NULL),
    ('Bangle', 'Gold 22k', 'Traditional', 'Coorgi stone', NULL, 'Karnataka Traditional', NULL),
    ('Bangle', 'Gold 22k', 'Traditional', 'Lakshmi', NULL, 'Karnataka Traditional', NULL),
    ('Bangle', 'Gold 22k', 'Traditional', 'Palakka', NULL, 'Kerala Traditional', NULL),
    ('Bangle', 'Gold 22k', 'Traditional', 'Traditional', NULL, 'Kerala Traditional', NULL),
    ('Bangle', 'Gold 22k', 'Turkish', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bangle', 'Precious', 'Turkish', 'FILIGREE', NULL, NULL, 'Filigree'),
    ('Bangle', 'Precious', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Bangle', 'Uncut', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Bracelet', 'Gold 14K', '14 Carat Ornaments', '14 Karat Ornaments', NULL, '14 Kt Ornaments', NULL),
    ('Bracelet', 'Gold 14K', '14 Carat Ornaments', 'Diamond', NULL, '14 Kt Ornaments', 'Fancy'),
    ('Bracelet', 'Gold 14K', '14 Carat Ornaments', 'Oval', NULL, '14 Kt Ornaments', NULL),
    ('Bracelet', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Bracelet', 'Gold 22k', 'Antique', 'MEHNDI STONE', NULL, NULL, 'Mehndi Stone'),
    ('Bracelet', 'Gold 22k', 'Antique Premium', 'Antique', NULL, 'Antique', 'Fancy'),
    ('Bracelet', 'Gold 22k', 'Bombay', 'BISCUIT', NULL, NULL, 'Biscuit'),
    ('Bracelet', 'Gold 22k', 'Bombay', 'Bombay', NULL, NULL, 'Plain'),
    ('Bracelet', 'Gold 22k', 'Bombay', 'CARTIER', NULL, NULL, 'Cartier'),
    ('Bracelet', 'Gold 22k', 'Bombay', 'CUBAN', NULL, NULL, 'Cuban'),
    ('Bracelet', 'Gold 22k', 'Bombay', 'HOLLOW', NULL, NULL, 'Hollow'),
    ('Bracelet', 'Gold 22k', 'Bombay', 'MEHNDI RODIUM', NULL, NULL, 'Mehndi Rodium'),
    ('Bracelet', 'Gold 22k', 'Bombay', 'NAVABI', NULL, NULL, 'Navabi'),
    ('Bracelet', 'Gold 22k', 'Bombay', 'NEW MAGIC', NULL, NULL, 'New Magic'),
    ('Bracelet', 'Gold 22k', 'Bombay', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bracelet', 'Gold 22k', 'Culcutta', 'Culcutta', NULL, 'Kolkata', 'Plain'),
    ('Bracelet', 'Gold 22k', 'Culcutta', 'Culcutta plain', NULL, 'Kolkata', 'Plain'),
    ('Bracelet', 'Gold 22k', 'Culcutta', 'Culcutta Stone', NULL, 'Kolkata', 'Stone'),
    ('Bracelet', 'Gold 22k', 'Culcutta', 'Plain', NULL, 'Kolkata', NULL),
    ('Bracelet', 'Diamond', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Bracelet', 'Diamond', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Bracelet', 'Diamond', 'Diamond', 'Oval', NULL, 'Moulding', NULL),
    ('Bracelet', 'Diamond', 'Diamond SI Jewellery', 'Diamond SI', NULL, 'Moulding', 'Fancy'),
    ('Bracelet', 'Polki', 'HERITAGE', 'JADAU', NULL, 'Polki', 'Jadau'),
    ('Bracelet', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Bracelet', 'Uncut', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Bracelet', 'Gold 14K', 'ITALIAN', 'CERA', NULL, NULL, 'Cera'),
    ('Bracelet', 'Gold 14K', 'ITALIAN', 'CUPOD', NULL, NULL, 'Cupod'),
    ('Bracelet', 'Gold 14K', 'ITALIAN', 'FLORA', NULL, NULL, 'Flora'),
    ('Bracelet', 'Gold 14K', 'ITALIAN', 'YIN-YANG', NULL, NULL, 'Yin-Yang'),
    ('Bracelet', 'Gold 18K', 'ITALIAN', 'Rodium', NULL, 'Italian', 'Rhodium'),
    ('Bracelet', 'Gold 22k', 'KARINGALI', 'KARINGALI', NULL, 'Kerala Traditional', 'Karingali'),
    ('Bracelet', 'Gold 22k', 'Kerala', 'Black Beeds', NULL, 'Kerala Traditional', NULL),
    ('Bracelet', 'Gold 22k', 'Kerala', 'KARINGALI', NULL, NULL, 'Karingali'),
    ('Bracelet', 'Gold 22k', 'Kerala', 'Parasparam', NULL, 'Rajkot', NULL),
    ('Bracelet', 'Gold 22k', 'Kerala', 'PARASPARAM RODIUM', NULL, NULL, 'Parasparam Rodium'),
    ('Bracelet', 'Gold 22k', 'Kerala', 'SANDAL BRACELET', NULL, NULL, 'Sandal Bracelet'),
    ('Bracelet', 'Gold 22k', 'Kerala Special', 'Red Sandal', NULL, 'Kerala Traditional', NULL),
    ('Bracelet', 'Gold 22k', 'Kerala Special', 'Rudraksham', NULL, 'Kerala Traditional', NULL),
    ('Bracelet', 'Gold 22k', 'Kerala Special', 'Thulasi', NULL, 'Kerala Traditional', NULL),
    ('Bracelet', 'Gold 22k', 'MADRASI', 'MADRASI SP', NULL, NULL, 'Madrasi Sp'),
    ('Bracelet', 'Gold 22k', 'Moulding', 'MEHNDI PLAIN', NULL, NULL, 'Mehndi Plain'),
    ('Bracelet', 'Gold 22k', 'Moulding', 'MEHNDI STONE', NULL, NULL, 'Mehndi Stone'),
    ('Bracelet', 'Gold 22k', 'Moulding', 'Moulding', NULL, NULL, 'Fancy'),
    ('Bracelet', 'Gold 22k', 'Moulding', 'Papper Cast', NULL, NULL, 'Paper Cast'),
    ('Bracelet', 'Gold 22k', 'Moulding', 'RAINBOW', NULL, NULL, 'Rainbow'),
    ('Bracelet', 'Gold 22k', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bracelet', 'Gold 22k', 'Moulding', 'SIMBA', NULL, NULL, 'Simba'),
    ('Bracelet', 'Gold 22k', 'Nagas', 'Nagas', NULL, NULL, 'Nakashi'),
    ('Bracelet', 'Gold 22k', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Bracelet', 'Gold 22k', 'Nagas', 'SITA RAM', NULL, NULL, 'Sita Ram'),
    ('Bracelet', 'Platinum', 'Platinum', 'CLASSIC', NULL, NULL, 'Fancy'),
    ('Bracelet', 'Platinum', 'Platinum', 'Platinum', NULL, NULL, 'Fancy'),
    ('Bracelet', 'Platinum', 'Platinum', 'Platinum Fusion', NULL, NULL, 'Fusion'),
    ('Bracelet', 'Platinum', 'PLATINUM FUSION', 'CLASSIC', NULL, 'Platinum', 'Fusion'),
    ('Bracelet', 'Polki', 'Polki', 'Polki', NULL, NULL, 'Fancy'),
    ('Bracelet', 'Gold 22k', 'Rajkot', 'Parasparam', NULL, 'Rajkot', NULL),
    ('Bracelet', 'Gold 22k', 'Rajkot', 'Rajkot', NULL, NULL, 'Plain'),
    ('Bracelet', 'Gold 22k', 'Rajkot', 'Rajkot Beeds', NULL, NULL, 'Beeds'),
    ('Bracelet', 'Gold 22k', 'Rajkot', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bracelet', 'Gold 22k', 'Semi Antique', 'Semi Antique', NULL, NULL, 'Nakashi'),
    ('Bracelet', 'Diamond', 'SIGNATURE', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Bracelet', 'Diamond', 'SIGNATURE', 'TENNIS', NULL, 'Moulding', 'Tennis'),
    ('Bracelet', 'Gold 22k', 'Singapore', 'CUBAN', NULL, NULL, 'Cuban'),
    ('Bracelet', 'Gold 22k', 'Singapore', 'DELUXE', NULL, NULL, 'Deluxe'),
    ('Bracelet', 'Gold 22k', 'Singapore', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bracelet', 'Gold 22k', 'Singapore', 'SIMBA', NULL, NULL, 'Simba'),
    ('Bracelet', 'Gold 22k', 'Singapore', 'SINGAPORE STONE', NULL, NULL, 'Singapore Stone'),
    ('Bracelet', 'Gold 22k', 'Traditional', 'Black Beeds', NULL, 'Kerala Traditional', NULL),
    ('Bracelet', 'Gold 22k', 'Traditional', 'Stone Special', NULL, 'Kerala Traditional', NULL),
    ('Bracelet', 'Gold 22k', 'Traditional', 'Traditional', NULL, 'Kerala Traditional', NULL),
    ('Bracelet', 'Gold 22k', 'Turkish', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Bracelet', 'Gold 22k', 'Turkish', 'TURKISH SPECIAL', NULL, NULL, 'Turkish Special'),
    ('Bracelet', 'Precious', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Chain', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Chain', 'Gold 22k', 'Bombay', 'BISCUIT', NULL, NULL, 'Biscuit'),
    ('Chain', 'Gold 22k', 'Bombay', 'Bombay', NULL, NULL, 'Plain'),
    ('Chain', 'Gold 22k', 'Bombay', 'MADHIRA', NULL, NULL, 'Madhira'),
    ('Chain', 'Gold 22k', 'Bombay', 'MADHIRA CUTTING', NULL, NULL, 'Madhira Cutting'),
    ('Chain', 'Gold 22k', 'Bombay', 'NAVABI', NULL, NULL, 'Navabi'),
    ('Chain', 'Gold 22k', 'Bombay', 'NAVABI KATTA', NULL, NULL, 'Navabi Katta'),
    ('Chain', 'Gold 22k', 'Chain Special', 'Special', NULL, 'Bombay', 'Indo Italian'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'ANUSHKA', NULL, NULL, 'Anushka'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BAHUBALI', NULL, NULL, 'Bahubali'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BALL BASHA', NULL, NULL, 'Ball Basha'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BASHA', NULL, NULL, 'Basha'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BATTANI', NULL, NULL, 'Battani'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BATTANI LAYER', NULL, NULL, 'Battani Layer'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BATTANI MIX', NULL, NULL, 'Battani Mix'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BATTANI MIX LAYER', NULL, NULL, 'Battani Mix Layer'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BISCUIT', NULL, NULL, 'Biscuit'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BULB', NULL, NULL, 'Bulb'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'BULB LAYER', NULL, NULL, 'Bulb Layer'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'CHANDRAMUKHI', NULL, NULL, 'Chandramukhi'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'COIMBATORE FANCY', NULL, NULL, 'Fancy'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'GENTLEMAN', NULL, NULL, 'Gentleman'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'HEART', NULL, NULL, 'Heart'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'HOLLOW CBT', NULL, NULL, 'Hollow Cbt'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'IPL', NULL, NULL, 'Ipl'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'IPL CUTTING', NULL, NULL, 'Ipl Cutting'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'KARBH', NULL, NULL, 'Curb'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'KATTAPPA', NULL, NULL, 'Kattappa'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'MUDICHI THARA', NULL, NULL, 'Mudichi Thara'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'MUGAPPU LAKSHMI', NULL, NULL, 'Mugappu Lakshmi'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'MUGAPPU LAKSHMI STONE', NULL, NULL, 'Mugappu Lakshmi Stone'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'MUGAPPU PEACOCK', NULL, NULL, 'Mugappu Peacock'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'mugappu special', NULL, NULL, 'Mugappu'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'MULLBERRY', NULL, NULL, 'Mullberry'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'NAVABI KATTA', NULL, NULL, 'Navabi Katta'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'PYRAMID', NULL, NULL, 'Pyramid'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'PYRAMID MIX', NULL, NULL, 'Pyramid Mix'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'SQUARE ROPE', NULL, NULL, 'Square Rope'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'THALI KODI', NULL, NULL, 'Thali Kodi'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'TIGHT ARANJAL', NULL, NULL, 'Tight Aranjal'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'TYRE', NULL, NULL, 'Tyre'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'TYRE LAYER', NULL, NULL, 'Tyre Layer'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'TYRE MIX', NULL, NULL, 'Tyre Mix'),
    ('Chain', 'Gold 22k', 'Coimbatore', 'TYRE MIX LAYER', NULL, NULL, 'Tyre Mix Layer'),
    ('Chain', 'Gold 22k', 'Karnataka', 'KATTAPPA', NULL, NULL, 'Kattappa'),
    ('Chain', 'Gold 22k', 'Kerala', 'BALL-URI KATTA', NULL, NULL, 'Ball-Uri Katta'),
    ('Chain', 'Gold 22k', 'Kerala', 'Ball-Uri Katti', NULL, NULL, 'Ball-Uri Katta'),  -- sheet says 'Ball Uri Katta' (no hyphen); no such style exists, confirmed typo for 'Ball-Uri Katta'
    ('Chain', 'Gold 22k', 'Kerala', 'DHRUVAM', NULL, NULL, 'Dhruvam'),
    ('Chain', 'Gold 22k', 'Kerala', 'DISCO', NULL, NULL, 'Disco'),
    ('Chain', 'Gold 22k', 'Kerala', 'DOUBLE SIDE KUMALA', NULL, NULL, 'Double Side Kumala'),
    ('Chain', 'Gold 22k', 'Kerala', 'GOPURAM', NULL, NULL, 'Gopuram'),
    ('Chain', 'Gold 22k', 'Kerala', 'HIGHWAY', NULL, NULL, 'Highway'),
    ('Chain', 'Gold 22k', 'Kerala', 'INDIAN RUPEE', NULL, NULL, 'Indian Rupee'),
    ('Chain', 'Gold 22k', 'Kerala', 'KANAKA MALA', NULL, NULL, 'Kanaka Mala'),
    ('Chain', 'Gold 22k', 'Kerala', 'KILUKKAM', NULL, NULL, 'Kilukkam'),
    ('Chain', 'Gold 22k', 'Kerala', 'MOGAMBO', NULL, NULL, 'Mogambo'),
    ('Chain', 'Gold 22k', 'Kerala', 'MONKEYPEN', NULL, NULL, 'Monkeypen'),
    ('Chain', 'Gold 22k', 'Kerala', 'MULLBERRY', NULL, NULL, 'Mullberry'),
    ('Chain', 'Gold 22k', 'Kerala', 'NEELA THAMARA', NULL, NULL, 'Neela Thamara'),
    ('Chain', 'Gold 22k', 'Kerala', 'ONE SIDE KUMALA', NULL, NULL, 'One Side Kumala'),
    ('Chain', 'Gold 22k', 'Kerala', 'OVAL KANNI', NULL, NULL, 'Oval Kanni'),
    ('Chain', 'Gold 22k', 'Kerala', 'Parasparam', NULL, 'Rajkot', NULL),
    ('Chain', 'Gold 22k', 'Kerala', 'PARASPARAM PLAIN', NULL, NULL, 'Parasparam Plain'),
    ('Chain', 'Gold 22k', 'Kerala', 'PARASPARAM RODIUM', NULL, NULL, 'Parasparam Rodium'),
    ('Chain', 'Gold 22k', 'Kerala', 'PUZHU S', NULL, NULL, 'Puzhu S'),
    ('Chain', 'Gold 22k', 'Kerala', 'SQUARE SUNDARI', NULL, NULL, 'Square Sundari'),
    ('Chain', 'Gold 22k', 'Kerala', 'THARA', NULL, NULL, 'Thara'),
    ('Chain', 'Gold 22k', 'Kerala', 'TIGHT ARANJAL', NULL, NULL, 'Tight Aranjal'),
    ('Chain', 'Gold 22k', 'Kerala', 'URI-KATTA', NULL, NULL, 'Uri-Katta'),
    ('Chain', 'Gold 22k', 'Kerala', 'V Chain', NULL, NULL, 'V Chain'),
    ('Chain', 'Gold 22k', 'Kerala Special', 'CH-CHETH', NULL, 'Kerala', 'Cheth'),
    ('Chain', 'Gold 22k', 'Kerala Special', 'KANAKA MALA', NULL, 'Kerala', 'Kanaka Mala'),
    ('Chain', 'Gold 22k', 'Kerala Special', 'MC GF SPECIAL', NULL, NULL, 'Mc Gf Special'),
    ('Chain', 'Gold 22k', 'Kerala Special', 'Parasparam', NULL, 'Rajkot', NULL),
    ('Chain', 'Gold 22k', 'Kerala Special', 'Pulimurugan', NULL, 'Kerala', NULL),
    ('Chain', 'Gold 18K', 'MECHINE', 'Box Chain', NULL, 'Bombay', NULL),
    ('Chain', 'Gold 18K', 'MECHINE', 'BOXCHAIN ROSE GOLD', NULL, 'Bombay', 'Boxchain Rose Gold'),
    ('Chain', 'Gold 18K', 'MECHINE', 'BOXCHAIN YELLOW GOLD', NULL, 'Bombay', 'Boxchain Yellow Gold'),
    ('Chain', 'Gold 22k', 'MECHINE', 'Gold Finger', NULL, 'Kerala', NULL),
    ('Chain', 'Gold 18K', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Chain', 'Platinum', 'Platinum', 'CLASSIC', NULL, NULL, 'Fancy'),
    ('Chain', 'Platinum', 'Platinum', 'Platinum', NULL, NULL, 'Fancy'),
    ('Chain', 'Platinum', 'Platinum', 'Platinum Fusion', NULL, NULL, 'Fusion'),
    ('Chain', 'Platinum', 'PLATINUM FUSION', 'CLASSIC', NULL, 'Platinum', 'Fusion'),
    ('Chain', 'Gold 22k', 'Rajkot', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Chain', 'Gold 22k', 'RAJKOT CHAIN', 'RAJKOT SP', NULL, 'Rajkot', 'Plain'),
    ('Chain', 'Gold 22k', 'Singapore', 'BISCUIT', NULL, NULL, 'Biscuit'),
    ('Chain', 'Gold 22k', 'Singapore', 'CUBAN', NULL, NULL, 'Cuban'),
    ('Chain', 'Gold 22k', 'Singapore', 'KAJU KATLI', NULL, NULL, 'Kaju Katli'),
    ('Chain', 'Gold 22k', 'Traditional', 'Manikasu', NULL, 'Kerala Traditional', NULL),
    ('Chain', 'Gold 22k', 'Traditional', 'Traditional', NULL, 'Kerala Traditional', NULL),
    ('Chutti', 'Gold 22k', 'Antique', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Chutti', 'Gold 22k', 'Bombay', 'Bombay', NULL, NULL, 'Plain'),
    ('Chutti', 'Diamond', 'BRIDAL', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Chutti', 'Diamond', 'BRIDAL', 'God', NULL, 'Moulding', NULL),
    ('Chutti', 'Diamond', 'BRIDAL', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Chutti', 'Gold 22k', 'Culcutta', 'Culcutta plain', NULL, 'Kolkata', 'Plain'),
    ('Chutti', 'Gold 22k', 'Culcutta', 'NAKASHI', NULL, 'Kolkata', 'Nakashi'),
    ('Chutti', 'Gold 22k', 'Culcutta', 'Plain', NULL, 'Kolkata', NULL),
    ('Chutti', 'Gold 22k', 'Culcutta', 'Stone', NULL, 'Kolkata', NULL),
    ('Chutti', 'Diamond', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Chutti', 'Diamond', 'DESIGNER', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Chutti', 'Diamond', 'DESIGNER', 'RAM PARIVAR', NULL, 'Moulding', 'Ram Parivar'),
    ('Chutti', 'Diamond', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Chutti', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Chutti', 'Uncut', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Chutti', 'Gold 18K', 'Nagas', 'MEENAKSHI', NULL, NULL, 'Meenakshi'),
    ('Chutti', 'Gold 22k', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Chutti', 'Gold 22k', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Chutti', 'Gold 22k', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Chutti', 'Uncut', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Chutti', 'Uncut', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Chutti', 'Polki', 'Polki', 'CLASSIC', NULL, NULL, 'Fancy'),
    ('Chutti', 'Precious', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Chutti', 'Uncut', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Hip Chain', 'Gold 22k', 'Kerala', 'TIGHT ARANJAL', NULL, NULL, 'Tight Aranjal'),
    ('Matti Chain', 'Gold 22k', 'Antique', 'Antique', NULL, NULL, 'Fancy'),
    ('Matti Chain', 'Gold 22k', 'Antique', 'Ilakka Thali', NULL, NULL, 'Elakkathali'),
    ('Matti Chain', 'Gold 22k', 'Culcutta', 'Culcutta plain', NULL, 'Kolkata', 'Plain'),
    ('Matti Chain', 'Gold 22k', 'Culcutta', 'Enamel', NULL, 'Kolkata', NULL),
    ('Matti Chain', 'Gold 22k', 'Culcutta', 'Plain', NULL, 'Kolkata', NULL),
    ('Matti Chain', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Matti Chain', 'Gold 22k', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Gold 14K', '14 Carat Ornaments', '14 Karat Ornaments', NULL, '14 Kt Ornaments', NULL),
    ('Necklace', 'Gold 14K', '14 Carat Ornaments', 'Diamond', NULL, '14 Kt Ornaments', 'Fancy'),
    ('Necklace', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Necklace', 'Gold 22k', 'Antique', 'Antique', NULL, NULL, 'Fancy'),
    ('Necklace', 'Gold 22k', 'Antique', 'Ilakka Thali', NULL, NULL, 'Elakkathali'),
    ('Necklace', 'Gold 22k', 'Antique', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Gold 22k', 'BENGALI', 'Plain', NULL, 'Bengali', NULL),
    ('Necklace', 'Gold 22k', 'BENGALI', 'Rodium', NULL, 'Bengali', 'Rhodium'),
    ('Necklace', 'Gold 22k', 'BENGALI', 'Stone', NULL, 'Bengali', NULL),
    ('Necklace', 'Gold 22k', 'BENGALI', 'THREAD', NULL, 'Bengali', 'Thread'),
    ('Necklace', 'Gold 22k', 'BENGALI', 'Thread Locket', NULL, 'Bengali', NULL),
    ('Necklace', 'Gold 22k', 'Bombay', 'Bombay', NULL, NULL, 'Plain'),
    ('Necklace', 'Diamond', 'BRIDAL', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Necklace', 'Diamond', 'BRIDAL', 'God', NULL, 'Moulding', NULL),
    ('Necklace', 'Diamond', 'BRIDAL', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Necklace', 'Diamond', 'BRIDAL', 'RADHA KRISHNA', NULL, 'Moulding', 'Radha Krishna'),
    ('Necklace', 'Gold 22k', 'Chettinadu', 'Chettinadu', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Gold 22k', 'Chettinadu', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Gold 22k', 'Coimbatore', 'ADDIGAI', NULL, NULL, 'Addigai'),
    ('Necklace', 'Gold 22k', 'Coimbatore', 'PADAKKA', NULL, NULL, 'Padakka'),
    ('Necklace', 'Gold 22k', 'Coimbatore', 'PEARL MALA', NULL, NULL, 'Pearl Mala'),
    ('Necklace', 'Gold 22k', 'Culcutta', 'Bengali', NULL, 'Kolkata', 'Plain'),
    ('Necklace', 'Gold 22k', 'Culcutta', 'Culcutta plain', NULL, 'Kolkata', 'Plain'),
    ('Necklace', 'Gold 22k', 'Culcutta', 'Culcutta Stone', NULL, 'Kolkata', 'Stone'),
    ('Necklace', 'Gold 22k', 'Culcutta', 'Enamel', NULL, 'Kolkata', NULL),
    ('Necklace', 'Gold 22k', 'Culcutta', 'Mangalsutra', NULL, 'Kolkata', NULL),
    ('Necklace', 'Gold 22k', 'Culcutta', 'Plain', NULL, 'Kolkata', NULL),
    ('Necklace', 'Gold 22k', 'Culcutta', 'Rodium', NULL, 'Kolkata', 'Rhodium'),
    ('Necklace', 'Gold 22k', 'Culcutta', 'Stone', NULL, 'Kolkata', NULL),
    ('Necklace', 'Diamond', 'DESIGNER', 'CHARMS', NULL, 'Moulding', 'Charms'),
    ('Necklace', 'Diamond', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Necklace', 'Diamond', 'DESIGNER', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Necklace', 'Diamond', 'DESIGNER', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Necklace', 'Diamond', 'DESIGNER', 'Navaratna', NULL, 'Moulding', NULL),
    ('Necklace', 'Diamond', 'DESIGNER', 'RADHA KRISHNA', NULL, 'Moulding', 'Radha Krishna'),
    ('Necklace', 'Gold 14K', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Necklace', 'Diamond', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Necklace', 'Gold 14K', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Necklace', 'Diamond', 'Diamond SI Jewellery', 'Diamond SI', NULL, 'Moulding', 'Fancy'),
    ('Necklace', 'Diamond', 'HERITAGE', 'CLASSIC', NULL, 'Moulding', 'Classic'),
    ('Necklace', 'Diamond', 'HERITAGE', 'CLOSED SETTING', NULL, 'Moulding', 'Closed Setting'),
    ('Necklace', 'Diamond', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Necklace', 'Diamond', 'HERITAGE', 'Mangalsutra', NULL, 'Moulding', NULL),
    ('Necklace', 'Diamond', 'HERITAGE', 'MEENAKSHI', NULL, 'Moulding', 'Meenakshi'),
    ('Necklace', 'Diamond', 'HERITAGE', 'OPEN CLOSE SETTING', NULL, 'Moulding', 'Open Close Setting'),
    ('Necklace', 'Diamond', 'HERITAGE', 'RADHA KRISHNA', NULL, 'Moulding', 'Radha Krishna'),
    ('Necklace', 'Polki', 'HERITAGE', 'JADAU', NULL, 'Polki', 'Jadau'),
    ('Necklace', 'Polki', 'HERITAGE', 'OPEN CLOSE SETTING', NULL, 'Polki', 'Open Close Setting'),
    ('Necklace', 'Precious', 'HERITAGE', 'Designer', NULL, 'Moulding', NULL),
    ('Necklace', 'Precious', 'HERITAGE', 'FILIGREE', NULL, 'Moulding', 'Filigree'),
    ('Necklace', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Necklace', 'Precious', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Necklace', 'Precious', 'HERITAGE', 'Navaratna', NULL, 'Moulding', NULL),
    ('Necklace', 'Uncut', 'HERITAGE', 'Designer', NULL, 'Moulding', NULL),
    ('Necklace', 'Uncut', 'HERITAGE', 'FILIGREE', NULL, 'Moulding', 'Filigree'),
    ('Necklace', 'Uncut', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Necklace', 'Uncut', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Necklace', 'Uncut', 'HERITAGE', 'Layer', NULL, 'Moulding', NULL),
    ('Necklace', 'Uncut', 'HERITAGE', 'Mangalsutra', NULL, 'Moulding', NULL),
    ('Necklace', 'Uncut', 'HERITAGE', 'NAKASHI', NULL, 'Moulding', 'Nakashi'),
    ('Necklace', 'Gold 14K', 'ITALIAN', 'CERA', NULL, 'Italian', 'Cera'),
    ('Necklace', 'Gold 14K', 'ITALIAN', 'CLASSIC', NULL, 'Italian', 'Fancy'),
    ('Necklace', 'Gold 14K', 'ITALIAN', 'CUPOD', NULL, 'Italian', 'Cupod'),
    ('Necklace', 'Gold 14K', 'ITALIAN', 'FLORA', NULL, 'Italian', 'Flora'),
    ('Necklace', 'Gold 14K', 'ITALIAN', 'YIN-YANG', NULL, 'Italian', 'Yin-Yang'),
    ('Necklace', 'Gold 18K', 'ITALIAN', 'Black Beeds', NULL, 'Italian', NULL),
    ('Necklace', 'Gold 18K', 'ITALIAN', 'Plain', NULL, 'Italian', NULL),
    ('Necklace', 'Gold 18K', 'ITALIAN', 'Rodium', NULL, 'Italian', 'Rhodium'),
    ('Necklace', 'Gold 22k', 'Karnataka', 'AVIL MALA', NULL, NULL, 'Avil Mala'),
    ('Necklace', 'Gold 22k', 'Karnataka', 'CORAL MALA', NULL, 'Karnataka Traditional', 'Coral'),
    ('Necklace', 'Gold 22k', 'Karnataka', 'MANDAKASARA', NULL, 'Karnataka Traditional', 'Mandakasara'),
    ('Necklace', 'Gold 22k', 'Karnataka', 'Mangalsutra', NULL, 'Karnataka Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Karnataka', 'MOHANMALA', NULL, 'Karnataka Traditional', 'Mohanmala'),
    ('Necklace', 'Gold 22k', 'Karnataka', 'NAVARATNA MALA', NULL, NULL, 'Navaratna Mala'),
    ('Necklace', 'Gold 22k', 'Karnataka', 'PEARL MALA', NULL, NULL, 'Pearl Mala'),
    ('Necklace', 'Gold 22k', 'Karnataka', 'STONE MALA', NULL, NULL, 'Stone Mala'),
    ('Necklace', 'Gold 22k', 'Karnataka', 'Thulasi', NULL, 'Karnataka Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Kerala', 'Black Beeds', NULL, 'Kerala Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Kerala', 'CRYSTAL', NULL, NULL, 'Crystal'),
    ('Necklace', 'Gold 22k', 'Kerala', 'Ilakka Thali', NULL, 'Kerala Traditional', 'Elakkathali'),
    ('Necklace', 'Gold 22k', 'Kerala', 'KARINGALI', NULL, NULL, 'Karingali'),
    ('Necklace', 'Gold 22k', 'Kerala', 'KASUMALA STONE', NULL, NULL, 'Kasumala Stone'),
    ('Necklace', 'Gold 22k', 'Kerala', 'LAKSHMI STONE', NULL, NULL, 'Lakshmi Stone'),
    ('Necklace', 'Gold 22k', 'Kerala', 'MATTE', NULL, NULL, 'Matte'),
    ('Necklace', 'Gold 22k', 'Kerala', 'MATTE STONE', NULL, NULL, 'Matte Stone'),
    ('Necklace', 'Gold 22k', 'Kerala', 'MULLAMUTTU STONE', NULL, NULL, 'Mullamuttu Stone'),
    ('Necklace', 'Gold 22k', 'Kerala', 'PALAKKA THREAD LOCKET', NULL, NULL, 'Palakka Thread Locket'),
    ('Necklace', 'Gold 22k', 'Kerala', 'PEARL MALA', NULL, NULL, 'Pearl Mala'),
    ('Necklace', 'Gold 22k', 'Kerala', 'THREAD LOCKET GOD', NULL, NULL, 'Thread Locket God'),
    ('Necklace', 'Gold 18K', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Necklace', 'Gold 22k', 'Moulding', 'Moulding', NULL, NULL, 'Fancy'),
    ('Necklace', 'Gold 22k', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Necklace', 'Diamond', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Necklace', 'Gold 18K', 'Nagas', 'MEENAKSHI', NULL, NULL, 'Meenakshi'),
    ('Necklace', 'Gold 22k', 'Nagas', 'BALAJI', NULL, NULL, 'Balaji'),
    ('Necklace', 'Gold 22k', 'Nagas', 'LAKSHMI STONE', NULL, NULL, 'Lakshmi Stone'),
    ('Necklace', 'Gold 22k', 'Nagas', 'MEENAKSHI', NULL, NULL, 'Meenakshi'),
    ('Necklace', 'Gold 22k', 'Nagas', 'Nagas', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Gold 22k', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Gold 22k', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Necklace', 'Gold 22k', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Necklace', 'Gold 22k', 'Nagas', 'SITA RAM', NULL, NULL, 'Sita Ram'),
    ('Necklace', 'Gold 22k', 'Nagas', 'special nagas', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Precious', 'Nagas', 'FILIGREE', NULL, NULL, 'Filigree'),
    ('Necklace', 'Precious', 'Nagas', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Necklace', 'Precious', 'Nagas', 'KANTI', NULL, NULL, 'Kanti'),
    ('Necklace', 'Precious', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Precious', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Necklace', 'Precious', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Necklace', 'Uncut', 'Nagas', 'KANTI', NULL, NULL, 'Kanti'),
    ('Necklace', 'Uncut', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Uncut', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Necklace', 'Uncut', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Necklace', 'Gold 22k', 'Nagas Premium', 'Nagas', NULL, 'Nagas', 'Nakashi'),
    ('Necklace', 'Gold 22k', 'Nagas Premium', 'special nagas', NULL, 'Nagas', 'Nakashi'),
    ('Necklace', 'Gold 22k', 'Nellore', 'Stone', NULL, 'Karnataka Traditional', 'Nellore'),
    ('Necklace', 'Platinum', 'Platinum', 'CLASSIC', NULL, NULL, 'Fancy'),
    ('Necklace', 'Platinum', 'Platinum', 'Platinum', NULL, NULL, 'Fancy'),
    ('Necklace', 'Platinum', 'Platinum', 'Platinum Fusion', NULL, NULL, 'Fusion'),
    ('Necklace', 'Platinum', 'PLATINUM FUSION', 'CLASSIC', NULL, 'Platinum', 'Fusion'),
    ('Necklace', 'Polki', 'Polki', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Polki', 'Polki', 'OPEN CLOSE SETTING', NULL, NULL, 'Open Close Setting'),
    ('Necklace', 'Polki', 'Polki', 'Polki', NULL, NULL, 'Fancy'),
    ('Necklace', 'Precious', 'Precious', 'Precious', NULL, 'Moulding', 'Fancy'),
    ('Necklace', 'Gold 22k', 'Rajkot', 'Rajkot', NULL, NULL, 'Plain'),
    ('Necklace', 'Gold 22k', 'Rajkot', 'Rajkot Beeds', NULL, NULL, 'Beeds'),
    ('Necklace', 'Gold 22k', 'Rajkot', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Necklace', 'Gold 22k', 'RAJKOT CHAIN', 'Rajkot', NULL, 'Rajkot', 'Plain'),
    ('Necklace', 'Gold 22k', 'RED SANDAL', 'RED SANDAL SP', NULL, 'Kerala Traditional', 'Red Sandal Sp'),
    ('Necklace', 'Gold 22k', 'RUDRAKSHAM', 'RUDRAKSHAM SP', NULL, 'Kerala Traditional', 'Rudraksham Sp'),
    ('Necklace', 'Gold 22k', 'Semi Antique', 'Semi Antique', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Gold 22k', 'Semi Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Gold 22k', 'Semi Nagas', 'Semi Nagas', NULL, NULL, 'Nakashi'),
    ('Necklace', 'Gold 22k', 'Semi Turkish', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Necklace', 'Gold 22k', 'Semi Turkish', 'Semi Turkish', NULL, NULL, 'Plain'),
    ('Necklace', 'Diamond', 'SIGNATURE', 'CHARMS', NULL, 'Moulding', 'Charms'),
    ('Necklace', 'Diamond', 'SIGNATURE', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Necklace', 'Diamond', 'SIGNATURE', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Necklace', 'Diamond', 'SIGNATURE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Necklace', 'Diamond', 'SIGNATURE', 'SOLITAIRE', NULL, 'Moulding', 'Solitaire'),
    ('Necklace', 'Diamond', 'SIGNATURE', 'Twisted', NULL, 'Moulding', NULL),
    ('Necklace', 'Gold 22k', 'Singapore', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Necklace', 'Gold 22k', 'Singapore', 'Singapore', NULL, NULL, 'Plain'),
    ('Necklace', 'Gold 22k', 'Singapore', 'SINGAPORE STONE', NULL, NULL, 'Singapore Stone'),
    ('Necklace', 'Diamond', 'SOLITAIRE', 'SOLITAIRE', NULL, 'Moulding', 'Solitaire'),
    ('Necklace', 'Gold 22k', 'THULASI', 'THULASI SP', NULL, 'Kerala Traditional', 'Thulasi'),
    ('Necklace', 'Gold 22k', 'Traditional', 'Black Beeds', NULL, 'Kerala Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Traditional', 'Coral', NULL, 'Kerala Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Traditional', 'Lakshmi', NULL, 'Karnataka Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Traditional', 'Mangalsutra', NULL, 'Karnataka Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Traditional', 'Palakka', NULL, 'Kerala Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Traditional', 'Palakka-A', NULL, 'Kerala Traditional', 'Palakka'),
    ('Necklace', 'Gold 22k', 'Traditional', 'Palakka-C', NULL, 'Kerala Traditional', 'Palakka'),
    ('Necklace', 'Gold 22k', 'Traditional', 'Traditional', NULL, 'Kerala Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Traditional', 'Traditional thread locket', NULL, 'Kerala Traditional', NULL),
    ('Necklace', 'Gold 22k', 'Traditional', 'TRADITIONAL THREAD LOCKET PALAKKA', NULL, 'Kerala Traditional', 'Traditional Thread Locket Palakka'),
    ('Necklace', 'Gold 22k', 'Turkish', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Necklace', 'Gold 22k', 'Turkish', 'Turkish', NULL, NULL, 'Plain'),
    ('Necklace', 'Gold 22k', 'Turkish', 'TURKISH SPECIAL', NULL, NULL, 'Stone'),
    ('Necklace', 'Precious', 'Turkish', 'FILIGREE', NULL, NULL, 'Filigree'),
    ('Necklace', 'Precious', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Necklace', 'Uncut', 'Turkish', 'FILIGREE', NULL, NULL, 'Filigree'),
    ('Necklace', 'Uncut', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Nose Pin', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Nose Pin', 'Diamond', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'BUGADI', NULL, 'Moulding', 'Bugadi'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'CLOSED SETTING', NULL, 'Moulding', 'Closed Setting'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'Fancy', NULL, 'Moulding', NULL),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'Flower', NULL, 'Moulding', 'Floral'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'J TYPE', NULL, 'Moulding', 'J Type'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'SANIYA', NULL, 'Moulding', 'Saniya'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'SINGLE STONE', NULL, 'Moulding', 'Single Stone'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'STAR', NULL, 'Moulding', 'Star'),
    ('Nose Pin', 'Diamond', 'SIGNATURE', 'SWASTIK', NULL, 'Moulding', 'Swastik'),
    ('Odiyyanam', 'Diamond', 'BRIDAL', 'God', NULL, 'Moulding', NULL),
    ('Odiyyanam', 'Diamond', 'DESIGNER', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Odiyyanam', 'Gold 18K', 'Nagas', 'MEENAKSHI', NULL, NULL, 'Meenakshi'),
    ('Odiyyanam', 'Gold 22k', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Odiyyanam', 'Gold 22k', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Odiyyanam', 'Gold 22k', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Odiyyanam', 'Precious', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Odiyyanam', 'Uncut', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Ovel Bracelet', 'Diamond', '14 Carat Ornaments', 'Diamond', 'Bracelet', '14 Kt Ornaments', 'Oval'),
    ('Ovel Bracelet', 'Gold 14K', '14 Carat Ornaments', '14 Karat Ornaments', 'Bracelet', '14 Kt Ornaments', 'Oval'),
    ('Ovel Bracelet', 'Gold 14K', '14 Carat Ornaments', 'Diamond', 'Bracelet', '14 Kt Ornaments', 'Oval'),
    ('Ovel Bracelet', 'Gold 14K', '14 Carat Ornaments', 'Oval', 'Bracelet', '14 Kt Ornaments', 'Oval'),
    ('Ovel Bracelet', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Ovel Bracelet', 'Diamond', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Ovel Bracelet', 'Diamond', 'DESIGNER', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Ovel Bracelet', 'Diamond', 'DESIGNER', 'Navaratna', NULL, 'Moulding', NULL),
    ('Ovel Bracelet', 'Diamond', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Ovel Bracelet', 'Diamond', 'Diamond', 'Oval', NULL, 'Moulding', NULL),
    ('Ovel Bracelet', 'Diamond', 'Diamond SI Jewellery', 'Diamond SI', NULL, 'Moulding', 'Fancy'),
    ('Ovel Bracelet', 'Diamond', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Ovel Bracelet', 'Diamond', 'HERITAGE', 'NAKASHI', NULL, 'Moulding', 'Nakashi'),
    ('Ovel Bracelet', 'Polki', 'HERITAGE', 'JADAU', NULL, 'Polki', 'Jadau'),
    ('Ovel Bracelet', 'Polki', 'HERITAGE', 'Navaratna', NULL, 'Polki', NULL),
    ('Ovel Bracelet', 'Polki', 'HERITAGE', 'OPEN CLOSE SETTING', NULL, 'Polki', 'Open Close Setting'),
    ('Ovel Bracelet', 'Precious', 'HERITAGE', 'FILIGREE', NULL, 'Moulding', 'Filigree'),
    ('Ovel Bracelet', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Ovel Bracelet', 'Precious', 'HERITAGE', 'Navaratna', NULL, 'Moulding', NULL),
    ('Ovel Bracelet', 'Uncut', 'HERITAGE', 'FILIGREE', NULL, 'Moulding', 'Filigree'),
    ('Ovel Bracelet', 'Uncut', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Ovel Bracelet', 'Gold 14K', 'ITALIAN', 'CERA', NULL, NULL, 'Cera'),
    ('Ovel Bracelet', 'Gold 14K', 'ITALIAN', 'CUPOD', NULL, NULL, 'Cupod'),
    ('Ovel Bracelet', 'Gold 14K', 'ITALIAN', 'FLORA', NULL, NULL, 'Flora'),
    ('Ovel Bracelet', 'Gold 14K', 'ITALIAN', 'YIN-YANG', NULL, NULL, 'Yin-Yang'),
    ('Ovel Bracelet', 'Precious', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Ovel Bracelet', 'Gold 14K', 'Ovel Bracelet', '14 Karat Ornaments', 'Bracelet', NULL, NULL),
    ('Ovel Bracelet', 'Platinum', 'Platinum', 'CLASSIC', NULL, NULL, 'Fancy'),
    ('Ovel Bracelet', 'Platinum', 'PLATINUM FUSION', 'CLASSIC', NULL, 'Platinum', 'Fusion'),
    ('Ovel Bracelet', 'Diamond', 'SIGNATURE', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Ovel Bracelet', 'Diamond', 'SIGNATURE', 'Twisted', NULL, 'Moulding', NULL),
    ('Pendant', 'Gold 14K', '14 Carat Ornaments', '14 Karat Ornaments', NULL, '14 Kt Ornaments', NULL),
    ('Pendant', 'Gold 14K', '14 Carat Ornaments', 'Diamond', NULL, '14 Kt Ornaments', 'Fancy'),
    ('Pendant', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Pendant', 'Gold 22k', 'Antique', 'Antique', NULL, NULL, 'Fancy'),
    ('Pendant', 'Gold 22k', 'Antique', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Pendant', 'Gold 22k', 'BENGALI', 'Plain', NULL, 'Bombay', NULL),
    ('Pendant', 'Gold 22k', 'BENGALI', 'Stone', NULL, 'Bombay', NULL),
    ('Pendant', 'Precious', 'BIRTH STONE', 'GEMSTONE', NULL, 'Birth Stone', 'Gemstone'),
    ('Pendant', 'Gold 22k', 'Bombay', 'Bombay', NULL, NULL, 'Plain'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'ADDIGAI', NULL, NULL, 'Addigai'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'ARASA ILLAI THALI', NULL, NULL, 'Arasa Illai Thali'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'LAKSHMI COIN', NULL, NULL, 'Lakshmi Coin'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'LAKSHMI DOLLAR', NULL, NULL, 'Lakshmi Dollar'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'MANGO STONE THALI', NULL, NULL, 'Mango Stone Thali'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'MANJIMA GOD', NULL, NULL, 'Manjima God'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'OHM DOLLAR', NULL, NULL, 'Ohm Dollar'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'PEACOCK THALI', NULL, NULL, 'Peacock Thali'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'PEARL THALI', NULL, NULL, 'Pearl Thali'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'PERAL RED', NULL, NULL, 'Coral'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'PILLAYAR THALI', NULL, NULL, 'Pillayar Thali'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'POTTU THALI', NULL, NULL, 'Pottu Thali'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'SILLUVAI DOLLAR', NULL, NULL, 'Silluvai Dollar'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'SILUVAI THALI', NULL, NULL, 'Siluvai Thali'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'SOKKAR MEENAKSHI THALI', NULL, NULL, 'Sokkar Meenakshi Thali'),
    ('Pendant', 'Gold 22k', 'Coimbatore', 'URUTTU POTHARAM', NULL, NULL, 'Uruttu Potharam'),
    ('Pendant', 'Gold 22k', 'Culcutta', 'Culcutta Enamel', NULL, 'Kolkata', 'Enamel'),
    ('Pendant', 'Gold 22k', 'Culcutta', 'Culcutta plain', NULL, 'Kolkata', 'Plain'),
    ('Pendant', 'Gold 22k', 'Culcutta', 'Culcutta Stone', NULL, 'Kolkata', 'Stone'),
    ('Pendant', 'Gold 22k', 'Culcutta', 'Enamel', NULL, 'Kolkata', NULL),
    ('Pendant', 'Gold 22k', 'Culcutta', 'Plain', NULL, 'Kolkata', NULL),
    ('Pendant', 'Gold 22k', 'Culcutta', 'Stone', NULL, 'Kolkata', NULL),
    ('Pendant', 'Diamond', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Pendant', 'Diamond', 'DESIGNER', 'TANMANIYA', NULL, 'Moulding', 'Tanmaniya'),
    ('Pendant', 'Gold 14K', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Pendant', 'Diamond', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Pendant', 'Gold 14K', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Pendant', 'Diamond', 'Diamond SI Jewellery', 'Diamond SI', NULL, 'Moulding', 'Fancy'),
    ('Pendant', 'Diamond', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Pendant', 'Diamond', 'HERITAGE', 'Mangalsutra', NULL, 'Moulding', NULL),
    ('Pendant', 'Diamond', 'HERITAGE', 'Mugappu', NULL, 'Moulding', NULL),
    ('Pendant', 'Diamond', 'HERITAGE', 'Mugappu God', NULL, 'Moulding', NULL),
    ('Pendant', 'Diamond', 'HERITAGE', 'MUGAPPU LAKSHMI', NULL, 'Moulding', 'Mugappu Lakshmi'),
    ('Pendant', 'Diamond', 'HERITAGE', 'OPEN CLOSE SETTING', NULL, 'Moulding', 'Open Close Setting'),
    ('Pendant', 'Polki', 'HERITAGE', 'JADAU', NULL, 'Polki', 'Jadau'),
    ('Pendant', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Pendant', 'Uncut', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Pendant', 'Uncut', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Pendant', 'Uncut', 'HERITAGE', 'TIGER NAIL', NULL, 'Moulding', 'Tiger Nail'),
    ('Pendant', 'Gold 14K', 'ITALIAN', 'CERA', NULL, NULL, 'Cera'),
    ('Pendant', 'Gold 14K', 'ITALIAN', 'CLASSIC', NULL, 'Italian', 'Fancy'),
    ('Pendant', 'Gold 14K', 'ITALIAN', 'CUPOD', NULL, NULL, 'Cupod'),
    ('Pendant', 'Gold 14K', 'ITALIAN', 'FLORA', NULL, NULL, 'Flora'),
    ('Pendant', 'Gold 14K', 'ITALIAN', 'YIN-YANG', NULL, NULL, 'Yin-Yang'),
    ('Pendant', 'Gold 18K', 'ITALIAN', 'Rodium', NULL, 'Italian', 'Rhodium'),
    ('Pendant', 'Gold 22k', 'Karnataka', 'DISCO KASU', NULL, NULL, 'Disco Kasu'),
    ('Pendant', 'Gold 22k', 'Karnataka', 'Gini Buttu', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Karnataka', 'Lakshmi', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Karnataka', 'LAKSHMI KAASHI', NULL, 'Karnataka Traditional', 'Kaasu'),
    ('Pendant', 'Gold 22k', 'Karnataka', 'M Thali', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Karnataka', 'MYSUR THALI', NULL, 'Karnataka Traditional', 'Mysur Thali'),
    ('Pendant', 'Gold 22k', 'Karwar', 'Karwar', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Kerala', 'KERALA FANCY', NULL, NULL, 'Kerala Fancy'),
    ('Pendant', 'Gold 22k', 'Kerala', 'KUMBALA OHM THALI', NULL, NULL, 'Kumbala Om Thali'),
    ('Pendant', 'Gold 22k', 'Kerala', 'KUMBALA PLAIN THALI', NULL, NULL, 'Kumbala Plain Thali'),
    ('Pendant', 'Gold 22k', 'Kerala', 'MANJIMA CROSS', NULL, NULL, 'Manjima Cross'),
    ('Pendant', 'Gold 22k', 'Kerala', 'MANJIMA GOD', NULL, NULL, 'Manjima God'),
    ('Pendant', 'Gold 22k', 'Kerala', 'MANJIMA GURUVAYURAPPAN', NULL, NULL, 'Manjima Guruvayurappan'),
    ('Pendant', 'Gold 22k', 'Kerala', 'MANJIMA JESUS', NULL, NULL, 'Manjima Jesus'),
    ('Pendant', 'Gold 22k', 'Kerala', 'MANJIMA KRISHNA', NULL, NULL, 'Manjima Krishna'),
    ('Pendant', 'Gold 22k', 'Kerala', 'MANJIMA LAKSHMI', NULL, NULL, 'Manjima Lakshmi'),
    ('Pendant', 'Gold 22k', 'Kerala', 'MANJIMA OM', NULL, NULL, 'Manjima Om'),
    ('Pendant', 'Gold 22k', 'Kerala', 'MANJIMA SARASWATHI', NULL, NULL, 'Manjima Saraswathi'),
    ('Pendant', 'Gold 22k', 'Kerala', 'Ohm Thali', NULL, 'Kerala Traditional', 'Om Thali'),
    ('Pendant', 'Gold 22k', 'Kerala', 'PIPE CROSS', NULL, NULL, 'Pipe Cross'),
    ('Pendant', 'Gold 22k', 'Kerala', 'SLEEVA CROSS', NULL, NULL, 'Sleeva Cross'),
    ('Pendant', 'Gold 22k', 'Kerala', 'SLEEVA THALI', NULL, NULL, 'Sleeva Thali'),
    ('Pendant', 'Gold 22k', 'Kerala', 'SOLID CROSS', NULL, NULL, 'Solid Cross'),
    ('Pendant', 'Gold 22k', 'Kerala Special', 'Bengali', NULL, 'Kerala', 'Plain'),
    ('Pendant', 'Gold 22k', 'Kerala Special', 'Kerala', NULL, 'Kerala', 'Plain'),
    ('Pendant', 'Gold 22k', 'Moulding', 'FISH', NULL, NULL, 'Fish'),
    ('Pendant', 'Gold 22k', 'Moulding', 'Moulding', NULL, NULL, 'Fancy'),
    ('Pendant', 'Gold 22k', 'Moulding', 'OHM', NULL, NULL, 'Om'),
    ('Pendant', 'Gold 22k', 'Moulding', 'Papper Cast', NULL, NULL, 'Paper Cast'),
    ('Pendant', 'Gold 22k', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Pendant', 'Gold 22k', 'Nagas', 'GANDABERUNDA', NULL, NULL, 'Gandaberunda'),
    ('Pendant', 'Gold 22k', 'Nagas', 'Nagas', NULL, NULL, 'Nakashi'),
    ('Pendant', 'Gold 22k', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Pendant', 'Gold 22k', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Pendant', 'Gold 22k', 'Nellore', 'Nellore', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Nellore', 'Stone', NULL, 'Karnataka Traditional', 'Nellore'),
    ('Pendant', 'Platinum', 'Platinum', 'CLASSIC', NULL, NULL, 'Fancy'),
    ('Pendant', 'Platinum', 'Platinum', 'Platinum', NULL, NULL, 'Fancy'),
    ('Pendant', 'Platinum', 'Platinum', 'Platinum Fusion', NULL, NULL, 'Fusion'),
    ('Pendant', 'Platinum', 'PLATINUM FUSION', 'CLASSIC', NULL, 'Platinum', 'Fusion'),
    ('Pendant', 'Polki', 'Polki', 'Polki', NULL, NULL, 'Fancy'),
    ('Pendant', 'Gold 22k', 'Rajkot', 'Rajkot', NULL, NULL, 'Plain'),
    ('Pendant', 'Gold 22k', 'Rajkot', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Pendant', 'Gold 22k', 'Rajkot', 'WATTI', NULL, NULL, 'Watti'),
    ('Pendant', 'Gold 22k', 'Semi Antique', 'Semi Antique', NULL, NULL, 'Nakashi'),
    ('Pendant', 'Diamond', 'SIGNATURE', 'Alphabet', NULL, 'Moulding', NULL),
    ('Pendant', 'Diamond', 'SIGNATURE', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Pendant', 'Diamond', 'SIGNATURE', 'HANGING THALI', NULL, 'Moulding', 'Hanging Thali'),
    ('Pendant', 'Diamond', 'SIGNATURE', 'Minnu', NULL, 'Moulding', NULL),
    ('Pendant', 'Diamond', 'SIGNATURE', 'TANMANIYA', NULL, 'Moulding', 'Tanmaniya'),
    ('Pendant', 'Diamond', 'SIGNATURE', 'THALI', NULL, 'Moulding', 'Thali'),
    ('Pendant', 'Gold 22k', 'SIGNITY', 'CLOSED SETTING', NULL, NULL, 'Closed Setting'),
    ('Pendant', 'Gold 22k', 'Singapore', 'SIMBA', NULL, NULL, 'Simba'),
    ('Pendant', 'Diamond', 'SOLITAIRE', 'SOLITAIRE', NULL, 'Moulding', 'Solitaire'),
    ('Pendant', 'Gold 22k', 'Traditional', 'Christian Thali', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Cross', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Gini Buttu', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Islamic Thali', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'M Thali', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Mangalore Thali', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Minnu', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Moulding', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Mysore Thali', NULL, 'Karnataka Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Name', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Ohm Thali', NULL, 'Kerala Traditional', 'Om Thali'),
    ('Pendant', 'Gold 22k', 'Traditional', 'Paksha Thali', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Palakka', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Tamil Thali', NULL, 'Tamil Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Thali God', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Thali Plain', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Gold 22k', 'Traditional', 'Traditional', NULL, 'Kerala Traditional', NULL),
    ('Pendant', 'Precious', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Ring', 'Gold 14K', '14 Carat Ornaments', '14 Karat Ornaments', NULL, '14 Kt Ornaments', NULL),
    ('Ring', 'Gold 14K', '14 Carat Ornaments', 'Diamond', NULL, '14 Kt Ornaments', 'Fancy'),
    ('Ring', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Ring', 'Gold 22k', 'Antique', 'Antique', NULL, NULL, 'Fancy'),
    ('Ring', 'Gold 22k', 'Antique', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Ring', 'Gold 22k', 'BENGALI', 'Bengali', NULL, 'Bombay', 'Plain'),
    ('Ring', 'Gold 22k', 'BENGALI', 'Enamel', NULL, 'Bombay', NULL),
    ('Ring', 'Gold 22k', 'BENGALI', 'Plain', NULL, 'Bombay', NULL),
    ('Ring', 'Gold 22k', 'BENGALI', 'Stone', NULL, 'Bombay', NULL),
    ('Ring', 'Precious', 'BIRTH STONE', 'GEMSTONE', NULL, 'Birth Stone', 'Gemstone'),
    ('Ring', 'Gold 22k', 'Bombay', 'Bombay', NULL, NULL, 'Plain'),
    ('Ring', 'Gold 22k', 'Bombay', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Ring', 'Gold 22k', 'Chettinadu', 'Chettinadu', NULL, NULL, 'Cocktail'),
    ('Ring', 'Gold 22k', 'Coimbatore', 'CLOSED SETTING', NULL, NULL, 'Closed Setting'),
    ('Ring', 'Gold 22k', 'Coimbatore', 'Vangi', NULL, NULL, 'Vanki'),
    ('Ring', 'Gold 22k', 'Coimbatore', 'VANGI CLOSED SETTING', NULL, NULL, 'Vangi Closed Setting'),
    ('Ring', 'Gold 22k', 'Culcutta', 'CALCUTTA VANGI RING ENAMEL', NULL, 'Kolkata', 'Vanki'),
    ('Ring', 'Gold 22k', 'Culcutta', 'Culcutta plain', NULL, 'Kolkata', 'Plain'),
    ('Ring', 'Gold 22k', 'Culcutta', 'Culcutta Stone', NULL, 'Kolkata', 'Stone'),
    ('Ring', 'Gold 22k', 'Culcutta', 'Enamel', NULL, 'Kolkata', NULL),
    ('Ring', 'Gold 22k', 'Culcutta', 'Plain', NULL, 'Kolkata', NULL),
    ('Ring', 'Gold 22k', 'Culcutta', 'Vangi', NULL, 'Kolkata', 'Vanki'),
    ('Ring', 'Diamond', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Ring', 'Diamond', 'DESIGNER', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Ring', 'Diamond', 'DESIGNER', 'PIE-CUT', NULL, 'Moulding', 'Pie-Cut'),
    ('Ring', 'Diamond', 'DESIGNER', 'Vangi', NULL, 'Moulding', 'Vanki'),
    ('Ring', 'Diamond', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Ring', 'Diamond', 'Diamond SI Jewellery', 'Diamond SI', NULL, 'Moulding', 'Fancy'),
    ('Ring', 'Diamond', 'HERITAGE', 'CLOSED SETTING', NULL, 'Moulding', 'Closed Setting'),
    ('Ring', 'Diamond', 'HERITAGE', 'God', NULL, 'Moulding', NULL),
    ('Ring', 'Diamond', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Ring', 'Polki', 'HERITAGE', 'JADAU', NULL, 'Polki', 'Jadau'),
    ('Ring', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Ring', 'Precious', 'HERITAGE', 'Navaratna', NULL, 'Moulding', NULL),
    ('Ring', 'Uncut', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Ring', 'Gold 14K', 'ITALIAN', 'CERA', NULL, NULL, 'Cera'),
    ('Ring', 'Gold 14K', 'ITALIAN', 'CLASSIC', NULL, 'Italian', 'Fancy'),
    ('Ring', 'Gold 14K', 'ITALIAN', 'CUPOD', NULL, NULL, 'Cupod'),
    ('Ring', 'Gold 14K', 'ITALIAN', 'FLORA', NULL, NULL, 'Flora'),
    ('Ring', 'Gold 14K', 'ITALIAN', 'YIN-YANG', NULL, NULL, 'Yin-Yang'),
    ('Ring', 'Gold 22k', 'Karnataka', 'Karwar', NULL, 'Karnataka Traditional', NULL),
    ('Ring', 'Gold 22k', 'Karwar', 'Karwar', NULL, 'Karnataka Traditional', NULL),
    ('Ring', 'Gold 22k', 'Kerala', 'KATTI TV', NULL, NULL, 'Katti Tv'),
    ('Ring', 'Gold 22k', 'Kerala', 'MINCHI PIPE', NULL, NULL, 'Minchi Pipe'),
    ('Ring', 'Gold 22k', 'Kerala Special', 'Kerala', NULL, 'Kerala', 'Plain'),
    ('Ring', 'Gold 18K', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Ring', 'Gold 22k', 'Moulding', 'COUPLE', NULL, NULL, 'Couple'),
    ('Ring', 'Gold 22k', 'Moulding', 'Moulding', NULL, NULL, 'Fancy'),
    ('Ring', 'Gold 22k', 'Moulding', 'Papper Cast', NULL, NULL, 'Paper Cast'),
    ('Ring', 'Gold 22k', 'Moulding', 'RAINBOW', NULL, NULL, 'Rainbow'),
    ('Ring', 'Gold 22k', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Ring', 'Gold 22k', 'Moulding', 'Vangi', NULL, NULL, 'Vanki'),
    ('Ring', 'Gold 22k', 'Moulding', 'VANGI STONE', NULL, NULL, 'Vangi Stone'),
    ('Ring', 'Gold 18K', 'Nagas', 'MEENAKSHI', NULL, NULL, 'Meenakshi'),
    ('Ring', 'Gold 22k', 'Nagas', 'Nagas', NULL, NULL, 'Nakashi'),
    ('Ring', 'Gold 22k', 'Nagas', 'NAGAS NORMAL', NULL, NULL, 'Nakashi'),
    ('Ring', 'Gold 22k', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Ring', 'Gold 22k', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Ring', 'Gold 22k', 'Nagas', 'VANGI STONE', NULL, NULL, 'Vangi Stone'),
    ('Ring', 'Precious', 'Nagas', 'Vangi', NULL, NULL, 'Vanki'),
    ('Ring', 'Gold 22k', 'Nellore', 'Nellore', NULL, 'Karnataka Traditional', NULL),
    ('Ring', 'Gold 22k', 'Nellore', 'Stone', NULL, 'Karnataka Traditional', 'Nellore'),
    ('Ring', 'Platinum', 'Platinum', 'CLASSIC', NULL, NULL, 'Fancy'),
    ('Ring', 'Platinum', 'Platinum', 'Platinum', NULL, NULL, 'Fancy'),
    ('Ring', 'Platinum', 'Platinum', 'Platinum Fusion', NULL, NULL, 'Fusion'),
    ('Ring', 'Platinum', 'PLATINUM FUSION', 'CLASSIC', NULL, 'Platinum', 'Fusion'),
    ('Ring', 'Polki', 'Polki', 'Polki', NULL, NULL, 'Fancy'),
    ('Ring', 'Gold 22k', 'Rajkot', 'Rajkot', NULL, NULL, 'Plain'),
    ('Ring', 'Gold 22k', 'Rajkot', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Ring', 'Diamond', 'SIGNATURE', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Ring', 'Diamond', 'SIGNATURE', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Ring', 'Diamond', 'SIGNATURE', 'COUPLE', NULL, 'Moulding', 'Couple'),
    ('Ring', 'Diamond', 'SIGNATURE', 'PIE-CUT', NULL, 'Moulding', 'Pie-Cut'),
    ('Ring', 'Diamond', 'SIGNATURE', 'RADHA KRISHNA', NULL, 'Moulding', 'Radha Krishna'),
    ('Ring', 'Diamond', 'SIGNATURE', 'Twisted', NULL, 'Moulding', NULL),
    ('Ring', 'Diamond', 'SIGNATURE', 'Vangi', NULL, 'Moulding', 'Vanki'),
    ('Ring', 'Gold 22k', 'SIGNITY', 'CLOSED SETTING', NULL, NULL, 'Closed Setting'),
    ('Ring', 'Gold 22k', 'SIGNITY', 'Vangi', NULL, NULL, 'Vanki'),
    ('Ring', 'Gold 22k', 'Singapore', 'SINGAPORE STONE', NULL, NULL, 'Singapore Stone'),
    ('Ring', 'Diamond', 'SOLITAIRE', 'SOLITAIRE', NULL, 'Moulding', 'Solitaire'),
    ('Ring', 'Gold 22k', 'Traditional', 'Anavaal', NULL, 'Kerala Traditional', NULL),
    ('Ring', 'Gold 22k', 'Traditional', 'Palakka', NULL, 'Kerala Traditional', NULL),
    ('Ring', 'Gold 22k', 'Traditional', 'Traditional', NULL, 'Kerala Traditional', NULL),
    ('Ring', 'Gold 22k', 'Turkish', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Ring', 'Precious', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone'),
    ('Stud', 'Gold 14K', '14 Carat Ornaments', '14 Karat Ornaments', NULL, '14 Kt Ornaments', NULL),
    ('Stud', 'Gold 14K', '14 Carat Ornaments', 'Diamond', NULL, '14 Kt Ornaments', 'Fancy'),
    ('Stud', 'Gold 18K', '18 Carat', '18 Karat', NULL, '18 Karat', NULL),
    ('Stud', 'Gold 22k', 'Antique', 'Antique', NULL, NULL, 'Fancy'),
    ('Stud', 'Gold 22k', 'Antique', 'Ilakka Thali', NULL, NULL, 'Elakkathali'),
    ('Stud', 'Gold 22k', 'Antique', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Stud', 'Gold 22k', 'BENGALI', 'Jimkka', NULL, 'Bombay', 'Jhumka'),
    ('Stud', 'Gold 22k', 'BENGALI', 'JIMKKA STONE', NULL, 'Bombay', 'Jhumka Stone'),
    ('Stud', 'Gold 22k', 'BENGALI', 'Plain', NULL, 'Bombay', NULL),
    ('Stud', 'Gold 22k', 'BENGALI', 'Rodium', NULL, 'Bombay', 'Rhodium'),
    ('Stud', 'Gold 22k', 'BENGALI', 'Stone', NULL, 'Bombay', NULL),
    ('Stud', 'Gold 22k', 'Bengali special', 'Bengali', NULL, 'Bombay', 'Plain'),
    ('Stud', 'Gold 22k', 'Bombay', 'Bombay', NULL, NULL, 'Plain'),
    ('Stud', 'Gold 22k', 'Bombay', 'Jimkka', NULL, NULL, 'Jhumka'),
    ('Stud', 'Gold 22k', 'Bombay', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Stud', 'Diamond', 'BRIDAL', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Stud', 'Diamond', 'BRIDAL', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Stud', 'Gold 22k', 'Chettinadu', 'CHAND BALI STONE', NULL, NULL, 'Chand Bali Stone'),
    ('Stud', 'Gold 22k', 'Chettinadu', 'Chettinadu', NULL, NULL, 'Nakashi'),
    ('Stud', 'Gold 22k', 'Chettinadu', 'Jimkka', NULL, NULL, 'Jhumka'),
    ('Stud', 'Gold 22k', 'Chettinadu', 'JIMKKA STONE', NULL, NULL, 'Jhumka Stone'),
    ('Stud', 'Gold 22k', 'Chettinadu', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Stud', 'Gold 22k', 'Coimbatore', 'BALI', NULL, NULL, 'Bali'),
    ('Stud', 'Gold 22k', 'Coimbatore', 'CBT NORMAL', NULL, NULL, 'Cbt'),
    ('Stud', 'Gold 22k', 'Coimbatore', 'CLOSED SETTING', NULL, NULL, 'Closed Setting'),
    ('Stud', 'Gold 22k', 'Coimbatore', 'Jimkka', NULL, NULL, 'Jhumka'),
    ('Stud', 'Gold 22k', 'Coimbatore', 'JIMKKA STONE', NULL, NULL, 'Jhumka Stone'),
    ('Stud', 'Gold 22k', 'Coimbatore', 'MATTE', NULL, NULL, 'Matte'),
    ('Stud', 'Gold 22k', 'Culcutta', 'Chand Bali', NULL, 'Kolkata', NULL),
    ('Stud', 'Gold 22k', 'Culcutta', 'CHAND BALI ENAMEL', NULL, 'Kolkata', 'Chand Bali Enamel'),
    ('Stud', 'Gold 22k', 'Culcutta', 'CHAND BALI STONE', NULL, 'Kolkata', 'Chand Bali Stone'),
    ('Stud', 'Gold 22k', 'Culcutta', 'Culcutta plain', NULL, 'Kolkata', 'Plain'),
    ('Stud', 'Gold 22k', 'Culcutta', 'Culcutta Stone', NULL, 'Kolkata', 'Stone'),
    ('Stud', 'Gold 22k', 'Culcutta', 'Enamel', NULL, 'Kolkata', NULL),
    ('Stud', 'Gold 22k', 'Culcutta', 'Jimkka', NULL, 'Kolkata', 'Jhumka'),
    ('Stud', 'Gold 22k', 'Culcutta', 'JIMKKA ENAMEL', NULL, 'Kolkata', 'Jhumka Enamel'),
    ('Stud', 'Gold 22k', 'Culcutta', 'JIMKKA STONE', NULL, 'Kolkata', 'Jhumka Stone'),
    ('Stud', 'Gold 22k', 'Culcutta', 'Plain', NULL, 'Kolkata', NULL),
    ('Stud', 'Gold 22k', 'Culcutta', 'Stone', NULL, 'Kolkata', NULL),
    ('Stud', 'Diamond', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Stud', 'Diamond', 'DESIGNER', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Stud', 'Diamond', 'DESIGNER', 'Designer', NULL, 'Moulding', 'Fancy'),
    ('Stud', 'Gold 14K', 'DESIGNER', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Stud', 'Diamond', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Stud', 'Gold 14K', 'Diamond', 'Diamond', NULL, 'Moulding', 'Fancy'),
    ('Stud', 'Diamond', 'Diamond SI Jewellery', 'Diamond SI', NULL, 'Moulding', 'Fancy'),
    ('Stud', 'Diamond', 'HERITAGE', 'CLASSIC', NULL, 'Moulding', 'Classic'),
    ('Stud', 'Diamond', 'HERITAGE', 'CLOSED SETTING', NULL, 'Moulding', 'Closed Setting'),
    ('Stud', 'Diamond', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Stud', 'Diamond', 'HERITAGE', 'MEENAKSHI', NULL, 'Moulding', 'Meenakshi'),
    ('Stud', 'Diamond', 'HERITAGE', 'OPEN CLOSE SETTING', NULL, 'Moulding', 'Open Close Setting'),
    ('Stud', 'Diamond', 'HERITAGE', 'RAM PARIVAR', NULL, 'Moulding', 'Ram Parivar'),
    ('Stud', 'Polki', 'HERITAGE', 'JADAU', NULL, 'Polki', 'Jadau'),
    ('Stud', 'Precious', 'HERITAGE', 'FILIGREE', NULL, 'Moulding', 'Filigree'),
    ('Stud', 'Precious', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Stud', 'Uncut', 'HERITAGE', 'GEMSTONE', NULL, 'Moulding', 'Gemstone'),
    ('Stud', 'Uncut', 'HERITAGE', 'Jimkka', NULL, 'Moulding', 'Jhumka'),
    ('Stud', 'Uncut', 'HERITAGE', 'Lakshmi', NULL, 'Moulding', NULL),
    ('Stud', 'Gold 14K', 'ITALIAN', 'CERA', NULL, NULL, 'Cera'),
    ('Stud', 'Gold 14K', 'ITALIAN', 'CLASSIC', NULL, 'Italian', 'Fancy'),
    ('Stud', 'Gold 14K', 'ITALIAN', 'CUPOD', NULL, NULL, 'Cupod'),
    ('Stud', 'Gold 14K', 'ITALIAN', 'FLORA', NULL, NULL, 'Flora'),
    ('Stud', 'Gold 14K', 'ITALIAN', 'YIN-YANG', NULL, NULL, 'Yin-Yang'),
    ('Stud', 'Gold 18K', 'ITALIAN', 'Rodium', NULL, 'Italian', 'Rhodium'),
    ('Stud', 'Gold 22k', 'Karwar', 'Karwar', NULL, 'Karnataka Traditional', NULL),
    ('Stud', 'Gold 22k', 'Kerala', 'BALI', NULL, NULL, 'Bali'),
    ('Stud', 'Gold 22k', 'Kerala', 'Jimkka', NULL, NULL, 'Jhumka'),
    ('Stud', 'Gold 22k', 'Kerala', 'LAKSHMI STONE', NULL, NULL, 'Lakshmi Stone'),
    ('Stud', 'Gold 18K', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Stud', 'Gold 22k', 'Moulding', 'Moulding', NULL, NULL, 'Fancy'),
    ('Stud', 'Gold 22k', 'Moulding', 'RAINBOW', NULL, NULL, 'Rainbow'),
    ('Stud', 'Gold 22k', 'Moulding', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Stud', 'Gold 18K', 'Nagas', 'MEENAKSHI', NULL, NULL, 'Meenakshi'),
    ('Stud', 'Gold 22k', 'Nagas', 'CHAND BALI GOD', NULL, NULL, 'Chand Bali God'),
    ('Stud', 'Gold 22k', 'Nagas', 'CHAND BALI LAKSHMI', NULL, NULL, 'Chand Bali Lakshmi'),
    ('Stud', 'Gold 22k', 'Nagas', 'CHAND BALI NAKSHI', NULL, NULL, 'Chand Bali Nakshi'),
    ('Stud', 'Gold 22k', 'Nagas', 'CHAND BALI RAM PARIVAR', NULL, NULL, 'Chand Bali Ram Parivar'),
    ('Stud', 'Gold 22k', 'Nagas', 'JIMKKA GOD', NULL, NULL, 'Jhumka God'),
    ('Stud', 'Gold 22k', 'Nagas', 'JIMKKA LAKSHMI', NULL, NULL, 'Jhumka Lakshmi'),
    ('Stud', 'Gold 22k', 'Nagas', 'JIMKKA NAKSHI', NULL, NULL, 'Jhumka Nakshi'),
    ('Stud', 'Gold 22k', 'Nagas', 'JIMKKA RAM PARIVAR', NULL, NULL, 'Jhumka Ram Parivar'),
    ('Stud', 'Gold 22k', 'Nagas', 'Nagas', NULL, NULL, 'Nakashi'),
    ('Stud', 'Gold 22k', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Stud', 'Gold 22k', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Stud', 'Gold 22k', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Stud', 'Precious', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Stud', 'Precious', 'Nagas', 'RADHA KRISHNA', NULL, NULL, 'Radha Krishna'),
    ('Stud', 'Precious', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Stud', 'Uncut', 'Nagas', 'NAKASHI', NULL, NULL, 'Nakashi'),
    ('Stud', 'Uncut', 'Nagas', 'RAM PARIVAR', NULL, NULL, 'Ram Parivar'),
    ('Stud', 'Gold 22k', 'Nagas Premium', 'Nagas', NULL, 'Nagas', 'Nakashi'),
    ('Stud', 'Gold 22k', 'Nagas Premium', 'NAGAS NORMAL', NULL, 'Nagas', 'Nakashi'),
    ('Stud', 'Gold 22k', 'Nagas Premium', 'special nagas', NULL, 'Nagas', 'Nakashi'),
    ('Stud', 'Gold 22k', 'Nellore', 'BALI', NULL, 'Karnataka Traditional', 'Nellore Bali'),
    ('Stud', 'Gold 22k', 'Nellore', 'Chand Bali', NULL, 'Karnataka Traditional', 'Nellore Chand Bali'),
    ('Stud', 'Gold 22k', 'Nellore', 'CHAND BALI LAKSHMI', NULL, 'Karnataka Traditional', 'Nellore Chand Bali'),
    ('Stud', 'Gold 22k', 'Nellore', 'God', NULL, 'Karnataka Traditional', 'Nellore God'),
    ('Stud', 'Gold 22k', 'Nellore', 'Jimkka', NULL, 'Karnataka Traditional', 'Nellore Jimkka'),
    ('Stud', 'Gold 22k', 'Nellore', 'JIMKKA GOD', NULL, 'Karnataka Traditional', 'Nellore Jimkka God'),
    ('Stud', 'Gold 22k', 'Nellore', 'JIMKKA LAKSHMI', NULL, 'Karnataka Traditional', 'Nellore Jimkka Lakshmi'),
    ('Stud', 'Gold 22k', 'Nellore', 'Lakshmi', NULL, 'Karnataka Traditional', 'Nellore Lakshmi'),
    ('Stud', 'Gold 22k', 'Nellore', 'NAKASHI', NULL, 'Karnataka Traditional', 'Nellore Nakashi'),
    ('Stud', 'Gold 22k', 'Nellore', 'Nellore', NULL, 'Karnataka Traditional', NULL),
    ('Stud', 'Gold 22k', 'Nellore', 'Stone', NULL, 'Karnataka Traditional', 'Nellore'),
    ('Stud', 'Platinum', 'Platinum', 'CLASSIC', NULL, NULL, 'Fancy'),
    ('Stud', 'Platinum', 'Platinum', 'Platinum', NULL, NULL, 'Fancy'),
    ('Stud', 'Platinum', 'Platinum', 'Platinum Fusion', NULL, NULL, 'Fusion'),
    ('Stud', 'Platinum', 'PLATINUM FUSION', 'CLASSIC', NULL, 'Platinum', 'Fusion'),
    ('Stud', 'Polki', 'Polki', 'Polki', NULL, NULL, 'Fancy'),
    ('Stud', 'Gold 22k', 'Rajkot', 'BALI', NULL, NULL, 'Bali'),
    ('Stud', 'Gold 22k', 'Rajkot', 'Rajkot', NULL, NULL, 'Plain'),
    ('Stud', 'Gold 22k', 'Rajkot', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Stud', 'Gold 22k', 'Semi Antique', 'Semi Antique', NULL, NULL, 'Nakashi'),
    ('Stud', 'Gold 22k', 'Semi Turkish', 'Semi Turkish', NULL, NULL, 'Plain'),
    ('Stud', 'Diamond', 'SIGNATURE', 'BUGADI', NULL, 'Moulding', 'Bugadi'),
    ('Stud', 'Diamond', 'SIGNATURE', 'CLASSIC', NULL, 'Moulding', 'Fancy'),
    ('Stud', 'Diamond', 'SIGNATURE', 'CLUSTER', NULL, 'Moulding', 'Cluster'),
    ('Stud', 'Diamond', 'SIGNATURE', 'SOLITAIRE', NULL, 'Moulding', 'Solitaire'),
    ('Stud', 'Diamond', 'SIGNATURE', 'Twisted', NULL, 'Moulding', NULL),
    ('Stud', 'Gold 22k', 'SIGNITY', 'CLOSED SETTING', NULL, NULL, 'Closed Setting'),
    ('Stud', 'Gold 22k', 'Singapore', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Stud', 'Gold 22k', 'Singapore', 'SINGAPORE STONE', NULL, NULL, 'Singapore Stone'),
    ('Stud', 'Diamond', 'SOLITAIRE', 'SOLITAIRE', NULL, 'Moulding', 'Solitaire'),
    ('Stud', 'Gold 22k', 'Traditional', 'Palakka', NULL, 'Kerala Traditional', NULL),
    ('Stud', 'Gold 22k', 'Traditional', 'Traditional', NULL, 'Kerala Traditional', NULL),
    ('Stud', 'Gold 22k', 'Turkish', 'Rodium', NULL, NULL, 'Rhodium'),
    ('Stud', 'Precious', 'Turkish', 'GEMSTONE', NULL, NULL, 'Gemstone');

-- ----------------------------------------------------------------------------
-- The sheet's "Existing" columns predate the spell-fix pass, which renamed
-- some enum values in place (same id, new text). Translate those old keys to
-- today's value, or those rows would match nothing. (Mapping from diffing
-- enum values by id against the untouched qa baseline.)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS enum_renames;

CREATE TEMP TABLE enum_renames (attribute_code text, old_value text, current_value text);

INSERT INTO enum_renames (attribute_code, old_value, current_value) VALUES
    ('COL', '14 Carat Ornaments', '14 Kt Ornaments'),
    ('COL', '18 Carat', '18 Karat'),
    ('COL', 'Culcutta', 'Kolkata'),
    ('COL', 'MECHINE', 'Machine'),
    ('STL', 'Dhasavatharam', 'Dasavatharam'),
    ('STL', 'Ilakka Thali', 'Elakkathali'),
    ('STL', 'JIMKKA ENAMEL', 'Jhumka Enamel'),
    ('STL', 'JIMKKA GOD', 'Jhumka God'),
    ('STL', 'JIMKKA LAKSHMI', 'Jhumka Lakshmi'),
    ('STL', 'JIMKKA NAKSHI', 'Jhumka Nakshi'),
    ('STL', 'JIMKKA RAM PARIVAR', 'Jhumka Ram Parivar'),
    ('STL', 'JIMKKA STONE', 'Jhumka Stone'),
    ('STL', 'Jimkka', 'Jhumka'),
    ('STL', 'KARBH', 'Curb'),
    ('STL', 'LAKSHMI KAASHI', 'Kaasu'),
    ('STL', 'OHM', 'Om'),
    ('STL', 'Ohm Thali', 'Om Thali'),
    ('STL', 'PIPE RODIUM', 'Pipe Rhodium'),
    ('STL', 'Papper Cast', 'Paper Cast'),
    ('STL', 'Rajkot Beeds', 'Beeds'),
    ('STL', 'Rodium', 'Rhodium'),
    ('STL', 'Vangi', 'Vanki'),
    ('STL', 'Kumbala Ohm Thali', 'Kumbala Om Thali');

UPDATE category_fixes cf SET db_collection = r.current_value
FROM enum_renames r WHERE r.attribute_code = 'COL' AND LOWER(r.old_value) = LOWER(cf.db_collection);

UPDATE category_fixes cf SET db_style = r.current_value
FROM enum_renames r WHERE r.attribute_code = 'STL' AND LOWER(r.old_value) = LOWER(cf.db_style);

WITH want AS (
    SELECT pa.id AS product_attribute_id, paev.id AS enum_id, pa.attribute_code, paev.product_attribute_enum_value_code AS code
    FROM (VALUES ('TYP','Gold 22k'), ('CTY','Bangle'), ('COL','Bombay'), ('STL','Plain')) AS w(attribute_code, value)
    JOIN product_attribute pa ON pa.attribute_code = w.attribute_code
    JOIN product_attribute_enum_value paev ON paev.product_attribute_id = pa.id AND LOWER(paev.value) = LOWER(w.value)
),
formula AS (
    SELECT 'A' || UPPER(
        MAX(CASE WHEN attribute_code='TYP' THEN code END) ||
        MAX(CASE WHEN attribute_code='CTY' THEN code END) ||
        MAX(CASE WHEN attribute_code='COL' THEN code END) ||
        MAX(CASE WHEN attribute_code='STL' THEN code END)
    ) AS code
    FROM want
)
INSERT INTO product_template_attribute_value (product_template_id, product_attribute_id, product_attribute_enum_value_id)
SELECT pt.id, want.product_attribute_id, want.enum_id
FROM product_template pt
CROSS JOIN want
WHERE pt.product_template_code = 'AG22BA769PLA'
  AND pt.product_template_code = (SELECT code FROM formula)
  AND NOT EXISTS (SELECT 1 FROM product_template_attribute_value ptav WHERE ptav.product_template_id = pt.id);

-- ----------------------------------------------------------------------------
-- Pivots: each product's / template's current attributes in one row.
-- Built once, BEFORE any update -- everything below matches on these.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS product_pivot;

CREATE TEMP TABLE product_pivot AS
SELECT
    pav.product_id,
    MAX(CASE WHEN pa.attribute_code='CTY' THEN paev.value END) AS category,
    MAX(CASE WHEN pa.attribute_code='CTY' THEN paev.id END) AS category_enum_id,
    MAX(CASE WHEN pa.attribute_code='TYP' THEN paev.value END) AS product_type,
    MAX(CASE WHEN pa.attribute_code='COL' THEN paev.value END) AS collection,
    MAX(CASE WHEN pa.attribute_code='COL' THEN paev.id END) AS collection_enum_id,
    MAX(CASE WHEN pa.attribute_code='STL' THEN paev.value END) AS style,
    MAX(CASE WHEN pa.attribute_code='STL' THEN paev.id END) AS style_enum_id,
    EXISTS (
        SELECT 1 FROM product_location pl
        WHERE pl.product_id = pav.product_id
          AND pl.end_time = '2100-01-01 00:00:00+00'
          AND pl.location_id IS NOT NULL
    ) AS is_unsold
FROM product_attribute_value pav
JOIN product_attribute pa ON pa.id = pav.attribute_id AND pa.attribute_code IN ('CTY','TYP','COL','STL')
JOIN product_attribute_enum_value paev ON paev.id = pav.product_attribute_enum_value_id
GROUP BY pav.product_id;

CREATE INDEX ON product_pivot (LOWER(category), LOWER(product_type), LOWER(collection), LOWER(style));

-- Same, for templates — no "unsold" concept, templates aren't physical stock.
DROP TABLE IF EXISTS template_pivot;

CREATE TEMP TABLE template_pivot AS
SELECT
    ptav.product_template_id,
    MAX(CASE WHEN pa.attribute_code='CTY' THEN paev.value END) AS category,
    MAX(CASE WHEN pa.attribute_code='CTY' THEN paev.id END) AS category_enum_id,
    MAX(CASE WHEN pa.attribute_code='TYP' THEN paev.value END) AS product_type,
    MAX(CASE WHEN pa.attribute_code='COL' THEN paev.value END) AS collection,
    MAX(CASE WHEN pa.attribute_code='COL' THEN paev.id END) AS collection_enum_id,
    MAX(CASE WHEN pa.attribute_code='STL' THEN paev.value END) AS style,
    MAX(CASE WHEN pa.attribute_code='STL' THEN paev.id END) AS style_enum_id
FROM product_template_attribute_value ptav
JOIN product_attribute pa ON pa.id = ptav.product_attribute_id AND pa.attribute_code IN ('CTY','TYP','COL','STL')
JOIN product_attribute_enum_value paev ON paev.id = ptav.product_attribute_enum_value_id
GROUP BY ptav.product_template_id;

CREATE INDEX ON template_pivot (LOWER(category), LOWER(product_type), LOWER(collection), LOWER(style));

-- Before-state of everything that will be touched (read by VERIFY).
DROP TABLE IF EXISTS full_before_snapshot_products;

CREATE TEMP TABLE full_before_snapshot_products AS
SELECT
    pp.product_id,
    p.product_code,
    pp.is_unsold,
    pp.category AS old_category, pp.product_type,
    pp.collection AS old_collection, pp.style AS old_style,
    p.product_name AS old_product_name,
    cf.new_category, cf.new_collection, cf.new_style
FROM product_pivot pp
JOIN product p ON p.id = pp.product_id
JOIN category_fixes cf
    ON LOWER(pp.category) = LOWER(cf.category) AND LOWER(pp.product_type) = LOWER(cf.product_type)
   AND LOWER(pp.collection) = LOWER(cf.db_collection) AND LOWER(pp.style) = LOWER(cf.db_style)
WHERE cf.new_category IS NOT NULL OR cf.new_collection IS NOT NULL OR cf.new_style IS NOT NULL;

UPDATE product_attribute_value pav
SET product_attribute_enum_value_id = new_e.id
FROM product_pivot pp
JOIN category_fixes cf
    ON LOWER(pp.category) = LOWER(cf.category) AND LOWER(pp.product_type) = LOWER(cf.product_type)
   AND LOWER(pp.collection) = LOWER(cf.db_collection) AND LOWER(pp.style) = LOWER(cf.db_style)
JOIN product_attribute_enum_value new_e
    ON new_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code='CTY')
   AND LOWER(new_e.value) = LOWER(cf.new_category)
WHERE pav.product_id = pp.product_id
  AND pav.product_attribute_enum_value_id = pp.category_enum_id
  AND cf.new_category IS NOT NULL
  AND pp.is_unsold;

                         -- <-- unsold products only

UPDATE product_attribute_value pav
SET product_attribute_enum_value_id = new_e.id
FROM product_pivot pp
JOIN category_fixes cf
    ON LOWER(pp.category) = LOWER(cf.category) AND LOWER(pp.product_type) = LOWER(cf.product_type)
   AND LOWER(pp.collection) = LOWER(cf.db_collection) AND LOWER(pp.style) = LOWER(cf.db_style)
JOIN product_attribute_enum_value new_e
    ON new_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code='COL')
   AND LOWER(new_e.value) = LOWER(cf.new_collection)
WHERE pav.product_id = pp.product_id
  AND pav.product_attribute_enum_value_id = pp.collection_enum_id
  AND cf.new_collection IS NOT NULL
  AND pp.is_unsold;

                         -- <-- unsold products only

UPDATE product_attribute_value pav
SET product_attribute_enum_value_id = new_e.id
FROM product_pivot pp
JOIN category_fixes cf
    ON LOWER(pp.category) = LOWER(cf.category) AND LOWER(pp.product_type) = LOWER(cf.product_type)
   AND LOWER(pp.collection) = LOWER(cf.db_collection) AND LOWER(pp.style) = LOWER(cf.db_style)
JOIN product_attribute_enum_value new_e
    ON new_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code='STL')
   AND LOWER(new_e.value) = LOWER(cf.new_style)
WHERE pav.product_id = pp.product_id
  AND pav.product_attribute_enum_value_id = pp.style_enum_id
  AND cf.new_style IS NOT NULL
  AND pp.is_unsold;

                         -- <-- unsold products only

UPDATE product_template_attribute_value ptav
SET product_attribute_enum_value_id = new_e.id
FROM template_pivot tp
JOIN category_fixes cf
    ON LOWER(tp.category) = LOWER(cf.category) AND LOWER(tp.product_type) = LOWER(cf.product_type)
   AND LOWER(tp.collection) = LOWER(cf.db_collection) AND LOWER(tp.style) = LOWER(cf.db_style)
JOIN product_attribute_enum_value new_e
    ON new_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code='CTY')
   AND LOWER(new_e.value) = LOWER(cf.new_category)
WHERE ptav.product_template_id = tp.product_template_id
  AND ptav.product_attribute_enum_value_id = tp.category_enum_id
  AND cf.new_category IS NOT NULL;

          -- templates: no unsold filter

UPDATE product_template_attribute_value ptav
SET product_attribute_enum_value_id = new_e.id
FROM template_pivot tp
JOIN category_fixes cf
    ON LOWER(tp.category) = LOWER(cf.category) AND LOWER(tp.product_type) = LOWER(cf.product_type)
   AND LOWER(tp.collection) = LOWER(cf.db_collection) AND LOWER(tp.style) = LOWER(cf.db_style)
JOIN product_attribute_enum_value new_e
    ON new_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code='COL')
   AND LOWER(new_e.value) = LOWER(cf.new_collection)
WHERE ptav.product_template_id = tp.product_template_id
  AND ptav.product_attribute_enum_value_id = tp.collection_enum_id
  AND cf.new_collection IS NOT NULL;

        -- templates: no unsold filter

UPDATE product_template_attribute_value ptav
SET product_attribute_enum_value_id = new_e.id
FROM template_pivot tp
JOIN category_fixes cf
    ON LOWER(tp.category) = LOWER(cf.category) AND LOWER(tp.product_type) = LOWER(cf.product_type)
   AND LOWER(tp.collection) = LOWER(cf.db_collection) AND LOWER(tp.style) = LOWER(cf.db_style)
JOIN product_attribute_enum_value new_e
    ON new_e.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code='STL')
   AND LOWER(new_e.value) = LOWER(cf.new_style)
WHERE ptav.product_template_id = tp.product_template_id
  AND ptav.product_attribute_enum_value_id = tp.style_enum_id
  AND cf.new_style IS NOT NULL;

-- ============================================================================
-- STEP 2 -- regenerate product_template_code and product_name.
--
-- Templates: template identity = Type + Category + Collection + Style + Spec
-- (no Spec = same as no Spec). Every template sharing a corrected combo is
-- grouped; one canonical per group (enabled first, then one whose code is
-- already correct, then lowest id purely as a stable tie-break) gets the
-- recalculated code and is enabled. Other group members are left untouched.
--
-- Product names: the old Category/Collection/Style code is swapped for the
-- new one only when it appears in the name exactly once.
-- ============================================================================
DROP TABLE IF EXISTS templates_to_recode;

CREATE TEMP TABLE templates_to_recode AS
SELECT DISTINCT tp.product_template_id
FROM template_pivot tp
JOIN category_fixes cf
    ON LOWER(tp.category) = LOWER(cf.category) AND LOWER(tp.product_type) = LOWER(cf.product_type)
   AND LOWER(tp.collection) = LOWER(cf.db_collection) AND LOWER(tp.style) = LOWER(cf.db_style)
WHERE cf.new_category IS NOT NULL OR cf.new_collection IS NOT NULL OR cf.new_style IS NOT NULL;

-- Unsold products matched by their OLD combo, same logic, sold products
-- excluded. Carries the OLD category/collection/style enum ids directly from
-- the pivot (no name lookup needed -- and no ambiguity, per the note above).
DROP TABLE IF EXISTS products_to_recode;

CREATE TEMP TABLE products_to_recode AS
SELECT DISTINCT
    pp.product_id,
    pp.category_enum_id AS old_category_enum_id,
    pp.collection_enum_id AS old_collection_enum_id,
    pp.style_enum_id AS old_style_enum_id,
    cf.new_category, cf.new_collection, cf.new_style
FROM product_pivot pp
JOIN category_fixes cf
    ON LOWER(pp.category) = LOWER(cf.category) AND LOWER(pp.product_type) = LOWER(cf.product_type)
   AND LOWER(pp.collection) = LOWER(cf.db_collection) AND LOWER(pp.style) = LOWER(cf.db_style)
WHERE (cf.new_category IS NOT NULL OR cf.new_collection IS NOT NULL OR cf.new_style IS NOT NULL)
  AND pp.is_unsold;

DROP TABLE IF EXISTS all_template_attrs;

CREATE TEMP TABLE all_template_attrs AS
SELECT
    ptav.product_template_id,
    MAX(CASE WHEN pa.attribute_code='CTY' THEN paev.value END) AS category,
    MAX(CASE WHEN pa.attribute_code='TYP' THEN paev.value END) AS product_type,
    MAX(CASE WHEN pa.attribute_code='COL' THEN paev.value END) AS collection,
    MAX(CASE WHEN pa.attribute_code='STL' THEN paev.value END) AS style,
    MAX(CASE WHEN pa.attribute_code='SPC' THEN paev.value END) AS spec
FROM product_template_attribute_value ptav
JOIN product_attribute pa ON pa.id = ptav.product_attribute_id AND pa.attribute_code IN ('CTY','TYP','COL','STL','SPC')
JOIN product_attribute_enum_value paev ON paev.id = ptav.product_attribute_enum_value_id
GROUP BY ptav.product_template_id;

-- Every template (recoded or pre-existing) that shares a corrected combo
-- with at least one template in templates_to_recode. LOWER(COALESCE(spec,''))
-- makes two Spec-absent templates match each other while never matching a
-- template that has a real Spec value (no real Spec enum value is ever the
-- literal empty string).
DROP TABLE IF EXISTS recode_groups;

CREATE TEMP TABLE recode_groups AS
SELECT LOWER(a.category) AS category, LOWER(a.product_type) AS product_type,
       LOWER(a.collection) AS collection, LOWER(a.style) AS style,
       LOWER(COALESCE(a.spec,'')) AS spec,
       a.product_template_id AS template_id, pt.is_enabled
FROM all_template_attrs a
JOIN product_template pt ON pt.id = a.product_template_id
WHERE (LOWER(a.category), LOWER(a.product_type), LOWER(a.collection), LOWER(a.style), LOWER(COALESCE(a.spec,''))) IN (
    SELECT LOWER(a2.category), LOWER(a2.product_type), LOWER(a2.collection), LOWER(a2.style), LOWER(COALESCE(a2.spec,''))
    FROM all_template_attrs a2
    WHERE a2.product_template_id IN (SELECT product_template_id FROM templates_to_recode)
);

-- Every group member's code as the formula computes it from ITS OWN current
-- attributes -- same formula as create_product_template.
DROP TABLE IF EXISTS recode_group_codes;

CREATE TEMP TABLE recode_group_codes AS
SELECT
    ptav.product_template_id,
    'A' || UPPER(
        COALESCE(MAX(CASE WHEN pa.attribute_code='TYP' THEN paev.product_attribute_enum_value_code END), '') ||
        COALESCE(MAX(CASE WHEN pa.attribute_code='CTY' THEN paev.product_attribute_enum_value_code END), '') ||
        COALESCE(MAX(CASE WHEN pa.attribute_code='COL' THEN paev.product_attribute_enum_value_code END), '') ||
        COALESCE(MAX(CASE WHEN pa.attribute_code='STL' THEN paev.product_attribute_enum_value_code END), '') ||
        COALESCE(MAX(CASE WHEN pa.attribute_code='SPC' THEN paev.product_attribute_enum_value_code END), '')
    ) AS code
FROM product_template_attribute_value ptav
JOIN product_attribute pa ON pa.id = ptav.product_attribute_id AND pa.attribute_code IN ('TYP','CTY','COL','STL','SPC')
JOIN product_attribute_enum_value paev ON paev.id = ptav.product_attribute_enum_value_id
WHERE ptav.product_template_id IN (SELECT template_id FROM recode_groups)
GROUP BY ptav.product_template_id;

-- One canonical template per corrected combo, in this order:
--   1. enabled beats disabled;
--   2. within that tier, a member whose code ALREADY equals its own formula
--      code wins -- otherwise the canonical could never take that code
--      (UNIQUE constraint) without touching the sibling that holds it;
--   3. lowest ID, purely as a deterministic tie-break so the pick is stable
--      and reruns are idempotent -- never a claim that it is "better."
DROP TABLE IF EXISTS canonical_template;

CREATE TEMP TABLE canonical_template AS
SELECT DISTINCT ON (rg.category, rg.product_type, rg.collection, rg.style, rg.spec)
    rg.category, rg.product_type, rg.collection, rg.style, rg.spec,
    rg.template_id AS canonical_template_id
FROM recode_groups rg
JOIN product_template pt ON pt.id = rg.template_id
JOIN recode_group_codes rgc ON rgc.product_template_id = rg.template_id
ORDER BY rg.category, rg.product_type, rg.collection, rg.style, rg.spec,
    rg.is_enabled DESC,
    (pt.product_template_code = rgc.code) DESC,
    rg.template_id ASC;

DROP TABLE IF EXISTS canonical_new_code;

CREATE TEMP TABLE canonical_new_code AS
SELECT rgc.product_template_id, rgc.code
FROM recode_group_codes rgc
WHERE rgc.product_template_id IN (SELECT canonical_template_id FROM canonical_template);

-- New product names, computed ONCE from each name as captured before STEP 1
-- (full_before_snapshot_products). Category, then Collection, then Style:
-- each old code is swapped for the new one only when the code actually
-- changes and the old code appears in the name exactly once. The UPDATE
-- below only applies where the name is still that original, so re-running
-- it can never stack a second swap on the first (e.g. 'CPL' -> 'PLA' turning
-- 'G22NCCPL' into 'G22NCPLA' and then 'G22NPLAA').
DROP TABLE IF EXISTS product_new_name;

CREATE TEMP TABLE product_new_name AS
WITH codes AS (
    SELECT
        ptr.product_id,
        s.old_product_name AS old_name,
        CASE WHEN ptr.new_category IS NOT NULL THEN old_cty.product_attribute_enum_value_code END AS o_cty,
        new_cty.product_attribute_enum_value_code AS n_cty,
        CASE WHEN ptr.new_collection IS NOT NULL THEN old_col.product_attribute_enum_value_code END AS o_col,
        new_col.product_attribute_enum_value_code AS n_col,
        CASE WHEN ptr.new_style IS NOT NULL THEN old_stl.product_attribute_enum_value_code END AS o_stl,
        new_stl.product_attribute_enum_value_code AS n_stl
    FROM products_to_recode ptr
    JOIN full_before_snapshot_products s ON s.product_id = ptr.product_id
    LEFT JOIN product_attribute_enum_value old_cty ON old_cty.id = ptr.old_category_enum_id
    LEFT JOIN product_attribute_enum_value new_cty
        ON new_cty.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code='CTY')
       AND LOWER(new_cty.value) = LOWER(ptr.new_category)
    LEFT JOIN product_attribute_enum_value old_col ON old_col.id = ptr.old_collection_enum_id
    LEFT JOIN product_attribute_enum_value new_col
        ON new_col.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code='COL')
       AND LOWER(new_col.value) = LOWER(ptr.new_collection)
    LEFT JOIN product_attribute_enum_value old_stl ON old_stl.id = ptr.old_style_enum_id
    LEFT JOIN product_attribute_enum_value new_stl
        ON new_stl.product_attribute_id = (SELECT id FROM product_attribute WHERE attribute_code='STL')
       AND LOWER(new_stl.value) = LOWER(ptr.new_style)
),
after_category AS (
    SELECT *, CASE WHEN o_cty <> n_cty AND (LENGTH(old_name) - LENGTH(REPLACE(old_name, o_cty, ''))) / NULLIF(LENGTH(o_cty), 0) = 1
                   THEN REPLACE(old_name, o_cty, n_cty) ELSE old_name END AS name1
    FROM codes
),
after_collection AS (
    SELECT *, CASE WHEN o_col <> n_col AND (LENGTH(name1) - LENGTH(REPLACE(name1, o_col, ''))) / NULLIF(LENGTH(o_col), 0) = 1
                   THEN REPLACE(name1, o_col, n_col) ELSE name1 END AS name2
    FROM after_category
)
SELECT product_id, old_name,
       CASE WHEN o_stl <> n_stl AND (LENGTH(name2) - LENGTH(REPLACE(name2, o_stl, ''))) / NULLIF(LENGTH(o_stl), 0) = 1
            THEN REPLACE(name2, o_stl, n_stl) ELSE name2 END AS new_name
FROM after_collection;

DELETE FROM product_new_name WHERE new_name = old_name;

-- A. Recalculate the canonical's code -- only if it actually needs it, and
-- only if nothing OUTSIDE its own group already holds that exact code
-- (since code is a pure function of attributes, an external collision here
-- would mean two different attribute combos produced an identical code
-- string -- a formula-level edge case, not expected, but guarded anyway).
-- Never touches a non-canonical template's code.
UPDATE product_template pt
SET product_template_code = new_code.code
FROM canonical_new_code new_code
WHERE pt.id = new_code.product_template_id
  AND pt.product_template_code <> new_code.code
  AND NOT EXISTS (
      SELECT 1 FROM product_template other
      WHERE other.product_template_code = new_code.code AND other.id <> pt.id
  );

-- B. Enable the canonical if it wasn't already -- covers both "no match,
-- freshly recoded" and "matching disabled template(s) exist, one is picked"
-- in one step. Only fires once the canonical's code actually equals its
-- formula code (i.e. UPDATE A succeeded or it was already correct) -- a
-- canonical blocked by a code held elsewhere stays disabled rather than
-- becoming an enabled template with a stale code (see the CHECK above).
-- Never fires for a non-canonical group member, and is a no-op if the
-- canonical was already enabled.
UPDATE product_template pt
SET is_enabled = true
FROM canonical_new_code cnc
WHERE pt.id = cnc.product_template_id
  AND pt.product_template_code = cnc.code
  AND pt.is_enabled = false;

-- Every non-canonical member of every group is deliberately left untouched
-- here: no enable, no disable, no code change. No product is ever
-- reassigned merely because duplicate templates exist.

-- C. Product names -- only where the name is still the original (see
-- product_new_name above), so running this again changes nothing.
UPDATE product p
SET product_name = n.new_name
FROM product_new_name n
WHERE p.id = n.product_id
  AND p.product_name = n.old_name;

COMMIT;
