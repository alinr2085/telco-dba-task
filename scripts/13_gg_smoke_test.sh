#!/bin/bash
# Smoke test of the GoldenGate replication SRC -> TGT on clean tables.
S() { MSYS_NO_PATHCONV=1 docker exec -i src-db sqlplus -s "/ as sysdba"; }
T() { MSYS_NO_PATHCONV=1 docker exec -i tgt-db sqlplus -s "/ as sysdba"; }
COUNTS="SELECT (SELECT COUNT(*) FROM telco.subscriber) AS subscriber_rows, (SELECT COUNT(*) FROM telco.cdr_usage) AS cdr_rows FROM dual;"
echo "== $(date -u '+%Y-%m-%d %H:%M:%S UTC') insert on SRC"
S <<EOF
ALTER SESSION SET CONTAINER = FREEPDB1;
INSERT INTO telco.subscriber VALUES (900001,'989120000001','T1','ACTIVE',SYSDATE);
INSERT INTO telco.subscriber VALUES (900002,'989120000002','T1','ACTIVE',SYSDATE);
INSERT INTO telco.cdr_usage VALUES (900001,'989120000001',1,SYSDATE,60,1.5);
INSERT INTO telco.cdr_usage VALUES (900002,'989120000002',2,SYSDATE,30,0.7);
COMMIT;
EOF
sleep 20
echo "== TGT after insert (expect 2 and 2)"
T <<EOF
ALTER SESSION SET CONTAINER = FREEPDB1;
$COUNTS
EOF
echo "== update on SRC"
S <<EOF
ALTER SESSION SET CONTAINER = FREEPDB1;
UPDATE telco.subscriber SET status = 'SUSPENDED' WHERE subscriber_id = 900001;
UPDATE telco.cdr_usage SET charge_amt = 9.9 WHERE call_id = 900001;
COMMIT;
EOF
sleep 20
echo "== TGT after update (expect SUSPENDED and 9.9)"
T <<EOF
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT status FROM telco.subscriber WHERE subscriber_id = 900001;
SELECT charge_amt FROM telco.cdr_usage WHERE call_id = 900001;
EOF
echo "== delete on SRC"
S <<EOF
ALTER SESSION SET CONTAINER = FREEPDB1;
DELETE FROM telco.subscriber WHERE subscriber_id IN (900001,900002);
DELETE FROM telco.cdr_usage WHERE call_id IN (900001,900002);
COMMIT;
EOF
sleep 20
echo "== counts after delete (expect 0 and 0 on both SRC and TGT)"
echo "SRC:"; S <<EOF
ALTER SESSION SET CONTAINER = FREEPDB1;
$COUNTS
EOF
echo "TGT:"; T <<EOF
ALTER SESSION SET CONTAINER = FREEPDB1;
$COUNTS
EOF
