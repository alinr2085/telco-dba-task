-- TGT: allow ggapply to create its own checkpoint table (minimum needed)
SET LINESIZE 200 PAGESIZE 100
ALTER SESSION SET CONTAINER = FREEPDB1;
GRANT CREATE TABLE TO ggapply;
ALTER USER ggapply QUOTA 50M ON users;
PROMPT == check
SELECT privilege FROM dba_sys_privs WHERE grantee = 'GGAPPLY';
SELECT tablespace_name, max_bytes/1024/1024 AS quota_mb FROM dba_ts_quotas WHERE username = 'GGAPPLY';
