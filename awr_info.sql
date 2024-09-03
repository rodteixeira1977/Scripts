-- retorna informacoes do AWR

select * from dba_hist_wr_control;
select occupant_desc, space_usage_kbytes from v$sysaux_occupants where occupant_name like '%AWR%';
