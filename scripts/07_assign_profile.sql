-- Run as SYS on SRC after the workload users exist and after the AWR measurements.
ALTER SESSION SET CONTAINER = FREEPDB1;
SET LINESIZE 200 PAGESIZE 100
PROMPT == profile exists?
SELECT DISTINCT profile FROM dba_profiles WHERE profile = 'APP_PROFILE';
PROMPT == assign
ALTER USER telco_app  PROFILE app_profile;
ALTER USER telco_load PROFILE app_profile;
PROMPT == result
SELECT username, profile, account_status FROM dba_users
 WHERE username IN ('TELCO_APP','TELCO_LOAD') ORDER BY username;
