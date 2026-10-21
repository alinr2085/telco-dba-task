-- SRC: least-privilege capture user (password comes from DEFINE gg_pwd, never stored here)
SET VERIFY OFF LINESIZE 200 PAGESIZE 100
ALTER SESSION SET CONTAINER = FREEPDB1;
CREATE USER ggcapture IDENTIFIED BY "&gg_pwd" PROFILE app_profile;
GRANT CREATE SESSION TO ggcapture;
GRANT OGG_CAPTURE TO ggcapture;
PROMPT == check
SELECT username, profile, account_status FROM dba_users WHERE username = 'GGCAPTURE';
SELECT granted_role FROM dba_role_privs WHERE grantee = 'GGCAPTURE';
