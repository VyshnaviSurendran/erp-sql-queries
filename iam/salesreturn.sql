-- 1) Preview: who currently holds this designation
SELECT ud.user_id, up.policies
FROM user_designation ud
JOIN designation d ON d.id = ud.designation_id
LEFT JOIN user_policy up ON up.user_id = ud.user_id
WHERE d.designation_code = 'INA'
  AND ud.end_time = '2100-01-01 00:00:00+00';

-- 2) Add/update SalesReturn.List and Invoice.List policies for everyone currently in that designation
WITH new_policies AS (
    SELECT '[
        {"action": "SalesReturn.List", "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "Invoice.List",     "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null}
    ]'::jsonb AS policies
),
target_users AS (
    SELECT ud.user_id
    FROM user_designation ud
    JOIN designation d ON d.id = ud.designation_id
    WHERE d.designation_code = 'INA'
      AND ud.end_time = '2100-01-01 00:00:00+00'
)
INSERT INTO user_policy (user_id, policies, updated_by)
SELECT tu.user_id, np.policies, 1080
FROM target_users tu
CROSS JOIN new_policies np
ON CONFLICT (user_id) DO UPDATE
SET
    policies = user_policy.policies || (
        SELECT jsonb_agg(elem)
        FROM jsonb_array_elements(EXCLUDED.policies) elem
        WHERE elem ->> 'action' NOT IN (
            SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e
        )
    ),
    updated_at = now(),
    updated_by = EXCLUDED.updated_by
WHERE EXISTS (
    SELECT 1
    FROM jsonb_array_elements(EXCLUDED.policies) elem
    WHERE elem ->> 'action' NOT IN (
        SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e
    )
);

-- 3) Verify
SELECT up.*
FROM user_policy up
JOIN user_designation ud ON ud.user_id = up.user_id AND ud.end_time = '2100-01-01 00:00:00+00'
JOIN designation d ON d.id = ud.designation_id
WHERE d.designation_code = 'INA';