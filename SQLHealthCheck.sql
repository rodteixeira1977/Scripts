## SQL - HealthCheck###
set echo off
set heading off
set lines 500 pages 500

prompt Health Check Report for Database  
select chr(9)||chr(9)||chr(9)|| name from V$database;
prompt Instance Name
select  INSTANCE_NAME, to_char(STARTUP_TIME,'dd-MON-yyyy hh24:mi') STARTUP_TIME from V$instance;

set heading on
col OWNER for a15
col OBJECT_NAME for  a30
break on owner on object_name
prompt ############################################################################
prompt Invalid Objects Currently in database
prompt ############################################################################

select owner, object_name, object_type from dba_objects where status <> 'VALID'
order by 1,2,3;

clear breaks

prompt ############################################################################
prompt Blocking Session in Database
prompt ############################################################################

select sid, serial#, username, status, event, BLOCKING_INSTANCE, BLOCKING_SESSION, BLOCKING_SESSION_STATUS, FINAL_BLOCKING_INSTANCE, FINAL_BLOCKING_SESSION_STATUS, FINAL_BLOCKING_SESSION
from v$session
where blocking_session is not null;

prompt ############################################################################
prompt Details of Blocking SIDs
prompt ############################################################################

select sid, serial#, username, status, event from V$session
where sid in (select distinct BLOCKING_SESSION from v$session
where blocking_session is not null);

prompt ############################################################################
prompt Sessions > 20MB PGA
prompt ############################################################################


column PGA_ALLOC_MEM format 99,990
column PGA_USED_MEM format 99,990
column inst_id format 99
column username format a15
column program format a40
column logon_time format a20

select s.inst_id, s.sid, s.username, s.logon_time, s.program, PGA_USED_MEM/1024/1024 PGA_USED_MEM, PGA_ALLOC_MEM/1024/1024 PGA_ALLOC_MEM
from gv$session s
, gv$process p
Where s.paddr = p.addr
and s.inst_id = p.inst_id
and PGA_USED_MEM/1024/1024 > 20  -- pga_used memory over 20mb
order by PGA_USED_MEM;

prompt ############################################################################
prompt Current Wait Events in the Database
prompt ############################################################################


col wait_class for a40
col event for a60
select wait_class, event, count(*)  from v$session
where username is not null
group by wait_class,event
order by 3,1,2;


prompt ############################################################################
prompt Detailed Sess Waits - (sesswaits.sql)
prompt ############################################################################


col seconds_in_wait heading "Wait|(Sec.)" format 9,999,999
select event,
       sid,BLOCKING_SESSION,sql_id,
       p1,
--       p1text,
       p2,
--       p2text,
SECONDS_IN_WAIT
from v$session
where event not in ('SQL*Net message from client',
                'SQL*Net message to client',
                'pipe get',
                'pmon timer',
                'rdbms ipc message',
                'Streams AQ: waiting for messages in the queue',
                'Streams AQ: qmn coordinator idle wait',
                'Streams AQ: waiting for time management or cleanup tasks',
                'PL/SQL lock timer',
                'Streams AQ: qmn slave idle wait',
                'jobq slave wait',
                'queue messages',
                'io done',
                'i/o slave wait',
                'sbtwrite2',
                'async disk IO',
                'smon timer')
order by event, p1,p2 ;


prompt ############################################################################
prompt Wait Events in Last 7 Minutes - Database
prompt ############################################################################

select wait_class, event, count(*)  from v$active_session_history
where sample_time > sysdate - 1/192
group by wait_class,event
order by 3,1,2;


prompt ############################################################################
prompt Wait Events in Last 15 Minutes - Database
prompt ############################################################################

select wait_class, event, count(*)  from v$active_session_history
where sample_time > sysdate - 1/96
group by wait_class,event
order by 3,1,2;


prompt ############################################################################
prompt Wait Events in Last 60 Minutes - Database
prompt ############################################################################

select wait_class, event, count(*)  from v$active_session_history
where sample_time > sysdate - 1/24
group by wait_class,event
order by 3,1,2;

prompt ############################################################################
prompt Current IO Functions Statistics
prompt ############################################################################


col function_name    format a25         heading "File Type"
col reads            format 99,999,999  heading "Reads"
col writes           format 99,999,999  heading "Writes"
col number_of_waits  format 99,999,999  heading "Waits"
col wait_time_sec    format 999,999,999 heading "Wait Time|Sec"
col avg_wait_ms      format 999.99      heading "Avg|Wait ms"

set lines 80
set pages 10000

select
   function_name,
   small_read_reqs + large_read_reqs reads,
   small_write_reqs + large_write_reqs writes,
   wait_time/1000 wait_time_sec,
   case when number_of_waits > 0 then
          round(wait_time / number_of_waits, 2)
       end avg_wait_ms
from
   v$iostat_function
order by
    wait_time desc;


set heading off
prompt ############################################################################
prompt Load Average For Server
prompt ############################################################################
 select 'Load Average - ' ||   value  || ' NUM_CPUS  - ' || (select   value   from v$osstat where stat_name = 'NUM_CPUS') || ' LA/pCPU - ' || value/(select   value   from v$osstat where stat_name = 'NUM_CPUS')
   from v$osstat
 where stat_name = 'LOAD';

set pagesize 60
column "Tablespace" heading "Tablespace Name" format a30
column "Size" heading "Tablespace|Size (mb)" format 9999999.9
column "Used" heading "Used|Space (mb)" format 9999999.9
column "Left" heading "Available|Space (mb)" format 9999999.9
column "PCTFree" heading "% Free" format 999.99

ttitle left "Tablespace Space Allocations"
break on report
-- compute sum of "Size", "Left", "Used" on report
select /*+ RULE */
t.tablespace_name,
NVL(round(((sum(u.blocks)*p.value)/1024/1024),2),0) Used_mb,
t.Tot_MB,
NVL(round(sum(u.blocks)*p.value/1024/1024/t.Tot_MB*100,2),0) "USED %"
from v$sort_usage u,
v$parameter p,
(select tablespace_name,sum(bytes)/1024/1024 Tot_MB
from dba_temp_files
group by tablespace_name
) t
where p.name = 'db_block_size'
and u.tablespace (+) = t.tablespace_name
group by
t.tablespace_name,p.value,t.Tot_MB
order by 1,2;

prompt ############################################################################
PROMPT ======================= Total TEMP_TS consuming =======================
prompt ############################################################################
select tablespace, sum(blocks)*8192/1024/1024 consuming_TEMP_MB from
v$session, v$sort_usage where tablespace in (select tablespace_name from
dba_tablespaces where contents = 'TEMPORARY') and session_addr=saddr
group by tablespace;

prompt ############################################################################
PROMPT ======================= Sessions consuming TEMP_TS more than 10 MB =======================
prompt ############################################################################
select sid, tablespace,
sum(blocks)*8192/1024/1024 consuming_TEMP_MB from v$session,
v$sort_usage where tablespace in (select tablespace_name from
dba_tablespaces where contents = 'TEMPORARY') and session_addr=saddr
group by sid, tablespace having sum(blocks)*8192/1024/1024 > 10
order by sum(blocks)*8192/1024/1024 desc ;



prompt ############################################################################
PROMPT ======================= Current Locked Objects =======================
prompt ############################################################################

 col owner for a25
 col object_name for a35
 col oracle_username for a25
col os_user_name for a25

 SELECT B.Owner, B.Object_Name,b.object_type, A.Oracle_Username, A.OS_User_Name, A.SESSION_ID, A.LOCKED_MODE
 FROM V$Locked_Object A, All_Objects B
 WHERE A.Object_ID = B.Object_ID;