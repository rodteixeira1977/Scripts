 WITH 
  stats_auto AS
                (select status , client_name
                 from dba_autotask_client 
                 where client_name like 'auto optimizer%'),
  stats_wndw AS
                (select count(1) actived
                 from dba_autotask_window_clients
                 where autotask_status = 'ENABLED'
                   and optimizer_stats = 'ENABLED'),
  stats_schd AS
                (select count(dsw.enabled) actived
                 from dba_autotask_window_clients dawc
                    , dba_scheduler_windows       dsw
                 where dawc.autotask_status = 'ENABLED'
                   and dawc.optimizer_stats = 'ENABLED'
                   and dsw.enabled          = 'TRUE'
                   and dsw.window_name      = dawc.window_name),
  stats_exec AS
                (select wd.window_name
                      , wd.req_start_date start_date
                      , wd.log_date end_date
                 from dba_scheduler_window_details wd
                 where wd.log_id = (select max(dswd.log_id)
                                    from dba_autotask_window_clients  dawc
                                       , dba_scheduler_windows        dsw
                                       , dba_scheduler_window_details dswd
                                    where dawc.autotask_status = 'ENABLED'
                                      and dawc.optimizer_stats = 'ENABLED'
                                      and dsw.enabled          = 'TRUE'
                                      and dsw.window_name      = dawc.window_name
                                      --and dsw.owner           = 'SAFEPAY_ADM'
                                      and dswd.window_name     = dsw.window_name)),
  stats_log  AS
                (select trim(decode(sl.status,'SUCCEEDED',0,'STOPPED',2,1) || ', '  ||
                        sl.job_name || ' - Termino => ' || sl.end_time     || ' - ' ||
                        case when trim(sl.additional_info) is not null
                             then 'Info: ' || trim(sl.additional_info)
                             else 'Job: '  || sl.log_id
                        end) Message
                      , end_execution
                 from (select dsjl.log_id
                            , dsjl.job_name
                            , dsjrd.actual_start_date end_execution
                            , to_char(dsjrd.actual_start_date+dsjrd.run_duration, 'hh24:mi:ss') end_time
                            , dsjrd.additional_info
                            , dsjrd.status
                       from dba_scheduler_job_log         dsjl
                          , dba_scheduler_job_run_details dsjrd
                       where dsjl.job_name = dsjrd.job_name(+)
                         and upper(trim(dsjl.additional_info)) like '%GATHER_STATS_PROG%'
                       order by 1 desc) sl
                 where rownum <= 1)
select case when (select status from stats_auto) = 'ENABLED'
            then case when (select actived from stats_wndw) > 0
                      then case when (select actived from stats_schd) > 0
                                then case when (select count(1) from stats_log where end_execution between (select start_date from stats_exec) 
                                                                                                       and (select end_date   from stats_exec)) > 0
                                          then decode((select count(sl1.Message) from stats_log sl1), 0, '1, Nenhum scheduler de ESTATISTICA agendado no banco de dados',
                                                                                                         (select sl2.Message from stats_log sl2))
                                          else (select '2' || substr(sl2.Message, 2) from stats_log sl2)
                                     end
                                else '2, Scheduler de ESTATISTICA desabilitado (DBA_SCHEDULER_WINDOWS)'
                           end
                      else '2, Nenhuma janela de ESTATISTICA ativado (DBA_AUTOTASK_CLIENT)'
                 end
            else '2, Scheduler de ESTATISTICA desabilitado (DBA_AUTOTASK_WINDOW_CLIENTS)' --ok
       end Return
from dual;