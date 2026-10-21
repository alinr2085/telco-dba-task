# Part 1: installation, configuration, schema and security

## 1. Environment
- Host: Windows 10 22H2, 16 GB RAM, Git Bash. WSL2 limited by `~/.wslconfig`: memory 11 GB, 4 processors, swap 4 GB. Docker Desktop (WSL2 backend).
- Two containers from the official Oracle image `container-registry.oracle.com/database/free:latest` (Oracle Database Free 23ai, version 23.26.3; image id `sha256:f988b0c04c4c386cd306a2a914c0d7a9702d83acc31b064a28ad8eb6278a8fba`, created 2026-07-05).
  - `src-db` (SRC, main database), host port 1521.
  - `tgt-db` (TGT, reporting target), host port 1522 (container port 1521).
- SID note: this image runs the instance with SID `FREE`. SRC and TGT are the container names. Application data lives in the PDB `FREEPDB1`.
- Secrets: the password is in `.env` (`ORACLE_PWD=...`), which is in `.gitignore` and not in the repository.

## 2. Installation (from scratch)
1. WSL2: `wsl --update --web-download` (the plain `wsl --install` failed with "Access is denied"). Create `~/.wslconfig` with memory/processors/swap as above, then `wsl --shutdown`.
2. Install Docker Desktop, reopen Git Bash, check with `docker run --rm hello-world`.
3. Create `.env` with `ORACLE_PWD=<chosen password>`.
4. Pull the image: `docker pull container-registry.oracle.com/database/free:latest`.
5. Start SRC (ARCHIVELOG is enabled by the image through `ENABLE_ARCHIVELOG=true`):
```bash
   MSYS_NO_PATHCONV=1 docker run -d --name src-db -p 1521:1521 --env-file .env \
     -e ENABLE_ARCHIVELOG=true -v src_data:/opt/oracle/oradata \
     container-registry.oracle.com/database/free:latest
```
6. Start TGT:
```bash
   MSYS_NO_PATHCONV=1 docker run -d --name tgt-db -p 1522:1521 --env-file .env \
     -v tgt_data:/opt/oracle/oradata \
     container-registry.oracle.com/database/free:latest
```
7. Wait until `docker logs src-db` (and `tgt-db`) show `DATABASE IS READY TO USE!`.
8. Helper functions in `~/.bashrc` (used in this repository's command lines):
```bash
   sqlsrc() { MSYS_NO_PATHCONV=1 docker exec -i src-db sqlplus -s "/ as sysdba"; }
   sqltgt() { MSYS_NO_PATHCONV=1 docker exec -i tgt-db sqlplus -s "/ as sysdba"; }
```

## 3. SRC configuration (evidence in `outputs/`)
- ARCHIVELOG: `SELECT log_mode FROM v$database;` returns ARCHIVELOG (see `outputs/02_fra_check.txt`).
- FRA limited to 8 GB (`outputs/02_fra_check.txt`):
```sql
  ALTER SYSTEM SET db_recovery_file_dest_size = 8G SCOPE = BOTH;
  ALTER SYSTEM SET db_recovery_file_dest = '/opt/oracle/oradata/fra' SCOPE = BOTH;
```
- Online redo: three groups of 50 MB (`outputs/01_redo_final.txt`). The image default groups were replaced: groups 4 to 6 (50 MB) added with `ALTER DATABASE ADD LOGFILE GROUP n ('/opt/oracle/oradata/FREE/redo0n.log') SIZE 50M`, log switched three times, `ALTER SYSTEM CHECKPOINT`, then `ALTER DATABASE DROP LOGFILE GROUP 1/2/3`.
- PDB check: `scripts/01_check_pdb.sql` (`outputs/03_pdb_check.txt`).
- `job_queue_processes = 40` (`ALTER SYSTEM SET job_queue_processes = 40 SCOPE = BOTH;`, `outputs/04_job_queue.txt`); the workload needs at least 16 scheduler jobs.

## 4. Schema TELCO (SRC and TGT)
- Script `scripts/02_create_schema.sql`, run in FREEPDB1 on both databases (`outputs/05_schema_src.txt`, `outputs/06_schema_tgt.txt`).
- `SUBSCRIBER` (SUBSCRIBER_ID primary key, MSISDN, TARIFF_CODE, STATUS, CREATED_AT).
- `CDR_USAGE` interval partitioned by day on `CALL_START`, intentionally without primary key.
- No other index exists in the schema (spec rule). This is why the index fix in Part 2 was only recommended.

## 5. Security (SRC and TGT)
- Before: `scripts/03_security_check.sql` (`outputs/07_security_check_src.txt`). Apply: `scripts/04_security.sql` (`outputs/08_security_src.txt`, `outputs/09_security_tgt.txt`).
- Profile `APP_PROFILE`: `failed_login_attempts 5`, `password_lock_time 1/24` (1 hour), `password_life_time 90`.
- It was assigned to the workload users `TELCO_APP` and `TELCO_LOAD` after the second AWR measurement with `scripts/07_assign_profile.sql` (`outputs/48_assign_profile.txt`), so that the two runs differ only by the fix.
- Default and non-essential accounts locked where Oracle allows. `SYSRAC` is a reserved user without password authentication; locking it fails with ORA-28222, so `authentication_type` was checked instead.
- Unified auditing: policy `ora_logon_failures` enabled; a failed logon was provoked and found in the audit trail (`outputs/10_audit_test_src.txt`).
- No password is stored in the repository, scripts or outputs.

## 6. Rebuild order (scripts)
`01_check_pdb.sql` -> `02_create_schema.sql` (SRC and TGT) -> `03_security_check.sql` -> `04_security.sql` (SRC and TGT) -> workload (Part 2) -> `07_assign_profile.sql`.

## GoldenGate (SRC -> TGT, unidirectional)

Product: Oracle GoldenGate Free (Microservices architecture), image `goldengate-oracle-free` from Oracle Container Registry, container `gg`, network `telco-net`, web UI on ports 8080/8443 (Administration Service). The task text says "Classic" but the diagram text says "Microservices 23ai"; I used Microservices because it is the image available. Clarification email to the company: pending.

Steps (scripts in scripts/, evidence in outputs/):
1. Prepare SRC: ARCHIVELOG, FORCE LOGGING, supplemental logging, ENABLE_GOLDENGATE_REPLICATION - scripts/08_gg_prepare_src.sql (outputs/52). Prepare TGT: scripts/09_gg_prepare_tgt.sql (outputs/53).
2. Least-privilege GG users, no SYS/SYSTEM inside GG: GGCAPTURE on SRC (role OGG_CAPTURE) - scripts/10_gg_user_src.sql; GGAPPLY on TGT (role OGG_APPLY) - scripts/11_gg_user_tgt.sql; grants for the checkpoint table - scripts/12_gg_apply_checkpoint_grants.sql (outputs/54-57). Passwords come from untracked .env files, never from the repo.
3. In the Administration Service: credential aliases src_ggcapture and tgt_ggapply (domain OracleGoldenGate), checkpoint table, then the two processes.
4. EXT1 (Integrated Extract), trail `aa`:
   EXTRACT EXT1 / USERIDALIAS src_ggcapture DOMAIN OracleGoldenGate / EXTTRAIL aa / TABLE TELCO.SUBSCRIBER; / TABLE TELCO.CDR_USAGE;
5. REP1 (Parallel Nonintegrated Replicat):
   REPLICAT REP1 / USERIDALIAS tgt_ggapply DOMAIN OracleGoldenGate / MAP TELCO.SUBSCRIBER, TARGET TELCO.SUBSCRIBER; / MAP TELCO.CDR_USAGE, TARGET TELCO.CDR_USAGE, KEYCOLS (CALL_ID);
   KEYCOLS is needed because CDR_USAGE has no primary key.
6. Smoke test of INSERT/UPDATE/DELETE: scripts/13_gg_smoke_test.sh, passing run in outputs/61_gg_smoke_test_clean.txt.
7. Sync status during the 65-minute workload: docs/part1_gg_sync_report.md (scripts 14-16, outputs 62-66).

Known design limit: the task forbids extra indexes on CDR_USAGE, GoldenGate warns that KEYCOLS should be indexed on the target, and the workload showed Replicat falling behind (see the report).
