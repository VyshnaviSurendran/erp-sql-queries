-- Drill-down for verifying a specific employee against ALL THREE summary
-- reports at once -- employee_mc_incentive.sql (default), _kerala.sql, and
-- _karnataka_tamil_nadu.sql -- in a single query: one row per invoice line
-- item, tagged with the region its sale was billed in and the Category
-- (Sale MC%) threshold that region uses, plus the Other (Type) scheme.
--
--   Sale MC% (default / Kerala)   Category     Rate
--   0%    - 4.5%               -> GOLD CAT 0   Rs 0/gram
--   4.6%  - 9.5%               -> GOLD CAT A   Rs 10/gram
--   9.6%  - 12.5%              -> GOLD CAT B   Rs 20/gram
--   12.6% and above            -> GOLD CAT C   Rs 30/gram (no upper bound)
--
--   Sale MC% (Karnataka / Tamil Nadu)   Category     Rate
--   0%    - 5.5%                     -> GOLD CAT 0   Rs 0/gram
--   5.6%  - 10.5%                    -> GOLD CAT A   Rs 10/gram
--   10.6% - 14.5%                    -> GOLD CAT B   Rs 20/gram
--   14.6% and above                  -> GOLD CAT C   Rs 30/gram (no upper bound)
--
--   CAT A/B/C (either threshold set) are further restricted to G22 (Gold
--   22k, TYP code 'G22') items only -- any other Type (or none) is forced
--   to GOLD CAT 0 regardless of Sale MC%.
--
--   Other (TYP attribute)      Rate
--   Diamond & Solitaire (DI2)  1.5% of taxable value
--   Platinum (PL4)             1.5% of taxable value
--   Uncut (UN7)                1% of taxable value
--   Precious (PR1)             1% of taxable value
--   18k (G18)                  1% of taxable value
--   14k (G14)                  1% of taxable value
--   Polki (PLK)                1% of taxable value
--
-- region is the SALE's billing branch (invoice.location_id -> branch ->
-- address.state_code), NOT the employee's own branch assignment --
-- 'KERALA' rows are what employee_mc_incentive_kerala.sql reports for this
-- employee, 'KARNATAKA_TAMIL_NADU' rows are what
-- employee_mc_incentive_karnataka_tamil_nadu.sql reports, and 'DEFAULT'
-- rows are what employee_mc_incentive.sql reports. sale_branch is that
-- same billing branch's name. For SR (returns), region/sale_branch come
-- from the ORIGINAL invoice's billing branch, not wherever the return was
-- processed.
--
-- Ordered by employee, then region, then category, then taxable value, so
-- you can see one employee's default-report sales, then their Kerala
-- sales, then their Karnataka/Tamil Nadu sales, each broken into CAT A/B/C/0
-- -- matching the cat_a/b/c/0 split-up in the three summary reports. Each
-- row also carries a running subtotal per employee+region+category AND per
-- employee+region+type (net weight/category incentive, and type
-- value/incentive respectively) via window functions, so all three
-- schemes' totals are visible without a separate query per report.
--
-- To check specific employee(s), edit the sample_employees CTE below:
--   WHERE au.user_code IN ('EMP001', 'EMP002')
--
-- Includes Sales Returns (SR) as a NEGATIVE contribution: a sales_return_line_item
-- always points back to one original invoice_line_item (it has no weight/value/
-- Sale MC% of its own), so the return reuses that original line's figures and
-- subtracts them -- crediting the reversal to the ORIGINAL salesperson
-- (i.salesperson_employee_id), not sr.salesperson_employee_id, matching how
-- sales_analysis_report_v3 treats SR. sale_type shows which side a row is from.
--
-- Edit the date range (WHERE clause in sold_line_items) to match the
-- period you're verifying against the summary reports.

WITH type_rate (type_code, rate_percent) AS (
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
        bl.branch_name,
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

    -- SR: sales returns, sign -1 -- reuses the ORIGINAL invoice_line_item's
    -- weight/value/Sale MC%, credited to the ORIGINAL salesperson, and
    -- region/sale_branch come from the ORIGINAL invoice's billing branch.
    SELECT
        ili.id AS line_item_id,
        sr.sales_return_code AS invoice_code,
        sr.created_at AS invoice_date,
        i.salesperson_employee_id,
        ili.product_id,
        ili.product_value,
        ili.sales_va_percentage,
        ili.created_at AS line_item_created_at,
        bl.branch_name,
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
        sli.branch_name AS sale_branch,
        sli.state_code,
        CASE
            WHEN sli.state_code = 'KL'          THEN 'KERALA'
            WHEN sli.state_code IN ('KA', 'TN') THEN 'KARNATAKA_TAMIL_NADU'
            ELSE 'DEFAULT'
        END AS region,
        p.product_code,
        p.product_name,
        sli.sales_va_percentage,
        ROUND(sli.sales_va_percentage, 1) AS sales_va_rounded,
        -- Category, using whichever threshold set applies to this line's region.
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
        -- sign flips these to negative for SR (returns), so every downstream
        -- SUM()/subtotal nets returns out automatically.
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
        enum_typ.value AS type_name,
        sli.sign * ROUND(sli.product_value * COALESCE(tr.rate_percent, 0) / 100.0, 2) AS type_incentive,
        sli.sign * ROUND(COALESCE(w.metal_amount, 0) * sli.sales_va_percentage / 100.0, 2) AS sales_va_amount
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
),
-- Same "earned something" definition as each summary report's
-- employee_totals/HAVING clause (per employee, across all regions).
qualifying_employees AS (
    SELECT salesperson_employee_id
    FROM line_detail
    GROUP BY salesperson_employee_id
    HAVING SUM(category_incentive) > 0 OR SUM(type_incentive) > 0
),
sample_employees AS (
    -- Checking a specific employee: user_code 2628.
    SELECT e.id AS salesperson_employee_id
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    WHERE au.user_code = '2628'
)
SELECT
    au.user_code                                 AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)     AS employee_name,
    ld.region,
    ld.sale_branch,
    ld.category,
    ld.type_code,
    ld.type_name,
    ld.sale_type,
    ld.invoice_code,
    ld.invoice_date::date AS invoice_date,
    ld.product_code,
    ld.product_name,
    ld.sales_va_percentage,
    ld.sales_va_rounded,
    ld.sales_va_amount,
    ld.taxable_value,
    ld.net_weight_gm,
    ld.category_incentive,
    ld.type_incentive,

    -- Category split-up per employee+region+category, repeated on every
    -- row of that group -- matches the cat_a/b/c/0 columns in whichever
    -- summary report this region belongs to.
    SUM(ld.net_weight_gm) OVER (PARTITION BY ld.salesperson_employee_id, ld.region, ld.category)        AS category_net_weight_subtotal,
    SUM(ld.category_incentive) OVER (PARTITION BY ld.salesperson_employee_id, ld.region, ld.category)   AS category_incentive_subtotal,
    SUM(ld.taxable_value) OVER (PARTITION BY ld.salesperson_employee_id, ld.region, ld.category)          AS category_taxable_value_subtotal,

    -- Other (Type) split-up per employee+region+type, repeated on every
    -- row of that group -- NULL for rows with no matching type_code.
    SUM(ld.taxable_value) OVER (PARTITION BY ld.salesperson_employee_id, ld.region, ld.type_code)   AS type_taxable_value_subtotal,
    SUM(ld.type_incentive) OVER (PARTITION BY ld.salesperson_employee_id, ld.region, ld.type_code)  AS type_incentive_subtotal
FROM line_detail ld
JOIN sample_employees se ON se.salesperson_employee_id = ld.salesperson_employee_id
JOIN employee e ON e.id = ld.salesperson_employee_id
JOIN app_user au ON au.id = e.user_id
ORDER BY employee_name, ld.region, ld.category_sort, ld.taxable_value ASC;
