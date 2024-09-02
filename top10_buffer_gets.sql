--
-- TOP 10 intruções SQL por Buffer Gets
set pagesize 200
set linesize 600
set tab off;
col elapsed_time for 999999999999999
col cpu_time for 999999999999999
col sql_text for a60
select username,
executions,
rows_processed,
round(cpu_time) "cpu_time(s)",
buffer_gets,
round(buffer_gets/executions) bg_por_exec,
sql_id,
substr(sql_text,1,60) sql_text
from (select b.username ,
a.executions ,
a.rows_processed ,
(cpu_time/1000000) cpu_time,
a.buffer_gets buffer_gets,
a.sql_id,
substr(sql_text,1,60) sql_text
 from sys.v_$sqlarea a,
sys.all_users b
 where a.parsing_user_id=b.user_id
 and b.username not in ('SYS','SYSTEM','SYSMAN','ORACLE_OCM','DBSNMP','MDSYS','XDB','EXFSYS')
 order by 5 desc)
where rownum < 11;
set lines 200 pages 100