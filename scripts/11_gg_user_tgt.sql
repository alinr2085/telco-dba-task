-- TGT: least-privilege apply user (password comes from DEFINE gg_pwd, never stored here)
SET VERIFY OFF LINESIZE 200 PAGESIZE 100
ALTER SESSION SET CONTAINER = FREEPDB1;
CREATE USER ggapply IDENTIFIED BY "&gg_pwd" PROFILE app_profile;
GRANT CREATE SESSION TO ggapply;
GRANT OGG_APPLY TO ggapply;
GRANT SELECT, INSERT, UPDATE, DELETE ON telco.subscriber TO ggapply;
GRANT SELECT, INSERT, UPDATE, DELETE ON telco.cdr_usage  TO ggapply;
PROMPT == check
SELECT username, profile, account_status FROM dba_users WHERE username = 'GGAPPLY';
SELECT granted_role FROM dba_role_privs WHERE grantee = 'GGAPPLY';
SELECT table_name, privilege FROM dba_tab_privs WHERE grantee = 'GGAPPLY' ORDER BY 1, 2;
