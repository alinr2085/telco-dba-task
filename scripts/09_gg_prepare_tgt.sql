-- TGT: enable GoldenGate replication (apply side)
SET LINESIZE 200 PAGESIZE 100
ALTER SYSTEM SET enable_goldengate_replication = TRUE SCOPE = BOTH;
PROMPT == check
SELECT name, value FROM v$parameter WHERE name = 'enable_goldengate_replication';
