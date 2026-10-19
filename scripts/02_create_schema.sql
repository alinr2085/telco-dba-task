whenever sqlerror exit failure
alter session set container = FREEPDB1;

create user telco no authentication
  default tablespace users
  quota unlimited on users;

create table telco.subscriber (
  subscriber_id  number primary key,
  msisdn         varchar2(15),
  tariff_code    varchar2(10),
  status         varchar2(10),
  created_at     date
) tablespace users;

create table telco.cdr_usage (
  call_id       number,
  msisdn        varchar2(15),
  cell_id       number,
  call_start    date,
  duration_sec  number,
  charge_amt    number(12,3)
) tablespace users
partition by range (call_start)
interval (numtodsinterval(1,'DAY'))
(partition p_init values less than (date '2026-01-01'));

set linesize 150
col table_name format a15
col index_name format a30
col partition_name format a15
col interval format a30
select table_name, partitioning_type, interval from dba_part_tables where owner = 'TELCO';
select table_name, partition_name from dba_tab_partitions where table_owner = 'TELCO';
select table_name, index_name, index_type from dba_indexes where owner = 'TELCO';
