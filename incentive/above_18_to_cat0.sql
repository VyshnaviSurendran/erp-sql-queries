-- Employee incentive summary, branch-wise: category is now determined by
-- the Sale MC% actually billed on each line item (ili.sales_va_percentage),
-- NOT by collection code. Collection is no longer part of the incentive
-- calculation at all (it's still shown in employee_invoice_detail.sql for
-- reference, but doesn't drive any rate here).
--
--   Sale MC%            Category     Rate
--   0%    - 4.5%     ->  GOLD CAT 0   Rs 0/gram
--   4.6%  - 9.5%     ->  GOLD CAT A   Rs 10/gram
--   9.6%  - 12.5%    ->  GOLD CAT B   Rs 20/gram
--   12.6% - 18%      ->  GOLD CAT C   Rs 30/gram
--   above 18%        ->  GOLD CAT 0   Rs 0/gram (no bracket defined above
--                        18%, so it falls back to the same default used for
--                        "no match" everywhere else in this report)
--
-- The bracket check rounds Sale MC% to 1 decimal first (ROUND(..., 1)), so
-- e.g. 4.55% rounds to 4.6% (-> CAT A) and 4.54% rounds to 4.5% (-> CAT 0),
-- closing the gap between the stated ranges -- confirmed with the business.
--
-- Type (TYP attribute) scheme is unchanged: Diamond & Solitaire / Platinum
-- (1.5%) and Uncut / Precious / 18k / 14k / Polki (1%), value-based
-- (product_value x rate%), independent of the category scheme above.
--
-- Filtered to salespeople whose CURRENT branch (user_branch) is one of
-- 8, 7, 21, 17 -- not the invoice's location_id, so the filter and the
-- displayed employee_branch always agree (see employee_invoice_detail.sql
-- for the full explanation of why that distinction matters).
-- A salesperson appears only if they have at least one item that earns
-- something under EITHER the Category or the Type scheme.
-- Incentive is credited to invoice.salesperson_employee_id.
-- sales_va_amount is an added verification column: metal value (rate x
-- weight) x the VA% actually billed on that sale -- informational only,
-- not used in any incentive calculation.
-- Edit the date range (WHERE clause in sold_line_items) as needed.

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
branch_employees AS (
    SELECT e.id AS salesperson_employee_id
    FROM employee e
    JOIN app_user au ON au.id = e.user_id
    JOIN user_branch ub
        ON ub.user_id = au.id
        AND ub.end_time = '2100-01-01 00:00:00+00'
    WHERE ub.branch_id = ANY(ARRAY[8,7,21,17]::int[])   -- branch filter, edit as needed
),
sold_line_items AS (
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
      AND i.salesperson_employee_id IN (SELECT salesperson_employee_id FROM branch_employees)
),
line_incentive AS (
    SELECT
        sli.salesperson_employee_id,
        sli.product_value,
        -- Category and rate, both derived purely from the rounded Sale MC%.
        CASE
            WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 'GOLD CAT 0'
            WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 'GOLD CAT A'
            WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 'GOLD CAT B'
            WHEN ROUND(sli.sales_va_percentage, 1) <= 18.0 THEN 'GOLD CAT C'
            ELSE 'GOLD CAT 0'
        END AS category,
        COALESCE(w.net_weight, 0) AS net_weight,
        ROUND(
            COALESCE(w.net_weight, 0) *
            (CASE
                WHEN ROUND(sli.sales_va_percentage, 1) <= 4.5  THEN 0
                WHEN ROUND(sli.sales_va_percentage, 1) <= 9.5  THEN 10
                WHEN ROUND(sli.sales_va_percentage, 1) <= 12.5 THEN 20
                WHEN ROUND(sli.sales_va_percentage, 1) <= 18.0 THEN 30
                ELSE 0
            END),
        2) AS category_incentive,
        enum_typ.product_attribute_enum_value_code AS type_code,
        ROUND(sli.product_value * COALESCE(tr.rate_percent, 0) / 100.0, 2) AS type_incentive,
        -- Same formula employee_invoice_detail.sql uses for sales_va_amount:
        -- metal value (rate x weight) x the VA% actually billed on this sale.
        ROUND(COALESCE(w.metal_amount, 0) * sli.sales_va_percentage / 100.0, 2) AS sales_va_amount
    FROM sold_line_items sli
    -- Type (TYP) lookup -> Diamond/Platinum/Uncut/Precious/18k/14k/Polki, else no match
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

        COALESCE(SUM(li.product_value) FILTER (WHERE li.type_code = 'DI2'), 0) AS diamond_solitaire_value,
        COALESCE(SUM(li.type_incentive) FILTER (WHERE li.type_code = 'DI2'), 0) AS diamond_solitaire_incentive,
        COALESCE(SUM(li.product_value) FILTER (WHERE li.type_code = 'PL4'), 0) AS platinum_value,
        COALESCE(SUM(li.type_incentive) FILTER (WHERE li.type_code = 'PL4'), 0) AS platinum_incentive,
        COALESCE(SUM(li.product_value) FILTER (WHERE li.type_code = 'UN7'), 0) AS uncut_value,
        COALESCE(SUM(li.type_incentive) FILTER (WHERE li.type_code = 'UN7'), 0) AS uncut_incentive,
        COALESCE(SUM(li.product_value) FILTER (WHERE li.type_code = 'PR1'), 0) AS precious_value,
        COALESCE(SUM(li.type_incentive) FILTER (WHERE li.type_code = 'PR1'), 0) AS precious_incentive,
        COALESCE(SUM(li.product_value) FILTER (WHERE li.type_code = 'G18'), 0) AS g18_value,
        COALESCE(SUM(li.type_incentive) FILTER (WHERE li.type_code = 'G18'), 0) AS g18_incentive,
        COALESCE(SUM(li.product_value) FILTER (WHERE li.type_code = 'G14'), 0) AS g14_value,
        COALESCE(SUM(li.type_incentive) FILTER (WHERE li.type_code = 'G14'), 0) AS g14_incentive,
        COALESCE(SUM(li.product_value) FILTER (WHERE li.type_code = 'PLK'), 0) AS polki_value,
        COALESCE(SUM(li.type_incentive) FILTER (WHERE li.type_code = 'PLK'), 0) AS polki_incentive,

        SUM(li.category_incentive) AS category_incentive_total,
        SUM(li.type_incentive) AS type_incentive_total,
        SUM(li.sales_va_amount) AS sales_va_amount,

        SUM(li.product_value) AS total_taxable_value,
        COALESCE(SUM(li.product_value) FILTER (
            WHERE li.category IN ('GOLD CAT A', 'GOLD CAT B', 'GOLD CAT C')
        ), 0) AS taxable_value_cat_abc,
        COALESCE(SUM(li.product_value) FILTER (WHERE li.category = 'GOLD CAT 0'), 0) AS taxable_value_cat_0
    FROM line_incentive li
    GROUP BY li.salesperson_employee_id
    HAVING SUM(li.category_incentive) > 0 OR SUM(li.type_incentive) > 0
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

    et.diamond_solitaire_value                  AS diamond_solitaire_1_5pct_value,
    et.diamond_solitaire_incentive              AS diamond_solitaire_1_5pct_incentive,
    et.platinum_value                           AS platinum_1_5pct_value,
    et.platinum_incentive                       AS platinum_1_5pct_incentive,
    et.uncut_value                              AS uncut_1pct_value,
    et.uncut_incentive                          AS uncut_1pct_incentive,
    et.precious_value                           AS precious_1pct_value,
    et.precious_incentive                       AS precious_1pct_incentive,
    et.g18_value                                AS g18_1pct_value,
    et.g18_incentive                            AS g18_1pct_incentive,
    et.g14_value                                AS g14_1pct_value,
    et.g14_incentive                            AS g14_1pct_incentive,
    et.polki_value                              AS polki_1pct_value,
    et.polki_incentive                          AS polki_1pct_incentive,

    et.total_taxable_value,
    et.sales_va_amount,
    et.taxable_value_cat_abc,
    ROUND(et.branded_pct, 2) AS taxable_value_cat_abc_percentage,
    et.taxable_value_cat_0,
    ROUND(et.taxable_value_cat_0 * 100.0 / NULLIF(et.total_taxable_value, 0), 2) AS taxable_value_cat_0_percentage,
    ROUND(et.category_incentive_total + et.type_incentive_total, 2) AS total_incentive,

    et.incentive_eligibility_percentage,

    -- Final payable incentive = total_incentive x incentive_eligibility_percentage.
    ROUND(
        (et.category_incentive_total + et.type_incentive_total) * et.incentive_eligibility_percentage / 100.0,
    2) AS final_incentive
FROM employee_eligibility et
JOIN employee e ON e.id = et.salesperson_employee_id
JOIN app_user au ON au.id = e.user_id
LEFT JOIN user_branch ub
    ON ub.user_id = au.id
    AND ub.end_time = '2100-01-01 00:00:00+00'
LEFT JOIN branch b ON b.id = ub.branch_id
ORDER BY employee_branch, employee_name;
