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
