-- workload_setup.sql  (candidate edition)
-- One script, one run. It asks for two passwords (hidden input), prepares the application
-- users, the sequence and the subscriber data, and then starts the vendor workload by itself:
-- 500 TPS, 16 sessions, 65 minutes.
--
-- Before running it, the schema TELCO with the tables SUBSCRIBER and CDR_USAGE must exist
-- (as described in the task sheet). SUBSCRIBER must be empty or already hold the data.
--
-- Run it once as SYS inside the PDB (not CDB$ROOT):
--   sqlplus sys@//<host>:1521/<pdb_service> as sysdba @workload_setup.sql
--
-- When the script returns, the workload is already running in the background
-- (DBMS_SCHEDULER jobs) and stops on its own after 65 minutes.
-- Running the script again while a workload is active does not start a second one.
-- Do not modify the vendor code. The application owner is TELCO_APP.

-- ---------------------------------------------------------------- settings
-- Passwords are asked at run time (input is hidden) and are not stored in this file.
-- Do not use double quotes or ampersands in a password.
-- If a user already exists its password is left unchanged and the value typed for it is ignored.
SET VERIFY OFF
ACCEPT app_pwd   CHAR PROMPT 'Password for the application user TELCO_APP: ' HIDE
ACCEPT load_pwd  CHAR PROMPT 'Password for the workload owner TELCO_LOAD: ' HIDE
-- Set to Y to drop and recreate TELCO_APP and TELCO_LOAD (the TELCO schema is never touched).
DEFINE reset_first = N
-- ------------------------------------------------------------------------

SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 150
SET PAGESIZE 100
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

PROMPT === Checking the environment
DECLARE
  l_cnt   NUMBER;
BEGIN
  IF SYS_CONTEXT('USERENV', 'CON_ID') = 1 THEN
    RAISE_APPLICATION_ERROR(-20001,
      'Connected to CDB$ROOT. Connect to the PDB and run this script again.');
  END IF;

  SELECT COUNT(*) INTO l_cnt FROM dba_tablespaces WHERE tablespace_name = 'USERS';
  IF l_cnt = 0 THEN
    RAISE_APPLICATION_ERROR(-20002,
      'Tablespace USERS does not exist. Edit this script to use an existing tablespace.');
  END IF;

  SELECT COUNT(*) INTO l_cnt FROM dba_users WHERE username = 'TELCO';
  IF l_cnt = 0 THEN
    RAISE_APPLICATION_ERROR(-20004, 'The schema TELCO does not exist. Create it first, as described in the task sheet.');
  END IF;

  FOR t IN (SELECT 'SUBSCRIBER' AS tab, 'SUBSCRIBER_ID,MSISDN,TARIFF_CODE,STATUS,CREATED_AT' AS cols FROM dual
            UNION ALL
            SELECT 'CDR_USAGE', 'CALL_ID,MSISDN,CELL_ID,CALL_START,DURATION_SEC,CHARGE_AMT' FROM dual) LOOP
    SELECT COUNT(*) INTO l_cnt FROM dba_tables WHERE owner = 'TELCO' AND table_name = t.tab;
    IF l_cnt = 0 THEN
      RAISE_APPLICATION_ERROR(-20005, 'The table TELCO.' || t.tab || ' does not exist. Create it first, as described in the task sheet.');
    END IF;
    FOR c IN (SELECT REGEXP_SUBSTR(t.cols, '[^,]+', 1, LEVEL) AS col FROM dual
              CONNECT BY REGEXP_SUBSTR(t.cols, '[^,]+', 1, LEVEL) IS NOT NULL) LOOP
      SELECT COUNT(*) INTO l_cnt FROM dba_tab_columns
       WHERE owner = 'TELCO' AND table_name = t.tab AND column_name = c.col;
      IF l_cnt = 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'The table TELCO.' || t.tab || ' has no column ' || c.col || '.');
      END IF;
    END LOOP;
  END LOOP;
END;
/

PROMPT === Application users
DECLARE
  PROCEDURE drop_user_if_exists(p_user IN VARCHAR2) IS
    l_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM dba_users WHERE username = p_user;
    IF l_cnt > 0 THEN
      EXECUTE IMMEDIATE 'DROP USER ' || p_user || ' CASCADE';
      DBMS_OUTPUT.PUT_LINE('User ' || p_user || ' dropped.');
    END IF;
  END drop_user_if_exists;

  PROCEDURE create_user_if_missing(p_user IN VARCHAR2, p_sql IN VARCHAR2) IS
    l_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM dba_users WHERE username = p_user;
    IF l_cnt = 0 THEN
      EXECUTE IMMEDIATE p_sql;
      DBMS_OUTPUT.PUT_LINE('User ' || p_user || ' created.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('User ' || p_user || ' already exists - password left unchanged.');
    END IF;
  END create_user_if_missing;
BEGIN
  IF UPPER('&reset_first') = 'Y' THEN
    drop_user_if_exists('TELCO_LOAD');
    drop_user_if_exists('TELCO_APP');
  END IF;

  create_user_if_missing('TELCO_APP',
    'CREATE USER telco_app IDENTIFIED BY "&app_pwd"');
  create_user_if_missing('TELCO_LOAD',
    'CREATE USER telco_load IDENTIFIED BY "&load_pwd" DEFAULT TABLESPACE users QUOTA 50M ON users');
END;
/

PROMPT === Sequence in TELCO
DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM dba_sequences WHERE sequence_owner = 'TELCO' AND sequence_name = 'CDR_SEQ';
  IF l_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE telco.cdr_seq START WITH 1 INCREMENT BY 1 CACHE 1000';
    DBMS_OUTPUT.PUT_LINE('Sequence TELCO.CDR_SEQ created.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Sequence TELCO.CDR_SEQ already exists - left unchanged.');
  END IF;
END;
/

PROMPT === Subscriber data
DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM telco.subscriber;
  IF l_cnt = 0 THEN
    INSERT /*+ APPEND */ INTO telco.subscriber
           (subscriber_id, msisdn, tariff_code, status, created_at)
    SELECT LEVEL,
           '98912' || LPAD(TO_CHAR(LEVEL), 7, '0'),
           CASE MOD(LEVEL, 4) WHEN 0 THEN 'PREPAID' WHEN 1 THEN 'POSTPAID'
                              WHEN 2 THEN 'DATA' ELSE 'CORP' END,
           CASE WHEN MOD(LEVEL, 50) = 0 THEN 'SUSPENDED' ELSE 'ACTIVE' END,
           TRUNC(SYSDATE) - MOD(LEVEL, 1000)
      FROM dual
   CONNECT BY LEVEL <= 200000;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUBSCRIBER loaded with 200000 rows.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('SUBSCRIBER already has ' || l_cnt || ' rows - left unchanged.');
  END IF;
  DBMS_STATS.GATHER_TABLE_STATS(ownname => 'TELCO', tabname => 'SUBSCRIBER');
END;
/

PROMPT === Privileges
-- TELCO_APP: application user
GRANT CREATE SESSION TO telco_app;
GRANT SELECT ON telco.subscriber TO telco_app;
GRANT SELECT, INSERT, UPDATE ON telco.cdr_usage TO telco_app;
GRANT SELECT ON telco.cdr_seq TO telco_app;

-- TELCO_LOAD: owner of the in-database workload package
GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE JOB TO telco_load;
GRANT SELECT ON telco.subscriber TO telco_load;
GRANT SELECT, INSERT, UPDATE ON telco.cdr_usage TO telco_load;
GRANT SELECT ON telco.cdr_seq TO telco_load;
GRANT SELECT ON sys.v_$parameter TO telco_load;

PROMPT === Control tables of the workload package (schema TELCO_LOAD)
DECLARE
  PROCEDURE create_table_if_missing(p_table IN VARCHAR2, p_ddl IN VARCHAR2) IS
    l_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM dba_tables WHERE owner = 'TELCO_LOAD' AND table_name = p_table;
    IF l_cnt = 0 THEN
      EXECUTE IMMEDIATE p_ddl;
      DBMS_OUTPUT.PUT_LINE('Table TELCO_LOAD.' || p_table || ' created.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('Table TELCO_LOAD.' || p_table || ' already exists - left unchanged.');
    END IF;
  END create_table_if_missing;
BEGIN
  DECLARE
    l_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM dba_sequences
     WHERE sequence_owner = 'TELCO_LOAD' AND sequence_name = 'WORKLOAD_RUN_SEQ';
    IF l_cnt = 0 THEN
      EXECUTE IMMEDIATE
        'CREATE SEQUENCE telco_load.workload_run_seq START WITH 1 INCREMENT BY 1 NOCACHE';
    END IF;
  END;

  create_table_if_missing('WORKLOAD_RUN', q'[
    CREATE TABLE telco_load.workload_run (
      run_id        NUMBER        NOT NULL,
      started_at    DATE          NOT NULL,
      target_tps    NUMBER        NOT NULL,
      sessions      NUMBER        NOT NULL,
      duration_sec  NUMBER        NOT NULL,
      stop_flag     NUMBER(1)     DEFAULT 0 NOT NULL,
      CONSTRAINT workload_run_pk PRIMARY KEY (run_id)
    )]');

  create_table_if_missing('WORKLOAD_STATS', q'[
    CREATE TABLE telco_load.workload_stats (
      run_id            NUMBER        NOT NULL,
      session_no        NUMBER        NOT NULL,
      updated_at        DATE          NOT NULL,
      cnt_record        NUMBER        DEFAULT 0 NOT NULL,
      cnt_rejected      NUMBER        DEFAULT 0 NOT NULL,
      cnt_rating        NUMBER        DEFAULT 0 NOT NULL,
      cnt_balance       NUMBER        DEFAULT 0 NOT NULL,
      cnt_errors        NUMBER        DEFAULT 0 NOT NULL,
      last_error        VARCHAR2(200),
      finished          NUMBER(1)     DEFAULT 0 NOT NULL,
      CONSTRAINT workload_stats_pk PRIMARY KEY (run_id, session_no)
    )]');
END;
/

PROMPT === Package specification
CREATE OR REPLACE PACKAGE telco_load.telco_workload AS
  PROCEDURE start_load(p_tps          IN NUMBER      DEFAULT 500,
                       p_sessions     IN PLS_INTEGER DEFAULT 16,
                       p_duration_sec IN NUMBER      DEFAULT 3900,
                       p_seed         IN NUMBER      DEFAULT NULL);
  PROCEDURE stop_load(p_force IN BOOLEAN DEFAULT FALSE);
  PROCEDURE status(p_run_id IN NUMBER DEFAULT NULL);

  -- Snapshot: state, planned end time, time left, counters.
  PROCEDURE monitor;
  -- Blocks until the latest run has finished or been stopped, then prints a notice
  -- (with a terminal bell) and the final counters. Output appears when the call returns.
  PROCEDURE wait_for_finish(p_poll_sec IN NUMBER DEFAULT 30);
  -- Immediate stop: sets the stop flag, stops the scheduler jobs and removes them.
  PROCEDURE kill_load;

  -- Called by the scheduler jobs. Do not call it directly.
  PROCEDURE run_session(p_run_id       IN NUMBER,
                        p_session_no   IN PLS_INTEGER,
                        p_tps          IN NUMBER,
                        p_sessions     IN PLS_INTEGER,
                        p_duration_sec IN NUMBER,
                        p_seed         IN NUMBER);
END telco_workload;
/

CREATE OR REPLACE PACKAGE BODY telco_load.telco_workload wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
b
4592 17df
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
/

SHOW ERRORS PACKAGE telco_load.telco_workload
SHOW ERRORS PACKAGE BODY telco_load.telco_workload

DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM dba_objects
   WHERE owner = 'TELCO_LOAD' AND object_name = 'TELCO_WORKLOAD'
     AND object_type IN ('PACKAGE', 'PACKAGE BODY') AND status = 'VALID';
  IF l_cnt <> 2 THEN
    RAISE_APPLICATION_ERROR(-20020,
      'TELCO_LOAD.TELCO_WORKLOAD is not valid. See the SHOW ERRORS output above.');
  END IF;
END;
/

PROMPT === Summary
COLUMN owner       FORMAT A12
COLUMN object_name FORMAT A22
COLUMN object_type FORMAT A14
COLUMN status      FORMAT A8
COLUMN table_name  FORMAT A14
COLUMN index_name  FORMAT A14
SELECT owner, object_name, object_type, status
  FROM dba_objects
 WHERE owner IN ('TELCO', 'TELCO_LOAD')
   AND object_type IN ('TABLE', 'SEQUENCE', 'PACKAGE', 'PACKAGE BODY')
 ORDER BY owner, object_type, object_name;

SELECT COUNT(*) AS subscriber_rows FROM telco.subscriber;

PROMPT === Starting the workload
DECLARE
  l_active NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_active
    FROM telco_load.workload_run
   WHERE stop_flag = 0
     AND started_at + duration_sec / 86400 > SYSDATE;
  IF l_active > 0 THEN
    DBMS_OUTPUT.PUT_LINE('A workload is already running - no second one started.');
  ELSE
    telco_load.telco_workload.start_load(p_tps => 500, p_sessions => 16, p_duration_sec => 3900);
    DBMS_OUTPUT.PUT_LINE('Workload started: 500 TPS, 16 sessions, 65 minutes.');
  END IF;
END;
/

PROMPT
PROMPT Done. The workload runs in the background for 65 minutes.
PROMPT Take the 1-hour AWR report while it is running.
PROMPT
PROMPT Helper commands (run as SYS or TELCO_LOAD, with SET SERVEROUTPUT ON):
PROMPT   EXEC telco_load.telco_workload.monitor;           -- state, planned end, time left, counters
PROMPT   EXEC telco_load.telco_workload.wait_for_finish;   -- waits and prints a notice when the run ends
PROMPT   EXEC telco_load.telco_workload.kill_load;         -- stops everything immediately
