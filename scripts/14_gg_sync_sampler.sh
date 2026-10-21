#!/bin/bash
# Usage: 14_gg_sync_sampler.sh <minutes> <outfile>
# Every 60 s: row counts on SRC and TGT and the difference of CDR_USAGE.
MIN=${1:-70}; OUT=${2:-outputs/62_gg_sync_samples.csv}
Q="SET HEADING OFF FEEDBACK OFF PAGESIZE 0
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT (SELECT COUNT(*) FROM telco.subscriber)||','||(SELECT COUNT(*) FROM telco.cdr_usage) FROM dual;"
echo "time_utc,src_subscriber,src_cdr,tgt_subscriber,tgt_cdr,cdr_diff" > "$OUT"
for i in $(seq 1 "$MIN"); do
  t=$(date -u '+%H:%M:%S')
  s=$(echo "$Q" | MSYS_NO_PATHCONV=1 docker exec -i src-db sqlplus -s "/ as sysdba" | tr -d ' \r' | grep ',' | tail -1)
  g=$(echo "$Q" | MSYS_NO_PATHCONV=1 docker exec -i tgt-db sqlplus -s "/ as sysdba" | tr -d ' \r' | grep ',' | tail -1)
  ss=${s%,*}; sc=${s#*,}; ts=${g%,*}; tc=${g#*,}
  echo "$t,${ss:-0},${sc:-0},${ts:-0},${tc:-0},$(( ${sc:-0} - ${tc:-0} ))" >> "$OUT"
  sleep 60
done
