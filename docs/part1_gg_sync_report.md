# Part 1 - GoldenGate sync status during the workload

Workload: 500 TPS, 16 sessions, 65 min (01:55-03:00 UTC). GoldenGate: EXT1 (Integrated Extract) -> trail aa -> REP1 (Parallel Replicat), unidirectional SRC -> TGT.
Data: outputs/62_gg_sync_samples.csv (row counts, ~1/min), outputs/63_gg_lag_samples.csv (lag via adminclient LAG, ~1/min), outputs/66_gg_lag_after_load.txt.

## Result in short
- Extract kept up the whole run: lag 1-5 s.
- Replicat fell behind steadily: lag 866 s (~14 min) at 02:25 -> 2302 s (~38 min) at 02:57. It kept growing after the load stopped (2764 s, ~46 min at 03:06).
- Backlog of CDR_USAGE rows at the end of the load: about 1.06 million (SRC 1,674,507 vs TGT ~611,800).

## Lag (seconds, from outputs/63_gg_lag_samples.csv)
| Time (UTC) | Extract | Replicat low | Replicat high |
|---|---|---|---|
| 02:25:46 | 1 | 866 | 857 |
| 02:36:17 | 1 | 1308 | 1322 |
| 02:46:38 | 1 | 1814 | 1809 |
| 02:56:59 | 1 | 2302 | 2306 |
| 03:04:15 (load ended 03:00) | 4 | 2666 | 2664 |
| 03:06:21 | 5 | 2764 | 2757 |

## Row counts of CDR_USAGE (from outputs/62_gg_sync_samples.csv)
| Time (UTC) | SRC | TGT | Backlog |
|---|---|---|---|
| 02:23:38 | 721,984 | 392,301 | 329,683 |
| 02:33:57 | 988,922 | 464,233 | 524,689 |
| 02:59:49 | 1,657,097 | 602,563 | 1,054,534 |
| 03:01:54 | 1,674,507 | 611,837 | 1,062,669 |

SUBSCRIBER stayed equal (200,000 on both sides). The source produced about 26,000 CDR rows/min. Replicat applied about 7,500 rows/min early and about 4,600-5,000 rows/min near the end.

## Likely cause (not proven)
CDR_USAGE has no index (task rule), so each UPDATE/DELETE applied on the target probably needs a full scan, which gets slower as the table grows. Supporting hint: the Replicat statistics page counted 68k updates/deletes on tables without a unique index early in the run. I did not verify this with SQL statistics on TGT.

## Not measured
- Time to catch up after the load: not measured (time limit). Linear estimate from the last apply rate: about 3.5 hours. Rough estimate only.
- Final row-count equality was not reached when sampling stopped.

## Possible improvements (proposals, not applied)
- An index or unique key on CALL_ID on TGT only (needs approval, the task forbids extra indexes on CDR_USAGE).
- More apply threads for the Parallel Replicat.
- Re-test with a lower update rate to find the sustainable rate.
