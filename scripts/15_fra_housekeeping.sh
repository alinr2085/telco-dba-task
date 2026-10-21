#!/bin/bash
# Every 10 minutes delete archived logs older than 15 minutes (lab only, no backups exist).
MIN=${1:-75}
for i in $(seq 1 $((MIN/10))); do
  MSYS_NO_PATHCONV=1 docker exec -i src-db rman target / <<'EOF'
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-15/1440';
EOF
  sleep 600
done
