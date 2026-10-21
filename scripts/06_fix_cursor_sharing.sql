ALTER SESSION SET CONTAINER = FREEPDB1;
SET PAGESIZE 100 LINESIZE 200
COLUMN name FORMAT A20
COLUMN value FORMAT A10
PROMPT == BEFORE
SELECT name, value FROM v$parameter WHERE name = 'cursor_sharing';
ALTER SYSTEM SET cursor_sharing = FORCE SCOPE = BOTH;
PROMPT == AFTER
SELECT name, value FROM v$parameter WHERE name = 'cursor_sharing';
