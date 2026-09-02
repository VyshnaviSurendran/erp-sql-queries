-----------------------------------add application access to SHH, SAE, STE----------------------------------------------------------------------
INSERT INTO user_application (user_id, application_id)
SELECT au.id, a.id
FROM app_user au
JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
JOIN designation d ON d.id = ud.designation_id
CROSS JOIN application a
WHERE d.designation_code IN ('SAE', 'STE')
  AND a.id IN (15, 18)
ON CONFLICT (user_id, application_id) DO NOTHING;

INSERT INTO user_application (user_id, application_id)
SELECT au.id, a.id
FROM app_user au
JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
JOIN designation d ON d.id = ud.designation_id
CROSS JOIN application a
WHERE d.designation_code = 'SHH'
  AND a.id IN (2, 18)
ON CONFLICT (user_id, application_id) DO NOTHING;
-----------------------------------delete application access other than visit, one and scheme to SHH, SAE, STE----------------------------------------------------------------------
DELETE FROM user_application ua
USING app_user au,
      user_designation ud,
      designation d
WHERE ua.user_id = au.id
  AND ud.user_id = au.id
  AND ud.end_time = '2100-01-01 00:00:00+00'
  AND d.id = ud.designation_id
  AND d.designation_code IN ('SAE', 'STE', 'SHH')
  AND NOT (
        (d.designation_code IN ('SAE', 'STE') AND ua.application_id IN (15, 18))
        OR (d.designation_code = 'SHH' AND ua.application_id IN (2, 18))
  );
-----------------------------------preview application access other than visit, one and scheme to SHH, SAE, STE----------------------------------------------------------------------
SELECT
    au.user_code                              AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)  AS employee_name,
    d.designation_code,
    a.id                                       AS application_id,
    a.name                                     AS application_name
FROM user_application ua
JOIN app_user au ON au.id = ua.user_id
JOIN user_designation ud ON ud.user_id = au.id AND ud.end_time = '2100-01-01 00:00:00+00'
JOIN designation d ON d.id = ud.designation_id
JOIN application a ON a.id = ua.application_id
WHERE d.designation_code IN ('SAE', 'STE', 'SHH')
  AND NOT (
        (d.designation_code IN ('SAE', 'STE') AND ua.application_id IN (15, 18))
        OR (d.designation_code = 'SHH' AND ua.application_id IN (2, 18))
  )
ORDER BY employee_name, application_name;
-----------------------------------display all user and their application access----------------------------------------------------------------------
WITH target_employees AS (
    SELECT DISTINCT ud.user_id, d.id AS designation_id, d.designation_code, d.designation_name
    FROM user_designation ud
    JOIN designation d ON d.id = ud.designation_id
    WHERE d.designation_code IN ('SAE', 'STE', 'SHH')
      AND ud.end_time = '2100-01-01 00:00:00+00'
)

SELECT
    au.user_code                              AS employee_code,
    CONCAT(au.first_name, ' ', au.last_name)  AS employee_name,
    te.designation_code,
    te.designation_name,
    a.id                                       AS application_id,
    a.name                                     AS application_name
FROM target_employees te
JOIN app_user au ON au.id = te.user_id
JOIN user_application ua ON ua.user_id = au.id
JOIN application a ON a.id = ua.application_id
ORDER BY employee_name, application_name;