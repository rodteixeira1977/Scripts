set lines 200
set pages 200
select a.inst_id,
     sql_text,
 sql_id,
 executions,
 a.FETCHES,
 (elapsed_time / 1000000) / executions avg_time,
 a.ROWS_PROCESSED,
 a.ADDRESS,
 a.HASH_VALUE,
 a.PLAN_HASH_VALUE,
 a.SQL_PROFILE,
 A.FIRST_LOAD_TIME
 from gv$sqlarea a
where sql_id IN ('&sqlid');
