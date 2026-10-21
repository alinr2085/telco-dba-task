#!/bin/bash
# Usage: 16_gg_lag_sampler.sh <minutes> <outfile>
# Every 60 s: Extract and Replicat lag in seconds (adminclient inside the gg container).
MIN=${1:-70}; OUT=${2:-outputs/63_gg_lag_samples.csv}
echo "time_utc,extract_lag_s,replicat_low_lag_s,replicat_high_lag_s" > "$OUT"
for i in $(seq 1 "$MIN"); do
  t=$(date -u '+%H:%M:%S')
  r=$(MSYS_NO_PATHCONV=1 docker exec gg sh -c '/u01/ogg/bin/adminclient <<EOF
CONNECT http://localhost:8080 AS $OGG_ADMIN PASSWORD $OGG_ADMIN_PWD
LAG EXTRACT EXT1
LAG REPLICAT REP1
EOF' 2>&1)
  e=$(echo "$r" | grep -o 'Last record lag [0-9]*' | grep -o '[0-9]*$')
  lo=$(echo "$r" | grep -o 'Low watermark lag: [0-9]*' | grep -o '[0-9]*$')
  hi=$(echo "$r" | grep -o 'High watermark lag: [0-9]*' | grep -o '[0-9]*$')
  echo "$t,${e:-NA},${lo:-NA},${hi:-NA}" >> "$OUT"
  sleep 60
done
