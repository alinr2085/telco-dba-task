# Part 2: AWR analysis, fix and comparison

Raw numbers: `docs/baseline_run1.md` (before) and `docs/run2_after_fix.md` (after). Sources: `docs/sources.md`.

## Problems found (from run 1)
- A: full table scan on CDR_USAGE by `1ppfr2kwym0kf` (22.5% of DB time, 36k executions). Fix = index on (MSISDN, CALL_START). Not applied: the spec forbids any index except the SUBSCRIBER primary key. Recommendation only.
- B: literal SQL, e.g. `SELECT ... FROM TELCO.subscriber WHERE subscriber_id = 2431`: 269 hard parses/s, with latch: shared pool, library cache mutex X, cursor: pin S wait on X, row cache mutex. Fix applied: CURSOR_SHARING=FORCE in FREEPDB1. Permanent fix: bind variables in the application code.

## Before and after
| Metric (per second) | Run 1 | Run 2 | Change |
|---|---|---|---|
| Hard parses | 269.4 | 0.1 | about -99.96% |
| Parses (total) | 552.9 | 534.0 | about unchanged |
| DB Time(s) | 1.3 (total 4,843 s) | 0.8 (total 3,033 s) | about -37% |
| DB CPU per transaction (derived) | about 2.7 ms | about 1.7 ms | about -35% |
| Transactions | 482.8 | 482.8 | unchanged (rate-limited workload) |
| library cache: mutex X | 26,874 waits, 11.0 s | 3,462 waits, 4.2 s | -87% waits |
| latch: shared pool | 178,205 waits, 42.8 s | not in top 10 | resolved |
| cursor: pin S wait on X | 708 waits, 15.1 s | not in top 10 | resolved |
| resmgr:cpu quantum | 2,100 waits, 150.1 s | 22 waits, 0.2 s | almost gone |
| Query A elapsed (s) | 1,088.68 (22.5%) | 912.73 (30.1%) | not fixed; share grew |

## Interpretation
- The fix removed hard parsing almost completely and the contention it caused. The workload is rate-limited to 500 TPS, so the benefit shows as lower DB time and CPU per transaction, not as higher TPS.
- Total parse count stayed about the same, as Oracle documents: FORCE turns hard parses into soft parses, it does not reduce the number of parses. Oracle also calls FORCE a temporary band-aid (see sources).
- Problem A is unchanged and is now the largest single item (30% of DB time).

## Caveats (honest limits)
- One run per side. The unchanged query A varied by about 15% per execution between runs (29.9 ms vs 25.3 ms), so differences of that size are noise.
- Run 1 window: PDB snaps 7 -> 9 (60.57 min); run 2: PDB snaps 14 -> 15 (60.01 min). Both PDB-level, comparable.
- Run 1 ADDM was read from the root report (snaps 6 -> 7); the PDB ADDM of run 1 was not extracted.
- ADDM "Sequence Usage" and "Large number of connections" disappeared after the fix. ADDM impacts overlap, so these earlier findings were probably tied to the parsing load. The sequence rejection (cache 1000) still stands.
- The drop of resmgr:cpu quantum fits the hypothesis of a CPU cap in the free edition, but this is not verified.
- Scope deviation: Oracle recommends session-level cursor sharing; we used PDB level because the workload code is unreadable.

## Not applied, recommended
- Index on CDR_USAGE (MSISDN, CALL_START): local index. Expected side effect: slower inserts.
- Bind variables in application code (permanent fix for B).
