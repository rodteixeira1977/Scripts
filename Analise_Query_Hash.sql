-------- Ultimo PLAN_HASH_VALUE na V$SQL:---------  
select inst_id,SQL_ID,plan_hash_value,executions,end_of_fetch_count,first_load_time,disk_reads,buffer_gets,rows_processed,last_active_time 
from gv$sqlarea where sql_id = TRIM('&SQL_ID');


-------- Planos em cache -------- 	

WITH
p AS (
SELECT plan_hash_value
  FROM gv$sql_plan
 WHERE sql_id = TRIM('&SQL_ID')
   AND other_xml IS NOT NULL
 UNION
SELECT plan_hash_value
  FROM dba_hist_sql_plan
 WHERE sql_id = TRIM('&SQL_ID')
   AND other_xml IS NOT NULL ),
m AS (
SELECT plan_hash_value,
       SUM(elapsed_time)/SUM(executions) avg_et_secs
  FROM gv$sql
 WHERE sql_id = TRIM('&SQL_ID')
   AND executions > 0
 GROUP BY
       plan_hash_value ),
a AS (
SELECT plan_hash_value,
       SUM(elapsed_time_total)/SUM(executions_total) avg_et_secs
  FROM dba_hist_sqlstat
 WHERE sql_id = TRIM('&SQL_ID')
   AND executions_total > 0
 GROUP BY
       plan_hash_value )
SELECT p.plan_hash_value,
       ROUND(NVL(m.avg_et_secs, a.avg_et_secs)/1e6, 3) avg_et_secs
  FROM p, m, a
 WHERE p.plan_hash_value = m.plan_hash_value(+)
   AND p.plan_hash_value = a.plan_hash_value(+)
 ORDER BY
       avg_et_secs NULLS LAST;

	   
-------- HISTORICO DE EXECUÇÕES -------- 
select 
b.begin_interval_time         BEGIN, 
a.instance_number             INST,
a.sql_id                      SQL_ID,
a.plan_hash_value             PLAN_HASH,
a.executions_delta            EXEC,
a.rows_processed_delta        ROWS_PROC,
a.buffer_gets_delta           BUFFER_GETS,
a.disk_reads_delta            DISK_READS,
a.elapsed_time_delta/1000000     ELAPSED_TIME,
a.cpu_time_delta/1000000         CPU_TIME,
a.iowait_delta                  IO_WAIT,
a.apwait_delta                  APP_WAIT,
a.ccwait_delta                  CONCUR_WAIT,
a.direct_writes_delta           DIRECT_WRITES,
a.physical_read_requests_delta  PHI_READS_REQ,
a.physical_read_bytes_delta     PHI_READS_BYTES,
a.physical_write_requests_delta PHI_WRITES_REQ,
a.physical_write_bytes_delta    PHI_WRITES_BYTES
from 
dba_hist_sqlstat a,
dba_hist_snapshot b
where 
a.snap_id=b.snap_id and
a.sql_id='&SQL_ID'
order by 1 desc; 


-------- Trazer sql _text -------- 
select a.instance_number inst_id,
a.snap_id,a.plan_hash_value,
s.sql_id,
to_char(begin_interval_time,'dd-mon-yy hh24:mi') btime,
abs(extract(minute from (end_interval_time-begin_interval_time)) + extract(hour from (end_interval_time-begin_interval_time))*60 + extract(day from (end_interval_time-begin_interval_time))*24*60) minutes,
executions_delta executions,
round(ELAPSED_TIME_delta/1000000/greatest(executions_delta,1),4) "avg duration (sec)" ,
s.sql_fulltext
from dba_hist_SQLSTAT a, dba_hist_snapshot b,Gv$sql s
where a.snap_id=b.snap_id
and a.instance_number=b.instance_number
and s.sql_id = a.sql_id
--and a.module = 'Sinacor.APE.AlocacaoUnificada.Administracao.WSer'
order by snap_id desc, a.instance_number;

-------- Encontrar plano de execução por período -------- 

SELECT DISTINCT sql_id, plan_hash_value
FROM dba_hist_sqlstat dhs,
    (
    SELECT /*+ NO_MERGE */ MIN(snap_id) min_snap, MAX(snap_id) max_snap
    FROM dba_hist_snapshot ss
    WHERE ss.begin_interval_time BETWEEN (SYSDATE - &No_Days) AND SYSDATE
    ) s
WHERE dhs.snap_id BETWEEN s.min_snap AND s.max_snap
  AND dhs.sql_id IN ( '847m9zkv&SQL_ID2qr7v')