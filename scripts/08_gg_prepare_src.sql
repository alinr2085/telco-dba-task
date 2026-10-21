-- SRC: enable GoldenGate replication and supplemental logging
SET LINESIZE 200 PAGESIZE 100
ALTER SYSTEM SET enable_goldengate_replication = TRUE SCOPE = BOTH;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER TABLE telco.subscriber ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS;
ALTER TABLE telco.cdr_usage  ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
PROMPT == check
SELECT name, value FROM v$parameter WHERE name = 'enable_goldengate_replication';
SELECT supplemental_log_data_min FROM v$database;
SELECT table_name, log_group_type FROM dba_log_groups WHERE owner = 'TELCO';
