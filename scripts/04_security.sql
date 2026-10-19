whenever sqlerror continue
alter session set container = FREEPDB1;

create profile app_profile limit
  failed_login_attempts 5
  password_lock_time 1/24
  password_life_time 90;

alter user pdbadmin account lock;
alter user sysrac   account lock;
alter user system   account lock;

audit policy ora_logon_failures whenever not successful;

set linesize 150 pagesize 100
col username format a20
col account_status format a20
col profile format a20
col resource_name format a25
col limit format a15
col policy_name format a25
select username, account_status from dba_users
 where username in ('PDBADMIN','SYSRAC','SYSTEM','SYS','TELCO') order by 1;
select profile, resource_name, limit from dba_profiles
 where profile = 'APP_PROFILE'
   and resource_name in ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME','PASSWORD_LIFE_TIME');
select policy_name, enabled_option, success, failure from audit_unified_enabled_policies
 where policy_name in ('ORA_LOGON_FAILURES','ORA_LOGIN_LOGOUT');
