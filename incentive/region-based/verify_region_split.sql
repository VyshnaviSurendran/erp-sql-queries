-- Verification: employee 1091's line items, tagged with the SAME region
-- (Kerala vs Karnataka/Tamil Nadu) and threshold logic used by the split
-- report files, side by side in one query -- so you can see exactly which
-- lines shifted between categories (CAT A <-> CAT 0, CAT C <-> CAT B) and
-- confirm the per-region subtotals match employee_mc_incentive_kerala.sql
-- and employee_mc_incentive_karnataka_tamil_nadu.sql exactly.
--
-- Kerala thresholds:      0-4.5=CAT0  4.6-9.5=CATA  9.6-12.5=CATB  >12.5=CATC
-- Karnataka/TN thresholds: 0-5.5=CAT0  5.6-10.5=CATA 10.6-14.5=CATB >14.5=CATC
--
-- Region is the SALE's billing branch (invoice.location_id), same as the
-- split files -- for SR (returns), the ORIGINAL invoice's billing branch.

WITH type_rate (type_code, rate_percent) AS (
    VALUES
        ('DI2', 1.50), ('PL4', 1.50), ('UN7', 1.00),
        ('PR1', 1.00), ('G18', 1.00), ('G14', 1.00), ('PLK', 1.00)
),
sold_line_items AS (
    -- SL: original sales, sign +1
    SELECT
        ili.id AS line_item_id,
        i.invoice_code,
        i.created_at AS invoice_date,
        i.salesperson_employee_id,
        ili.product_id,
        ili.product_value,
        ili.sales_va_percentage,
        ili.created_at AS line_item_created_at,
        al.state_code,
        'SL' AS sale_type,
        1 AS sign
    FROM invoice_line_item ili
    JOIN invoice i ON i.id = ili.invoice_id
    JOIN invoice_status ist
        ON ist.invoice_id = i.id
        AND ist.end_time = '2100-01-01 00:00:00+00'
        AND ist.status <> 'CANCELLED'
    JOIN branch bl ON bl.id = i.location_id
    JOIN address al ON al.id = bl.address_id
    WHERE i.created_at >= '2026-08-01'   -- period start, edit as needed
      AND i.created_at <  '2026-09-01'   -- period end, edit as needed

    UNION ALL

    -- SR: sales returns, sign -1 -- region/state comes from the ORIGINAL
    -- invoice's billing branch, not wherever the return was processed.
    SELECT
        ili.id AS line_item_id,
        sr.sales_return_code AS invoice_code,
        sr.created_at AS invoice_date,
        i.salesperson_employee_id,
        ili.product_id,
        ili.product_value,
        ili.sales_va_percentage,
        ili.created_at AS line_item_created_at,
        al.state_code,
        'SR' AS sale_type,
        -1 AS sign
    FROM sales_return_line_item srli
    JOIN sales_return sr ON sr.id = srli.sales_return_id
    JOIN sales_return_status srs
        ON srs.sales_return_id = sr.id
        AND srs.end_time = '2100-01-01 00:00:00+00'
        AND srs.status <> 'CANCELLED'
    JOIN invoice_line_item ili ON ili.id = srli.invoice_line_item_id
    JOIN invoice i ON i.id = ili.invoice_id
    JOIN branch bl ON bl.id = i.location_id
    JOIN address al ON al.id = bl.address_id
    WHERE sr.created_at >= '2026-08-01'   -- period start, edit as needed
      AND sr.created_at <  '2026-09-01'   -- period end, edit as needed
),
line_detail AS (
    SELECT
        sli.salesperson_employee_id,
        sli.sale_type,
        sli.invoice_code,
        sli.invoice_date,
        p.product_code,
        p.product_name,
        sli.state_code,
        CASE
            WHEN sli.state_code = 'KL'              THEN 'KERALA'
            WHEN sli.state_code IN ('KA', 'TN')      THEN 'KARNATAKA_TAMIL_NADU'
            ELSE 'OTHER (default file)'
        END AS region,
        sli.sales_va_percentage,
        ROUND(sli.sales_va_percentage, 1) AS sales_va_rounded,
        -- Category, using WHICHEVER threshold set applies to this line's region.
        CASE
            WHEN enum_typ.product_attribute_enum_value_code IS DISTINCT FROM 'G22' THEN 'GOLD CAT 0'
            WHEN sli.state_code IN ('KA', 'TN') THEN
                CASE
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 5.5  THEN 'GOLD CAT 0'
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 10.5 THEN 'GOLD CAT A'
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 14.5 THEN 'GOLD CAT B'
                    ELSE 'GOLD CAT C'
                END
            ELSE  -- Kerala and everywhere else: default thresholds
                CASE
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 'GOLD CAT 0'
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 'GOLD CAT A'
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 'GOLD CAT B'
                    ELSE 'GOLD CAT C'
                END
        END AS category,
        CASE
            WHEN enum_typ.product_attribute_enum_value_code IS DISTINCT FROM 'G22' THEN 1
            WHEN sli.state_code IN ('KA', 'TN') THEN
                CASE
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 5.5  THEN 1
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 10.5 THEN 2
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 14.5 THEN 3
                    ELSE 4
                END
            ELSE
                CASE
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 1
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 2
                    WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 3
                    ELSE 4
                END
        END AS category_sort,
        sli.sign * sli.product_value AS taxable_value,
        sli.sign * COALESCE(w.net_weight, 0) AS net_weight_gm,
        sli.sign * ROUND(
            COALESCE(w.net_weight, 0) *
            (CASE
                WHEN enum_typ.product_attribute_enum_value_code IS DISTINCT FROM 'G22' THEN 0
                WHEN sli.state_code IN ('KA', 'TN') THEN
                    CASE
                        WHEN ROUND(sli.sales_va_percentage, 1) <= 5.5  THEN 0
                        WHEN ROUND(sli.sales_va_percentage, 1) <= 10.5 THEN 10
                        WHEN ROUND(sli.sales_va_percentage, 1) <= 14.5 THEN 20
                        ELSE 30
                    END
                ELSE
                    CASE
                        WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 0
                        WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 10
                        WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 20
                        ELSE 30
                    END
            END),
        2) AS category_incentive,
        enum_typ.product_attribute_enum_value_code AS type_code,
        sli.sign * ROUND(sli.product_value * COALESCE(tr.rate_percent, 0) / 100.0, 2) AS type_incentive
    FROM sold_line_items sli
    JOIN product p ON p.id = sli.product_id
    LEFT JOIN product_attribute_value pav_typ
        ON pav_typ.product_id = sli.product_id
        AND pav_typ.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'TYP')
    LEFT JOIN product_attribute_enum_value enum_typ
        ON enum_typ.id = pav_typ.product_attribute_enum_value_id
    LEFT JOIN type_rate tr
        ON tr.type_code = enum_typ.product_attribute_enum_value_code
    LEFT JOIN LATERAL (
        SELECT
            SUM(pmw.weight) AS net_weight,
            SUM(ilim.rate * pmw.weight) AS metal_amount
        FROM invoice_line_item_material ilim
        JOIN product_material pm ON pm.id = ilim.product_material_id
        JOIN material m ON m.id = pm.material_id AND m.type = 'METAL'
        JOIN product_material_weight pmw
            ON pmw.product_material_id = pm.id
            AND pmw.created_at <= sli.line_item_created_at
        WHERE ilim.invoice_line_item_id = sli.line_item_id
    ) w ON TRUE
    WHERE sli.salesperson_employee_id = (
        SELECT e.id FROM employee e JOIN app_user au ON au.id = e.user_id
        WHERE au.user_code = '1091'   -- <-- employee to check
    )
)
SELECT
    region,
    category,
    sale_type,
    invoice_code,
    invoice_date::date AS invoice_date,
    product_code,
    product_name,
    state_code,
    sales_va_percentage,
    sales_va_rounded,
    taxable_value,
    net_weight_gm,
    category_incentive,
    type_code,
    type_incentive,

    -- Per-region, per-category subtotal -- should match the cat_a/b/c/0
    -- columns in employee_mc_incentive_kerala.sql /
    -- employee_mc_incentive_karnataka_tamil_nadu.sql for this employee.
    SUM(net_weight_gm) OVER (PARTITION BY region, category)        AS region_category_net_weight_subtotal,
    SUM(category_incentive) OVER (PARTITION BY region, category)  AS region_category_incentive_subtotal,
    SUM(taxable_value) OVER (PARTITION BY region, category)        AS region_category_taxable_value_subtotal
FROM line_detail
ORDER BY region, category_sort, invoice_date;
