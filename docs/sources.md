# Sources, search phrases, applied and rejected recommendations

Searches were run with AI assistance (Claude); the cited pages were opened and read, except where marked "title only".

## Search phrases used
- Oracle Database 23ai CURSOR_SHARING FORCE literal replacement bind variables reference
- Oracle Database Performance Tuning Guide shared pool hard parse literals library cache latch mutex contention
- Oracle ADDM Automatic Database Diagnostic Monitor findings documentation 23ai
- Oracle multitenant PDB AWR snapshots awr_pdb_autoflush_enabled AWR_PDB AWR_ROOT report awrrpt
- Oracle full table scan missing index partition pruning local index interval partitioning
- Oracle Database 23ai CREATE PROFILE FAILED_LOGIN_ATTEMPTS PASSWORD_LOCK_TIME unified auditing
- Oracle GoldenGate 23ai unidirectional replication privileges DBMS_GOLDENGATE_AUTH least privilege

## AWR analysis (Part 2) - read sources
1. Improving Real-World Performance Through Cursor Sharing (SQL Tuning Guide 19c): https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/improving-rwp-cursor-sharing.html
   - Literals create separate cursors and hard parses; hard parse needs library cache and dictionary cache latching.
   - CURSOR_SHARING=FORCE replaces literals with system bind variables; Oracle calls it a temporary band-aid, not a permanent fix; recommended scope is session; downsides: extra soft-parse work, possible bad plans.
2. Tuning the Shared Pool and the Large Pool (Performance Tuning Guide 21c): https://docs.oracle.com/en/database/oracle/oracle-database/21/tgdba/tuning-shared-pool-and-large-pool.html
   - Hard parse needs shared pool latch gets in addition to library cache latch gets; use bind variables.
3. Automatic Performance Diagnostics / ADDM (Performance Tuning Guide 21c): https://docs.oracle.com/en/database/oracle/oracle-database/21/tgdba/automatic-performance-diagnostics.html
   - ADDM runs after each snapshot; finding impact is a share of DB time; impacts can overlap and sum above 100%.
4. Managing AWR in a Multitenant Environment (23ai): https://docs.oracle.com/en/database/oracle/oracle-database/23/tgdba/managing-automatic-workload-repository-multitenant-environment.html
   - PDB snapshots have their own snapshot IDs; manual snapshots recommended for a PDB; AWR_PDB vs AWR_ROOT views.

## Other parts (title only, open before citing)
- Profiles: https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/CREATE-PROFILE.html
- Password policy: https://docs.oracle.com/en/database/oracle/oracle-database/26/dbseg/using-password-management-policy.html
- GoldenGate users and privileges: https://docs.oracle.com/en/middleware/goldengate/core/23/coredoc/prepare-database-user-and-privileges-oracle.html
- DBMS_GOLDENGATE_AUTH: https://docs.oracle.com/en/database/oracle/oracle-database/26/arpls/DBMS_GOLDENGATE_AUTH.html
- Partitioning: https://docs.oracle.com/en/database/oracle/oracle-database/19/vldbg/maintenance-partition-tables-indexes.html

## Applied
- CURSOR_SHARING=FORCE in FREEPDB1 (problem B). Reason: application code is not readable/changeable, no schema rule is broken, reversible. Deviation: Oracle recommends session scope; PDB scope used because workload sessions are created by scheduler jobs.

## Recommended but not applied
- Index on CDR_USAGE (MSISDN, CALL_START) (problem A): project spec forbids any index except SUBSCRIBER primary key; pending approval.
- Bind variables in application code (problem B permanent fix): application team.

## Rejected (with reason)
- ADDM "Sequence Usage": CDR_SEQ cache is already 1000; row cache mutex 0.3% of DB time.
- ADDM "Large number of database connections": 16 sessions is the task design.
- Larger redo logs/FRA: about 28 log switches/hour, log file switch waits 0.2%; sizes prescribed by task.
- Disk slowness: not in top events under load.
- CURSOR_SHARING=FORCE as a permanent solution: Oracle documentation says it is a band-aid.
