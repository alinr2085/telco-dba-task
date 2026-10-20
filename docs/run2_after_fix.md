# Run 2 (after fix: CURSOR_SHARING=FORCE in FREEPDB1)

## Scope and method
- Same workload, unmodified `workload_setup.sql`, 500 TPS target, 16 sessions, 65 min.
- Load window (DB server time UTC): started 01:47:55, planned end 02:52:55. Result FINISHED, elapsed 3900 s, 1,949,991 transactions, avg 500 TPS, 0 errors (`outputs/44_run2_monitor_final.txt`).
- Report: PDB-level AWR (AWR_PDB), manual snapshots PDB snap 14 -> 15 (01:51:35 -> 02:51:36, minute 3.7 to 63.7, 60.01 min). Files: `awr/awr_run2_pdb.html`, `outputs/46_run2_pdb_awr.txt`, `outputs/47_run2_pdb_key_sections.txt`.
- Fix applied before the run: `ALTER SYSTEM SET cursor_sharing = FORCE SCOPE = BOTH` in FREEPDB1 (`scripts/06_fix_cursor_sharing.sql`, `outputs/39_fix_cursor_sharing.txt`).
- A first attempt at run 2 was invalidated by a laptop sleep (elapsed 4403 s, avg 286.5 TPS) and repeated; see `docs/unexpected_events.md`.

## Numbers (PDB report, snap 14 -> 15)
| Metric (per second unless noted) | Value |
|---|---|
| DB Time(s) | 0.8 (50.55 min in 60.01 min; total 3,033 s) |
| DB CPU(s) | 0.8 (99.9% of DB time) |
| Transactions | 482.8 |
| Executes (SQL) | 1,389.7 |
| Parses (SQL) | 534.0 |
| Hard parses (SQL) | 0.1 |
| Logical reads (blocks) | 59,822 |
| Block changes | 2,865.9 |
| Redo size (bytes) | 403,041 |

Top foreground events:
| Event | Waits | Total wait (s) | % DB time |
|---|---|---|---|
| DB CPU | - | 3,030.7 | 99.9 |
| log file switch (private strand flush incomplete) | 225 | 6.2 | 0.2 |
| library cache: mutex X | 3,462 | 4.2 | 0.1 |
| buffer busy waits | 4,775 | 1.2 | 0.0 |
| log file switch (checkpoint incomplete) | 51 | 0.4 | 0.0 |
| cursor: pin S | 292 | 0.4 | 0.0 |
| resmgr:cpu quantum | 22 | 0.2 | 0.0 |

Top SQL: `1ppfr2kwym0kf` 912.73 s, 36,007 executions, 0.03 s per execution, 30.10% of DB time, 91.9% CPU, 0% IO (problem A unchanged).
ADDM (PDB): Top SQL Statements 66.81%, PL/SQL Execution 31.06%, Soft Parse 2.96%. No literal, sequence or connection findings.
