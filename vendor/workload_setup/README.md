# TELCO Billing Workload - User Guide

## 1. Purpose

`workload_setup.sql` creates a simulated workload of the TELCO billing application on the
SRC database. It generates call-record, rating and balance-inquiry transactions at a fixed
rate, so that the database can be observed and analysed under realistic load
(for example with an AWR report).

The script is the property of the company. **You must not modify it.** The only things you
can choose are the passwords typed when the script runs, and the helper commands in section 6.

## 2. Prerequisites

| Item | Requirement |
|---|---|
| Database | Oracle Database 19c (or Oracle Database Free), the SRC database |
| Connection | `SYS` (`AS SYSDBA`) connected to the **PDB**, not to `CDB$ROOT` |
| Client | `sqlplus` (SQL Developer and Toad cannot read hidden password input) |
| Schema | `TELCO` with the tables `SUBSCRIBER` and `CDR_USAGE` already created, as described in the task sheet |
| Data | `SUBSCRIBER` must be empty; the script loads the subscriber data |
| Tablespace | `USERS` must exist |
| Parameter | `job_queue_processes` must be at least 16 |

If a prerequisite is missing, the script stops at the start with a message that names the
missing object, and nothing is started.

## 3. Run

Run the script once:

```
sqlplus sys@//<host>:1521/<pdb_service> as sysdba @workload_setup.sql
```

The script asks for two passwords. The input is hidden.

| Prompt | Used for |
|---|---|
| `Password for the application user TELCO_APP` | The application user that the workload represents |
| `Password for the workload owner TELCO_LOAD` | The internal owner of the workload package |

Passwords must not contain double quotes (`"`) or ampersands (`&`).
Use the same passwords again if the script is run a second time; an existing user keeps its
old password and the typed value is ignored.

## 4. What the script does

1. Checks the environment (PDB, tables, columns, tablespace).
2. Creates the users `TELCO_APP` and `TELCO_LOAD` if they do not exist.
3. Creates the sequence `TELCO.CDR_SEQ` if it does not exist.
4. Loads 200,000 rows into `TELCO.SUBSCRIBER` if the table is empty, and gathers its statistics.
5. Grants the required privileges.
6. Installs the workload package `TELCO_LOAD.TELCO_WORKLOAD`. Its source is not readable.
7. Starts the workload in the background and returns.

## 5. The workload

| Setting | Value |
|---|---|
| Target rate | 500 business transactions per second |
| Sessions | 16 database sessions |
| Duration | 3,900 seconds (65 minutes) |
| Execution | Background jobs of the Oracle scheduler; closing your terminal does not stop it |

The workload stops on its own when the time is over. Running the script again while a
workload is active does not start a second one.

Take your one-hour AWR report while the workload is running (for example from minute 3
to minute 63).

## 6. Helper commands

Run them as `SYS` or `TELCO_LOAD`, after `SET SERVEROUTPUT ON`.

| Command | What it does |
|---|---|
| `EXEC telco_load.telco_workload.monitor;` | Shows the state, the planned end time, the time left and the counters |
| `EXEC telco_load.telco_workload.wait_for_finish;` | Waits and prints a notice (and a terminal bell) when the run has ended |
| `EXEC telco_load.telco_workload.kill_load;` | Stops the workload immediately |

States reported by `monitor`:

| State | Meaning |
|---|---|
| `RUNNING` | The workload is running |
| `STOPPING` | A stop was requested; the sessions are finishing |
| `STOPPED` | The workload was stopped with `kill_load` |
| `FINISHED` | The 65 minutes are over and all sessions have ended |
| `ENDED_ABNORMALLY` | The jobs ended earlier than planned without finishing; see section 8 |

The counters show the total transactions, the average rate and the number of errors.
`wait_for_finish` prints nothing until the run has ended, because SQL*Plus shows the
output only when a call returns. Use `monitor` from a second session for progress.

## 7. Starting again

After a run has finished or was stopped, run `workload_setup.sql` again to start a new one.
Existing users, tables and data are not changed. A workload that is already running is
never started twice.

## 8. Troubleshooting

| Message or symptom | Action |
|---|---|
| `Connected to CDB$ROOT` | Connect to the PDB service and run the script again |
| `The schema TELCO does not exist` or `The table TELCO.<name> does not exist` | Create the schema and tables first, as described in the task sheet |
| `The table TELCO.<name> has no column <name>` | Fix the table definition to match the task sheet |
| `Tablespace USERS does not exist` | Create the tablespace `USERS` |
| `job_queue_processes is <n> but 16 sessions were requested` | Increase the parameter, for example `ALTER SYSTEM SET job_queue_processes = 40;` |
| `TELCO_LOAD.TELCO_WORKLOAD is not valid` | The package did not compile; run `SHOW ERRORS PACKAGE BODY telco_load.telco_workload` and report the output |
| `ENDED_ABNORMALLY` | Check `SELECT job_name, status, additional_info FROM dba_scheduler_job_run_details WHERE owner = 'TELCO_LOAD' ORDER BY log_date DESC;` |
| Errors counter above 0 | `monitor` prints the last error message; keep it as evidence for your analysis |

## 9. Cleaning up

Stop the workload with `kill_load` first. To remove everything that the script created,
connect as `SYS` and run:

```
DROP USER telco_load CASCADE;
DROP USER telco_app CASCADE;
DROP SEQUENCE telco.cdr_seq;
```

The `TELCO` schema and its tables belong to you and are not removed by these commands.
