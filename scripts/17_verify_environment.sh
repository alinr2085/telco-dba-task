#!/bin/bash
# Verifies the Part 1 environment against the task requirements (read-only).
# Usage from the repo root (Git Bash): ./scripts/17_verify_environment.sh [outfile]
OUT=${1:-outputs/68_verify_environment.txt}
PASS=0; FAIL=0
ok()   { echo "PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL  $1  (got: $2)"; FAIL=$((FAIL+1)); }
expect() { if [ "$3" = "$2" ]; then ok "$1"; else bad "$1" "$3, expected $2"; fi; }
atleast1() { if [ "${2:-0}" -ge 1 ] 2>/dev/null; then ok "$1"; else bad "$1" "${2:-empty}"; fi; }

# sq <container> <root|pdb>: SQL from stdin, prints the last non-empty line
sq() {
  local c=$1 pre=""
  [ "$2" = pdb ] && pre="ALTER SESSION SET CONTAINER = FREEPDB1;"
  { printf 'SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 300\n%s\n' "$pre"; cat; } \
    | MSYS_NO_PATHCONV=1 docker exec -i "$c" sqlplus -s "/ as sysdba" 2>&1 \
    | tr -d '\r' | sed '/^[[:space:]]*$/d' | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
# sqall: same, but all lines joined with commas
sqall() {
  local c=$1 pre=""
  [ "$2" = pdb ] && pre="ALTER SESSION SET CONTAINER = FREEPDB1;"
  { printf 'SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 300\n%s\n' "$pre"; cat; } \
    | MSYS_NO_PATHCONV=1 docker exec -i "$c" sqlplus -s "/ as sysdba" 2>&1 \
    | tr -d '\r' | sed '/^[[:space:]]*$/d' | paste -sd, -
}

check_schema() {
  local c=$1
  echo "== $c: schema, security"
  expect "$c: TELCO has SUBSCRIBER and CDR_USAGE" 2 "$(sq $c pdb <<'SQL'
SELECT COUNT(*) FROM dba_tables WHERE owner='TELCO' AND table_name IN ('SUBSCRIBER','CDR_USAGE');
SQL
)"
  expect "$c: CDR_USAGE is interval-partitioned" "RANGE interval" "$(sq $c pdb <<'SQL'
SELECT partitioning_type||' '||NVL2("INTERVAL",'interval','no-interval') FROM dba_part_tables WHERE owner='TELCO' AND table_name='CDR_USAGE';
SQL
)"
  expect "$c: partition key is CALL_START" CALL_START "$(sq $c pdb <<'SQL'
SELECT column_name FROM dba_part_key_columns WHERE owner='TELCO' AND name='CDR_USAGE' AND object_type='TABLE';
SQL
)"
  expect "$c: CDR_USAGE has no primary or unique key" 0 "$(sq $c pdb <<'SQL'
SELECT COUNT(*) FROM dba_constraints WHERE owner='TELCO' AND table_name='CDR_USAGE' AND constraint_type IN ('P','U');
SQL
)"
  expect "$c: SUBSCRIBER has a primary key" 1 "$(sq $c pdb <<'SQL'
SELECT COUNT(*) FROM dba_constraints WHERE owner='TELCO' AND table_name='SUBSCRIBER' AND constraint_type='P';
SQL
)"
  expect "$c: no index except the SUBSCRIBER primary key" 0 "$(sq $c pdb <<'SQL'
SELECT COUNT(*) FROM dba_indexes i WHERE i.table_owner='TELCO' AND NOT EXISTS (SELECT 1 FROM dba_constraints k WHERE k.owner=i.table_owner AND k.index_name=i.index_name AND k.constraint_type='P' AND k.table_name='SUBSCRIBER');
SQL
)"
  atleast1 "$c: a profile with a failed-login limit exists" "$(sq $c pdb <<'SQL'
SELECT COUNT(*) FROM dba_profiles WHERE resource_name='FAILED_LOGIN_ATTEMPTS' AND profile<>'DEFAULT' AND limit NOT IN ('UNLIMITED','DEFAULT');
SQL
)"
  local a b
  a=$(sq $c root <<'SQL'
SELECT COUNT(*) FROM audit_unified_enabled_policies e JOIN audit_unified_policies p ON p.policy_name=e.policy_name WHERE p.audit_option='LOGON' AND e.failure='YES';
SQL
)
  b=$(sq $c pdb <<'SQL'
SELECT COUNT(*) FROM audit_unified_enabled_policies e JOIN audit_unified_policies p ON p.policy_name=e.policy_name WHERE p.audit_option='LOGON' AND e.failure='YES';
SQL
)
  atleast1 "$c: failed-logon audit policy enabled (root + PDB)" "$(( ${a:-0} + ${b:-0} ))"
  echo "INFO  $c: Oracle-maintained accounts still OPEN (review: should be only SYS/SYSTEM-like): $(sqall $c pdb <<'SQL'
SELECT username FROM dba_users WHERE oracle_maintained='Y' AND account_status='OPEN' ORDER BY 1;
SQL
)"
}

{
echo "Environment verification, $(date -u '+%Y-%m-%d %H:%M:%S') UTC"
echo "== Containers"
for c in src-db tgt-db gg; do
  if docker ps --format '{{.Names}}' | grep -qx "$c"; then ok "container $c is running"; else bad "container $c is running" "not running"; fi
done
echo "== SRC database settings"
expect "SRC is in ARCHIVELOG mode" ARCHIVELOG "$(sq src-db root <<'SQL'
SELECT log_mode FROM v$database;
SQL
)"
expect "SRC FRA size is 8 GiB" 8589934592 "$(sq src-db root <<'SQL'
SELECT value FROM v$parameter WHERE name='db_recovery_file_dest_size';
SQL
)"
expect "SRC has 3 redo groups of 50 MB" "3 groups, min 52428800, max 52428800" "$(sq src-db root <<'SQL'
SELECT COUNT(*)||' groups, min '||MIN(bytes)||', max '||MAX(bytes) FROM v$log;
SQL
)"
check_schema src-db
check_schema tgt-db
echo "== GoldenGate (informational: process state depends on whether they were started)"
MSYS_NO_PATHCONV=1 docker exec gg sh -c '/u01/ogg/bin/adminclient <<EOF
CONNECT http://localhost:8080 AS $OGG_ADMIN PASSWORD $OGG_ADMIN_PWD
INFO ALL
INFO CREDENTIALSTORE DOMAIN OracleGoldenGate
EOF' 2>&1 | grep -viE 'password|copyright|version|linux|character set|^[[:space:]]*$'
echo "== Row counts (informational)"
echo "INFO  SRC CDR_USAGE rows: $(sq src-db pdb <<'SQL'
SELECT COUNT(*) FROM telco.cdr_usage;
SQL
)"
echo "INFO  TGT CDR_USAGE rows: $(sq tgt-db pdb <<'SQL'
SELECT COUNT(*) FROM telco.cdr_usage;
SQL
)"
echo "== Result: $PASS passed, $FAIL failed"
} | tee "$OUT"
