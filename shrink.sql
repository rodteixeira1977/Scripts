select 'alter database datafile '''||dtf.FILE_NAME||''' resize '||
       to_char(greatest(trunc((nvl(HWM.HWM_MB, 1) * blk.value)/1024/1024) + 10, 10 ))||'M;            ----- ATUAL: ' ||round(dtf.bytes/1024/1024/1024, 2)
from 
  (select to_number(value) value from v$parameter where name = 'db_block_size') blk,
  dba_data_files dtf
  left join (
     select file_id, 
            max(block_id + blocks - 1) HWM_MB
     from dba_extents 
     group by file_id 
  ) HWM on (hwm.file_id = dtf.file_id)
order by dtf.file_id
/
