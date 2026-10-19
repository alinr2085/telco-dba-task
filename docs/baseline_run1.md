# Run 1 baseline (before any fix)

## Scope and method
- Workload: unmodified `workload_setup.sql`, 500 TPS target, 16 sessions, 65 min, in FREEPDB1 on SRC.
- Load window (DB server time): started 16:00:51, finished 17:05:51. Result: FINISHED, 1,949,992 transactions, avg 500 TPS, 0 errors.
- Official report: PDB-level AWR (AWR_PDB), manual snapshots PDB snap 7 -> 9 (16:05:05 -> 17:05:39, about minute 4 to 64).
  PDB DBID 3457782515, file `awr/awr_run1_pdb.html`, text extract `outputs/36_run1_pdb_awr.txt`.
- Cross-check: root auto snapshots 6 -> 7 (16:00:51 -> 17:00:57), file `awr/awr_run1.html`. Same picture.
- Idle reference (no load): `awr/awr_test.html`.

## Baseline numbers (PDB report, snap 7 -> 9)
| Metric (per second unless noted) | Value |
|---|---|
| DB Time(s) | 1.3 |
| DB CPU(s) | 1.3 (96.7% of DB time) |
| Total DB time | 4,843 s |
| Transactions | 482.8 |
| Executes (SQL) | 1,428.8 |
| Parses (SQL) | 552.9 |
| Hard parses (SQL) | 269.4 |
| Logical reads (blocks) | 61,593 |
| Block changes | 2,865 |
| Redo size (bytes) | 403,223 |

Top foreground events:
| Event | Waits | Total wait (s) | % DB time |
|---|---|---|---|
| DB CPU | - | 4,684.6 | 96.7 |
| resmgr:cpu quantum | 2,100 | 150.1 | 3.1 |
| latch: shared pool | 178,205 | 42.8 | 0.9 |
| row cache mutex | 26,924 | 16.0 | 0.3 |
| cursor: pin S wait on X | 708 | 15.1 | 0.3 |
| library cache: mutex X | 26,874 | 11.0 | 0.2 |
| log file switch (private strand flush incomplete) | 397 | 9.1 | 0.2 |

Root report cross-check (snap 6 -> 7): AAS 1.27, DB time 4,591 s, hard parses 296.8/s, parses 583.6/s, redo 407,503 B/s, query A 20.19% of DB time.

## Problem A: full table scan on CDR_USAGE
- SQL_ID `1ppfr2kwym0kf`: `SELECT COUNT(*), NVL(SUM(charge_amt),0) FROM TELCO.cdr_usage WHERE msisdn = :m AND call_start >= SYSDATE - 1/24`
- 36,367 executions, 1,088.68 s elapsed, 22.48% of DB time, 90% CPU, 0% IO.
- Plan hash 1050735216: PARTITION RANGE ITERATOR + TABLE ACCESS FULL (no index exists on CDR_USAGE). `CDR_USAGE` has no optimizer statistics (dynamic sampling used).
- Where seen in AWR: SQL ordered by Elapsed Time; ADDM "Top SQL Statements"; Top SQL with Top Events (TABLE ACCESS - FULL); plan via DBMS_XPLAN.DISPLAY_AWR.
- Fix: local index on (MSISDN, CALL_START). NOT applied: the project spec allows no index except the SUBSCRIBER primary key. Recorded as a recommendation (pending approval from Mohaymen).
- Alternatives (not applied): hash sub-partitioning on MSISDN; app-side change.
- Expected side effect of the index: slower INSERTs (index maintenance).

## Problem B: literal SQL causing hard parses
- Example: `SELECT msisdn, tariff_code, status FROM TELCO.subscriber WHERE subscriber_id = 2431` (same text, different literal each time; 100+ sql_ids, one force_matching_signature in ASH).
- 269 hard parses/s of 553 parses/s. Symptoms: latch: shared pool, library cache: mutex X, cursor: pin S wait on X, row cache mutex.
- Where seen in AWR: Load Profile (Hard parses); Top Foreground Events; ADDM "Hard Parse Due to Literal Usage" (about 25% of activity).
- Root cause: application code does not use bind variables (report to the application team; permanent fix = bind variables).
- Fix to apply: `ALTER SYSTEM SET cursor_sharing = FORCE` in FREEPDB1 (reversible, no code change). It is a mitigation, not a cure. Risk: one plan reused for skewed values.
- What to compare in run 2: Hard parses/s (269.4), DB Time/s (1.3), the four contention events above, DB CPU. TPS stays about 500 because the workload is rate-limited.

## Recommendations rejected, with reason
- ADDM "Sequence Usage": TELCO.CDR_SEQ already has CACHE 1000; row cache mutex only 0.3% of DB time.
- ADDM "Large number of database connections": 16 sessions is by design of the task.
- Larger redo logs / FRA: log switches about 28/hour (1.47 GB redo / 50 MB), log file switch wait only 0.2%; redo size is also prescribed by the task.
- Slow disk (log file sync 134 ms in the idle test): not a bottleneck under load; log file sync is not in the top events.
- resmgr:cpu quantum (3.1%): resource manager CPU throttling, probably an environment limit of the free edition (hypothesis, not verified).

## Unexpected events (for the report)
1. Manual snapshots seemed to disappear. Cause: the PDB has its own DBID (3457782515) and its own snapshot numbering; my query filtered on the root DBID (1509902213), so PDB snapshots were hidden. Proof: cdb_hist_snapshot without the dbid filter shows PDB snaps 7 and 9 at 16:05:05 and 17:05:39.
2. awrrpt inside a PDB asks an extra prompt (`awr_location`: AWR_PDB or AWR_ROOT); a first run with shifted inputs failed with ORA-00903 and produced no file.
3. ADDM sequence finding was contradicted by evidence (cache already 1000).
4. GoldenGate image could not be pulled (401) and an Oracle account could not be created (403); see GoldenGate notes.
