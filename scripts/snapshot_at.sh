#!/bin/bash
# snapshot_at.sh — Sleep until a given UTC time and take an AWR snapshot.
# Usage: ./scripts/snapshot_at.sh "2026-10-19 17:03:51" outputs/20_snapshot_end.txt

set -euo pipefail

TARGET_UTC="${1:?Usage: $0 'YYYY-MM-DD HH:MM:SS' output_file}"
OUTFILE="${2:?Usage: $0 'YYYY-MM-DD HH:MM:SS' output_file}"

TARGET_EPOCH=$(date -u -d "$TARGET_UTC" +%s)
NOW_EPOCH=$(date -u +%s)
SLEEP_SEC=$((TARGET_EPOCH - NOW_EPOCH))

if [ "$SLEEP_SEC" -gt 0 ]; then
  echo "Waiting ${SLEEP_SEC} seconds until ${TARGET_UTC} UTC..."
  sleep "$SLEEP_SEC"
else
  echo "Target time ${TARGET_UTC} already passed; taking snapshot immediately."
fi

{
  echo "=== SCRIPT START: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
  echo "=== TARGET TIME: ${TARGET_UTC} UTC ==="
  sqlsrc <<'EOF'
ALTER SESSION SET CONTAINER = FREEPDB1;
SET PAGESIZE 100 LINESIZE 150
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();
SELECT snap_id, begin_interval_time, end_interval_time
  FROM dba_hist_snapshot
 WHERE snap_id = (SELECT MAX(snap_id) FROM dba_hist_snapshot);
EOF
  echo "=== SCRIPT END: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
} | tee "$OUTFILE"
