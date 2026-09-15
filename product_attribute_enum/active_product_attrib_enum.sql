-- Active master values for Type / Category / Collection / Style / Spec
-- (product_attribute_enum_value.is_enabled = true).
--
-- Each block below is a separate result set -> paste each into its own sheet
-- in the workbook (Type, Category, Collection, Style, Spec). Run them
-- individually; this file can't produce multiple Excel sheets on its own.

-- Sheet: Type
SELECT paev.value AS type
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'TYP'
WHERE paev.is_enabled = true
ORDER BY paev.value;

-- Sheet: Category
SELECT paev.value AS category
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'CTY'
WHERE paev.is_enabled = true
ORDER BY paev.value;

-- Sheet: Collection
SELECT paev.value AS collection
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'COL'
WHERE paev.is_enabled = true
ORDER BY paev.value;

-- Sheet: Style
SELECT paev.value AS style
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'STL'
WHERE paev.is_enabled = true
ORDER BY paev.value;

-- Sheet: Spec
SELECT paev.value AS spec
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'SPC'
WHERE paev.is_enabled = true
ORDER BY paev.value;
