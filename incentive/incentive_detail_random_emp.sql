-- Drill-down for verifying employee_mc_incentive.sql: one row per invoice
-- line item, for 2 employees picked from 2 DIFFERENT branches (so you can
-- spot-check across branches in one go), using the exact same Sale MC%
-- bracket logic as the summary report.
--
--   Sale MC%            Category     Rate
--   0%    - 4.5%     ->  GOLD CAT 0   Rs 0/gram
--   4.6%  - 9.5%     ->  GOLD CAT A   Rs 10/gram
--   9.6%  - 12.5%    ->  GOLD CAT B   Rs 20/gram
--   12.6% - 18%      ->  GOLD CAT C   Rs 30/gram
--   above 18%        ->  NOT categorized (category shown as NULL)
--
-- Ordered by employee, then category, then taxable value, so each
-- employee's GOLD CAT A sales are grouped together, then CAT B, etc.,
-- matching the cat_a/b/c/0 split-up in the summary. Each row also carries
-- a running subtotal per employee+category (net weight, category
-- incentive, taxable value) via window functions.
--
-- To check a SPECIFIC employee instead of a random 2-branch sample,
-- replace the sample_employees CTE with:
--   SELECT e.id AS salesperson_employee_id
--   FROM employee e JOIN app_user au ON au.id = e.user_id
--   WHERE au.user_code IN ('EMP001', 'EMP002')
--
-- Edit the date range (WHERE clause in sold_line_items) to match the
-- period you're verifying against the summary report.

WITH sold_line_items AS (
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
line_detail AS (
    SELECT
        sli.salesperson_employee_id,
        sli.invoice_code,
        sli.invoice_date,
        p.product_code,
        p.product_name,
        sli.sales_va_percentage,
        ROUND(sli.sales_va_percentage, 1) AS sales_va_rounded,
        CASE
            WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 'GOLD CAT 0'
            WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 'GOLD CAT A'
            WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 'GOLD CAT B'
            WHEN ROUND(sli.sales_va_percentage, 1) <= 18.0 THEN 'GOLD CAT C'
        END AS category,
        CASE
            WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 1
            WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 2
            WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 3
            WHEN ROUND(sli.sales_va_percentage, 1) <= 18.0 THEN 4
            ELSE 5
        END AS category_sort,
        sli.product_value AS taxable_value,
        COALESCE(w.net_weight, 0) AS net_weight_gm,
        ROUND(
            COALESCE(w.net_weight, 0) *
            (CASE
                WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 0
                WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 10
                WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 20
                WHEN ROUND(sli.sales_va_percentage, 1) <= 18.0 THEN 30
            END),
        2) AS category_incentive,
        ROUND(COALESCE(w.metal_amount, 0) * sli.sales_va_percentage / 100.0, 2) AS sales_va_amount
    FROM sold_line_items sli
    JOIN product p ON p.id = sli.product_id
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
-- Same "earned something" definition as employee_mc_incentive.sql's
-- employee_totals/HAVING clause.
qualifying_employees AS (
    SELECT salesperson_employee_id
    FROM line_detail
    GROUP BY salesperson_employee_id
    HAVING SUM(category_incentive) > 0
),
sample_employees AS (
    -- Picks one qualifying employee per branch, then keeps 2 branches --
    -- i.e. 2 employees guaranteed to be from 2 different branches.
    SELECT DISTINCT ON (ub.branch_id)
        qe.salesperson_employee_id,
        ub.branch_id
    FROM qualifying_employees qe
    JOIN employee e ON e.id = qe.salesperson_employee_id
    JOIN app_user au ON au.id = e.user_id
    JOIN user_branch ub
        ON ub.user_id = au.id
        AND ub.end_time = '2100-01-01 00:00:00+00'
    ORDER BY ub.branch_id, random()
    LIMIT 2
)
SELECT
    b.branch_name                                AS employee_branch,
    au.user_code                                 AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)     AS employee_name,
    ld.category,
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

    -- Split-up per employee+category, repeated on every row of that group.
    SUM(ld.net_weight_gm) OVER (PARTITION BY ld.salesperson_employee_id, ld.category)        AS category_net_weight_subtotal,
    SUM(ld.category_incentive) OVER (PARTITION BY ld.salesperson_employee_id, ld.category)   AS category_incentive_subtotal,
    SUM(ld.taxable_value) OVER (PARTITION BY ld.salesperson_employee_id, ld.category)          AS category_taxable_value_subtotal
FROM line_detail ld
JOIN sample_employees se ON se.salesperson_employee_id = ld.salesperson_employee_id
JOIN employee e ON e.id = ld.salesperson_employee_id
JOIN app_user au ON au.id = e.user_id
LEFT JOIN user_branch ub
    ON ub.user_id = au.id
    AND ub.end_time = '2100-01-01 00:00:00+00'
LEFT JOIN branch b ON b.id = ub.branch_id
ORDER BY employee_branch, employee_name, ld.category_sort, ld.taxable_value ASC;
