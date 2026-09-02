-----------------------------------check a users sales incentive details----------------------------------------------------------------------
WITH collection_category_rate (collection_code, category, rate_per_gram) AS (
    VALUES
        ('769', 'GOLD CAT A', 10), ('778', 'GOLD CAT A', 10), ('459', 'GOLD CAT A', 10),
        ('709', 'GOLD CAT A', 10), ('475', 'GOLD CAT A', 10), ('821', 'GOLD CAT A', 10),
        ('523', 'GOLD CAT A', 10), ('452', 'GOLD CAT A', 10), ('159', 'GOLD CAT A', 10),
        ('824', 'GOLD CAT A', 10), ('451', 'GOLD CAT A', 10), ('107', 'GOLD CAT A', 10),
        ('986', 'GOLD CAT A', 10), ('348', 'GOLD CAT A', 10), ('859', 'GOLD CAT A', 10),
        ('103', 'GOLD CAT A', 10),
        ('657', 'GOLD CAT B', 20), ('160', 'GOLD CAT B', 20),
        ('773', 'GOLD CAT B', 20), ('597', 'GOLD CAT B', 20),
        ('415', 'GOLD CAT C', 30), ('308', 'GOLD CAT C', 30),
        ('105', 'GOLD CAT C', 30), ('167', 'GOLD CAT C', 30)
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
        ili.created_at AS line_item_created_at
    FROM invoice_line_item ili
    JOIN invoice i ON i.id = ili.invoice_id
    JOIN invoice_status ist
        ON ist.invoice_id = i.id
        AND ist.end_time = '2100-01-01 00:00:00+00'
        AND ist.status <> 'CANCELLED'
    WHERE i.created_at >= '2026-08-01'   -- period start, edit as needed
      AND i.created_at <  '2026-09-01'   -- period end, edit as needed
)
SELECT
    au.user_code                                AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)    AS employee_name,
    sli.invoice_code,
    sli.invoice_date::date                      AS invoice_date,
    p.product_code,
    p.product_name,
    enum_col.product_attribute_enum_value_code  AS collection_code,
    enum_col.value                              AS collection_name,
    COALESCE(ccr.category, 'GOLD CAT 0')        AS category,
    enum_typ.product_attribute_enum_value_code  AS type_code,
    enum_typ.value                              AS type_name,
    sli.product_value                           AS taxable_value,
    COALESCE(w.net_weight, 0)                   AS net_weight_gm,
    ROUND(COALESCE(w.net_weight, 0) * COALESCE(ccr.rate_per_gram, 0), 2) AS category_incentive,
    ROUND(sli.product_value * COALESCE(tr.rate_percent, 0) / 100.0, 2)  AS type_incentive
FROM sold_line_items sli
JOIN employee e ON e.id = sli.salesperson_employee_id
JOIN app_user au ON au.id = e.user_id
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
WHERE au.user_code = '3098'   -- <-- set the salesperson's employee_code here
ORDER BY sli.product_value ASC;

-----------------------------------incentive details with eligibility----------------------------------------------------------------------
WITH collection_category_rate (collection_code, category, rate_per_gram) AS (
    VALUES
        ('769', 'GOLD CAT A', 10), ('778', 'GOLD CAT A', 10), ('459', 'GOLD CAT A', 10),
        ('709', 'GOLD CAT A', 10), ('475', 'GOLD CAT A', 10), ('821', 'GOLD CAT A', 10),
        ('523', 'GOLD CAT A', 10), ('452', 'GOLD CAT A', 10), ('159', 'GOLD CAT A', 10),
        ('824', 'GOLD CAT A', 10), ('451', 'GOLD CAT A', 10), ('107', 'GOLD CAT A', 10),
        ('986', 'GOLD CAT A', 10), ('348', 'GOLD CAT A', 10), ('859', 'GOLD CAT A', 10),
        ('103', 'GOLD CAT A', 10),
        ('657', 'GOLD CAT B', 20), ('160', 'GOLD CAT B', 20),
        ('773', 'GOLD CAT B', 20), ('597', 'GOLD CAT B', 20),
        ('415', 'GOLD CAT C', 30), ('308', 'GOLD CAT C', 30),
        ('105', 'GOLD CAT C', 30), ('167', 'GOLD CAT C', 30)
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
        i.salesperson_employee_id,
        ili.product_id,
        ili.product_value,
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
        COALESCE(ccr.category, 'GOLD CAT 0') AS category,
        COALESCE(w.net_weight, 0) AS net_weight,
        ROUND(COALESCE(w.net_weight, 0) * COALESCE(ccr.rate_per_gram, 0), 2) AS category_incentive,
        enum_typ.product_attribute_enum_value_code AS type_code,
        ROUND(sli.product_value * COALESCE(tr.rate_percent, 0) / 100.0, 2) AS type_incentive
    FROM sold_line_items sli
    -- Collection (COL) lookup -> category A/B/C, else GOLD CAT 0 / rate 0.
    -- LEFT JOIN so unmatched items are kept, not dropped.
    LEFT JOIN product_attribute_value pav_col
        ON pav_col.product_id = sli.product_id
        AND pav_col.attribute_id = (SELECT id FROM product_attribute WHERE attribute_code = 'COL')
    LEFT JOIN product_attribute_enum_value enum_col
        ON enum_col.id = pav_col.product_attribute_enum_value_id
    LEFT JOIN collection_category_rate ccr
        ON ccr.collection_code = enum_col.product_attribute_enum_value_code
    -- Type (TYP) lookup -> Diamond/Platinum/Uncut/Precious/18k/14k/Polki, else no match
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
