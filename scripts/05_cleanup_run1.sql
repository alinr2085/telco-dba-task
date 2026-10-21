ALTER SESSION SET CONTAINER = FREEPDB1;
SET PAGESIZE 100 LINESIZE 200
PROMPT == BEFORE cleanup: row counts and partitions
SELECT COUNT(*) subscriber_rows FROM telco.subscriber;
SELECT COUNT(*) cdr_rows FROM telco.cdr_usage;
SELECT COUNT(*) cdr_partitions FROM dba_tab_partitions WHERE table_owner='TELCO' AND table_name='CDR_USAGE';
PROMPT == workload jobs still present (expect none running)
SELECT owner, job_name, state FROM dba_scheduler_jobs WHERE owner IN ('TELCO_LOAD','TELCO_APP');
PROMPT == cleanup (README steps)
DROP USER telco_load CASCADE;
DROP USER telco_app CASCADE;
DROP SEQUENCE telco.cdr_seq;
TRUNCATE TABLE telco.cdr_usage;
TRUNCATE TABLE telco.subscriber;
PROMPT == AFTER cleanup (expect zeros)
SELECT COUNT(*) subscriber_rows FROM telco.subscriber;
SELECT COUNT(*) cdr_rows FROM telco.cdr_usage;
SELECT COUNT(*) users_left FROM dba_users WHERE username IN ('TELCO_LOAD','TELCO_APP');
