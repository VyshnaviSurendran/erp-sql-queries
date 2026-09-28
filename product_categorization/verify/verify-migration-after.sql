DROP TABLE IF EXISTS enum_now;
CREATE TEMP TABLE enum_now AS
SELECT e.id, pa.attribute_code, e.value, e.product_attribute_enum_value_code AS code, e.is_enabled
FROM product_attribute_enum_value e
JOIN product_attribute pa ON pa.id = e.product_attribute_id;
CREATE INDEX ON enum_now (id);

DROP TABLE IF EXISTS product_now;
CREATE TEMP TABLE product_now AS
SELECT
    p.id,
    p.product_name,
    MAX(CASE WHEN pa.attribute_code = 'CTY' THEN pav.product_attribute_enum_value_id END) AS cty_id,
    MAX(CASE WHEN pa.attribute_code = 'TYP' THEN pav.product_attribute_enum_value_id END) AS typ_id,
    MAX(CASE WHEN pa.attribute_code = 'COL' THEN pav.product_attribute_enum_value_id END) AS col_id,
    MAX(CASE WHEN pa.attribute_code = 'STL' THEN pav.product_attribute_enum_value_id END) AS stl_id
FROM product p
LEFT JOIN product_attribute_value pav ON pav.product_id = p.id
LEFT JOIN product_attribute pa ON pa.id = pav.attribute_id
GROUP BY p.id;
CREATE INDEX ON product_now (id);

-- ----------------------------------------------------------------------------
-- Products: expected attributes and name, from the before-state + rules.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS product_check;
CREATE TEMP TABLE product_check AS
WITH base AS (
    SELECT
        b.id, b.is_unsold, b.product_name AS name_before,
        b.cty_id AS cty_b, b.typ_id AS typ_b, b.col_id AS col_b, b.stl_id AS stl_b,
        n.id IS NOT NULL AS still_exists, n.product_name AS name_now,
        n.cty_id AS cty_n, n.typ_id AS typ_n, n.col_id AS col_n, n.stl_id AS stl_n,
        r.sheet_row, r.new_category, r.new_collection, r.new_style,
        -- codes of the BEFORE values: as they were, and as they are now
        -- (differs only where the spell-fix renamed a code)
        ebc.code AS col_code_was, enc.code AS col_code_now,
        ebs.code AS stl_code_was, ens.code AS stl_code_now,
        enc_cty.code AS cty_code_old, enc.code AS col_code_old, ens.code AS stl_code_old,
        -- codes of the values the product has NOW
        nn_cty.code AS cty_code_new, nn_col.code AS col_code_new, nn_stl.code AS stl_code_new,
        nn_cty.value AS cty_value_now, nn_col.value AS col_value_now, nn_stl.value AS stl_value_now
    FROM migration_check.product_before b
    LEFT JOIN product_now n ON n.id = b.id
    LEFT JOIN migration_check.enum_before e_cty ON e_cty.id = b.cty_id
    LEFT JOIN migration_check.enum_before e_typ ON e_typ.id = b.typ_id
    LEFT JOIN migration_check.enum_before e_col ON e_col.id = b.col_id
    LEFT JOIN migration_check.enum_before e_stl ON e_stl.id = b.stl_id
    LEFT JOIN migration_check.rules r
        ON LOWER(r.category) = LOWER(e_cty.value) AND LOWER(r.product_type) = LOWER(e_typ.value)
       AND LOWER(r.collection) = LOWER(e_col.value) AND LOWER(r.style) = LOWER(e_stl.value)
       AND (r.new_category IS NOT NULL OR r.new_collection IS NOT NULL OR r.new_style IS NOT NULL)
    LEFT JOIN migration_check.enum_before ebc ON ebc.id = b.col_id
    LEFT JOIN migration_check.enum_before ebs ON ebs.id = b.stl_id
    LEFT JOIN enum_now enc_cty ON enc_cty.id = b.cty_id
    LEFT JOIN enum_now enc ON enc.id = b.col_id
    LEFT JOIN enum_now ens ON ens.id = b.stl_id
    LEFT JOIN enum_now nn_cty ON nn_cty.id = n.cty_id
    LEFT JOIN enum_now nn_col ON nn_col.id = n.col_id
    LEFT JOIN enum_now nn_stl ON nn_stl.id = n.stl_id
),
-- 1) spell-fix code renames (unsold only): old code exactly once, new code not already present
spell_col AS (
    SELECT *, CASE WHEN is_unsold AND col_code_was <> col_code_now
                    AND (LENGTH(name_before) - LENGTH(REPLACE(name_before, col_code_was, ''))) / NULLIF(LENGTH(col_code_was), 0) = 1
                    AND POSITION(col_code_now IN name_before) = 0
                   THEN REPLACE(name_before, col_code_was, col_code_now) ELSE name_before END AS name_a1
    FROM base
),
spell_stl AS (
    SELECT *, CASE WHEN is_unsold AND stl_code_was <> stl_code_now
                    AND (LENGTH(name_a1) - LENGTH(REPLACE(name_a1, stl_code_was, ''))) / NULLIF(LENGTH(stl_code_was), 0) = 1
                    AND POSITION(stl_code_now IN name_a1) = 0
                   THEN REPLACE(name_a1, stl_code_was, stl_code_now) ELSE name_a1 END AS name_a
    FROM spell_col
),
-- 2) migration swaps (unsold + Excel rule): Category, Collection, Style, each once
mig_cty AS (
    SELECT *, CASE WHEN is_unsold AND sheet_row IS NOT NULL AND new_category IS NOT NULL AND cty_code_old <> cty_code_new
                    AND (LENGTH(name_a) - LENGTH(REPLACE(name_a, cty_code_old, ''))) / NULLIF(LENGTH(cty_code_old), 0) = 1
                   THEN REPLACE(name_a, cty_code_old, cty_code_new) ELSE name_a END AS name_b1
    FROM spell_stl
),
mig_col AS (
    SELECT *, CASE WHEN is_unsold AND sheet_row IS NOT NULL AND new_collection IS NOT NULL AND col_code_old <> col_code_new
                    AND (LENGTH(name_b1) - LENGTH(REPLACE(name_b1, col_code_old, ''))) / NULLIF(LENGTH(col_code_old), 0) = 1
                   THEN REPLACE(name_b1, col_code_old, col_code_new) ELSE name_b1 END AS name_b2
    FROM mig_cty
),
mig_stl AS (
    SELECT *, CASE WHEN is_unsold AND sheet_row IS NOT NULL AND new_style IS NOT NULL AND stl_code_old <> stl_code_new
                    AND (LENGTH(name_b2) - LENGTH(REPLACE(name_b2, stl_code_old, ''))) / NULLIF(LENGTH(stl_code_old), 0) = 1
                   THEN REPLACE(name_b2, stl_code_old, stl_code_new) ELSE name_b2 END AS expected_name
    FROM mig_col
)
SELECT
    id, is_unsold, sheet_row, name_before, expected_name, name_now,
    CASE
        WHEN NOT still_exists THEN 'BUG -- product no longer exists'
        WHEN NOT is_unsold AND (cty_n IS DISTINCT FROM cty_b OR typ_n IS DISTINCT FROM typ_b
                                OR col_n IS DISTINCT FROM col_b OR stl_n IS DISTINCT FROM stl_b
                                OR name_now <> name_before)
            THEN 'BUG -- SOLD product was changed'
        WHEN NOT is_unsold THEN 'OK -- sold, untouched'
        WHEN typ_n IS DISTINCT FROM typ_b THEN 'BUG -- unsold: product type changed'
        WHEN sheet_row IS NULL AND (cty_n IS DISTINCT FROM cty_b OR col_n IS DISTINCT FROM col_b OR stl_n IS DISTINCT FROM stl_b)
            THEN 'BUG -- unsold, not in the Excel: attributes changed'
        WHEN sheet_row IS NOT NULL AND (
                 (new_category IS NOT NULL AND LOWER(cty_value_now) IS DISTINCT FROM LOWER(new_category))
              OR (new_category IS NULL AND cty_n IS DISTINCT FROM cty_b)
              OR (new_collection IS NOT NULL AND LOWER(col_value_now) IS DISTINCT FROM LOWER(new_collection))
              OR (new_collection IS NULL AND col_n IS DISTINCT FROM col_b)
              OR (new_style IS NOT NULL AND LOWER(stl_value_now) IS DISTINCT FROM LOWER(new_style))
              OR (new_style IS NULL AND stl_n IS DISTINCT FROM stl_b))
            THEN 'BUG -- unsold: attributes not what the Excel says'
        WHEN name_now IS DISTINCT FROM expected_name THEN 'BUG -- unsold: product name wrong'
        WHEN sheet_row IS NOT NULL AND name_now <> name_before THEN 'OK -- unsold, corrected, name changed'
        WHEN sheet_row IS NOT NULL THEN 'OK -- unsold, corrected, name unchanged (code not in name exactly once)'
        WHEN name_now <> name_before THEN 'OK -- unsold, not in the Excel, name follows a spell-fix code rename'
        ELSE 'OK -- unsold, not in the Excel, untouched'
    END AS status
FROM mig_stl;

-- ----------------------------------------------------------------------------
-- Templates: expected code / enabled, from the before-state + rules.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS template_now;
CREATE TEMP TABLE template_now AS
SELECT
    pt.id, pt.product_template_code AS code, pt.is_enabled,
    MAX(CASE WHEN pa.attribute_code = 'CTY' THEN t.product_attribute_enum_value_id END) AS cty_id,
    MAX(CASE WHEN pa.attribute_code = 'TYP' THEN t.product_attribute_enum_value_id END) AS typ_id,
    MAX(CASE WHEN pa.attribute_code = 'COL' THEN t.product_attribute_enum_value_id END) AS col_id,
    MAX(CASE WHEN pa.attribute_code = 'STL' THEN t.product_attribute_enum_value_id END) AS stl_id,
    MAX(CASE WHEN pa.attribute_code = 'SPC' THEN t.product_attribute_enum_value_id END) AS spc_id,
    COUNT(t.id) AS attr_count
FROM product_template pt
LEFT JOIN product_template_attribute_value t ON t.product_template_id = pt.id
LEFT JOIN product_attribute pa ON pa.id = t.product_attribute_id
GROUP BY pt.id;

DROP TABLE IF EXISTS template_expect;
CREATE TEMP TABLE template_expect AS
WITH base AS (
    SELECT
        b.id, b.code AS code_before, b.is_enabled AS enabled_before, b.attr_count AS attrs_before,
        n.id IS NOT NULL AS still_exists, n.code AS code_now, n.is_enabled AS enabled_now, n.attr_count AS attrs_now,
        b.cty_id AS cty_b, b.col_id AS col_b, b.stl_id AS stl_b, b.typ_id AS typ_b, b.spc_id AS spc_b,
        n.cty_id AS cty_n, n.col_id AS col_n, n.stl_id AS stl_n, n.typ_id AS typ_n, n.spc_id AS spc_n,
        r.sheet_row, r.new_category, r.new_collection, r.new_style,
        ebc.code AS col_code_was, enc.code AS col_code_now_same_value,
        ebs.code AS stl_code_was, ens.code AS stl_code_now_same_value,
        LOWER(COALESCE(v_cty.value, '')) || '|' || LOWER(COALESCE(v_typ.value, '')) || '|' || LOWER(COALESCE(v_col.value, ''))
            || '|' || LOWER(COALESCE(v_stl.value, '')) || '|' || LOWER(COALESCE(v_spc.value, '')) AS combo_now,
        'A' || UPPER(COALESCE(v_typ.code, '') || COALESCE(v_cty.code, '') || COALESCE(v_col.code, '')
                     || COALESCE(v_stl.code, '') || COALESCE(v_spc.code, '')) AS formula_now,
        v_cty.value AS cty_value_now, v_col.value AS col_value_now, v_stl.value AS stl_value_now
    FROM migration_check.template_before b
    LEFT JOIN template_now n ON n.id = b.id
    LEFT JOIN migration_check.enum_before e_cty ON e_cty.id = b.cty_id
    LEFT JOIN migration_check.enum_before e_typ ON e_typ.id = b.typ_id
    LEFT JOIN migration_check.enum_before e_col ON e_col.id = b.col_id
    LEFT JOIN migration_check.enum_before e_stl ON e_stl.id = b.stl_id
    LEFT JOIN migration_check.rules r
        ON LOWER(r.category) = LOWER(e_cty.value) AND LOWER(r.product_type) = LOWER(e_typ.value)
       AND LOWER(r.collection) = LOWER(e_col.value) AND LOWER(r.style) = LOWER(e_stl.value)
       AND (r.new_category IS NOT NULL OR r.new_collection IS NOT NULL OR r.new_style IS NOT NULL)
    LEFT JOIN migration_check.enum_before ebc ON ebc.id = b.col_id
    LEFT JOIN migration_check.enum_before ebs ON ebs.id = b.stl_id
    LEFT JOIN enum_now enc ON enc.id = b.col_id
    LEFT JOIN enum_now ens ON ens.id = b.stl_id
    LEFT JOIN enum_now v_cty ON v_cty.id = n.cty_id
    LEFT JOIN enum_now v_typ ON v_typ.id = n.typ_id
    LEFT JOIN enum_now v_col ON v_col.id = n.col_id
    LEFT JOIN enum_now v_stl ON v_stl.id = n.stl_id
    LEFT JOIN enum_now v_spc ON v_spc.id = n.spc_id
),
-- spell-fix code renames on the template code (Collection, then Style)
spell AS (
    SELECT *, CASE WHEN col_code_was <> col_code_now_same_value
                    AND (LENGTH(code_before) - LENGTH(REPLACE(code_before, col_code_was, ''))) / NULLIF(LENGTH(col_code_was), 0) = 1
                    AND POSITION(col_code_now_same_value IN code_before) = 0
                   THEN REPLACE(code_before, col_code_was, col_code_now_same_value) ELSE code_before END AS code_a1
    FROM base
),
spell2 AS (
    SELECT *, CASE WHEN stl_code_was <> stl_code_now_same_value
                    AND (LENGTH(code_a1) - LENGTH(REPLACE(code_a1, stl_code_was, ''))) / NULLIF(LENGTH(stl_code_was), 0) = 1
                    AND POSITION(stl_code_now_same_value IN code_a1) = 0
                   THEN REPLACE(code_a1, stl_code_was, stl_code_now_same_value) ELSE code_a1 END AS code_a
    FROM spell
)
SELECT * FROM spell2;

-- a spell-fix rename is skipped if another template already holds the result
UPDATE template_expect t SET code_a = t.code_before
WHERE t.code_a <> t.code_before
  AND EXISTS (SELECT 1 FROM template_expect o WHERE o.id <> t.id AND o.code_before = t.code_a);

-- groups of identical corrected combinations that contain a corrected template
DROP TABLE IF EXISTS template_canonical;
CREATE TEMP TABLE template_canonical AS
SELECT DISTINCT ON (combo_now) combo_now, id AS canonical_id, formula_now
FROM template_expect
WHERE attrs_now > 0
  AND combo_now IN (SELECT combo_now FROM template_expect WHERE sheet_row IS NOT NULL)
ORDER BY combo_now, enabled_before DESC, (code_a = formula_now) DESC, id;

DROP TABLE IF EXISTS template_check;
CREATE TEMP TABLE template_check AS
SELECT
    t.id, t.sheet_row, t.code_before, t.code_now, t.enabled_before, t.enabled_now,
    CASE WHEN c.canonical_id = t.id AND NOT EXISTS (SELECT 1 FROM template_expect o WHERE o.id <> t.id AND o.code_a = t.formula_now)
         THEN t.formula_now ELSE t.code_a END AS expected_code,
    CASE WHEN c.canonical_id = t.id AND NOT EXISTS (SELECT 1 FROM template_expect o WHERE o.id <> t.id AND o.code_a = t.formula_now)
         THEN true ELSE t.enabled_before END AS expected_enabled,
    CASE
        WHEN NOT t.still_exists THEN 'BUG -- template no longer exists'
        WHEN t.attrs_before = 0 AND t.attrs_now > 0 THEN 'INFO -- had no attributes before, now has ' || t.attrs_now
        WHEN t.typ_n IS DISTINCT FROM t.typ_b OR t.spc_n IS DISTINCT FROM t.spc_b THEN 'BUG -- type or spec changed'
        WHEN t.sheet_row IS NULL AND (t.cty_n IS DISTINCT FROM t.cty_b OR t.col_n IS DISTINCT FROM t.col_b OR t.stl_n IS DISTINCT FROM t.stl_b)
            THEN 'BUG -- not in the Excel: attributes changed'
        WHEN t.sheet_row IS NOT NULL AND (
                 (t.new_category IS NOT NULL AND LOWER(t.cty_value_now) IS DISTINCT FROM LOWER(t.new_category))
              OR (t.new_category IS NULL AND t.cty_n IS DISTINCT FROM t.cty_b)
              OR (t.new_collection IS NOT NULL AND LOWER(t.col_value_now) IS DISTINCT FROM LOWER(t.new_collection))
              OR (t.new_collection IS NULL AND t.col_n IS DISTINCT FROM t.col_b)
              OR (t.new_style IS NOT NULL AND LOWER(t.stl_value_now) IS DISTINCT FROM LOWER(t.new_style))
              OR (t.new_style IS NULL AND t.stl_n IS DISTINCT FROM t.stl_b))
            THEN 'BUG -- attributes not what the Excel says'
        ELSE NULL
    END AS attr_status,
    c.canonical_id,
    (c.canonical_id = t.id) AS is_canonical
FROM template_expect t
LEFT JOIN template_canonical c ON c.combo_now = t.combo_now;

ALTER TABLE template_check ADD COLUMN status text;
UPDATE template_check SET status = CASE
    WHEN attr_status LIKE 'BUG%' THEN attr_status
    WHEN code_now IS DISTINCT FROM expected_code OR enabled_now IS DISTINCT FROM expected_enabled THEN
        CASE WHEN is_canonical THEN 'BUG -- canonical: code/enabled not as expected'
             WHEN canonical_id IS NOT NULL THEN 'BUG -- duplicate of a canonical: was changed'
             ELSE 'BUG -- not in a corrected group: code/enabled changed' END
    WHEN attr_status IS NOT NULL THEN attr_status
    WHEN is_canonical AND code_now <> code_before AND NOT enabled_before THEN 'OK -- canonical: recoded + enabled'
    WHEN is_canonical AND code_now <> code_before THEN 'OK -- canonical: recoded'
    WHEN is_canonical AND NOT enabled_before THEN 'OK -- canonical: enabled'
    WHEN is_canonical THEN 'OK -- canonical: already correct'
    WHEN canonical_id IS NOT NULL THEN 'OK -- duplicate of a canonical, left as it was'
    WHEN code_now <> code_before THEN 'OK -- code follows a spell-fix code rename'
    ELSE 'OK -- untouched'
END;

-- ----------------------------------------------------------------------------
-- SUMMARY -- every BUG row must be 0. OK / INFO rows are counts for review.
-- ----------------------------------------------------------------------------
SELECT area, status, COUNT(*) AS rows
FROM (
    SELECT 'product' AS area, status FROM product_check
    UNION ALL
    SELECT 'template', status FROM template_check
    UNION ALL
    SELECT 'attribute value', 'BUG -- value deleted' FROM migration_check.enum_before b
    WHERE NOT EXISTS (SELECT 1 FROM enum_now n WHERE n.id = b.id)
    UNION ALL
    SELECT 'attribute value', CASE WHEN b.is_enabled IS DISTINCT FROM false
                                   THEN 'BUG -- disabled by the migration but still used'
                                   ELSE 'INFO -- was already disabled before, still used (old data)' END
    FROM enum_now n LEFT JOIN migration_check.enum_before b ON b.id = n.id
    WHERE NOT n.is_enabled
      AND (EXISTS (SELECT 1 FROM product_attribute_value pav WHERE pav.product_attribute_enum_value_id = n.id)
        OR EXISTS (SELECT 1 FROM product_template_attribute_value t WHERE t.product_attribute_enum_value_id = n.id))
    UNION ALL
    SELECT 'attribute value', CASE
        WHEN b.id IS NULL THEN 'INFO -- added'
        WHEN b.value <> n.value THEN 'INFO -- renamed'
        WHEN b.code <> n.code THEN 'INFO -- code changed'
        WHEN b.is_enabled AND NOT n.is_enabled THEN 'INFO -- disabled (unused)'
        WHEN NOT b.is_enabled AND n.is_enabled THEN 'INFO -- enabled'
    END
    FROM enum_now n LEFT JOIN migration_check.enum_before b ON b.id = n.id
    WHERE b.id IS NULL OR b.value <> n.value OR b.code <> n.code OR b.is_enabled <> n.is_enabled
    UNION ALL
    SELECT 'hierarchy', 'BUG -- edge on a disabled value'
    FROM product_attribute_enum_hierarchy h
    JOIN enum_now c ON c.id = h.product_attribute_enum_value_id
    JOIN enum_now p ON p.id = h.parent_product_attribute_enum_value_id
    WHERE NOT c.is_enabled OR NOT p.is_enabled
    UNION ALL
    SELECT 'hierarchy', 'BUG -- condition table is empty'
    WHERE NOT EXISTS (SELECT 1 FROM product_attribute_hierarchy_condition)
    UNION ALL
    -- a migration run left open (e.g. pgAdmin with auto-commit off): its
    -- changes are invisible here, so every result above would be wrong
    SELECT 'database', 'BUG -- uncommitted changes in session pid ' || a.pid || ' (' || COALESCE(NULLIF(a.application_name, ''), '?')
                       || '): run COMMIT there, then rerun this check'
    FROM pg_stat_activity a
    WHERE a.datname = current_database() AND a.pid <> pg_backend_pid()
      AND a.state LIKE 'idle in transaction%' AND a.xact_start < now() - interval '1 minute'
      AND EXISTS (SELECT 1 FROM pg_locks l JOIN pg_class c ON c.oid = l.relation
                  WHERE l.pid = a.pid AND l.mode = 'RowExclusiveLock'
                    AND c.relname IN ('product', 'product_template', 'product_attribute_value',
                                      'product_template_attribute_value', 'product_attribute_enum_value',
                                      'product_attribute_enum_hierarchy', 'product_attribute_hierarchy_condition'))
) x
GROUP BY area, status
ORDER BY area, status LIKE 'BUG%' DESC, status;

-- ----------------------------------------------------------------------------
-- DETAIL -- the BUG rows themselves (first 200), to investigate.
-- ----------------------------------------------------------------------------
SELECT 'product' AS area, id, status, name_before AS was, expected_name AS expected, name_now AS now
FROM product_check WHERE status LIKE 'BUG%'
UNION ALL
SELECT 'template', id, status,
       code_before || ' / enabled=' || enabled_before,
       expected_code || ' / enabled=' || expected_enabled,
       code_now || ' / enabled=' || enabled_now
FROM template_check WHERE status LIKE 'BUG%'
ORDER BY 1, 3, 2
LIMIT 200;
