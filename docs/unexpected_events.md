# Unexpected events that cost real time

## 1. Manual AWR snapshots "disappeared"
- Symptom: after the first workload, my manual snapshots were not in `dba_hist_snapshot`; only automatic ones were.
- Cause: the PDB has its own DBID (3457782515) and its own snapshot numbering. My query filtered on the root DBID (1509902213), so PDB snapshots were hidden.
- Proof: `cdb_hist_snapshot` without the DBID filter shows PDB snaps 7 and 9 at the expected times (`outputs/34_snap_root_cause_and_literal_sql.txt`).
- Decision: the official reports are PDB-level (`AWR_PDB`) with manual snapshots in the PDB. Oracle documents that PDB snapshot IDs are independent of CDB ones (see `docs/sources.md`).

## 2. Snapshot script failed inside bash
- Symptom: the begin snapshot of the second run was not taken; the script printed `sqlsrc: command not found`.
- Cause: `sqlsrc` was a shell function in `~/.bashrc`, not visible inside a script.
- Fix: the script now calls `docker exec ... sqlplus` directly. Related pitfall: `awrrpt` inside a PDB asks an extra question (`AWR_PDB` or `AWR_ROOT`); a shifted input caused ORA-00903 and no report file.

## 3. Laptop sleep invalidated run 2
- Symptom: `monitor` showed elapsed 4403 s instead of 3900 s and an average of 286.5 TPS instead of 500.
- Cause: Windows went to sleep and paused Docker and WSL during the load.
- Decision: the run was discarded and repeated after cleanup, with sleep disabled. Evidence kept in `outputs/40_*` to `outputs/42_*`.

## 4. The obvious fix conflicts with the spec
- Problem A (full scan of CDR_USAGE) is solved by an index on (MSISDN, CALL_START), but the spec allows no index except the SUBSCRIBER primary key.
- Decision: the index is only a recommendation (needs approval); the applied fix is `CURSOR_SHARING=FORCE` for problem B. Oracle's documentation calls FORCE a temporary band-aid and recommends bind variables (see `docs/sources.md`).

## 5. Two false leads
- Slow disk: the idle test showed `log file sync` of about 134 ms. Under load `log file sync` was not among the top events, so the hypothesis was dropped.
- ADDM "Sequence Usage": the `CDR_SEQ` cache was already 1000 and the related wait was 0.3% of DB time, so it was rejected. The finding also disappeared in run 2.

(GoldenGate: to be added.)

## GoldenGate events

### GG1 - Image pull failed with 401
Symptom: docker pull returned 401 (outputs/49). Causes: I first used the wrong image name (goldengate-free instead of goldengate-oracle-free) and no Oracle account was logged in. Fix: created an Oracle account, accepted the terms, docker login, used the right image name (outputs/50, 51).

### GG2 - Admin password rejected by the container
The OGG_ADMIN_PWD did not meet the password policy of the image. Fix: validated the password first, recreated the container and its volumes.

### GG3 - EXT1 abended with OGG-02718
Cause: SOURCECATALOG in the parameter file is not allowed when the process is connected directly to the PDB. Fix: removed SOURCECATALOG from EXT1.prm and REP1.prm. A duplicated EXTRACT line (warning OGG-10173) was also cleaned.

### GG4 - REP1 abended with ORA-14402 on the first smoke test
Cause: SRC still held old workload data with duplicated CALL_IDs, so KEYCOLS(CALL_ID) matched several rows and an UPDATE tried to move a row between interval partitions. Fix: cleaned both databases, deleted and recreated REP1, repeated the test (failing run kept as evidence in outputs/58, clean run in outputs/61).

### GG5 - FRA was 67% full before the GG run
FRA held 134 archived logs from the earlier runs (5494 of 8192 MB, nothing reclaimable because no backup exists). Fix: RMAN DELETE of old archived logs, then scripts/15_fra_housekeeping.sh during the run. Side effect: point-in-time recovery for the deleted period is gone (lab only, no backups). RMAN-08137 showed that Oracle itself protects the logs the Extract still needs.

### GG6 - Replicat fell behind during the workload
Replicat lag grew from 866 s to about 2764 s and a backlog of about 1.06 million CDR_USAGE rows existed at the end of the load. Probable cause: no index on CDR_USAGE (task rule), so updates/deletes on the target are slow. Not proven with SQL statistics. Details and numbers: docs/part1_gg_sync_report.md.

### GG7 - Evidence file overwritten
One lag output file (outputs/64_gg_lag_mid.txt) was overwritten with a later measurement; it was renamed to outputs/65_gg_lag_end.txt. The mid-run values are taken from outputs/63_gg_lag_samples.csv instead.
