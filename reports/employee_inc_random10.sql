WITH collection_category_rate (collection_code, category, category_sort, rate_per_gram) AS (
    VALUES
        ('769', 'GOLD CAT A', 1, 10), ('778', 'GOLD CAT A', 1, 10), ('459', 'GOLD CAT A', 1, 10),
        ('709', 'GOLD CAT A', 1, 10), ('475', 'GOLD CAT A', 1, 10), ('821', 'GOLD CAT A', 1, 10),
        ('523', 'GOLD CAT A', 1, 10), ('452', 'GOLD CAT A', 1, 10), ('159', 'GOLD CAT A', 1, 10),
        ('824', 'GOLD CAT A', 1, 10), ('451', 'GOLD CAT A', 1, 10), ('107', 'GOLD CAT A', 1, 10),
        ('986', 'GOLD CAT A', 1, 10), ('348', 'GOLD CAT A', 1, 10), ('859', 'GOLD CAT A', 1, 10),
        ('103', 'GOLD CAT A', 1, 10),
        ('657', 'GOLD CAT B', 2, 20), ('160', 'GOLD CAT B', 2, 20),
        ('773', 'GOLD CAT B', 2, 20), ('597', 'GOLD CAT B', 2, 20),
        ('415', 'GOLD CAT C', 3, 30), ('308', 'GOLD CAT C', 3, 30),
        ('105', 'GOLD CAT C', 3, 30), ('167', 'GOLD CAT C', 3, 30)
),
type_rate (type_code, rate_percent) AS (
    VALUES
        ('DI2', 1.50),   -- Diamond & Solitaire
        ('PL4', 1.50),   -- Platinum
        ('UN7', 1.00),   -- Uncut
        ('PR1', 1.00),   -- Precious
        ('G18', 1.00),   -- 18k
        ('G14', 1.00),   -- 14k
        ('PLK', 1.00)    -- Polki
),
sold_line_items AS (
    SELECT
        ili.id AS line_item_id,
        i.invoice_code,
        i.created_at AS invoice_date,
        i.salesperson_employee_id,
        ili.product_id,
        ili.product_value,
        ili.sales_va_percentage,
        ili.created_at AS line_item_created_at
    FROM invoice_line_item ili
    JOIN invoice i ON i.id = ili.invoice_id
    JOIN invoice_status ist
        ON ist.invoice_id = i.id
        AND ist.end_time = '2100-01-01 00:00:00+00'
        AND ist.status <> 'CANCELLED'
    WHERE i.created_at >= '2026-08-01'   -- period start, edit as needed
      AND i.created_at <  '2026-09-01'   -- period end, edit as needed
),
-- Same "earned something" definition as employee_collection_incentive.sql's
-- employee_totals/HAVING clause, so the random sample is drawn from the
-- same employee universe that actually appears in the summary report.
qualifying_employees AS (
    SELECT sli.salesperson_employee_id
    FROM sold_line_items sli
    LEFT JOIN product_attribute_value pav_col
        ON pav_col.product_id = sli.product_id
        AND pav_col.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
    LEFT JOIN product_attribute_enum_value enum_col
        ON enum_col.id = pav_col.product_attribute_enum_value_id
    LEFT JOIN collection_category_rate ccr
        ON ccr.collection_code = enum_col.product_attribute_enum_value_code
    LEFT JOIN product_attribute_value pav_typ
        ON pav_typ.product_id = sli.product_id
        AND pav_typ.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'TYP')
    LEFT JOIN product_attribute_enum_value enum_typ
        ON enum_typ.id = pav_typ.product_attribute_enum_value_id
    LEFT JOIN type_rate tr
        ON tr.type_code = enum_typ.product_attribute_enum_value_code
    LEFT JOIN LATERAL (
        SELECT SUM(pmw.weight) AS net_weight
        FROM invoice_line_item_material ilim
        JOIN product_material pm ON pm.id = ilim.product_material_id
        JOIN material m ON m.id = pm.material_id AND m.type = 'METAL'
        JOIN product_material_weight pmw
            ON pmw.product_material_id = pm.id
            AND pmw.created_at <= sli.line_item_created_at
        WHERE ilim.invoice_line_item_id = sli.line_item_id
    ) w ON TRUE
    GROUP BY sli.salesperson_employee_id
    HAVING
        SUM(COALESCE(w.net_weight, 0) * COALESCE(ccr.rate_per_gram, 0)) > 0
        OR SUM(sli.product_value * COALESCE(tr.rate_percent, 0) / 100.0) > 0
),
random_employees AS (
    SELECT salesperson_employee_id
    FROM qualifying_employees
    ORDER BY random()
    LIMIT 10   -- <-- change this to sample a different number of employees
),
line_detail AS (
    SELECT
        sli.salesperson_employee_id,
        sli.invoice_code,
        sli.invoice_date,
        p.product_code,
        p.product_name,
        p.minimum_va_percentage                     AS mc_percentage,
        sli.sales_va_percentage,
        enum_col.product_attribute_enum_value_code   AS collection_code,
        enum_col.value                               AS collection_name,
        COALESCE(ccr.category, 'GOLD CAT 0')         AS category,
        COALESCE(ccr.category_sort, 4)                AS category_sort,
        enum_typ.product_attribute_enum_value_code   AS type_code,
        enum_typ.value                               AS type_name,
        sli.product_value                            AS taxable_value,
        COALESCE(w.net_weight, 0)                     AS net_weight_gm,
        ROUND(COALESCE(w.net_weight, 0) * COALESCE(ccr.rate_per_gram, 0), 2) AS category_incentive,
        ROUND(sli.product_value * COALESCE(tr.rate_percent, 0) / 100.0, 2)  AS type_incentive
    FROM sold_line_items sli
    JOIN product p ON p.id = sli.product_id
    LEFT JOIN product_attribute_value pav_col
        ON pav_col.product_id = sli.product_id
        AND pav_col.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
    LEFT JOIN product_attribute_enum_value enum_col
        ON enum_col.id = pav_col.product_attribute_enum_value_id
    LEFT JOIN collection_category_rate ccr
        ON ccr.collection_code = enum_col.product_attribute_enum_value_code
    LEFT JOIN product_attribute_value pav_typ
        ON pav_typ.product_id = sli.product_id
        AND pav_typ.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'TYP')
    LEFT JOIN product_attribute_enum_value enum_typ
        ON enum_typ.id = pav_typ.product_attribute_enum_value_id
    LEFT JOIN type_rate tr
        ON tr.type_code = enum_typ.product_attribute_enum_value_code
    LEFT JOIN LATERAL (
        SELECT SUM(pmw.weight) AS net_weight
        FROM invoice_line_item_material ilim
        JOIN product_material pm ON pm.id = ilim.product_material_id
        JOIN material m ON m.id = pm.material_id AND m.type = 'METAL'
        JOIN product_material_weight pmw
            ON pmw.product_material_id = pm.id
            AND pmw.created_at <= sli.line_item_created_at
        WHERE ilim.invoice_line_item_id = sli.line_item_id
    ) w ON TRUE
    WHERE sli.salesperson_employee_id IN (SELECT salesperson_employee_id FROM random_employees)
)
SELECT
    au.user_code                                AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)    AS employee_name,
    ld.category,
    ld.invoice_code,
    ld.invoice_date::date AS invoice_date,
    ld.product_code,
    ld.product_name,
    ld.collection_code,
    ld.collection_name,
    ld.type_code,
    ld.sales_va_percentage,
    ld.taxable_value,
    ld.net_weight_gm,
    ld.category_incentive

FROM line_detail ld
JOIN employee e ON e.id = ld.salesperson_employee_id
JOIN app_user au ON au.id = e.user_id
ORDER BY employee_name, ld.category_sort, ld.taxable_value ASC;
