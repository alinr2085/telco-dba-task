alter session set container = FREEPDB1;
set linesize 150
col tablespace_name format a20
select sys_context('USERENV','CON_NAME') as current_container from dual;
select tablespace_name, status from dba_tablespaces order by 1;
select name, value from v$parameter where name = 'job_queue_processes';
