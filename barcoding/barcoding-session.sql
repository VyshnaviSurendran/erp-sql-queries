SELECT
    df.id AS draft_id,
    df.created_at,
    bli.id AS barcoding_line_item_id,
    blit.is_done_at AS employee_task_done_at,
    au.id AS user_id,
    au.first_name
FROM draft_form df
JOIN barcoding_line_item_draft_form blidf ON blidf.draft_form_id = df.id
JOIN barcoding_line_item bli ON bli.id = blidf.barcode_line_item_id
JOIN barcoding_line_item_task blit ON blit.barcoding_line_item_id = bli.id
JOIN employee e ON e.id = blit.employee_id
JOIN app_user au ON au.id = e.user_id
WHERE df.form_type = 'BARCODE'
  AND au.id = 3911
  AND blit.is_done_at IS NULL
ORDER BY df.created_at DESC;
--------------------------------ots only barcode session of user 3911------------------------------------------------------------------
SELECT
    df.id AS draft_id,
    df.created_at,
    bli.id AS barcoding_line_item_id,
    blit.is_done_at AS employee_task_done_at,
    au.id AS user_id,
    au.first_name
FROM draft_form df
JOIN barcoding_line_item_draft_form blidf ON blidf.draft_form_id = df.id
JOIN barcoding_line_item bli ON bli.id = blidf.barcode_line_item_id
JOIN barcoding_line_item_task blit ON blit.barcoding_line_item_id = bli.id
JOIN employee e ON e.id = blit.employee_id
JOIN app_user au ON au.id = e.user_id
WHERE df.form_type = 'BARCODE'
  AND au.id = 3911
  AND blit.is_done_at IS NULL
ORDER BY df.created_at DESC;
