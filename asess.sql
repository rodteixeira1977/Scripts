column sid format 999999;
column serial# format 999999;
column IDLE format a10
column osuser format a19
column PROGRAM format a50
column USERNAME format a25
column LOGON_TIME format a20

SELECT inst_id, sid,
serial#,
osuser,
username,
status,
TO_CHAR(logon_time, 'DAY HH24:MI:SS') LOGON_TIME,
FLOOR(last_call_et/3600)||':'||
FLOOR(MOD(last_call_et,3600)/60)||':'||
MOD(MOD(last_call_et,3600),60) IDLE, program,machine,
SQL_ID
FROM gv$session
WHERE status = 'ACTIVE' AND USERNAME  IS NOT NULL
ORDER BY last_call_et;

