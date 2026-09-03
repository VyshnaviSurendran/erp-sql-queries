-- Duplicate app_user + copy current designation/branch/application/payroll access
DO $$
DECLARE
    src_user_id    integer := 1080;              -- <-- source user id to copy from
    new_user_id    integer;
    new_user_code  text    := 'EMP-3805';        -- <-- must be unique (app_user_user_code_key)
    new_phone      text    := '9999999999';      -- <-- provide a new phone (NOT NULL)
BEGIN
    -- 1. Duplicate the base app_user row
    INSERT INTO app_user (
        first_name, last_name, department, company_id,
        primary_address_id, gender, primary_phone, dob,
        user_code, email,
        direct_incentive_multplier_amount, indirect_incentive_multplier_amount,
        special_direct_incentive_multplier_amount, special_indirect_incentive_multplier_amount
    )
    SELECT
        first_name, last_name, department, company_id,
        primary_address_id, gender, new_phone, dob,
        new_user_code, NULL,
        direct_incentive_multplier_amount, indirect_incentive_multplier_amount,
        special_direct_incentive_multplier_amount, special_indirect_incentive_multplier_amount
    FROM app_user
    WHERE id = src_user_id
    RETURNING id INTO new_user_id;

    -- 2. Copy current active designation (end_time = '2100-01-01' marks "current")
    INSERT INTO user_designation (user_id, designation_id, start_time, end_time)
    SELECT new_user_id, designation_id, now(), end_time
    FROM user_designation
    WHERE user_id = src_user_id AND end_time = '2100-01-01 00:00:00+00';

    -- 3. Copy current active branch access
    INSERT INTO user_branch (user_id, branch_id, start_time, end_time)
    SELECT new_user_id, branch_id, now(), end_time
    FROM user_branch
    WHERE user_id = src_user_id AND end_time = '2100-01-01 00:00:00+00';

    -- 4. Copy application (module) access
    INSERT INTO user_application (user_id, application_id)
    SELECT new_user_id, application_id
    FROM user_application
    WHERE user_id = src_user_id;

    -- 5. Copy current active payroll location
    INSERT INTO user_payroll_location (user_id, location_id, start_time, end_time)
    SELECT new_user_id, location_id, now(), end_time
    FROM user_payroll_location
    WHERE user_id = src_user_id AND end_time = '2100-01-01 00:00:00+00';

    RAISE NOTICE 'New user id: %', new_user_id;

	-- 6. Copy user_policy
    INSERT INTO user_policy (user_id, policies, updated_by)
    SELECT new_user_id, policies, src_user_id
    FROM user_policy
    WHERE user_id = src_user_id;

	-- 7. Create login for the new user
    INSERT INTO user_login (user_id, username, password)
    VALUES (new_user_id, '3805', '$argon2d$v=19$m=12,t=3,p=1$bHNkandhZGZheDAwMDAwMA$T6oks+S4WyHUQ46svCSmqw');

END $$;
