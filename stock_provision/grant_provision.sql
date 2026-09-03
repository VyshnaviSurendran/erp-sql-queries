-----------------------------------grant provision SAM current branch----------------------------------------------------------------------
WITH new_policies AS (
    SELECT '[
        {"action": "Provision.List", "effect": "allow", "context": {"location": ["${current_location}"], "region": null}, "expires_at": null}
    ]'::jsonb AS policies
),
target_users AS (
    SELECT user_id FROM user_designation
    WHERE designation_id = 71 AND end_time = '2100-01-01 00:00:00+00'
)
INSERT INTO user_policy (user_id, policies, updated_by)
SELECT tu.user_id, np.policies, 1080
FROM target_users tu CROSS JOIN new_policies np
ON CONFLICT (user_id) DO UPDATE
SET policies = user_policy.policies || (
        SELECT jsonb_agg(elem) FROM jsonb_array_elements(EXCLUDED.policies) elem
        WHERE elem ->> 'action' NOT IN (SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e)
    ),
    updated_at = now(), updated_by = EXCLUDED.updated_by
WHERE EXISTS (
    SELECT 1 FROM jsonb_array_elements(EXCLUDED.policies) elem
    WHERE elem ->> 'action' NOT IN (SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e)
);

-----------------------------------preview provision policies designation SAM----------------------------------------------------------------------
SELECT ud.user_id, up.policies
FROM user_designation ud
LEFT JOIN user_policy up ON up.user_id = ud.user_id
WHERE ud.designation_id = 71
  AND ud.end_time = '2100-01-01 00:00:00+00';

-----------------------------------grant policy based on user id----------------------------------------------------------------------
-- 1) Preview
SELECT user_id, policies FROM user_policy WHERE user_id = 378;

-- 2) Add/update provision policies, unscoped (all branches)
WITH new_policies AS (
    SELECT '[
        {"action": "Provision.Create",     "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "Provision.Read",       "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "Provision.Update",     "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "Provision.List",       "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "ProvisionReport.List", "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null}
    ]'::jsonb AS policies
)
INSERT INTO user_policy (user_id, policies, updated_by)
SELECT 2691, np.policies, 1080
FROM new_policies np
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
SELECT * FROM user_policy WHERE user_id = 2691;

-----------------------------------grant policy based on designation----------------------------------------------------------------------
-- 1) Preview: who currently holds this designation
SELECT ud.user_id, up.policies
FROM user_designation ud
JOIN designation d ON d.id = ud.designation_id
LEFT JOIN user_policy up ON up.user_id = ud.user_id
WHERE d.designation_code = 'SALES_MGR'   -- swap in the real designation_code
  AND ud.end_time = '2100-01-01 00:00:00+00';

-- 2) Add/update provision policies for everyone currently in that designation
WITH new_policies AS (
    SELECT '[
        {"action": "Provision.Create",     "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "Provision.Read",       "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "Provision.Update",     "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "Provision.List",       "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null},
        {"action": "ProvisionReport.List", "effect": "allow", "context": {"location": null, "region": null}, "expires_at": null}
    ]'::jsonb AS policies
),
target_users AS (
    SELECT ud.user_id
    FROM user_designation ud
    JOIN designation d ON d.id = ud.designation_id
    WHERE d.designation_code = 'SALES_MGR'   -- swap in the real designation_code
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
WHERE d.designation_code = 'SALES_MGR';

-----------------------------------grant policy based on user id----------------------------------------------------------------------
WITH new_policies AS (
    SELECT '[
        {
            "action": "CustomerCollectionDue.List",
            "effect": "allow",
            "context": {"location": null, "region": null},
            "expires_at": null
        },
        {
            "action": "CustomerPaymentDue.List",
            "effect": "allow",
            "context": {"location": null, "region": null},
            "expires_at": null
        }
    ]'::jsonb AS policies
)
INSERT INTO user_policy (user_id, policies, updated_by)
SELECT 3692, np.policies, 1080
FROM new_policies np
ON CONFLICT (user_id) DO UPDATE
SET
    policies = user_policy.policies || (
        SELECT jsonb_agg(elem)
        FROM jsonb_array_elements((SELECT policies FROM new_policies)) elem
        WHERE elem ->> 'action' NOT IN (
            SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e
        )
    ),
    updated_at = now(),
    updated_by = EXCLUDED.updated_by
WHERE EXISTS (
    SELECT 1
    FROM jsonb_array_elements((SELECT policies FROM new_policies)) elem
    WHERE elem ->> 'action' NOT IN (
        SELECT e ->> 'action' FROM jsonb_array_elements(user_policy.policies) e
    )
);
