alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';

select PLAN_VALUES.SQL_ID, PLAN_VALUES.old_plan_hash_value,TIME_VALUESMIN.avg_etime,PLAN_VALUES.old_timestamp,
                           PLAN_VALUES.NEW_plan_hash_value,TIME_VALUESMAX.avg_etime,PLAN_VALUES.new_timestamp
           from (select
                  sql_id,
                  old_plan_hash_value,
                  old_timestamp,
                  new_plan_hash_value,
                  new_timestamp
                from
                 (select
                    sql_id,
                    max(decode(seq,2,plan_hash_value,null)) old_plan_hash_value,
                    max(decode(seq,2,timestamp,null)) old_timestamp,
                    max(decode(seq,1,plan_hash_value,null)) new_plan_hash_value,
                    max(decode(seq,1,timestamp,null)) new_timestamp
                  from
                   (select
                      sql_id, plan_hash_value, timestamp,
                      row_number() over(partition by sql_id order by timestamp desc) seq,
                      count(1) over(partition by sql_id) qtde
                    from
                     (select
                        distinct sql_id, plan_hash_value, timestamp
                      from dba_hist_sql_plan))
                  where  seq <= 2 and qtde >= 2
                  group by sql_id)
                where
                  new_timestamp > sysdate-10 and new_timestamp <= sysdate) PLAN_VALUES,
                 (
                 select sql_id,
                             plan_hash_value,
                             (min((elapsed_time_delta / decode(nvl(executions_delta, 0), 0, 1, executions_delta)) / 1000000)) avg_etime
                        from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS
                       where ss.snap_id = S.snap_id
                         and ss.instance_number = S.instance_number
                         and executions_delta > 2
                         and begin_interval_time > sysdate-10 and begin_interval_time <= sysdate
                      group by sql_id, plan_hash_value
                  ) TIME_VALUESMIN,
                 (
                select sql_id,
                             plan_hash_value,
                             (min((elapsed_time_delta / decode(nvl(executions_delta, 0), 0, 1, executions_delta)) / 1000000)) avg_etime
                        from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS
                       where ss.snap_id = S.snap_id
                         and ss.instance_number = S.instance_number
                         and executions_delta > 2
                         and begin_interval_time > sysdate-10 and begin_interval_time <= sysdate
                      group by sql_id, plan_hash_value ) TIME_VALUESMAX
                  WHERE PLAN_VALUES.SQL_ID = TIME_VALUESMIN.SQL_ID
                    AND PLAN_VALUES.SQL_ID = TIME_VALUESMAX.SQL_ID
                    AND PLAN_VALUES.old_plan_hash_value = TIME_VALUESMIN.plan_hash_value
                    AND PLAN_VALUES.new_plan_hash_value = TIME_VALUESMAX.plan_hash_value;