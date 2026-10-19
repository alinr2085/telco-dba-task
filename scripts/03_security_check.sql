alter session set container = FREEPDB1;
set linesize 150 pagesize 100
col username format a30
col account_status format a20
col profile format a20
col resource_name format a25
col limit format a20
col policy_name format a30
col enabled_option format a20

prompt === Open accounts
select username, account_status, profile from dba_users where account_status = 'OPEN' order by 1;
prompt === DEFAULT profile limits
select profile, resource_name, limit from dba_profiles
 where profile = 'DEFAULT'
   and resource_name in ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME','PASSWORD_LIFE_TIME');
prompt === Enabled audit policies
select policy_name, enabled_option from audit_unified_enabled_policies;
