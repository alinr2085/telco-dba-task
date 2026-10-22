#!/bin/bash
# GoldenGate control through adminclient inside the gg container (passwords never leave the container).
# Usage: ./scripts/18_gg_ctl.sh start|stop|status|lag|report
run() {
  MSYS_NO_PATHCONV=1 docker exec -i gg sh -c "/u01/ogg/bin/adminclient <<EOF
CONNECT http://localhost:8080 AS \$OGG_ADMIN PASSWORD \$OGG_ADMIN_PWD
$1
EOF" 2>&1 | grep -viE 'password|copyright|^version|^linux|character set|^[[:space:]]*$'
}
case "${1:-status}" in
  start)  run $'START EXTRACT EXT1\nSTART REPLICAT REP1'; sleep 5; run 'INFO ALL' ;;
  stop)   run $'STOP REPLICAT REP1\nSTOP EXTRACT EXT1' ;;
  status) run 'INFO ALL' ;;
  lag)    run $'LAG EXTRACT EXT1\nLAG REPLICAT REP1' ;;
  report) run 'VIEW REPORT EXT1' | tail -40; echo ----; run 'VIEW REPORT REP1' | tail -40 ;;
  *) echo "usage: $0 start|stop|status|lag|report"; exit 1 ;;
esac
