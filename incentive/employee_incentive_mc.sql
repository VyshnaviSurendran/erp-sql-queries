-- Employee incentive summary, branch-wise: category is determined ONLY by
-- the Sale MC% actually billed on each line item (ili.sales_va_percentage).
-- Collection and Type are NOT part of this calculation at all -- this is a
-- pure Sale-MC%-based scheme, replacing both prior dimensions entirely.
--
--   Sale MC%            Category     Rate
--   0%    - 4.5%     ->  GOLD CAT 0   Rs 0/gram
--   4.6%  - 9.5%     ->  GOLD CAT A   Rs 10/gram
--   9.6%  - 12.5%    ->  GOLD CAT B   Rs 20/gram
--   12.6% - 18%      ->  GOLD CAT C   Rs 30/gram
--   above 18%        ->  NOT categorized yet (pending confirmation -- see
--                        below). These items are excluded from every
--                        category bucket and from taxable_value_cat_abc /
--                        taxable_value_cat_0, but they DO still count
--                        toward total_taxable_value (which is a plain,
--                        unfiltered sum), so total_taxable_value can be
--                        greater than taxable_value_cat_abc +
--                        taxable_value_cat_0 whenever such items exist.
--
-- The bracket check rounds Sale MC% to 1 decimal first (ROUND(..., 1)), so
-- e.g. 4.55% rounds to 4.6% (-> CAT A) and 4.54% rounds to 4.5% (-> CAT 0),
-- closing the gap between the stated ranges -- confirmed with the business.
--
-- No branch filter -- covers every salesperson, every branch.
-- A salesperson appears only if they earned a non-zero category incentive
-- (an employee whose sales are ALL above-18%/uncategorized won't appear).
-- Incentive is credited to invoice.salesperson_employee_id.
-- sales_va_amount is an added verification column: metal value (rate x
-- weight) x the VA% actually billed on that sale -- informational only,
-- not used in any incentive calculation.
-- Edit the date range (WHERE clause in sold_line_items) as needed.

WITH sold_line_items AS (
    SELECT
        ili.id AS line_item_id,
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
line_incentive AS (
    SELECT
        sli.salesperson_employee_id,
        sli.product_value,
        -- Category and rate, both derived purely from the rounded Sale MC%.
        -- No ELSE branch: above 18% MC, category stays NULL (not yet
        -- categorized) rather than being silently forced into a bucket.
        CASE
            WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 'GOLD CAT 0'
            WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 'GOLD CAT A'
            WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 'GOLD CAT B'
            WHEN ROUND(sli.sales_va_percentage, 1) <= 18.0 THEN 'GOLD CAT C'
        END AS category,
        COALESCE(w.net_weight, 0) AS net_weight,
        ROUND(
            COALESCE(w.net_weight, 0) *
            (CASE
                WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 0
                WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 10
                WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 20
                WHEN ROUND(sli.sales_va_percentage, 1) <= 18.0 THEN 30
            END),
        2) AS category_incentive,
        -- Same formula employee_invoice_detail.sql uses for sales_va_amount:
        -- metal value (rate x weight) x the VA% actually billed on this sale.
        ROUND(COALESCE(w.metal_amount, 0) * sli.sales_va_percentage / 100.0, 2) AS sales_va_amount
    FROM sold_line_items sli
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
employee_totals AS (
    SELECT
        li.salesperson_employee_id,

        COALESCE(SUM(li.net_weight) FILTER (WHERE li.category = 'GOLD CAT A'), 0) AS cat_a_net_weight_gm,
        COALESCE(SUM(li.category_incentive) FILTER (WHERE li.category = 'GOLD CAT A'), 0) AS cat_a_incentive,
        COALESCE(SUM(li.net_weight) FILTER (WHERE li.category = 'GOLD CAT B'), 0) AS cat_b_net_weight_gm,
        COALESCE(SUM(li.category_incentive) FILTER (WHERE li.category = 'GOLD CAT B'), 0) AS cat_b_incentive,
        COALESCE(SUM(li.net_weight) FILTER (WHERE li.category = 'GOLD CAT C'), 0) AS cat_c_net_weight_gm,
        COALESCE(SUM(li.category_incentive) FILTER (WHERE li.category = 'GOLD CAT C'), 0) AS cat_c_incentive,
        COALESCE(SUM(li.net_weight) FILTER (WHERE li.category = 'GOLD CAT 0'), 0) AS cat_0_net_weight_gm,
        COALESCE(SUM(li.category_incentive) FILTER (WHERE li.category = 'GOLD CAT 0'), 0) AS cat_0_incentive,

        -- Items above 18% MC (category IS NULL) -- not categorized yet,
        -- kept separately so they're visible rather than silently dropped.
        COALESCE(SUM(li.net_weight) FILTER (WHERE li.category IS NULL), 0) AS uncategorized_net_weight_gm,
        COALESCE(SUM(li.product_value) FILTER (WHERE li.category IS NULL), 0) AS uncategorized_value,

        SUM(li.category_incentive) AS category_incentive_total,
        SUM(li.sales_va_amount) AS sales_va_amount,

        SUM(li.product_value) AS total_taxable_value,
        COALESCE(SUM(li.product_value) FILTER (
            WHERE li.category IN ('GOLD CAT A', 'GOLD CAT B', 'GOLD CAT C')
        ), 0) AS taxable_value_cat_abc,
        COALESCE(SUM(li.product_value) FILTER (WHERE li.category = 'GOLD CAT 0'), 0) AS taxable_value_cat_0
    FROM line_incentive li
    GROUP BY li.salesperson_employee_id
    HAVING SUM(li.category_incentive) > 0
),
employee_eligibility AS (
    -- Branded product contribution = share of sales value from items that
    -- landed in a paying category (A/B/C) rather than CAT 0 -- same figure
    -- shown as taxable_value_cat_abc_percentage. incentive_eligibility_percentage
    -- is the slab lookup on that share; below 10% earns no incentive at all.
    SELECT
        et.*,
        et.taxable_value_cat_abc * 100.0 / NULLIF(et.total_taxable_value, 0) AS branded_pct,
        CASE
            WHEN et.taxable_value_cat_abc * 100.0 / NULLIF(et.total_taxable_value, 0) >= 50 THEN 100
            WHEN et.taxable_value_cat_abc * 100.0 / NULLIF(et.total_taxable_value, 0) >= 40 THEN 80
            WHEN et.taxable_value_cat_abc * 100.0 / NULLIF(et.total_taxable_value, 0) >= 30 THEN 60
            WHEN et.taxable_value_cat_abc * 100.0 / NULLIF(et.total_taxable_value, 0) >= 20 THEN 40
            WHEN et.taxable_value_cat_abc * 100.0 / NULLIF(et.total_taxable_value, 0) >= 10 THEN 20
            ELSE 0
        END AS incentive_eligibility_percentage
    FROM employee_totals et
)
SELECT
    au.user_code                                AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)    AS employee_name,
    b.branch_name                                AS employee_branch,

    et.cat_a_net_weight_gm                      AS cat_a_10rs_per_gm_net_weight_gm,
    et.cat_a_incentive                          AS cat_a_10rs_per_gm_incentive,
    et.cat_b_net_weight_gm                      AS cat_b_20rs_per_gm_net_weight_gm,
    et.cat_b_incentive                          AS cat_b_20rs_per_gm_incentive,
    et.cat_c_net_weight_gm                      AS cat_c_30rs_per_gm_net_weight_gm,
    et.cat_c_incentive                          AS cat_c_30rs_per_gm_incentive,
    et.cat_0_net_weight_gm                      AS cat_0_0rs_per_gm_net_weight_gm,
    et.cat_0_incentive                          AS cat_0_0rs_per_gm_incentive,

    et.uncategorized_net_weight_gm,
    et.uncategorized_value,

    et.total_taxable_value,
    et.sales_va_amount,
    et.taxable_value_cat_abc,
    ROUND(et.branded_pct, 2) AS taxable_value_cat_abc_percentage,
    et.taxable_value_cat_0,
    ROUND(et.taxable_value_cat_0 * 100.0 / NULLIF(et.total_taxable_value, 0), 2) AS taxable_value_cat_0_percentage,
    ROUND(et.category_incentive_total, 2) AS total_incentive,

    et.incentive_eligibility_percentage,

    -- Final payable incentive = total_incentive x incentive_eligibility_percentage.
    ROUND(et.category_incentive_total * et.incentive_eligibility_percentage / 100.0, 2) AS final_incentive
FROM employee_eligibility et
JOIN employee e ON e.id = et.salesperson_employee_id
JOIN app_user au ON au.id = e.user_id
LEFT JOIN user_branch ub
    ON ub.user_id = au.id
    AND ub.end_time = '2100-01-01 00:00:00+00'
LEFT JOIN branch b ON b.id = ub.branch_id
ORDER BY employee_branch, employee_name;
