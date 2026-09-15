-- Sheet: Type
SELECT DISTINCT paev.value AS type
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'TYP'
WHERE paev.is_enabled = false
    AND EXISTS (
        SELECT 1 FROM product_attribute_value pav
        WHERE pav.product_attribute_enum_value_id = paev.id
    )
ORDER BY paev.value;

-- Sheet: Category
SELECT DISTINCT paev.value AS category
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'CTY'
WHERE paev.is_enabled = false
    AND EXISTS (
        SELECT 1 FROM product_attribute_value pav
        WHERE pav.product_attribute_enum_value_id = paev.id
    )
ORDER BY paev.value;

-- Sheet: Collection
SELECT DISTINCT paev.value AS collection
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'COL'
WHERE paev.is_enabled = false
    AND EXISTS (
        SELECT 1 FROM product_attribute_value pav
        WHERE pav.product_attribute_enum_value_id = paev.id
    )
ORDER BY paev.value;

-- Sheet: Style
SELECT DISTINCT paev.value AS style
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'STL'
WHERE paev.is_enabled = false
    AND EXISTS (
        SELECT 1 FROM product_attribute_value pav
        WHERE pav.product_attribute_enum_value_id = paev.id
    )
ORDER BY paev.value;

-- Sheet: Spec
SELECT DISTINCT paev.value AS spec
FROM product_attribute_enum_value paev
JOIN product_attribute pa
    ON pa.id = paev.product_attribute_id AND pa.attribute_code = 'SPC'
WHERE paev.is_enabled = false
    AND EXISTS (
        SELECT 1 FROM product_attribute_value pav
        WHERE pav.product_attribute_enum_value_id = paev.id
    )
ORDER BY paev.value;
