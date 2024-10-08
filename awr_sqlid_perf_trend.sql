-- Maris Elsins / Pythian / 2013
-- SQL performance trends from AWR
-- Usage: @awr_sqlid_perf_trend.sql <sql_id> <number of days to report> <interval in hours>
-- i.e. @awr_sqlid_perf_trend.sql 46ah673phw02j 2 4
-- i.e. The example above summarizes the execution statistics for sql_id 46ah673phw02j in last 2 days breaking down the statistics by 4 hours.
-- v1.0 - inital version
-- v1.1 - Adding instance_number to the outputs
set ver off pages 50000 lines 260 tab off
undef sql_id
undef days_history
undef interval_hours
def sql_id="&1"
def days_history="&2"
def interval_hours="&3"
col inst for 9999
col time for a19
col executions for 9999999999
col rows_processed_1exec for 9999999.999
col elapsed_time_s_1exec for 9999999.999
col cpu_time_s_1exec for 9999999.999
col iowait_s_1exec for 9999999.999
col clwait_s_1exec for 9999999.999
col apwait_s_1exec for 9999999.999
col ccwait_s_1exec for 9999999.999
col plsexec_time_s_1exec for 9999999.999
col javexec_time_s_1exec for 9999999.999
col buffer_gets_1exec for 999999999999.999
col disk_reads_1exec for 999999999999.999
col direct_writes_1exec for 999999999999.999
BREAK ON inst SKIP 1
select hss.instance_number inst,
    to_char(trunc(sysdate-&days_history+1)+trunc((cast(hs.begin_interval_time as date)-(trunc(sysdate-&days_history+1)))*24/(&interval_hours))*(&interval_hours)/24,'dd.mm.yyyy hh24:mi:ss') time,
    sum(hss.executions_delta) executions,
    round(sum(hss.elapsed_time_delta)/1000000/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) elapsed_time_s_1exec,
    round(sum(hss.cpu_time_delta)/1000000/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) cpu_time_s_1exec,
    round(sum(hss.iowait_delta)/1000000/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) iowait_s_1exec,
    round(sum(hss.clwait_delta)/1000000/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) clwait_s_1exec,
    round(sum(hss.apwait_delta)/1000000/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) apwait_s_1exec,
    round(sum(hss.ccwait_delta)/1000000/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) ccwait_s_1exec,
    --round(sum(hss.plsexec_time_delta)/1000000/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) plsexec_time_s_1exec,
    --round(sum(hss.javexec_time_delta)/1000000/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) javexec_time_s_1exec,
    round(sum(hss.rows_processed_delta)/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) rows_processed_1exec,
    round(sum(hss.buffer_gets_delta)/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) buffer_gets_1exec,
    round(sum(hss.disk_reads_delta)/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) disk_reads_1exec,
    round(sum(hss.direct_writes_delta)/decode(sum(hss.executions_delta),0,null,sum(hss.executions_delta)),3) direct_writes_1exec
from dba_hist_sqlstat hss, dba_hist_snapshot hs
where hss.sql_id='&sql_id'
    and hss.snap_id=hs.snap_id
    and hs.begin_interval_time>=trunc(sysdate)-&days_history+1
group by hss.instance_number, trunc(sysdate-&days_history+1)+trunc((cast(hs.begin_interval_time as date)-(trunc(sysdate-&days_history+1)))*24/(&interval_hours))*(&interval_hours)/24
order by hss.instance_number,trunc(sysdate-&days_history+1)+trunc((cast(hs.begin_interval_time as date)-(trunc(sysdate-&days_history+1)))*24/(&interval_hours))*(&interval_hours)/24;

