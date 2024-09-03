REM --------------------------------------------------------------------------------------------------
REM Author: Riyaj Shamsudeen @OraInternals, LLC
REM         www.orainternals.com
REM
REM Functionality: This script is to print details about a specific session for the past N minutes
REM **************
REM Source  : gv$active_session_history
REM
REM Note : 1. Keep window 160 columns for better visibility.
REM
REM Exectution type: Execute from sqlplus or any other tool.
REM
REM No implied or explicit warranty
REM
REM Please send me an email to rshamsud@orainternals.com, if you enhance this script :-)
REM  This is a open Source code and it is free to use and modify.
REM --------------------------------------------------------------------------------------------------
REM
prompt ALL outputs for a session
prompt =========================
prompt 
undef session_id
undef minutes
undef inst_id
prompt  ========================================
prompt  Top 30 wait events in the past N minutes
prompt  ========================================
REM
set lines 160 pages 100
set verify off
undef minutes session_id inst_id

select * from (
select event,  inst_id, 
   sum(decode(ash.session_state,'WAITING',1,0)) cnt_waiting , 
   module, action
from  gv$active_session_history ash
where sample_time > sysdate - &&minutes /( 60*24)
and  ash.session_id=&&session_id
and  ash.inst_id=&&inst_id
group by event ,inst_id, module, action
order by 3 desc
) where rownum <=30
/
REM
prompt  ===================================================
prompt  Top 30 sql_ids consuming CPUs in the past &&minutes minutes ( sid : &&session_id)
prompt  ===================================================
REM
select * from (
select sql_id,  inst_id, 
      sum(decode(ash.session_state,'ON CPU',1,0))  cnt_on_cpu,
      sum(decode(ash.session_state,'WAITING',1,0)) cnt_waiting
from  gv$active_session_history ash
where sample_time > sysdate - &&minutes /( 60*24)
and  ash.session_id=&&session_id
and  ash.inst_id=&&inst_id
group by sql_id, inst_id
order by 3 desc
) where rownum <=30
/
REM
col cnt_sessions format 99999
col event format A40
REM
prompt  =======================================================================
prompt  Top 30 sql_ids waiting for an event - Intersection of above two + event ( sid : &&session_id)
prompt  =======================================================================
REM
select * from (
select sql_id,  inst_id,  
   sum(decode(ash.session_state,'ON CPU',1,0))  cnt_on_cpu,
   sum(decode(ash.session_state,'WAITING',1,0)) cnt_waiting ,
   event , count(distinct(session_id||session_serial#)) cnt
from  gv$active_session_history ash
where sample_time > sysdate - &&minutes /( 60*24)
and  ash.session_id=&&session_id
and  ash.inst_id=&&inst_id
group by event ,inst_id, sql_id , event
order by 4 desc
) where rownum <=30
/
